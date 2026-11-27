import XCTest
@testable import FamilyPlanner

final class ItemFilterTests: XCTestCase {
    private let mine = WeekItem(id: "a", time: .at(8, 0), title: "Mine", assignee: "Alex")
    private let theirs = WeekItem(id: "b", time: .at(9, 0), title: "Theirs", assignee: "Sam")
    private let shared = WeekItem(id: "c", time: .at(10, 0), title: "Everyone")

    private func titles(_ filter: ItemFilter) -> [String] {
        [mine, theirs, shared].filter { filter.matches($0, viewer: "Alex") }.map(\.title)
    }

    func testAllShowsEverything() {
        XCTAssertEqual(titles(.all), ["Mine", "Theirs", "Everyone"])
    }

    func testMineShowsOnlyMyOwnItems() {
        XCTAssertEqual(titles(.mine), ["Mine"])
    }

    func testPersonShowsOnlyThatPerson() {
        XCTAssertEqual(titles(.person("Sam")), ["Theirs"])
    }

    func testFamilyShowsItemsWithoutAssignee() {
        XCTAssertEqual(titles(.family), ["Everyone"])
    }

    func testMineIsEmptyWhenTheNameIsUnknown() {
        XCTAssertFalse(ItemFilter.mine.matches(mine, viewer: nil))
    }

    func testOnlyItemsOfOthersAreMarkedAsSomeoneElses() {
        XCTAssertFalse(mine.isForSomeoneElse(than: "Alex"))
        XCTAssertTrue(theirs.isForSomeoneElse(than: "Alex"))
        XCTAssertFalse(shared.isForSomeoneElse(than: "Alex"))
    }
}
