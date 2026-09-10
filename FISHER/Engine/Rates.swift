import Foundation

/// Exchange rates, so a Danish boat and a Swedish one can be compared without
/// arithmetic in your head. Everything is held against the euro, because both
/// sources publish it that way, and the rate is fetched once a day alongside
/// the sweep — never per listing.
struct RateBook: Codable {
    var date: String
    var source: String
    var perEuro: [String: Double]
    var fetchedAt: Date

    var age: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: fetchedAt, relativeTo: Date())
    }
}

enum Rates {
    private(set) static var book: RateBook?

    private static var url: URL { Store.folder.appendingPathComponent("rates.json") }

    static func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        book = try? d.decode(RateBook.self, from: data)
    }

    static func save() {
        guard let book else { return }
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? e.encode(book).write(to: url, options: .atomic)
    }

    /// Refresh at most once a day. The European Central Bank's figures first;
    /// a broader table as a fallback for currencies the ECB doesn't publish.
    static func refreshIfStale(userAgent: String) async {
        if let book, Date().timeIntervalSince(book.fetchedAt) < 20 * 3600 { return }

        let attempts: [(String, String)] = [
            ("https://api.frankfurter.app/latest?from=EUR", "European Central Bank"),
            ("https://open.er-api.com/v6/latest/EUR", "open.er-api.com")
        ]
        for (link, source) in attempts {
            guard let url = URL(string: link) else { continue }
            do {
                let response = try await Fetcher.shared.get(url, throttle: 0, userAgent: userAgent)
                guard (200..<300).contains(response.status),
                      let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                      let rates = json["rates"] as? [String: Any] else { continue }

                var table: [String: Double] = ["EUR": 1]
                for (code, value) in rates {
                    if let number = value as? Double { table[code] = number }
                    else if let number = value as? NSNumber { table[code] = number.doubleValue }
                }
                guard table.count > 5 else { continue }
                let date = (json["date"] as? String)
                    ?? (json["time_last_update_utc"] as? String).map { String($0.prefix(16)) }
                    ?? ""
                book = RateBook(date: date, source: source, perEuro: table, fetchedAt: Date())
                save()
                return
            } catch { continue }
        }
    }

    static func convert(_ amount: Double, from: String, to: String) -> Double? {
        let from = from.uppercased(), to = to.uppercased()
        guard !from.isEmpty, !to.isEmpty, from != to,
              let table = book?.perEuro,
              let a = table[from], let b = table[to], a > 0 else { return nil }
        return amount / a * b
    }

    /// Currencies we can actually convert, for the Settings menu.
    static var known: [String] {
        (book?.perEuro.keys).map { Array($0).sorted() } ?? ["EUR", "USD", "GBP", "ISK", "DKK", "SEK", "NOK"]
    }
}

extension Money {
    /// "≈ 2,480,000 ISK" — never shown unless a rate genuinely exists.
    static func alsoIn(_ value: Double?, _ currency: String) -> String? {
        guard let value, !currency.isEmpty else { return nil }
        let home = Defaults.homeCurrency
        guard !home.isEmpty, home.uppercased() != currency.uppercased(),
              let converted = Rates.convert(value, from: currency, to: home) else { return nil }
        return "≈ " + format(converted.rounded(), home)
    }

    /// Same thing, shortened, for a line of small print.
    static func alsoInCompact(_ value: Double?, _ currency: String) -> String? {
        guard let value, !currency.isEmpty else { return nil }
        let home = Defaults.homeCurrency
        guard !home.isEmpty, home.uppercased() != currency.uppercased(),
              let converted = Rates.convert(value, from: currency, to: home) else { return nil }
        if converted >= 1_000_000 {
            return String(format: "≈ %.1fm %@", converted / 1_000_000, home.uppercased())
        }
        if converted >= 10_000 {
            return String(format: "≈ %.0fk %@", converted / 1_000, home.uppercased())
        }
        return "≈ " + format(converted.rounded(), home)
    }
}
