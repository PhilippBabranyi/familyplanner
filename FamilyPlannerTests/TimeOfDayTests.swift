import XCTest
@testable import FamilyPlanner

final class TimeOfDayTests: XCTestCase {
    func testRejectsInvalidValues() {
        XCTAssertNil(TimeOfDay(hour: 24, minute: 0))
        XCTAssertNil(TimeOfDay(hour: -1, minute: 0))
        XCTAssertNil(TimeOfDay(hour: 12, minute: 60))
    }

    func testAcceptsBoundaryValues() {
        XCTAssertNotNil(TimeOfDay(hour: 0, minute: 0))
        XCTAssertNotNil(TimeOfDay(hour: 23, minute: 59))
    }

    func testFormatsWithLeadingZeros() {
        XCTAssertEqual(TimeOfDay.at(7, 5).description, "07:05")
        XCTAssertEqual(TimeOfDay.at(16, 20).description, "16:20")
    }

    func testOrdersByHourThenMinute() {
        XCTAssertLessThan(TimeOfDay.at(15, 59), .at(16, 0))
        XCTAssertLessThan(TimeOfDay.at(16, 0), .at(16, 20))
    }

    func testFormatsEuroAmounts() {
        XCTAssertEqual(formattedEuros(cents: 4000), "40 €")
    }
}
