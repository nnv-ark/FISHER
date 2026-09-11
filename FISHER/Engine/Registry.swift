import Foundation

/// A hosted adapters.json — the same data the app ships, published at any
/// URL the user points at. When the hosted file carries a newer version of
/// a source, installs that have not tuned that source by hand pick the fix
/// up without waiting for an app update. That is the whole point of
/// adapters being data: a broken site is a file to republish.
@MainActor
enum Registry {

    struct Cache: Codable {
        var fetchedAt: Date
        var adapters: [Adapter]
    }

    private static var cacheURL: URL { Store.folder.appendingPathComponent("registry.json") }

    /// Where the hosted file lives. Empty means the feature is off.
    static var remote: URL? {
        let raw = (UserDefaults.standard.string(forKey: PrefKey.registryURL) ?? "")
            .trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    /// The last fetched copy, if any. Folded into the live list at launch,
    /// so an update picked up yesterday is in effect today.
    static func cached() -> [Adapter]? { cache()?.adapters }

    private static func cache() -> Cache? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(Cache.self, from: data)
    }

    /// Fetch at most once a week — the cache itself is the throttle, so the
    /// cadence survives restarts. `force` bypasses it for the Check now
    /// button. The return value is a line for the settings pane.
    static func refreshIfStale(userAgent: String, force: Bool = false) async -> String? {
        guard let remote else { return "No registry URL is set." }
        if !force, let cache = cache(), Date().timeIntervalSince(cache.fetchedAt) < 6 * 86_400 {
            return nil
        }
        do {
            let response = try await Fetcher.shared.get(remote, throttle: 0, userAgent: userAgent)
            guard (200..<300).contains(response.status) else {
                return "The registry answered HTTP \(response.status)."
            }
            let list = try JSONDecoder().decode([Adapter].self, from: response.data)
            guard !list.isEmpty else { return "The registry returned no sources." }
            let e = JSONEncoder()
            e.outputFormatting = [.prettyPrinted, .sortedKeys]
            e.dateEncodingStrategy = .iso8601
            try? e.encode(Cache(fetchedAt: Date(), adapters: list))
                .write(to: cacheURL, options: .atomic)
            let top = list.compactMap(\.adapterVersion).max() ?? 0
            return "Registry read — \(list.count) sources, versions up to \(top)."
        } catch {
            return "Could not read the registry — \(error.localizedDescription)."
        }
    }
}
