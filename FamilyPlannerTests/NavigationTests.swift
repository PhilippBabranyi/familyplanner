import XCTest
@testable import FamilyPlanner

@MainActor
final class NavigationTests: XCTestCase {
    private func model() -> WeekViewModel {
        let monday = WeekBuilder.date(fromISO: "2026-11-23", calendar: WeekBuilder.calendar()) ?? Date()
        return WeekViewModel(source: DemoDataSource(), now: monday)
    }

    func testSwipingMovesToTheNextAndPreviousDay() {
        let model = model()
        XCTAssertEqual(model.moveDay(from: .monday, by: 1), .tuesday)
        XCTAssertEqual(model.moveDay(from: .friday, by: -1), .thursday)
        XCTAssertEqual(model.shownWeekOffset, 0)
    }

    func testSwipingOverTheEndOfTheWeekShowsTheNeighbouringWeek() {
        let model = model()
        XCTAssertEqual(model.moveDay(from: .sunday, by: 1), .monday)
        XCTAssertEqual(model.shownWeekOffset, 1)
        XCTAssertEqual(model.moveDay(from: .monday, by: -1), .sunday)
        XCTAssertEqual(model.shownWeekOffset, 0)
    }

    func testATapOnANotificationShowsThatDayOnce() {
        let model = model()
        // 2026-12-02 is a Wednesday in the week after the shown one.
        model.focus(on: WeekBuilder.date(fromISO: "2026-12-02", calendar: WeekBuilder.calendar()) ?? Date())
        XCTAssertEqual(model.shownWeekOffset, 1)
        XCTAssertEqual(model.takeFocusedDay(), .wednesday)
        XCTAssertNil(model.takeFocusedDay())
    }
}
