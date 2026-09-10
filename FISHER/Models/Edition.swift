import Foundation

/// One morning's paper. Finite, dated, and allowed to be empty.
struct Edition: Identifiable, Codable, Hashable {
    var id: Int
    var date: Date
    var sourcesRead: Int
    var printedAt: Date
    var lead: Item?
    var seconds: [Item] = []
    var brief: [BriefLine] = []
    var obituaries: [String] = []
    var stillOut: [String] = []
    /// Sources that were asked and could not be read — named, so a sweep that
    /// failed everywhere never masquerades as a quiet morning.
    /// Optional so editions printed before this existed still open.
    var missedSources: [String]? = []

    var isQuiet: Bool { lead == nil && seconds.isEmpty && brief.isEmpty }
    var newCount: Int { (lead == nil ? 0 : 1) + seconds.count + brief.count }

    struct Item: Codable, Hashable, Identifiable {
        var id: String
        var flag: String
        var headline: String
        var dek: String
        var body: [String]
        var listing: Listing
        /// Optional so editions printed before this existed still open.
        var market: Market?
    }

    /// What the paper is comparing against, set out so it can be checked
    /// rather than taken on trust.
    struct Market: Codable, Hashable {
        var currency: String
        var count: Int
        var since: Date
        var sources: Int
        var cheapest: Double
        var cheapestName: String
        var median: Double
        var dearest: Double
        var dearestName: String
        var subject: Double?

        var sinceLine: String {
            let f = DateFormatter(); f.dateFormat = "d MMMM"
            return f.string(from: since)
        }
    }

    struct BriefLine: Codable, Hashable, Identifiable {
        var id: String
        var sourceName: String
        var text: String
        var amount: String
        var url: URL
    }

    var dayLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f.string(from: date)
    }

    var shortDayLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }

    var printedLine: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "Printed at \(f.string(from: printedAt)) · \(sourcesRead) source\(sourcesRead == 1 ? "" : "s")"
    }

    /// "9 sources read overnight" — or "7 of 9 sources read overnight" when
    /// some were asked and answered with an error.
    var readLine: String {
        let missed = missedSources ?? []
        let total = sourcesRead + missed.count
        if !missed.isEmpty {
            return "\(sourcesRead) of \(total) sources read overnight"
        }
        return "\(sourcesRead) source\(sourcesRead == 1 ? "" : "s") read overnight"
    }
}
