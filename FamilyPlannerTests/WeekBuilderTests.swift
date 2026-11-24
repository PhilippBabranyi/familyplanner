import XCTest
@testable import FamilyPlanner

final class WeekBuilderTests: XCTestCase {
    private let calendar = WeekBuilder.calendar()

    private func date(_ text: String) -> Date {
        guard let result = WeekBuilder.date(fromISO: text, calendar: calendar) else {
            preconditionFailure("bad date \(text)")
        }
        return result
    }

    private func item(
        _ id: String,
        on startsOn: String,
        weekly: Bool = false,
        at time: TimeOfDay = .at(9, 0),
        cash: Int? = nil
    ) -> StoredCalendarItem {
        StoredCalendarItem(
            id: id, title: id, note: nil, startsOn: startsOn, time: time,
            repeatsWeekly: weekly, assignee: nil, cashCents: cash
        )
    }

    private var weekStart: Date { date("2026-11-23") }

    func testWeekStartIsTheMonday() {
        XCTAssertEqual(WeekBuilder.weekStart(containing: date("2026-11-24"), calendar: calendar), weekStart)
        XCTAssertEqual(WeekBuilder.weekStart(containing: date("2026-11-29"), calendar: calendar), weekStart)
        XCTAssertEqual(WeekBuilder.weekStart(containing: date("2026-11-23"), calendar: calendar), weekStart)
    }

    func testWeekdayMapping() {
        XCTAssertEqual(WeekBuilder.weekday(of: date("2026-11-23"), calendar: calendar), .monday)
        XCTAssertEqual(WeekBuilder.weekday(of: date("2026-11-29"), calendar: calendar), .sunday)
    }

    func testOneOffItemAppearsOnlyOnItsDay() {
        let plan = WeekBuilder.plan(items: [item("op", on: "2026-11-25")], pickups: [:],
                                    weekStart: weekStart, calendar: calendar)
        XCTAssertEqual(plan.items(on: .wednesday).count, 1)
        XCTAssertEqual(Weekday.allCases.map { plan.items(on: $0).count }.reduce(0, +), 1)
    }

    func testOneOffItemOfAnotherWeekIsNotShown() {
        let plan = WeekBuilder.plan(items: [item("later", on: "2026-12-02")], pickups: [:],
                                    weekStart: weekStart, calendar: calendar)
        XCTAssertTrue(Weekday.allCases.allSatisfy { plan.items(on: $0).isEmpty })
    }

    func testWeeklyItemRepeatsOnTheSameWeekdayFromItsStartOn() {
        // 2026-11-06 is a Friday.
        let weekly = item("piano", on: "2026-11-06", weekly: true)
        let plan = WeekBuilder.plan(items: [weekly], pickups: [:], weekStart: weekStart, calendar: calendar)
        XCTAssertEqual(plan.items(on: .friday).count, 1)
        XCTAssertEqual(Weekday.allCases.map { plan.items(on: $0).count }.reduce(0, +), 1)
    }

    func testWeeklyItemDoesNotAppearBeforeItStarts() {
        let weekly = item("piano", on: "2026-12-04", weekly: true)
        let plan = WeekBuilder.plan(items: [weekly], pickups: [:], weekStart: weekStart, calendar: calendar)
        XCTAssertTrue(plan.items(on: .friday).isEmpty)
    }

    func testCashTagBecomesPartOfTheWeekTotal() {
        let plan = WeekBuilder.plan(items: [item("sitter", on: "2026-11-27", cash: 2000)], pickups: [:],
                                    weekStart: weekStart, calendar: calendar)
        XCTAssertEqual(plan.cashNeededCents(on: .friday), 2000)
    }

    func testMostCommonPickupTimeIsTheDefaultAndOthersAreExceptions() {
        let pickups: [Weekday: TimeOfDay] = [
            .monday: .at(15, 20), .tuesday: .at(15, 20), .wednesday: .at(15, 20),
            .thursday: .at(16, 20), .friday: .at(15, 20)
        ]
        let schedule = WeekBuilder.schedule(from: pickups)
        XCTAssertEqual(schedule.defaultTime, .at(15, 20))
        XCTAssertTrue(schedule.isException(on: .thursday))
        XCTAssertNil(schedule.time(on: .saturday))
    }

    func testNoPickupRowsMeansNoPickupDays() {
        let schedule = WeekBuilder.schedule(from: [:])
        XCTAssertTrue(schedule.pickupDays.isEmpty)
    }

    func testDatabaseTimeParsing() {
        XCTAssertEqual(TimeOfDay(databaseValue: "15:20:00"), .at(15, 20))
        XCTAssertEqual(TimeOfDay(databaseValue: "07:30"), .at(7, 30))
        XCTAssertNil(TimeOfDay(databaseValue: "25:00:00"))
        XCTAssertNil(TimeOfDay(databaseValue: "noon"))
    }

    func testCalendarRowDecoding() throws {
        let json = """
        {"id":"\(UUID().uuidString)","title":"Klavier","note":null,"starts_on":"2026-11-06",
         "at_time":"07:30:00","repeats_weekly":true,"assignee":null,"cash_cents":null}
        """
        let row = try JSONDecoder().decode(CalendarItemRow.self, from: Data(json.utf8))
        let stored = try XCTUnwrap(row.makeItem(memberNames: [:]))
        XCTAssertEqual(stored.time, .at(7, 30))
        XCTAssertTrue(stored.repeatsWeekly)
    }
}
