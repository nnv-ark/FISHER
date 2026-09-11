import XCTest

/// Scoring decides what makes the front page and what gets spiked. These
/// cases pin the behavior that matters: names must all be present, hard
/// filters are hard, and a name in the small print is not a headline.
final class MatcherTests: XCTestCase {

    private func listing(title: String, summary: String = "", price: Double? = nil,
                         currency: String = "EUR", place: String = "") -> Listing {
        Listing(id: "test#\(title)", title: title, summary: summary,
                price: price, currency: currency, place: place,
                url: URL(string: "https://example.com/ad")!, source: "TestSource")
    }

    private func ad(core: [String] = [], concepts: [String] = [], exclusions: [String] = [],
                    maxPrice: Double? = nil, places: [String] = []) -> WantedAd {
        WantedAd(sentence: "test wish", terms: core, core: core, concepts: concepts,
                 exclusions: exclusions, maxPrice: maxPrice, currency: "EUR", places: places)
    }

    func testPerfectMatchTakesTheLead() {
        let ad = ad(core: ["Grinde"], concepts: ["sailboat"], maxPrice: 30_000, places: ["svendborg"])
        let item = listing(title: "Grinde 27 — fine condition",
                           summary: "Well kept sailboat", price: 25_000, place: "Svendborg")
        let score = Matcher.score(item, against: ad)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
        XCTAssertEqual(Matcher.slot(for: score), .lead)
    }

    func testExclusionSpikesIt() {
        let ad = ad(core: ["Grinde"], concepts: ["sailboat"], exclusions: ["cushion"])
        let item = listing(title: "Grinde cushion set", summary: "sailboat cushions")
        XCTAssertEqual(Matcher.score(item, against: ad), 0)
        XCTAssertEqual(Matcher.slot(for: 0), .spiked)
    }

    func testOverCeilingSpikesIt() {
        let ad = ad(core: ["Grinde"], concepts: ["sailboat"], maxPrice: 30_000)
        let item = listing(title: "Grinde 27 sailboat", price: 35_000)
        XCTAssertEqual(Matcher.score(item, against: ad), 0)
    }

    func testCeilingAllowsFivePercent() {
        let ad = ad(core: ["Grinde"], concepts: ["sailboat"], maxPrice: 30_000)
        let item = listing(title: "Grinde 27 sailboat", price: 31_500)
        XCTAssertGreaterThan(Matcher.score(item, against: ad), 0)
    }

    func testNameInSmallPrintWithoutCategoryDemoted() {
        // The name is only in the summary and nothing says it is the thing
        // wished for — kept, but not on the front page.
        let ad = ad(core: ["Grinde"], concepts: ["sailboat"])
        let item = listing(title: "Boat gear for sale", summary: "Fits a Grinde 27 nicely")
        let score = Matcher.score(item, against: ad)
        XCTAssertEqual(Matcher.slot(for: score), .brief)
        XCTAssertFalse(Matcher.namesCategory(item, ad))
    }

    func testMissingNameSpikesIt() {
        let ad = ad(core: ["Grinde"], concepts: ["sailboat"])
        let item = listing(title: "Albin Vega sailboat", summary: "")
        XCTAssertEqual(Matcher.score(item, against: ad), 0)
    }

    func testNameMustStandAsAWord() {
        // "grind" is Swedish for a gate; the letters inside "grindar" and
        // "grinde" must not count. This is the Blocket garden-gates case.
        let ad = ad(core: ["grind"])
        XCTAssertEqual(Matcher.score(listing(title: "Grinde 27"), against: ad), 0)
        XCTAssertEqual(Matcher.score(listing(title: "Garden gates (grindar)"), against: ad), 0)
        let exact = Matcher.score(listing(title: "Grind i fint skick"), against: ad)
        XCTAssertGreaterThan(exact, 0.5)
    }

    func testCategoryRecognisedInAnotherLanguage() {
        // A Danish ad answers an English wish.
        let ad = ad(concepts: ["sailboat"])
        let item = listing(title: "Fin sejlbåd til salg", price: 10_000)
        XCTAssertGreaterThan(Matcher.score(item, against: ad), 0.5)
    }
}
