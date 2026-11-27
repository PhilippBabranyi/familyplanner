import XCTest
@testable import FamilyPlanner

@MainActor
final class PickupNotesTests: XCTestCase {
    private let notes = [
        PickupNote(weekday: .wednesday, validFrom: "2026-09-01", note: "Book back, PE kit"),
        PickupNote(weekday: .thursday, validFrom: "2026-09-01", note: "Ballet bag"),
        PickupNote(weekday: .thursday, validFrom: "2027-01-11", note: "")
    ]

    private func bring(_ day: String, _ weekday: Weekday, overrides: [String: String] = [:], holiday: Bool = false)
        -> String? {
        PickupNotes.bring(on: day, weekday: weekday, notes: notes, overrides: overrides, inHoliday: holiday)
    }

    func testTheRhythmDecidesWhatToTakeAlong() {
        XCTAssertEqual(bring("2026-12-02", .wednesday), "Book back, PE kit")
        XCTAssertEqual(bring("2026-12-03", .thursday), "Ballet bag")
        XCTAssertNil(bring("2026-12-04", .friday))
        XCTAssertNil(bring("2026-08-27", .thursday), "before the first rhythm there is nothing")
    }

    func testANewRhythmReplacesTheOldOneFromItsStartDay() {
        XCTAssertEqual(bring("2027-01-07", .thursday), "Ballet bag")
        XCTAssertNil(bring("2027-01-14", .thursday), "the empty note ends the old one")
    }

    func testANoteForOneDayIsAddedToTheRhythmAndAnEmptyOneClears() {
        XCTAssertEqual(
            bring("2026-12-02", .wednesday, overrides: ["2026-12-02": "Swimming kit"]),
            "Book back, PE kit & Swimming kit"
        )
        XCTAssertEqual(bring("2026-12-03", .thursday, overrides: ["2026-12-03": "Jumper"]), "Ballet bag & Jumper")
        XCTAssertNil(bring("2026-12-02", .wednesday, overrides: ["2026-12-02": " "]))
    }

    func testNothingIsTakenAlongInHolidays() {
        XCTAssertNil(bring("2026-12-02", .wednesday, holiday: true))
    }

    func testOnlyChangedWeekdaysGetNewRows() {
        let rows = PickupNotes.rows(
            startingOn: "2027-02-01",
            texts: [.wednesday: "Book back, PE kit", .thursday: "", .friday: "Piano book"],
            current: notes
        )
        XCTAssertEqual(rows, [PickupNote(weekday: .friday, validFrom: "2027-02-01", note: "Piano book")])
    }

    func testAnEmptyTextEndsAnEarlierNote() {
        let rows = PickupNotes.rows(startingOn: "2027-02-01", texts: [.wednesday: ""], current: notes)
        XCTAssertEqual(rows, [PickupNote(weekday: .wednesday, validFrom: "2027-02-01", note: "")])
    }

    func testTheWeekShowsTheNotesAndNothingInHolidays() async {
        let monday = WeekBuilder.date(fromISO: "2026-11-23", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: monday)
        await model.load()
        let start = WeekBuilder.date(fromISO: "2026-09-01", calendar: WeekBuilder.calendar()) ?? monday
        let saved = await model.saveRhythm(from: start, texts: [.wednesday: "Book back", .friday: "Piano book"])
        XCTAssertTrue(saved)
        XCTAssertEqual(model.shownPlan.bringByDay[.wednesday], "Book back")
        XCTAssertEqual(model.shownPlan.bringByDay[.friday], "Piano book")
        XCTAssertNil(model.shownPlan.bringByDay[.monday])
        _ = await model.addHoliday(name: "Break", startsOn: "2026-11-25", endsOn: "2026-11-25")
        XCTAssertNil(model.shownPlan.bringByDay[.wednesday])
    }

    func testANewRhythmDoesNotChangeEarlierWeeks() async {
        let monday = WeekBuilder.date(fromISO: "2026-11-23", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: monday)
        await model.load()
        let first = WeekBuilder.date(fromISO: "2026-09-01", calendar: WeekBuilder.calendar()) ?? monday
        let second = WeekBuilder.date(fromISO: "2026-11-30", calendar: WeekBuilder.calendar()) ?? monday
        _ = await model.saveRhythm(from: first, texts: [.thursday: "Ballet bag"])
        _ = await model.saveRhythm(from: second, texts: [.thursday: ""])
        XCTAssertEqual(model.shownPlan.bringByDay[.thursday], "Ballet bag")
        model.showWeek(offsetBy: 1)
        XCTAssertNil(model.shownPlan.bringByDay[.thursday])
    }

    func testANoteForOneDayCanBeSetAndReset() async {
        let monday = WeekBuilder.date(fromISO: "2026-11-23", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: monday)
        await model.load()
        _ = await model.setBringNote(day: .tuesday, note: "Swimming kit")
        XCTAssertEqual(model.shownPlan.bringByDay[.tuesday], "Swimming kit")
        XCTAssertTrue(model.shownPlan.bringChangedDays.contains(.tuesday))
        _ = await model.setBringNote(day: .tuesday, note: nil)
        XCTAssertNil(model.shownPlan.bringByDay[.tuesday])
    }
}
