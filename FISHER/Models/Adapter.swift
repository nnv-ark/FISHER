import Foundation

/// A site reader, expressed as data rather than code, so a site redesign is a
/// file to republish rather than an app release.
struct Adapter: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var kind: Kind
    var searchURL: String
    var enabled: Bool = true
    var throttle: Double = 3

    /// html: XPath selecting each listing element.
    var listingPath: String?
    /// html: XPath per field, relative to the listing element. Attribute steps
    /// (".../@href") are fine. jsonld/nextdata: dotted key paths, "*" wildcards.
    var fields: [String: String] = [:]
    /// nextdata: key path from the root JSON to the array of listings.
    var collectionPath: String?
    var baseURL: String?
    var defaultCurrency: String = ""
    /// The language its listings are written in — decides which words we
    /// type into its search box.
    var language: String?
    /// How many result pages to read per sweep.
    var pages: Int?
    /// Some sites quote money in cents.
    var priceDivisor: Double?
    /// "http" (default) or "browser" — the latter renders the page in WebKit
    /// first, for sites that turn away plain requests or draw their listings
    /// with script.
    var render: String?
    /// What this source carries. A boat vertical has no opinion about guitars,
    /// so a wish for one should not knock on its door. Empty means everything.
    var concepts: [String]?
    var canaryMinResults: Int = 1
    var notes: String?
    /// Bumped in Resources/adapters.json when the shipped definition of this
    /// source changes. On launch, a bundled version newer than the saved one
    /// replaces it — that is how a selector fix reaches existing installs
    /// without an app update. A source with no version at all is legacy:
    /// it is never touched, so fixes a user already made by hand are safe.
    var adapterVersion: Int?
    /// Set when the source is tuned in Settings ▸ Sources, so a later
    /// bundled fix never silently overwrites hand-edited selectors.
    /// "Restore bundled sources" is the way back.
    var userEdited: Bool?

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case html, jsonld, nextdata
        var id: String { rawValue }
        var title: String {
            switch self {
            case .html:     return "HTML / XPath"
            case .jsonld:   return "JSON-LD (schema.org)"
            case .nextdata: return "Embedded __NEXT_DATA__"
            }
        }
    }

    var lang: String { language ?? "en" }
    var pageCount: Int { max(1, min(pages ?? 2, 10)) }
    var divisor: Double { let d = priceDivisor ?? 1; return d > 0 ? d : 1 }
    var needsBrowser: Bool { (render ?? "http").lowercased() == "browser" }
    /// A fixed page — a club's for-sale list — rather than a search box.
    var isFixedPage: Bool { !searchURL.contains("{terms}") }

    /// Worth asking this source about that wish?
    func carries(_ wish: WantedAd) -> Bool {
        guard let mine = concepts, !mine.isEmpty else { return true }
        let wanted = wish.conceptTerms
        guard !wanted.isEmpty else { return true }   // a bare name could be anything
        return !Set(mine).isDisjoint(with: Set(wanted))
    }

    func url(for query: String, page: Int = 1) -> URL? {
        // Where the terms go into the path rather than a query string — as on
        // Boat24, which files boats by builder: /en/sailingboats/grinde/ — the
        // words have to become a path segment. "GRINDE" would 404.
        let placeholderIsInPath: Bool = {
            guard let slot = searchURL.range(of: "{terms}") else { return false }
            guard let mark = searchURL.firstIndex(of: "?") else { return true }
            return slot.lowerBound < mark
        }()

        let replacement: String
        if placeholderIsInPath {
            replacement = query
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en"))
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
        } else {
            replacement = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        }

        let s = searchURL
            .replacingOccurrences(of: "{terms}", with: replacement)
            .replacingOccurrences(of: "{page}", with: String(page))
        return URL(string: s)
    }
}

/// Result of pointing one adapter at one page. Used by the canary and by
/// Settings ▸ Sources ▸ Test.
struct AdapterProbe {
    var adapter: Adapter
    var url: URL?
    var httpStatus: Int?
    var found: Int
    var withImages: Int
    var samples: [Listing]
    var error: String?

    var verdict: String {
        if let e = error { return "Failed — \(e)" }
        if found == 0 { return "Fetched, but read nothing. Selectors are probably stale." }
        if found < adapter.canaryMinResults { return "Only \(found) — below the canary floor of \(adapter.canaryMinResults)." }
        return "Read \(found) listing\(found == 1 ? "" : "s"), \(withImages) with a picture."
    }
}

extension Array where Element == Adapter {
    /// Merge rules shared by the bundled adapters and a hosted registry:
    /// the saved list wins, except that an incoming definition with a newer
    /// version replaces the saved one. Never touched: entries the user
    /// tuned by hand (`userEdited`, which disabling a source also sets) and
    /// legacy entries saved before versions existed. Unknown incoming ids
    /// are appended in incoming order; the saved order is kept.
    func merged(with incoming: [Adapter]) -> [Adapter] {
        guard !incoming.isEmpty else { return self }
        var byID: [String: Adapter] = [:]
        for adapter in self { byID[adapter.id] = adapter }
        for fresh in incoming {
            guard let current = byID[fresh.id] else {
                byID[fresh.id] = fresh          // a source we did not know
                continue
            }
            let freshVersion = fresh.adapterVersion ?? 0
            let currentVersion = current.adapterVersion ?? 0
            if freshVersion > currentVersion,
               current.adapterVersion != nil,     // legacy saves: hands off
               current.userEdited != true {
                byID[fresh.id] = fresh
            }
        }
        var merged = compactMap { byID[$0.id] }
        for fresh in incoming where !contains(where: { $0.id == fresh.id }) {
            merged.append(fresh)
        }
        return merged
    }
}
