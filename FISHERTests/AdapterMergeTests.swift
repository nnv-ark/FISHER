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

    // MARK: the real registry file

    /// .../FISHERTests/AdapterMergeTests.swift → up two → repo root.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FISHERTests
            .deletingLastPathComponent()   // repo root
    }

    /// The Python validator checks the registry's shape; this proves the
    /// app itself can decode it. If Adapter.swift ever gains a required
    /// field, the drift is caught here, not on users' machines.
    func testRegistryFileDecodesThroughAdapter() throws {
        let url = repoRoot.appendingPathComponent("registry/adapters.json")
        let data = try Data(contentsOf: url)
        let registry = try JSONDecoder().decode([Adapter].self, from: data)
        XCTAssertFalse(registry.isEmpty)
        for adapter in registry {
            XCTAssertFalse(adapter.id.isEmpty, "an entry has an empty id")
            XCTAssertFalse(adapter.name.isEmpty, "\(adapter.id) has an empty name")
            XCTAssertFalse(adapter.searchURL.isEmpty, "\(adapter.id) has an empty searchURL")
            XCTAssertNotNil(adapter.adapterVersion,
                            "\(adapter.id) has no version — the registry could never update it")
        }
    }

    /// Same cross-check the validator does: a source the app also ships
    /// bundled must not regress below the bundled version, or installs
    /// carrying the bundled one would ignore every registry fix.
    func testRegistryVersionsNeverBelowBundled() throws {
        let bundled = try JSONDecoder().decode(
            [Adapter].self,
            from: Data(contentsOf: repoRoot.appendingPathComponent("FISHER/Resources/adapters.json")))
        let registry = try JSONDecoder().decode(
            [Adapter].self,
            from: Data(contentsOf: repoRoot.appendingPathComponent("registry/adapters.json")))
        let bundledVersions = Dictionary(uniqueKeysWithValues: bundled.map { ($0.id, $0.adapterVersion) })
        for entry in registry {
            if let floor = bundledVersions[entry.id], let version = entry.adapterVersion, let floor {
                XCTAssertGreaterThanOrEqual(version, floor,
                    "\(entry.id): registry version \(version) is below the bundled \(floor)")
            }
        }
    }
}
