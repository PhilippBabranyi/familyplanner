import XCTest
@testable import FamilyPlanner

final class InboxModelsTests: XCTestCase {
    private func payload(
        kind: String = "task", date: String? = "2026-12-04", time: String? = nil,
        amount: Double? = 5, currency: String? = "GBP"
    ) -> SuggestionPayload {
        SuggestionPayload(
            kind: kind, title: "Kostümtag", date: date, time: time,
            amount: amount, currency: currency, summary: "Kostüm mitgeben."
        )
    }

    private func make(_ payload: SuggestionPayload) -> InboxSuggestion? {
        InboxSuggestion(
            id: "1", payload: payload, sender: "teacher@school.example", subject: "Costume day",
            link: "https://mail.google.com/mail/#all/abc"
        )
    }

    func testSuggestionsWithNothingToDoAreDropped() {
        XCTAssertNil(make(payload(kind: "none")))
        XCTAssertNil(make(payload(kind: "something-else")))
    }

    func testTaskAndEventAreRecognised() {
        XCTAssertEqual(make(payload(kind: "task"))?.kind, .task)
        XCTAssertEqual(make(payload(kind: "event", time: "18:00"))?.kind, .event)
    }

    func testAmountIsShownInTheCurrencyOfTheMail() {
        let suggestion = make(payload(amount: 5, currency: "GBP"))
        XCTAssertEqual(suggestion?.amountCents, 500)
        XCTAssertEqual(suggestion?.amountText, "5,00 GBP")
    }

    func testOnlyEuroAmountsAreTakenOverIntoTheCashField() {
        XCTAssertNil(make(payload(amount: 5, currency: "GBP"))?.amountCentsInEuro)
        XCTAssertEqual(make(payload(amount: 12.5, currency: "EUR"))?.amountCentsInEuro, 1250)
        XCTAssertEqual(make(payload(amount: 12.5, currency: nil))?.amountCentsInEuro, 1250)
        XCTAssertNil(make(payload(amount: nil, currency: nil))?.amountCentsInEuro)
    }

    func testWhenTextNamesDayAndTime() {
        XCTAssertEqual(make(payload(date: "2026-12-04", time: nil))?.whenText, "4.12.")
        XCTAssertEqual(make(payload(kind: "event", date: "2026-12-04", time: "09:30"))?.whenText, "4.12. um 09:30")
        XCTAssertNil(make(payload(date: nil))?.whenText)
    }

    func testBrokenTimeIsIgnored() {
        XCTAssertNil(make(payload(kind: "event", time: "25:99"))?.time)
    }

    func testDecodingTheStoredJson() throws {
        let json = """
        {"kind":"task","title":"Kostümtag","date":"2026-12-04","time":null,"amount":5,"currency":"GBP",
         "summary":"Kostüm mitgeben."}
        """
        let decoded = try JSONDecoder().decode(SuggestionPayload.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.amount, 5)
        XCTAssertNil(decoded.time)
    }
}
