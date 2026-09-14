import XCTest

/// One paper per day. A sweep reprints the day's edition rather than
/// stacking a second issue under the same date.
final class EditionTests: XCTestCase {

    private func edition(id: Int, date: Date) -> Edition {
        Edition(id: id, date: date, sourcesRead: 1, printedAt: date)
    }

    func testNewDayAppends() {
        let yesterday = Date().addingTimeInterval(-86_400)
        let existing = [edition(id: 1, date: yesterday)]
        let out = Edition.inserting(edition(id: 2, date: Date()), into: existing)
        XCTAssertEqual(out.map(\.id), [1, 2])
    }

    func testSameDayReprintsKeepingIssueNumber() {
        let first = edition(id: 6, date: Date())
        let reprint = edition(id: 7, date: Date())
        let out = Edition.inserting(reprint, into: [first])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].id, 6, "a reprint keeps the number the day's paper already had")
    }

    func testReprintTargetsTodayNotEarlierIssue() {
        let yesterday = Date().addingTimeInterval(-86_400)
        let older = edition(id: 5, date: yesterday)
        let todays = edition(id: 6, date: Date())
        let out = Edition.inserting(edition(id: 7, date: Date()), into: [older, todays])
        XCTAssertEqual(out.map(\.id), [5, 6])
        XCTAssertEqual(out.count, 2)
    }

    func testFirstEditionAppends() {
        let out = Edition.inserting(edition(id: 1, date: Date()), into: [])
        XCTAssertEqual(out.map(\.id), [1])
    }
}
