import Foundation

/// Invented sample data. Real family data is never stored in this repository.
enum DemoData {
    static let taskBoard = TaskBoard(tasks: [
        TaskItem(id: "gift", title: "Geschenk für Oma besorgen", assignee: "Alex", due: "bis Fr", status: .open),
        TaskItem(id: "dentist", title: "Zahnarzt-Termin ausmachen", assignee: "Alex", due: "heute", status: .open),
        TaskItem(id: "windows", title: "Fenster putzen", assignee: "Haushaltshilfe", due: "Do", status: .open),
        TaskItem(id: "cake", title: "Kuchen backen", assignee: "Sam", due: "Fr", status: .doing),
        TaskItem(id: "tax", title: "Steuerunterlagen sortieren", assignee: "Alex", due: "ohne Datum", status: .doing),
        TaskItem(id: "flowers", title: "Blumen kaufen", assignee: "Sam", due: "erledigt", status: .done),
        TaskItem(id: "card", title: "Karte schreiben", assignee: "Alex", due: "erledigt", status: .done)
    ])

    static let shoppingList = ShoppingList(items: [
        ShoppingItem(id: "tomatoes", name: "Tomaten", quantity: "500 g", group: .produce),
        ShoppingItem(id: "apples", name: "Äpfel", quantity: "6 Stück", group: .produce),
        ShoppingItem(id: "flour", name: "Mehl", quantity: "1 kg", group: .baking,
                     isInBasket: true, label: "Omas Kuchen"),
        ShoppingItem(id: "butter", name: "Butter", quantity: "250 g", group: .baking, label: "Omas Kuchen"),
        ShoppingItem(id: "eggs", name: "Eier", quantity: "6 Stück", group: .baking, label: "Omas Kuchen"),
        ShoppingItem(id: "soap", name: "Spülmittel", group: .household),
        ShoppingItem(id: "oatmilk", name: "Hafermilch", quantity: "2 l", group: .household, isInBasket: true)
    ])

    static let weekPlan = WeekPlan(
        pickup: PickupSchedule(
            pickupDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            defaultTime: .at(15, 20),
            exceptions: [.thursday: .at(16, 20)]
        ),
        itemsByDay: [
            .monday: [
                WeekItem(id: "mon-tax", time: .at(20, 0), title: "Steuerunterlagen sortieren",
                         note: "Frist rückt näher", assignee: "Alex")
            ],
            .tuesday: [
                WeekItem(id: "tue-dentist", time: .at(10, 0), title: "Zahnarzt anrufen", assignee: "Alex"),
                WeekItem(id: "tue-cake", time: .at(13, 0), title: "Zutaten fürs Kuchenbacken", assignee: "Sam"),
                WeekItem(id: "tue-helper", time: .at(16, 0), title: "Haushaltshilfe kommt",
                         assignee: "Haushaltshilfe", tag: .cash(cents: 4000))
            ],
            .wednesday: [
                WeekItem(id: "wed-library", time: .at(7, 30), title: "Library Day", note: "Buch mitnehmen"),
                WeekItem(id: "wed-sports", time: .at(7, 30), title: "Sports Day", note: "Sportsachen anziehen"),
                WeekItem(id: "wed-trash", time: .at(19, 0), title: "Müll rausstellen", tag: .homeAssistant)
            ],
            .thursday: [
                WeekItem(id: "thu-ballet", time: .at(15, 30), title: "Ballett", note: "Abholung erst um 16:20")
            ],
            .friday: [
                WeekItem(id: "fri-piano", time: .at(7, 30), title: "Klavier", note: "Buch nicht vergessen"),
                WeekItem(id: "fri-gift", time: .at(12, 0), title: "Geschenk für Oma besorgen",
                         note: "Frist: heute", assignee: "Alex"),
                WeekItem(id: "fri-sitter", time: .at(19, 0), title: "Babysitter kommt",
                         tag: .cash(cents: 2000))
            ],
            .saturday: [
                WeekItem(id: "sat-plants", time: .at(8, 0), title: "Pflanzen gießen", tag: .homeAssistant),
                WeekItem(id: "sat-swim", time: .at(9, 30), title: "Schwimmen"),
                WeekItem(id: "sat-birthday", time: .at(15, 0), title: "Omas 80. Geburtstag",
                         note: "Kuchen und Geschenk mitbringen")
            ],
            .sunday: [
                WeekItem(id: "sun-preview", time: .at(19, 0), title: "Wochenvorschau",
                         note: "Die neue Woche auf einen Blick")
            ]
        ]
    )

    /// Two invented suggestions for the bell.
    static let suggestions = [
        InboxSuggestion(
            id: "s1", kind: .task, title: "Kostümtag bei den Owls", date: "2026-12-04", time: nil,
            amountCents: 500, currency: "GBP",
            summary: "Am Freitag, 4. Dezember, ist Kostümtag. Ein Kostüm und 5 Pfund für die Spendenaktion mitgeben.",
            sender: "teacher@school.example", subject: "Costume day",
            link: URL(string: "https://mail.google.com/mail/#all/demo1")
        ),
        InboxSuggestion(
            id: "s2", kind: .event, title: "Zoo-Ausflug", date: "2026-12-10", time: .at(9, 0),
            amountCents: nil, currency: nil,
            summary: "Die Klasse fährt in den Zoo. Brotzeit einpacken.",
            sender: "teacher@school.example", subject: "Zoo trip",
            link: URL(string: "https://mail.google.com/mail/#all/demo2")
        )
    ]

    static let members = [
        Member(id: "Alex", name: "Alex"),
        Member(id: "Sam", name: "Sam"),
        Member(id: "Haushaltshilfe", name: "Haushaltshilfe")
    ]

    /// The demo week (23 to 29 November 2026) in the shape the database delivers it.
    static let calendarData = CalendarData(
        items: [
            demoItem("mon-tax", "Steuerunterlagen sortieren", "2026-11-23", .at(20, 0), assignee: "Alex"),
            demoItem("tue-dentist", "Zahnarzt anrufen", "2026-11-24", .at(10, 0), assignee: "Alex"),
            demoItem("tue-cake", "Zutaten fürs Kuchenbacken", "2026-11-24", .at(13, 0), assignee: "Sam"),
            demoItem("tue-helper", "Haushaltshilfe kommt", "2026-11-24", .at(16, 0),
                     assignee: "Haushaltshilfe", cashCents: 4000),
            demoItem("wed-library", "Library Day", "2026-11-25", .at(7, 30), note: "Buch mitnehmen"),
            demoItem("thu-ballet", "Ballett", "2026-11-26", .at(15, 30), note: "Abholung erst um 16:20"),
            demoItem("fri-piano", "Klavier", "2026-11-27", .at(7, 30), note: "Buch nicht vergessen"),
            demoItem("fri-sitter", "Babysitter kommt", "2026-11-27", .at(19, 0), cashCents: 2000),
            demoItem("sat-swim", "Schwimmen", "2026-11-28", .at(9, 30))
        ],
        pickups: [
            .monday: .at(15, 20), .tuesday: .at(15, 20), .wednesday: .at(15, 20),
            .thursday: .at(16, 20), .friday: .at(15, 20)
        ],
        holidays: []
    )

    private static func demoItem(
        _ id: String, _ title: String, _ date: String, _ time: TimeOfDay,
        note: String? = nil, assignee: String? = nil, cashCents: Int? = nil
    ) -> StoredCalendarItem {
        StoredCalendarItem(
            id: id, title: title, note: note, startsOn: date, time: time,
            assigneeId: assignee, assignee: assignee, cashCents: cashCents
        )
    }
}
