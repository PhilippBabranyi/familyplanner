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

    func testAnItemHasStartedOnceItsTimeIsReached() async throws {
        // Thursday 2026-11-26 has the ballet at 15:30 in the demo week.
        let calendar = WeekBuilder.calendar()
        let thursday = try XCTUnwrap(WeekBuilder.date(fromISO: "2026-11-26", calendar: calendar))
        let model = WeekViewModel(source: DemoDataSource(), now: thursday)
        await model.load()
        let ballet = try XCTUnwrap(model.plan.items(on: .thursday).first { $0.title == "Ballett" })
        let morning = try XCTUnwrap(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: thursday))
        let evening = try XCTUnwrap(calendar.date(bySettingHour: 21, minute: 0, second: 0, of: thursday))
        XCTAssertFalse(model.hasStarted(ballet, at: morning))
        XCTAssertTrue(model.hasStarted(ballet, at: evening))
    }

    func testOpenPickupsOfTodayAndTomorrowShowInTheBell() async throws {
        // Thursday 2026-11-26 (16:20 in the demo week) and Friday (15:20): nobody is entered.
        let calendar = WeekBuilder.calendar()
        let thursday = try XCTUnwrap(WeekBuilder.date(fromISO: "2026-11-26", calendar: calendar))
        let model = WeekViewModel(source: DemoDataSource(), now: thursday)
        await model.load()
        let noon = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: thursday))
        XCTAssertEqual(model.openPickups(now: noon).map(\.dayText), ["2026-11-26", "2026-11-27"])
        // Once Thursday's pickup is over, only tomorrow is left.
        let evening = try XCTUnwrap(calendar.date(bySettingHour: 18, minute: 0, second: 0, of: thursday))
        XCTAssertEqual(model.openPickups(now: evening).map(\.dayText), ["2026-11-27"])
        // Somebody takes tomorrow over from the bell.
        _ = await model.setPickupDriver(dayText: "2026-11-27", memberId: "Alex")
        XCTAssertTrue(model.openPickups(now: evening).isEmpty)
    }

    func testSundayLooksIntoNextWeek() async throws {
        let calendar = WeekBuilder.calendar()
        let sunday = try XCTUnwrap(WeekBuilder.date(fromISO: "2026-11-29", calendar: calendar))
        let model = WeekViewModel(source: DemoDataSource(), now: sunday)
        await model.load()
        // There is no pickup on Sunday, but Monday of the next week has the weekly one.
        let noon = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: sunday))
        XCTAssertEqual(model.openPickups(now: noon).map(\.dayText), ["2026-11-30"])
    }
}
