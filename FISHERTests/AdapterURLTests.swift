import XCTest

/// How {terms} becomes a request. Path placeholders get lowercase slugs
/// ("-"-joined unless the adapter says otherwise); query placeholders get
/// percent-encoding with the case kept.
final class AdapterURLTests: XCTestCase {

    func testPathTermsBecomeLowercaseHyphenatedSlug() {
        var a = Adapter(id: "x", name: "x", kind: .html,
                        searchURL: "https://example.com/q/{terms}/p/{page}/")
        let url = a.url(for: "PHANTOM FLOYD ROSE")
        XCTAssertEqual(url?.absoluteString, "https://example.com/q/phantom-floyd-rose/p/1/")
    }

    func testPathTermsRespectTermsSeparator() {
        // Marktplaats: hyphenated path terms match nothing, the words must
        // be "+"-joined.
        var a = Adapter(id: "x", name: "x", kind: .html,
                        searchURL: "https://example.com/q/{terms}/p/{page}/")
        a.termsSeparator = "+"
        let url = a.url(for: "PHANTOM FLOYD ROSE")
        XCTAssertEqual(url?.absoluteString, "https://example.com/q/phantom+floyd+rose/p/1/")
    }

    func testQueryTermsArePercentEncodedAndKeepCase() {
        var a = Adapter(id: "x", name: "x", kind: .html,
                        searchURL: "https://example.com/search?q={terms}&page={page}")
        let url = a.url(for: "PHANTOM FLOYD ROSE")
        XCTAssertEqual(url?.absoluteString,
                       "https://example.com/search?q=PHANTOM%20FLOYD%20ROSE&page=1")
    }

    func testMinimalEntryDecodesWithDefaults() throws {
        // Only id/name/kind/searchURL are required; everything else has a
        // default. Registry entries are written by hand, in a hurry.
        let json = """
        {"id":"x","name":"x","kind":"html","searchURL":"https://example.com/?q={terms}",
         "headers":{"Referer":"https://example.com/"}}
        """.data(using: .utf8)!
        let a = try JSONDecoder().decode(Adapter.self, from: json)
        XCTAssertEqual(a.headers?["Referer"], "https://example.com/")
        XCTAssertTrue(a.enabled)
        XCTAssertEqual(a.throttle, 3)
        XCTAssertEqual(a.fields, [:])
        XCTAssertEqual(a.canaryMinResults, 1)
    }
}
