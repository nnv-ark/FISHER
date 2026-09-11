import XCTest

/// The merge rules shared by the bundled adapters.json and a hosted
/// registry. Saved wins, except a strictly newer incoming version replaces
/// the saved entry — and never when the entry was hand-tuned (`userEdited`,
/// which disabling a source also sets) or saved before versions existed.
final class AdapterMergeTests: XCTestCase {

    func adapter(_ id: String, version: Int?, edited: Bool? = nil) -> Adapter {
        var a = Adapter(id: id, name: id, kind: .html, searchURL: "https://example.com/?q={terms}")
        a.adapterVersion = version
        a.userEdited = edited
        return a
    }

    func testNewerIncomingReplacesStockSavedAndKeepsOrder() {
        let saved = [adapter("a", version: 1), adapter("b", version: 1)]
        let incoming = [adapter("b", version: 2), adapter("a", version: 1)]
        let merged = saved.merged(with: incoming)
        XCTAssertEqual(merged.map(\.id), ["a", "b"])
        XCTAssertEqual(merged.first { $0.id == "b" }?.adapterVersion, 2)
    }

    func testOlderOrEqualIncomingDoesNotReplace() {
        let saved = [adapter("a", version: 3)]
        let merged = saved.merged(with: [adapter("a", version: 2), adapter("a", version: 3)])
        XCTAssertEqual(merged.first?.adapterVersion, 3)
    }

    func testUserEditedNeverReplaced() {
        let saved = [adapter("a", version: 1, edited: true)]
        let merged = saved.merged(with: [adapter("a", version: 5)])
        XCTAssertEqual(merged.first?.adapterVersion, 1)
    }

    func testLegacyNilVersionNeverReplaced() {
        let saved = [adapter("a", version: nil)]
        let merged = saved.merged(with: [adapter("a", version: 5)])
        XCTAssertEqual(merged.first?.adapterVersion, nil)
    }

    func testUnknownIncomingIdsAppendedInOrder() {
        let saved = [adapter("a", version: 1)]
        let merged = saved.merged(with: [adapter("x", version: 1), adapter("y", version: 1)])
        XCTAssertEqual(merged.map(\.id), ["a", "x", "y"])
    }

    func testEmptyIncomingIsNoOp() {
        let saved = [adapter("a", version: 1)]
        XCTAssertEqual(saved.merged(with: []), saved)
    }
}
