import XCTest
@testable import FamilyPlanner

final class TaskBoardTests: XCTestCase {
    func testAdvanceMovesThroughAllStatesAndBackToOpen() {
        var board = DemoData.taskBoard
        XCTAssertEqual(board.tasks.first { $0.id == "gift" }?.status, .open)
        board.advance("gift")
        XCTAssertEqual(board.tasks.first { $0.id == "gift" }?.status, .doing)
        board.advance("gift")
        XCTAssertEqual(board.tasks.first { $0.id == "gift" }?.status, .done)
        board.advance("gift")
        XCTAssertEqual(board.tasks.first { $0.id == "gift" }?.status, .open)
    }

    func testCountsFollowTheMovedTask() {
        var board = DemoData.taskBoard
        let open = board.count(in: .open)
        let doing = board.count(in: .doing)
        board.advance("dentist")
        XCTAssertEqual(board.count(in: .open), open - 1)
        XCTAssertEqual(board.count(in: .doing), doing + 1)
    }

    func testUnknownIdChangesNothing() {
        var board = DemoData.taskBoard
        let before = TaskStatus.allCases.map { board.count(in: $0) }
        board.advance("does-not-exist")
        XCTAssertEqual(TaskStatus.allCases.map { board.count(in: $0) }, before)
    }

    func testEveryTaskHasExactlyOneStatus() {
        let board = DemoData.taskBoard
        let total = TaskStatus.allCases.reduce(0) { $0 + board.count(in: $1) }
        XCTAssertEqual(total, board.tasks.count)
    }
}
