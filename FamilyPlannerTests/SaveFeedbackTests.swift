import XCTest
@testable import FamilyPlanner

@MainActor
final class SaveFeedbackTests: XCTestCase {
    func testFailedSaveKeepsTheReasonAndSuccessAnnouncesIt() async {
        let model = WeekViewModel(source: ReadOnlySource())
        await model.load()
        _ = await model.setPickupDriver(day: .monday, memberId: "Alex")
        XCTAssertNotNil(model.errorDetail)
        model.clearMessages()
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(model.errorDetail)
        model.announceSaved()
        XCTAssertEqual(model.savedNotice, "Gespeichert")
    }
}
