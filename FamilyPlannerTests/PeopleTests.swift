import XCTest
@testable import FamilyPlanner

@MainActor
final class PeopleTests: XCTestCase {
    private let account = UUID()
    private let person = UUID()

    func testMemberIdOfAPersonWithoutAccountCarriesAPrefix() {
        let id = PeopleNames.memberId(member: nil, person: person)
        XCTAssertEqual(id, "person:" + person.uuidString)
        XCTAssertEqual(Member.personId(from: id), person.uuidString)
        XCTAssertEqual(Member(id: id ?? "", name: "Kim").personId, person.uuidString)
    }

    func testMemberIdOfAnAccountIsTheUserId() {
        XCTAssertEqual(PeopleNames.memberId(member: account, person: nil), account.uuidString)
        XCTAssertNil(Member.personId(from: account.uuidString))
        XCTAssertNil(PeopleNames.memberId(member: nil, person: nil))
    }

    func testAssigneeColumnsAreSplitByKind() {
        let forPerson = AssigneeColumns(memberId: "person:" + person.uuidString)
        XCTAssertNil(forPerson.member)
        XCTAssertEqual(forPerson.person, person.uuidString)
        let forAccount = AssigneeColumns(memberId: account.uuidString)
        XCTAssertEqual(forAccount.member, account.uuidString)
        XCTAssertNil(forAccount.person)
        let nobody = AssigneeColumns(memberId: nil)
        XCTAssertNil(nobody.member)
        XCTAssertNil(nobody.person)
    }

    func testNamesComeFromEitherKind() {
        let names = PeopleNames(members: [account: "Alex"], people: [person: "Kim"])
        XCTAssertEqual(names.name(member: account, person: nil), "Alex")
        XCTAssertEqual(names.name(member: nil, person: person), "Kim")
        XCTAssertNil(names.name(member: nil, person: nil))
    }

    func testTaskRowOfAPersonWithoutAccountAndWithTime() throws {
        let json = """
        {"id":"\(UUID().uuidString)","title":"Costume","assignee":null,"assignee_person":"\(person.uuidString)",
         "due_on":"2026-12-04","due_time":"08:15:00","status":"open","cash_cents":500}
        """
        let row = try JSONDecoder().decode(TaskRow.self, from: Data(json.utf8))
        let item = row.makeItem(names: PeopleNames(members: [:], people: [person: "Kim"]))
        XCTAssertEqual(item.assignee, "Kim")
        XCTAssertEqual(item.assigneeId, "person:" + person.uuidString)
        XCTAssertEqual(item.dueTime, "08:15")
        XCTAssertEqual(item.cashCents, 500)
    }

    func testTimeIsNotWrittenWithoutADate() throws {
        let write = TaskWrite(
            familyId: nil, title: "No date", assignee: nil, assigneePerson: nil,
            dueOn: nil, dueTime: "08:15", cashCents: nil
        )
        let data = try JSONEncoder().encode(write)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(object["due_time"] is NSNull)
    }

    func testTaskWithPersonAndTimeIsSavedByTheDemoSource() async {
        let model = TasksViewModel(source: DemoDataSource())
        let draft = TaskDraft(
            id: nil, title: "Kostüm", assigneeId: "person:kim", dueOn: "2026-12-04", cashCents: nil, dueTime: "08:15"
        )
        let saved = await model.save(draft)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.board.tasks.last?.assignee, "Kim")
        XCTAssertEqual(model.board.tasks.last?.dueTime, "08:15")
    }

    func testSuggestionTimeBecomesTheTaskTime() {
        let suggestion = InboxSuggestion(
            id: "1", kind: .task, title: "Costume", date: "2026-12-04", time: .at(8, 15), amountCents: nil,
            currency: nil, summary: "", sender: "", subject: "", link: nil
        )
        XCTAssertEqual(SuggestionDrafts.task(from: suggestion).dueTime, "08:15")
    }
}
