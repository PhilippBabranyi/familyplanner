import XCTest
@testable import FamilyPlanner

@MainActor
final class PickupTests: XCTestCase {
    func testPickupDriverCanBeEnteredAndRemoved() async {
        let monday = WeekBuilder.date(fromISO: "2026-11-23", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: monday)
        await model.load()
        XCTAssertNil(model.driverName(on: .monday))
        let saved = await model.setPickupDriver(day: .monday, memberId: "Alex")
        XCTAssertTrue(saved)
        XCTAssertEqual(model.driverName(on: .monday), "Alex")
        _ = await model.setPickupDriver(day: .monday, memberId: nil)
        XCTAssertNil(model.driverName(on: .monday))
    }

    func testPickupCanBeChangedForOneDayAndReset() async {
        let monday = WeekBuilder.date(fromISO: "2026-11-23", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: monday)
        await model.load()
        XCTAssertEqual(model.shownPlan.pickupTime(on: .monday), .at(15, 20))
        _ = await model.setPickupOverride(day: .monday, override: .time(.at(13, 0)))
        XCTAssertEqual(model.shownPlan.pickupTime(on: .monday), .at(13, 0))
        XCTAssertEqual(model.shownPlan.pickupTime(on: .tuesday), .at(15, 20))
        _ = await model.setPickupOverride(day: .monday, override: .cancelled)
        XCTAssertNil(model.shownPlan.pickupTime(on: .monday))
        _ = await model.setPickupOverride(day: .monday, override: nil)
        XCTAssertEqual(model.shownPlan.pickupTime(on: .monday), .at(15, 20))
    }

    func testTodayShowsThePickupAndWhoTakesIt() async {
        let monday = WeekBuilder.date(fromISO: "2026-11-23", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: monday)
        await model.load()
        XCTAssertEqual(model.todayPickup, TodayPickup(time: .at(15, 20), driver: nil, mark: .open))
        _ = await model.setPickupDriver(day: .monday, memberId: "Alex")
        XCTAssertEqual(model.todayPickup, TodayPickup(time: .at(15, 20), driver: "Alex", mark: .assigned))
        _ = await model.setPickupOverride(day: .monday, override: .cancelled)
        XCTAssertNil(model.todayPickup)
    }
}
