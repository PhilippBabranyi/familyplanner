/// Invented sample data. Real family data is never stored in this repository.
enum DemoData {
    /// Day-of-month of the Monday of the demo week (23 November 2026).
    static let weekStartDay = 23

    static func dayNumber(_ day: Weekday) -> Int {
        weekStartDay + day.rawValue - 1
    }

    static let weekPlan = WeekPlan(
        pickup: PickupSchedule(
            pickupDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            defaultTime: .at(15, 20),
            exceptions: [.thursday: .at(16, 20)]
        ),
        itemsByDay: [
            .monday: [
                WeekItem(id: "mon-tax", time: .at(20, 0), title: "Steuerunterlagen sortieren",
                         note: "Frist rückt näher", owner: .alex)
            ],
            .tuesday: [
                WeekItem(id: "tue-dentist", time: .at(10, 0), title: "Zahnarzt anrufen", owner: .alex),
                WeekItem(id: "tue-cake", time: .at(13, 0), title: "Zutaten fürs Kuchenbacken", owner: .sam),
                WeekItem(id: "tue-helper", time: .at(16, 0), title: "Haushaltshilfe kommt",
                         owner: .helper, tag: .cash(cents: 4000))
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
                         note: "Frist: heute", owner: .alex),
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
}
