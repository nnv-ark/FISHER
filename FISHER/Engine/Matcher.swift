import Foundation

/// Cheap first, expensive never. Term hits weighted by field, hard filters on
/// price and exclusions, small nudges for place and freshness.
enum Matcher {

    static func score(_ listing: Listing, against ad: WantedAd) -> Double {
        let title = Lexicon.fold(listing.title)
        let body = Lexicon.fold(listing.summary)
        let haystack = title + " " + body

        for bad in ad.exclusions where !bad.isEmpty && haystack.contains(Lexicon.fold(bad)) { return 0 }
        if let ceiling = ad.maxPrice, let price = listing.price, price > ceiling * 1.05 { return 0 }

        // Names must be there. All of them.
        var score = 0.0
        var namedInTitle = false
        let names = ad.coreTerms.flatMap { $0.split(separator: " ").map(String.init) }
            .filter { $0.count > 1 && !Lexicon.stopwords.contains(Lexicon.fold($0)) }
        if !names.isEmpty {
            var hits = 0.0
            var inTitle = true
            for name in names {
                let needle = Lexicon.fold(name)
                if containsWord(title, needle) { hits += 1.0 }
                else if containsWord(body, needle) { hits += 0.55; inTitle = false }
                else { return 0 }
            }
            score = 0.45 + 0.35 * (hits / Double(names.count))
            namedInTitle = inTitle
        }

        // Categories are how we recognise it, not how we find it — and a
        // Danish ad saying "sejlbåd" answers an English wish for a sailboat.
        if !ad.conceptTerms.isEmpty {
            var recognised = 0
            for concept in ad.conceptTerms {
                let anyLanguage = Lexicon.allWords(concept).map(Lexicon.fold)
                if anyLanguage.contains(where: { haystack.contains($0) }) { recognised += 1 }
            }
            let share = Double(recognised) / Double(ad.conceptTerms.count)
            score += names.isEmpty ? 0.45 + 0.35 * share : 0.12 * share
            if recognised == 0 {
                if names.isEmpty { return 0 }
                // The name turned up only in the small print of the ad and
                // nothing says it is the kind of thing wished for — an espresso
                // machine whose blurb mentions a grinder. Keep it, but not on
                // the front page. A name in the headline is trusted.
                if !namedInTitle { score *= 0.75 }
            }
        }

        guard score > 0 else { return 0 }

        if !ad.places.isEmpty {
            let where_ = Lexicon.fold(listing.place + " " + listing.source)
            if ad.places.contains(where: { where_.contains(Lexicon.fold($0)) }) { score += 0.07 }
        }
        if listing.price != nil { score += 0.05 }
        if listing.imageURL != nil { score += 0.03 }
        return min(1, score)
    }

    /// Does the ad itself say what kind of thing it is, in any language?
    static func namesCategory(_ listing: Listing, _ ad: WantedAd) -> Bool {
        guard !ad.conceptTerms.isEmpty else { return false }
        let haystack = Lexicon.fold(listing.title + " " + listing.summary)
        for concept in ad.conceptTerms {
            if Lexicon.allWords(concept).map(Lexicon.fold).contains(where: { haystack.contains($0) }) {
                return true
            }
        }
        return false
    }

    /// A name has to stand as its own word. Searching Blocket for "Grinde"
    /// otherwise returns eleven hundred Swedish garden gates — grind, grinden,
    /// hundgrindar — because every one of them contains the letters.
    private static func containsWord(_ haystack: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return false }
        var from = haystack.startIndex
        while let found = haystack.range(of: needle, range: from..<haystack.endIndex) {
            let before = found.lowerBound == haystack.startIndex
                ? true
                : !isWordish(haystack[haystack.index(before: found.lowerBound)])
            let after = found.upperBound == haystack.endIndex
                ? true
                : !isWordish(haystack[found.upperBound])
            if before && after { return true }
            guard found.lowerBound < haystack.endIndex else { break }
            from = haystack.index(after: found.lowerBound)
        }
        return false
    }

    private static func isWordish(_ c: Character) -> Bool { c.isLetter || c.isNumber }

    /// Where an item lands in the paper.
    enum Slot { case lead, second, brief, spiked }

    static func slot(for score: Double) -> Slot {
        switch score {
        case 0.75...: return .lead
        case 0.50..<0.75: return .second
        case 0.30..<0.50: return .brief
        default: return .spiked
        }
    }
}
