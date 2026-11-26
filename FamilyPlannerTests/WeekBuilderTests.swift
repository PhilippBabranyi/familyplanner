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
        weekdays: Set<Weekday> = [],
        until: String? = nil,
        skipHolidays: Bool = false,
        at time: TimeOfDay = .at(9, 0),
        cash: Int? = nil
    ) -> StoredCalendarItem {
        StoredCalendarItem(
            id: id, title: id, note: nil, startsOn: startsOn, time: time,
            weekdays: weekdays, repeatUntil: until, skipHolidays: skipHolidays, cashCents: cash
        )
    }

    private func plan(
        _ items: [StoredCalendarItem] = [],
        pickups: [Weekday: TimeOfDay] = [:],
        holidays: [Holiday] = []
    ) -> WeekPlan {
        WeekBuilder.plan(
            data: CalendarData(items: items, pickups: pickups, holidays: holidays),
            weekStart: weekStart,
            calendar: calendar
        )
    }

    private func total(_ plan: WeekPlan) -> Int {
        Weekday.allCases.map { plan.items(on: $0).count }.reduce(0, +)
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
        let result = plan([item("op", on: "2026-11-25")])
        XCTAssertEqual(result.items(on: .wednesday).count, 1)
        XCTAssertEqual(total(result), 1)
    }

    func testOneOffItemOfAnotherWeekIsNotShown() {
        XCTAssertEqual(total(plan([item("later", on: "2026-12-02")])), 0)
    }

    func testSeriesRepeatsOnItsWeekdaysFromItsStartOn() {
        let series = item("pickup", on: "2026-11-02", weekdays: [.monday, .tuesday, .wednesday, .friday])
        let result = plan([series])
        XCTAssertEqual(result.items(on: .monday).count, 1)
        XCTAssertEqual(result.items(on: .thursday).count, 0)
        XCTAssertEqual(result.items(on: .friday).count, 1)
        XCTAssertEqual(total(result), 4)
    }

    func testSeriesDoesNotAppearBeforeItStarts() {
        XCTAssertEqual(total(plan([item("piano", on: "2026-12-04", weekdays: [.friday])])), 0)
    }

    func testSeriesStopsAfterItsEndDate() {
        let series = item("course", on: "2026-11-02", weekdays: [.monday, .friday], until: "2026-11-25")
        let result = plan([series])
        XCTAssertEqual(result.items(on: .monday).count, 1)
        XCTAssertEqual(result.items(on: .friday).count, 0)
    }

    func testSeriesWithSkipHolidaysPausesInHolidaysOnly() {
        let series = item("kita", on: "2026-11-02", weekdays: [.monday, .tuesday], skipHolidays: true)
        let always = item("sports", on: "2026-11-02", weekdays: [.monday, .tuesday])
        let holiday = Holiday(id: "h", name: "Herbst", startsOn: "2026-11-24", endsOn: "2026-11-27")
        let result = plan([series, always], holidays: [holiday])
        XCTAssertEqual(result.items(on: .monday).count, 2)
        XCTAssertEqual(result.items(on: .tuesday).map(\.title), ["sports"])
        XCTAssertEqual(result.holidays[.tuesday], "Herbst")
        XCTAssertNil(result.holidays[.monday])
    }

    func testNoPickupOnHolidayDaysButNormalOtherwise() {
        let pickups: [Weekday: TimeOfDay] = [.monday: .at(15, 20), .tuesday: .at(15, 20), .thursday: .at(16, 20)]
        let holiday = Holiday(id: "h", name: "Herbst", startsOn: "2026-11-24", endsOn: "2026-11-26")
        let result = plan(pickups: pickups, holidays: [holiday])
        XCTAssertEqual(result.pickup.time(on: .monday), .at(15, 20))
        XCTAssertNil(result.pickup.time(on: .tuesday))
        XCTAssertNil(result.pickup.time(on: .thursday))
    }

    func testCashTagBecomesPartOfTheWeekTotal() {
        let result = plan([item("sitter", on: "2026-11-27", cash: 2000)])
        XCTAssertEqual(result.cashNeededCents(on: .friday), 2000)
    }

    func testEntriesKnowTheirStoredItem() {
        let result = plan([item("op", on: "2026-11-25")])
        XCTAssertEqual(result.items(on: .wednesday).first?.sourceId, "op")
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
         "at_time":"07:30:00","weekdays":[1,5],"repeat_until":null,"skip_holidays":true,
         "assignee":null,"cash_cents":null}
        """
        let row = try JSONDecoder().decode(CalendarItemRow.self, from: Data(json.utf8))
        let stored = try XCTUnwrap(row.makeItem(names: PeopleNames()))
        XCTAssertEqual(stored.time, .at(7, 30))
        XCTAssertEqual(stored.weekdays, [.monday, .friday])
        XCTAssertTrue(stored.skipHolidays)
    }

    func testPickupDriverIsPlacedOnItsDayAndNotOnHolidays() {
        let data = CalendarData(
            pickups: [.monday: .at(15, 20), .tuesday: .at(15, 20)],
            holidays: [Holiday(id: "h", name: "Break", startsOn: "2026-11-24", endsOn: "2026-11-24")],
            pickupDrivers: ["2026-11-23": "sam", "2026-11-24": "sam"]
        )
        let result = WeekBuilder.plan(data: data, weekStart: date("2026-11-23"), calendar: calendar)
        XCTAssertEqual(result.driverByDay[.monday], "sam")
        XCTAssertNil(result.driverByDay[.tuesday])
        XCTAssertNil(result.driverByDay[.wednesday])
    }

    func testPickupDriverIdMatchesTheMemberIdOfTheApp() throws {
        // The database delivers ids in lower case; the app builds member ids from UUID.uuidString (upper case).
        let id = UUID()
        let json = "{\"day\":\"2026-11-26\",\"driver\":\"\(id.uuidString.lowercased())\"}"
        let row = try JSONDecoder().decode(PickupDriverRow.self, from: Data(json.utf8))
        XCTAssertEqual(row.driverId, id.uuidString)
    }
}
