import XCTest

/// The wish sentence is the record; this is the interpretation. Each row is
/// a sentence in the user's own words and the parts the engine must hear in
/// it: names (never translated), categories (recognised in any language),
/// the ceiling, the place, the exclusions.
final class WishParserTests: XCTestCase {

    func testNameCategoryCeiling() {
        let ad = WishParser.parse("I wish for a Grinde 27 sailboat under €25,000")
        XCTAssertEqual(ad.maxPrice, 25_000)
        XCTAssertEqual(ad.currency, "EUR")
        XCTAssertEqual(ad.core ?? [], ["Grinde", "27"])
        XCTAssertEqual(ad.concepts ?? [], ["sailboat"])
        XCTAssertEqual(ad.places, [])
        XCTAssertEqual(ad.exclusions, [])
    }

    func testCeilingAndPlaceBothParsed() {
        // The place must come last — the ceiling cannot follow it.
        let ad = WishParser.parse("a used bicycle under 4.000 kr in Copenhagen")
        XCTAssertEqual(ad.maxPrice, 4_000)
        XCTAssertEqual(ad.currency, "DKK")
        XCTAssertEqual(ad.places, ["Copenhagen"])
        XCTAssertEqual(ad.concepts ?? [], ["bicycle"])
        XCTAssertTrue(ad.core?.isEmpty ?? false)
    }

    func testExclusionAndCategory() {
        let ad = WishParser.parse("looking for a turntable, not a project")
        XCTAssertEqual(ad.concepts ?? [], ["turntable"])
        XCTAssertEqual(ad.exclusions, ["project"])
    }

    func testQuotedPhraseIsAName() {
        let ad = WishParser.parse("a \"Fender Rhodes\" piano under 2.000 eur")
        XCTAssertEqual(ad.maxPrice, 2_000)
        XCTAssertEqual(ad.currency, "EUR")
        XCTAssertTrue(ad.core?.contains("Fender Rhodes") ?? false)
        XCTAssertEqual(ad.concepts ?? [], ["piano"])
    }

    func testDanishLeadInAndCategory() {
        let ad = WishParser.parse("jeg ønsker mig en sejlbåd")
        XCTAssertEqual(ad.concepts ?? [], ["sailboat"])
        XCTAssertTrue(ad.core?.isEmpty ?? false)
    }

    func testCeilingWithKThousands() {
        let ad = WishParser.parse("a guitar amplifier below 25k")
        XCTAssertEqual(ad.maxPrice, 25_000)
    }

    func testNoCeilingNoPlace() {
        let ad = WishParser.parse("a kayak in good condition")
        XCTAssertNil(ad.maxPrice)
        XCTAssertEqual(ad.concepts ?? [], ["kayak"])
    }
}
