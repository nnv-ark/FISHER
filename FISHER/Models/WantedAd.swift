import Foundation

/// A wish. Written as one sentence; everything else is derived from it and stays editable.
struct WantedAd: Identifiable, Codable, Hashable {
    var id = UUID()
    var sentence: String
    var terms: [String] = []
    /// Names — model names, makers, proper nouns. Never translated, always searched.
    var core: [String]?
    /// Categories — "sailboat", "sejlbåd", "gítar". Recognised in every language.
    var concepts: [String]?
    var exclusions: [String] = []
    var maxPrice: Double?
    var currency: String?
    var places: [String] = []
    var createdAt = Date()
    var isActive = true

    var displayName: String {
        if let first = terms.first, !first.isEmpty {
            return first.split(separator: " ").map(\.capitalized).joined(separator: " ")
        }
        return String(sentence.prefix(28))
    }

    /// nil means a wish saved before names and categories were told apart.
    var coreTerms: [String] { core ?? terms }
    var conceptTerms: [String] { concepts ?? [] }

    /// What goes in the {terms} slot of a search URL.
    ///
    /// A name is distinctive enough on its own, so when the wish has one we
    /// search for that alone and sort out the rest by reading the results.
    /// Sending "Grinde sejlbåd" to a site that titles the ad "Grinde 27"
    /// finds nothing, which is exactly the wrong kind of clever.
    func query(language: String) -> String {
        if !coreTerms.isEmpty { return coreTerms.joined(separator: " ") }
        let words = conceptTerms.compactMap { Lexicon.words($0, language: language).first }
        return words.isEmpty ? sentence : words.joined(separator: " ")
    }

    var queryString: String { query(language: "en") }

    /// What to ask a site, in its own language.
    ///
    /// The name alone is usually best — but when the name happens to be an
    /// ordinary word in that language ("grind" is Swedish for a gate), the
    /// bare search drowns. So we also ask for the name together with what the
    /// thing actually is, and merge the two answers.
    func queries(language: String) -> [String] {
        let names = coreTerms.joined(separator: " ")
        guard !names.isEmpty else {
            let words = conceptTerms.compactMap { Lexicon.words($0, language: language).first }
            return words.isEmpty ? [sentence] : [words.joined(separator: " ")]
        }
        var out = [names]
        for concept in conceptTerms {
            if let word = Lexicon.words(concept, language: language).first {
                out.append("\(names) \(word)")
            }
        }
        return out
    }
}
