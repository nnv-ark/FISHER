import Foundation

/// Turns "I wish for a Grinde 27, under €25,000, anywhere in Europe" into
/// something the engine can run. The sentence stays the record; this is only
/// an interpretation, and the user corrects it by rewriting the sentence.
enum WishParser {

    static func parse(_ raw: String) -> WantedAd {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for lead in Lexicon.leadIns.sorted(by: { $0.count > $1.count }) {
            if s.lowercased().hasPrefix(lead) { s = String(s.dropFirst(lead.count)); break }
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: #"^(a|an|the|en|et|ett|een|ein|eine|un|une)\s+"#,
                                   with: "", options: [.regularExpression, .caseInsensitive])

        var ad = WantedAd(sentence: raw.trimmingCharacters(in: .whitespacesAndNewlines))

        // Ceiling: "under €25,000", "below 25k", "up to 400 eur"
        let ceiling = Lexicon.ceilingWords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        if let m = firstMatch("(?:\(ceiling))\\s*([€$£]|kr\\.?|eur|dkk|sek|nok|isk|usd|gbp)?\\s*([\\d][\\d\\.,\\s]*)\\s*(k\\b|thousand|þús\\.?)?", in: s) {
            var amount = Double(m[2].filter { $0.isNumber }) ?? 0
            if !m[3].isEmpty { amount *= 1000 }
            if amount > 0 {
                ad.maxPrice = amount
                let (_, code) = PriceParser.parse(m[1].isEmpty ? nil : m[1])
                ad.currency = code.isEmpty ? nil : code
            }
        }

        // Where: "anywhere in Europe", "in Denmark", "near Reykjavík"
        let places = Lexicon.placeWords.map { NSRegularExpression.escapedPattern(for: $0) }
            .sorted { $0.count > $1.count }.joined(separator: "|")
        if let m = firstMatch("(?:\\b)(?:\(places))\\s+([\\p{L}][\\p{L}\\s\\-]{2,30})\\s*$", in: s) {
            let place = m[1].trimmingCharacters(in: .whitespaces)
            if !place.isEmpty, Lexicon.concept(for: place) == nil { ad.places = [place] }
        }

        // Exclusions: "not a project", "no trailer", "excluding parts"
        for m in allMatches(#"(?:not|no|without|excluding|except)\s+(?:a\s+|an\s+)?([\p{L}][\p{L}\s]{2,20}?)(?=[,.;]|$)"#, in: s) {
            let word = m[1].trimmingCharacters(in: .whitespaces)
            if !word.isEmpty { ad.exclusions.append(word.lowercased()) }
        }

        // The head of the sentence, before any qualifier.
        var head = s
        var cuts = [",", ";", " not ", " without ", " anywhere "]
        cuts += Lexicon.ceilingWords.map { " \($0) " }
        for cut in cuts {
            if let r = head.range(of: cut, options: .caseInsensitive) { head = String(head[..<r.lowerBound]) }
        }
        head = head.trimmingCharacters(in: .whitespacesAndNewlines)

        // Sort its words: a name we can search with, or a category we can
        // recognise in any language. Two-word categories ("sailing boat",
        // "barca a vela") are checked before single words.
        let words = head.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        var core: [String] = []
        var concepts: [String] = []
        var index = 0
        while index < words.count {
            var matched = false
            for span in stride(from: min(3, words.count - index), through: 1, by: -1) {
                let phrase = words[index..<(index + span)].joined(separator: " ")
                if let concept = Lexicon.concept(for: phrase) {
                    if !concepts.contains(concept) { concepts.append(concept) }
                    index += span
                    matched = true
                    break
                }
            }
            if matched { continue }
            let word = words[index]
            let bare = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            let folded = Lexicon.fold(bare)
            let isBigNumber = bare.allSatisfy { $0.isNumber || $0 == "." || $0 == "," }
                && bare.filter(\.isNumber).count > 4
            if !bare.isEmpty, !Lexicon.stopwords.contains(folded),
               !Lexicon.currencyWords.contains(folded), !isBigNumber {
                core.append(bare)
            }
            index += 1
        }

        ad.core = core
        ad.concepts = concepts
        ad.terms = core.isEmpty ? [head] : [core.joined(separator: " ")]   // his own words, for the label

        // Quoted phrases are always names, verbatim.
        for m in allMatches(#""([^"]{2,40})""#, in: raw) where !m[1].isEmpty {
            ad.core?.append(m[1])
            ad.terms.append(m[1])
        }
        if ad.terms.isEmpty { ad.terms = [s] }
        if (ad.core ?? []).isEmpty && (ad.concepts ?? []).isEmpty { ad.core = [s] }
        return ad
    }

    // MARK: regex helpers

    private static func firstMatch(_ pattern: String, in s: String) -> [String]? {
        allMatches(pattern, in: s).first
    }

    private static func allMatches(_ pattern: String, in s: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { i in
                m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i))
            }
        }
    }
}
