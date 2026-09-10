import Foundation
import SwiftUI

/// Everything the app knows, on disk as plain JSON in Application Support so
/// it can be read, backed up and repaired with a text editor.
@MainActor
final class Store: ObservableObject {
    @Published var wishes: [WantedAd] = []
    @Published var listings: [String: Listing] = [:]
    @Published var editions: [Edition] = []
    @Published var adapters: [Adapter] = []
    @Published var selectedIssue: Int?
    @Published var isSweeping = false
    @Published var sweepNote: String = ""
    @Published var lastSweep: Date?

    var currentEdition: Edition? {
        guard let id = selectedIssue else { return editions.last }
        return editions.first { $0.id == id } ?? editions.last
    }

    // MARK: paths

    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wish Fisher", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private var wishesURL: URL   { Self.folder.appendingPathComponent("wishes.json") }
    private var listingsURL: URL { Self.folder.appendingPathComponent("listings.json") }
    private var editionsURL: URL { Self.folder.appendingPathComponent("editions.json") }
    private var adaptersURL: URL { Self.folder.appendingPathComponent("adapters.json") }

    // MARK: loading

    init() {
        Defaults.register()
        load()
        Rates.load()
    }

    func load() {
        wishes   = read([WantedAd].self, from: wishesURL) ?? []
        listings = read([String: Listing].self, from: listingsURL) ?? [:]
        editions = read([Edition].self, from: editionsURL) ?? []
        adapters = mergedWithBundle(read([Adapter].self, from: adaptersURL) ?? [])
        if !adapters.isEmpty, adapters.allSatisfy({ $0.language == nil }) {
            adapters = bundledAdapters()   // saved before sites knew their language
        }
        selectedIssue = editions.last?.id
    }

    func bundledAdapters() -> [Adapter] {
        guard let url = Bundle.main.url(forResource: "adapters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Adapter].self, from: data) else { return [] }
        return list
    }

    /// Saved adapters win, with one exception: a bundled version newer than
    /// the saved one replaces it, which is how a selector fix ships to
    /// existing installs without an app update. Three kinds are never
    /// touched — a source the user tuned by hand, a source saved before
    /// versions existed, and one the user has disabled. New bundled sources
    /// are appended; the user's order is kept.
    private func mergedWithBundle(_ saved: [Adapter]) -> [Adapter] {
        let bundled = bundledAdapters()
        guard !bundled.isEmpty else { return saved }
        var byID: [String: Adapter] = [:]
        for adapter in saved { byID[adapter.id] = adapter }
        for fresh in bundled {
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
        var merged = saved.compactMap { byID[$0.id] }
        for fresh in bundled where !saved.contains(where: { $0.id == fresh.id }) {
            merged.append(fresh)
        }
        return merged
    }

    /// Settings ▸ Sources tuned this source by hand. From now on a bundled
    /// update of it will not overwrite the tuning.
    func markAdapterEdited(id: String) {
        guard let i = adapters.firstIndex(where: { $0.id == id }) else { return }
        adapters[i].userEdited = true
        save()
    }

    /// Turning a source off is a choice about *this* source, so it also
    /// shields the entry from being swapped for a bundled update.
    func setAdapterEnabled(_ id: String, _ enabled: Bool) {
        guard let i = adapters.firstIndex(where: { $0.id == id }) else { return }
        adapters[i].enabled = enabled
        adapters[i].userEdited = true
        save()
    }

    func restoreBundledAdapters() {
        adapters = bundledAdapters()
        save()
    }

    // MARK: saving

    func save() {
        prune()
        write(wishes, to: wishesURL)
        write(listings, to: listingsURL)
        write(editions.suffix(UserDefaults.standard.integer(forKey: PrefKey.keepIssues)).map { $0 }, to: editionsURL)
        write(adapters, to: adaptersURL)
    }

    /// Listings gone for two months are forgotten. Their obituaries were
    /// printed long ago, and an archive of dead ads the app never re-reads
    /// only makes every launch slower.
    private func prune() {
        let cutoff = Date().addingTimeInterval(-60 * 86_400)
        listings = listings.filter {
            !$0.value.isGone || ($0.value.lastMissing ?? .distantPast) >= cutoff
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        guard let data = try? e.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: mutations

    func addWish(_ ad: WantedAd) {
        wishes.append(ad)
        save()
    }

    var activeWishes: [WantedAd] { wishes.filter(\.isActive) }
    var retiredWishes: [WantedAd] { wishes.filter { !$0.isActive } }

    /// A wish you stop making is put away, not thrown out. It stops being
    /// searched for; everything it ever found stays on the shelf, and you can
    /// take it up again.
    func retireWish(_ ad: WantedAd) {
        guard let i = wishes.firstIndex(where: { $0.id == ad.id }) else { return }
        wishes[i].isActive = false
        save()
    }

    func reviveWish(_ ad: WantedAd) {
        guard let i = wishes.firstIndex(where: { $0.id == ad.id }) else { return }
        wishes[i].isActive = true
        save()
    }

    /// The only thing that actually destroys anything.
    func forgetWish(_ ad: WantedAd) {
        wishes.removeAll { $0.id == ad.id }
        for (key, listing) in listings where listing.adID == ad.id { listings[key] = nil }
        save()
    }

    /// Order is meaning here: the first wish owns the front page.
    func moveWish(id: UUID, before other: UUID) {
        guard id != other,
              let from = wishes.firstIndex(where: { $0.id == id }) else { return }
        let moved = wishes.remove(at: from)
        let to = wishes.firstIndex(where: { $0.id == other }) ?? wishes.count
        wishes.insert(moved, at: to)
        save()
    }

    func name(for adID: UUID?) -> String {
        wishes.first { $0.id == adID }?.displayName ?? "Wanted"
    }
}
