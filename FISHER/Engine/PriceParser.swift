import Foundation

enum PriceParser {
    /// Symbols can appear anywhere; words have to stand alone, or "skrog"
    /// reads as Swedish kronor and a Danish boat gets priced in the wrong money.
    private static let symbols: [(String, String)] = [
        ("€", "EUR"), ("$", "USD"), ("£", "GBP")
    ]
    private static let words: [(String, String)] = [
        ("eur", "EUR"), ("euro", "EUR"), ("dkk", "DKK"), ("sek", "SEK"),
        ("nok", "NOK"), ("isk", "ISK"), ("usd", "USD"), ("gbp", "GBP"),
        ("kr", "DKK"), ("kr.", "DKK"), ("kroner", "DKK"), ("kronor", "SEK"),
        ("krónur", "ISK"), ("pln", "PLN")
    ]

    /// Pulls an amount and a currency out of the soup classifieds emit:
    /// "19.500 kr.", "€ 19,500", "189 000 SEK", "129.000,-", "Pris: 6.900".
    static func parse(_ raw: String?, fallbackCurrency: String = "") -> (Double?, String) {
        guard let raw, !raw.isEmpty else { return (nil, fallbackCurrency) }
        let lower = raw.lowercased()

        var currency = fallbackCurrency
        var sawCurrency = false
        for (needle, code) in symbols where lower.contains(needle) {
            currency = code; sawCurrency = true; break
        }
        if !sawCurrency {
            let tokens = lower.split(whereSeparator: { !$0.isLetter && $0 != "." }).map(String.init)
            outer: for (needle, code) in words {
                for token in tokens where token == needle {
                    // "kr" is the krona of four countries. A source that told
                    // us its money — Tradera (SEK), dba (DKK) — wins over
                    // the Danish default; only a bare "kr" with no hint
                    // falls back to DKK.
                    if needle == "kr" || needle == "kr.", !fallbackCurrency.isEmpty {
                        currency = fallbackCurrency
                    } else {
                        currency = code
                    }
                    sawCurrency = true; break outer
                }
            }
        }

        guard let re = try? NSRegularExpression(pattern: #"\d[\d\.,  ]{0,15}\d|\d+"#) else {
            return (nil, currency)
        }
        let ns = raw as NSString
        let candidates = re.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            .map { (text: ns.substring(with: $0.range), range: $0.range) }
            .filter { !digits($0.text).isEmpty }
        guard !candidates.isEmpty else { return (nil, currency) }

        // Prefer grouped numbers ("129.000") and anything sitting next to money.
        func rank(_ c: (text: String, range: NSRange)) -> Int {
            var score = digits(c.text).count
            if c.text.contains(".") || c.text.contains(",") || c.text.contains(" ") { score += 6 }
            let after = ns.substring(from: min(ns.length, c.range.location + c.range.length))
                .prefix(6).lowercased()
            let before = ns.substring(to: c.range.location).suffix(3).lowercased()
            if after.contains("kr") || after.contains(",-") || after.contains("€")
                || before.contains("€") || before.contains("$") { score += 8 }
            if looksLikeYear(c.text) { score -= 12 }
            return score
        }

        guard let best = candidates.max(by: { rank($0) < rank($1) }) else { return (nil, currency) }
        if looksLikeYear(best.text) && !sawCurrency { return (nil, currency) }

        // Mining a price out of prose is guesswork. "Grinde D564 årgang 1976"
        // has three numbers in it and none of them is what the boat costs, so
        // unless money is named or the figure is grouped, say nothing.
        let wordCount = raw.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        if wordCount >= 4, !sawCurrency {
            let grouped = (best.text.contains(".") || best.text.contains(",") || best.text.contains(" "))
                && digits(best.text).count >= 4        // "model 2." is not 2 kroner
            if !grouped { return (nil, currency) }
        }

        guard let value = Double(digits(best.text)), value > 0 else { return (nil, currency) }
        return (value, currency)
    }

    /// "årgang 1976" is a vintage, not an asking price.
    private static func looksLikeYear(_ text: String) -> Bool {
        let bare = digits(text)
        guard bare.count == 4, bare == text.trimmingCharacters(in: .whitespaces),
              let n = Int(bare) else { return false }
        return n >= 1900 && n <= 2100
    }

    private static func digits(_ s: String) -> String { s.filter { $0.isNumber } }
}
