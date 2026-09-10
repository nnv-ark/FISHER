import Foundation

struct PricePoint: Codable, Hashable {
    var date: Date
    var price: Double
}

struct Listing: Identifiable, Codable, Hashable {
    var id: String
    var adID: UUID?
    var title: String
    var summary: String = ""
    var price: Double?
    var currency: String = ""
    var place: String = ""
    var url: URL
    var imageURL: URL?
    var source: String
    var firstSeen = Date()
    var lastSeen = Date()
    var lastMissing: Date?
    var priceHistory: [PricePoint] = []
    var score: Double = 0
    var isGone = false
    /// True when this really looks like the thing wished for — the ad names the
    /// category, or it came from a source that carries only that kind of thing.
    /// A cushion set for a Grinde mentions Grinde but is not one, and must stay
    /// out of any comparison of prices.
    var likelyTheThing: Bool?

    var priceText: String {
        guard let p = price else { return "no price given" }
        return Money.format(p, currency)
    }

    /// Positive when the price has come down since it was first seen.
    var priceDrop: Double? {
        guard let now = price, let first = priceHistory.first?.price, first > now else { return nil }
        return first - now
    }

    var daysListed: Int {
        max(0, Calendar.current.dateComponents([.day], from: firstSeen, to: Date()).day ?? 0)
    }

    /// Loose identity across sites: title words + price bucket.
    var dedupKey: String {
        let words = title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .sorted()
            .prefix(6)
            .joined(separator: "-")
        let bucket = price.map { Int($0 / 500) } ?? -1
        return "\(words)#\(bucket)"
    }
}

enum Money {
    static func format(_ value: Double, _ currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        let n = f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        switch currency.uppercased() {
        case "EUR": return "€\(n)"
        case "USD": return "$\(n)"
        case "GBP": return "£\(n)"
        case "":    return n
        default:    return "\(n) \(currency.uppercased())"
        }
    }
}
