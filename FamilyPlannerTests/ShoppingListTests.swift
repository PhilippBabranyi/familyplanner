import XCTest
@testable import FamilyPlanner

final class ShoppingListTests: XCTestCase {
    func testSectionsListOpenGroupsInFixedOrderThenBasket() {
        let titles = DemoData.shoppingList.sections.map(\.title)
        XCTAssertEqual(titles, ["Obst & Gemüse", "Backen", "Haushalt", ShoppingList.basketTitle])
    }

    func testTogglingMovesAnItemIntoTheBasketAndBack() {
        var list = DemoData.shoppingList
        let before = list.inBasketCount
        list.toggle("tomatoes")
        XCTAssertEqual(list.inBasketCount, before + 1)
        XCTAssertEqual(list.sections.last?.title, ShoppingList.basketTitle)
        XCTAssertTrue(list.sections.last?.items.contains { $0.id == "tomatoes" } ?? false)
        list.toggle("tomatoes")
        XCTAssertEqual(list.inBasketCount, before)
    }

    func testEmptyGroupsDisappear() {
        var list = DemoData.shoppingList
        XCTAssertTrue(list.sections.map(\.title).contains("Haushalt"))
        list.toggle("soap")
        XCTAssertFalse(list.sections.map(\.title).contains("Haushalt"))
    }

    func testAddTrimsAndPutsItemUnderSonstiges() {
        var list = DemoData.shoppingList
        XCTAssertTrue(list.add(name: "  Brot \n"))
        let added = list.items.last
        XCTAssertEqual(added?.name, "Brot")
        XCTAssertEqual(added?.group, .other)
        XCTAssertTrue(list.sections.map(\.title).contains("Sonstiges"))
    }

    func testAddRejectsBlankNames() {
        var list = DemoData.shoppingList
        let count = list.items.count
        XCTAssertFalse(list.add(name: "   "))
        XCTAssertFalse(list.add(name: ""))
        XCTAssertEqual(list.items.count, count)
    }
}
