import XCTest
@testable import FamilyPlanner

final class WeekPlanTests: XCTestCase {
    private let plan = DemoData.weekPlan

    func testPickupIsFifteenTwentyOnNormalSchoolDays() {
        for day in [Weekday.monday, .tuesday, .wednesday, .friday] {
            XCTAssertEqual(plan.pickup.time(on: day), .at(15, 20), "\(day.longName)")
            XCTAssertFalse(plan.pickup.isException(on: day), "\(day.longName)")
        }
    }

    func testThursdayPickupIsAnHourLaterAndMarkedAsException() {
        XCTAssertEqual(plan.pickup.time(on: .thursday), .at(16, 20))
        XCTAssertTrue(plan.pickup.isException(on: .thursday))
    }

    func testNoPickupOnWeekend() {
        XCTAssertNil(plan.pickup.time(on: .saturday))
        XCTAssertNil(plan.pickup.time(on: .sunday))
        XCTAssertFalse(plan.pickup.isException(on: .saturday))
    }

    func testItemsAreSortedByTime() {
        let times = plan.items(on: .wednesday).map(\.time)
        XCTAssertEqual(times, times.sorted())
        XCTAssertEqual(times.last, .at(19, 0))
    }

    func testCashNeededOnATuesdayIsFortyEuros() {
        XCTAssertEqual(plan.cashNeededCents(on: .tuesday), 4000)
    }

    func testCashNeededForTheWeekIsSixtyEuros() {
        XCTAssertEqual(plan.cashNeededCents, 6000)
    }

    func testDayWithoutItemsHasNoCashAndNoItems() {
        let empty = WeekPlan(pickup: plan.pickup, itemsByDay: [:])
        XCTAssertTrue(empty.items(on: .monday).isEmpty)
        XCTAssertEqual(empty.cashNeededCents, 0)
    }
}
