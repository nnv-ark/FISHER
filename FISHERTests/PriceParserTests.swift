import XCTest

/// Table-driven cases for the money soup classifieds emit. Each row is a
/// string a site actually prints, the currency to assume when the string
/// names none, and what must come out. Rows deliberately avoid decimal
/// fractions ("129,50") — the parser reads grouped thousands, not cents.
final class PriceParserTests: XCTestCase {

    struct Case {
        let raw: String
        let fallback: String
        let price: Double?
        let currency: String
    }

    let cases: [Case] = [
        .init(raw: "19.500 kr.",        fallback: "",    price: 19_500, currency: "DKK"),
        .init(raw: "€ 19,500",          fallback: "",    price: 19_500, currency: "EUR"),
        .init(raw: "189 000 SEK",       fallback: "",    price: 189_000, currency: "SEK"),
        .init(raw: "129.000,-",         fallback: "EUR", price: 129_000, currency: "EUR"),
        .init(raw: "Pris: 6.900",       fallback: "DKK", price: 6_900, currency: "DKK"),
        .init(raw: "£12,500",           fallback: "",    price: 12_500, currency: "GBP"),
        .init(raw: "25.000 DKK",        fallback: "",    price: 25_000, currency: "DKK"),
        .init(raw: "9.999 kr",          fallback: "",    price: 9_999, currency: "DKK"),
        .init(raw: "kr. 45.000",        fallback: "",    price: 45_000, currency: "DKK"),
        // A year is a vintage, never an asking price.
        .init(raw: "årgang 1976",       fallback: "DKK", price: nil, currency: "DKK"),
        .init(raw: "2020 Honda motor",  fallback: "EUR", price: nil, currency: "EUR"),
        // Prose with no money in it says nothing.
        .init(raw: "Grinde D564 årgang 1976", fallback: "DKK", price: nil, currency: "DKK"),
        // Real price beats the model year next to it.
        .init(raw: "Grinde 1976 model — 45.000 kr.", fallback: "", price: 45_000, currency: "DKK"),
        // "kr" alone is ambiguous — the source's own money wins when it has one.
        .init(raw: "175 kr,",             fallback: "SEK", price: 175,      currency: "SEK"),
        .init(raw: "1 643 kr,",           fallback: "SEK", price: 1_643,   currency: "SEK"),
        .init(raw: "1.500 kr",            fallback: "DKK", price: 1_500,   currency: "DKK"),
        // Nothing at all.
        .init(raw: "",                  fallback: "EUR", price: nil, currency: "EUR"),
    ]

    func testTable() {
        for c in cases {
            let (price, currency) = PriceParser.parse(c.raw, fallbackCurrency: c.fallback)
            XCTAssertEqual(price, c.price, "price of \(c.raw.debugDescription)")
            XCTAssertEqual(currency, c.currency, "currency of \(c.raw.debugDescription)")
        }
    }
}
