import Foundation

/// Writes the paper. A headline is a judgment, not the seller's title — so it
/// is assembled from facts the app knows and the seller doesn't state:
/// rarity, price history, how long things usually last.
///
/// `HeadlineWriter` is the seam where a language model can take over the
/// phrasing later. The numbers must always come from here.
protocol HeadlineWriter {
    func headline(for listing: Listing, context: EditorContext) -> (String, String)
}

struct EditorContext {
    var medianPrice: Double?
    /// This listing's price in whatever currency the comparison is being made in.
    var subjectPrice: Double?
    /// Comparisons are made in your own currency when rates are available, so a
    /// Danish boat and a Swedish one can be weighed against each other.
    var currency: String
    var cheapestInMonths: Int?
    var seenBefore: Int
    var priceDrop: Double?
    var isNew: Bool
    /// nil when too few comparable things have been seen to call it a market.
    var market: Edition.Market?
}

struct PlainHeadlineWriter: HeadlineWriter {
    func headline(for listing: Listing, context: EditorContext) -> (String, String) {
        let money = listing.priceText

        if let drop = context.priceDrop, drop > 0 {
            let head = "\(shortTitle(listing)) \(whereClause(listing)) drops \(Money.format(drop, listing.currency))"
            var dek = "Now \(money), after \(listing.daysListed) days listed."
            if let standing = standingLine(context) { dek += " " + standing }
            return (head, dek)
        }

        let head = "\(shortTitle(listing)) surfaces \(whereClause(listing)) — \(money)"
        var parts: [String] = []
        if let standing = standingLine(context) { parts.append(standing) }
        if parts.isEmpty, context.seenBefore <= 1 {
            parts.append("The first one this wish has turned up.")
        }
        if parts.isEmpty { parts.append("Listed today on \(listing.source).") }
        return (head, parts.joined(separator: " "))
    }

    /// Says where this one stands among the ones the app has actually seen —
    /// and never claims a history it does not have. The figures themselves are
    /// printed in the table beneath the story.
    private func standingLine(_ context: EditorContext) -> String? {
        guard let market = context.market, let subject = market.subject else { return nil }
        let n = market.count
        if subject <= market.cheapest {
            return "The cheapest of the \(n) this wish has found."
        }
        if subject >= market.dearest {
            return "The dearest of the \(n) this wish has found."
        }
        if subject == market.median { return "The middle one of the \(n) this wish has found." }
        return subject < market.median
            ? "Below the middle of the \(n) this wish has found."
            : "Above the middle of the \(n) this wish has found."
    }

    /// "in Svendborg" when the seller said where, otherwise "on dba.dk".
    private func whereClause(_ listing: Listing) -> String {
        listing.place.isEmpty ? "on \(listing.source)" : "in \(listing.place)"
    }

    /// Sellers type in lower case. Headlines do not.
    private func shortTitle(_ listing: Listing) -> String {
        // Brokerages title a boat "make model", which for a Grinde built by
        // Grinde reads "Grinde Grinde".
        var seen: [String] = []
        for word in listing.title.split(separator: " ").map(String.init) {
            if seen.last?.caseInsensitiveCompare(word) == .orderedSame { continue }
            seen.append(word)
        }
        let words = seen.prefix(5).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–—,"))
        guard let first = words.first else { return words }
        return String(first).uppercased() + words.dropFirst()
    }
}

enum Editor {

    static func compose(issueNumber: Int,
                        fresh: [Listing],
                        history: [Listing],
                        gone: [Listing],
                        stillOut: [Listing],
                        sourcesRead: Int,
                        missedSources: [String] = [],
                        adName: (UUID?) -> String,
                        writer: HeadlineWriter = PlainHeadlineWriter()) -> Edition {

        var edition = Edition(id: issueNumber, date: Date(), sourcesRead: sourcesRead, printedAt: Date())
        edition.missedSources = missedSources
        let ranked = fresh.sorted { $0.score > $1.score }

        var leads: [Edition.Item] = []
        var seconds: [Edition.Item] = []
        var brief: [Edition.BriefLine] = []

        for listing in ranked {
            let context = context(for: listing, history: history)
            switch Matcher.slot(for: listing.score) {
            case .lead, .second:
                let (head, dek) = writer.headline(for: listing, context: context)
                let item = Edition.Item(id: listing.id,
                                        flag: adName(listing.adID),
                                        headline: head,
                                        dek: dek,
                                        body: bodyParagraphs(listing, context: context),
                                        listing: listing,
                                        market: context.market)
                if leads.isEmpty && Matcher.slot(for: listing.score) == .lead { leads.append(item) }
                else { seconds.append(item) }
            case .brief:
                brief.append(Edition.BriefLine(id: listing.id,
                                               sourceName: listing.source,
                                               text: listing.title,
                                               amount: listing.priceText,
                                               url: listing.url))
            case .spiked:
                continue
            }
        }

        edition.lead = leads.first
        edition.seconds = Array(seconds.prefix(6))
        edition.brief = Array(brief.prefix(10))
        edition.obituaries = gone.prefix(6).map { listing in
            let verb = listing.daysListed > 1 ? "after \(listing.daysListed) days" : "the same day"
            return "Gone — \(listing.title), \(listing.priceText), \(verb) on \(listing.source)."
        }
        edition.stillOut = stillOut.prefix(4).map { listing in
            "Still listed — \(listing.title), day \(listing.daysListed). \(listing.priceDrop.map { "Down \(Money.format($0, listing.currency)) since it appeared." } ?? "No movement on price.")"
        }
        return edition
    }

    private static func bodyParagraphs(_ listing: Listing, context: EditorContext) -> [String] {
        var out: [String] = []
        if !listing.summary.isEmpty {
            out.append(String(listing.summary.prefix(420)))
        }
        return out
    }

    private static func context(for listing: Listing, history: [Listing]) -> EditorContext {
        let home = Defaults.homeCurrency
        let canConvert = !home.isEmpty && Rates.book != nil
        let currency = canConvert ? home : listing.currency

        func value(_ item: Listing) -> Double? {
            guard let price = item.price, price > 0 else { return nil }
            if !canConvert { return item.currency == listing.currency ? price : nil }
            if item.currency.uppercased() == home { return price }
            return Rates.convert(price, from: item.currency, to: home)
        }

        let subject = value(listing)

        // Only things that are actually the thing. An ad for a cushion set
        // mentions the boat's name; it is not a boat, and averaging it in is
        // how you end up "£102,000 under the average".
        let comparable = history.filter {
            $0.adID == listing.adID && $0.id != listing.id && ($0.likelyTheThing ?? false)
        }
        let priced = comparable.compactMap { item -> (Listing, Double)? in value(item).map { (item, $0) } }
        let prices = priced.map(\.1).sorted()
        let median: Double? = prices.isEmpty ? nil : prices[prices.count / 2]

        var cheapestInMonths: Int?
        if let subject {
            let cheaper = priced.filter { $0.1 <= subject }
            if let mostRecent = cheaper.map(\.0.firstSeen).max() {
                cheapestInMonths = Calendar.current.dateComponents([.month], from: mostRecent, to: Date()).month ?? 0
            }
        }

        // Two is not a market.
        var market: Edition.Market?
        let all = priced + [(listing, subject ?? 0)].filter { _ in subject != nil }
        if all.count >= 3, let low = all.min(by: { $0.1 < $1.1 }), let high = all.max(by: { $0.1 < $1.1 }) {
            let sorted = all.map(\.1).sorted()
            market = Edition.Market(currency: currency,
                                    count: all.count,
                                    since: all.map(\.0.firstSeen).min() ?? Date(),
                                    sources: Set(all.map(\.0.source)).count,
                                    cheapest: low.1,
                                    cheapestName: shortName(low.0),
                                    median: sorted[sorted.count / 2],
                                    dearest: high.1,
                                    dearestName: shortName(high.0),
                                    subject: subject)
        }

        return EditorContext(medianPrice: median,
                             subjectPrice: subject,
                             currency: currency,
                             cheapestInMonths: cheapestInMonths,
                             seenBefore: comparable.count,
                             priceDrop: listing.priceDrop,
                             isNew: listing.priceHistory.count <= 1,
                             market: market)
    }

    private static func shortName(_ listing: Listing) -> String {
        let words = listing.title.split(separator: " ").prefix(6).joined(separator: " ")
        return "\(words) · \(listing.source)"
    }
}
