import Foundation

/// Walks decoded JSON with dotted key paths. "props.pageProps.*.listings.*.title"
/// — every "*" fans out over an array or a dictionary's values.
enum JSONWalker {
    static func values(_ path: String, in root: Any) -> [Any] {
        var current: [Any] = [root]
        for segment in path.split(separator: ".").map(String.init) where !segment.isEmpty {
            var next: [Any] = []
            for node in current {
                if segment == "*" {
                    if let array = node as? [Any] { next.append(contentsOf: array) }
                    else if let dict = node as? [String: Any] { next.append(contentsOf: dict.values) }
                } else if let dict = node as? [String: Any], let hit = dict[segment] {
                    next.append(hit)
                } else if let array = node as? [Any], let index = Int(segment), array.indices.contains(index) {
                    next.append(array[index])
                }
            }
            current = next
            if current.isEmpty { return [] }
        }
        // Ending on the array itself is the same as asking for its members.
        if current.count == 1, let only = current.first as? [Any] { return only }
        return current
    }

    static func string(_ path: String, in root: Any) -> String? {
        for value in values(path, in: root) {
            if let s = value as? String, !s.isEmpty { return s }
            if let n = value as? NSNumber { return n.stringValue }
            if let a = value as? [Any] {
                if let s = a.compactMap({ $0 as? String }).first { return s }
                if let d = a.compactMap({ $0 as? [String: Any] }).first,
                   let s = d["url"] as? String ?? d["contentUrl"] as? String { return s }
            }
            if let d = value as? [String: Any] {
                if let s = d["url"] as? String ?? d["contentUrl"] as? String ?? d["name"] as? String { return s }
            }
        }
        return nil
    }
}
