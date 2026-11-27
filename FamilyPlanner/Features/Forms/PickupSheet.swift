import SwiftUI

/// Pickup times per weekday and the holidays during which there is no pickup.
struct PickupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: WeekViewModel

    @State private var enabled: Set<Weekday>
    @State private var times: [Weekday: Date]
    @State private var holidayName = ""
    @State private var holidayStart = Date()
    @State private var holidayEnd = Date()
    @State private var remindMinutes: Int
    @State private var isSaving = false
    @State private var rhythmStart = Date()
    @State private var bringTexts: [Weekday: String]

    init(model: WeekViewModel) {
        self.model = model
        let pickups = model.data.pickups
        _enabled = State(initialValue: Set(pickups.keys))
        var initial: [Weekday: Date] = [:]
        for day in Weekday.allCases {
            initial[day] = FormDates.date(from: pickups[day] ?? .at(15, 20))
        }
        _times = State(initialValue: initial)
        _remindMinutes = State(initialValue: model.data.remindMinutes)
        _bringTexts = State(initialValue: model.rhythmTexts(on: Date()))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Abholzeiten") {
                    ForEach(Weekday.allCases) { day in
                        HStack {
                            Toggle(day.longName, isOn: binding(for: day))
                                .accessibilityIdentifier("pickup-\(day.shortName)")
                            if enabled.contains(day) {
                                DatePicker("", selection: timeBinding(for: day), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                Section {
                    Picker("Erinnerung", selection: $remindMinutes) {
                        ForEach(reminderChoices, id: \.self) { minutes in
                            Text("\(minutes) Minuten vorher").tag(minutes)
                        }
                    }
                    .accessibilityIdentifier("pickup-remind")
                } footer: {
                    Text("Die Person, die an dem Tag abholt, bekommt dann die Nachricht „Zeit zum Losfahren“.")
                }
                bringSection
                holidaySection
            }
            .softFormStyle()
            .navigationTitle("\(model.pickupLabel) & Ferien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(isSaving)
                        .accessibilityIdentifier("pickup-save")
                }
            }
        }
    }

    /// The usual lead times, plus the stored one if it is something else.
    private var reminderChoices: [Int] {
        Array(Set([10, 15, 20, 30, 45, 60, 90, remindMinutes])).sorted()
    }

    /// What to take along on which weekday. Changing it starts a new rhythm from a date; earlier days keep theirs.
    private var bringSection: some View {
        Section {
            DatePicker("Gilt ab", selection: $rhythmStart, displayedComponents: .date)
                .accessibilityIdentifier("bring-from")
                .onChange(of: rhythmStart) { _, date in bringTexts = model.rhythmTexts(on: date) }
            ForEach(Weekday.allCases) { day in
                HStack {
                    Text(day.shortName).frame(width: 36, alignment: .leading).foregroundStyle(Theme.muted)
                    TextField("nichts", text: bringBinding(for: day))
                        .accessibilityIdentifier("bring-\(day.shortName)")
                }
            }
        } header: {
            Text("Mitnehmen")
        } footer: {
            Text("Zum Beispiel „Buch zurückbringen“. Am Morgen um 7:30 kommt dazu eine Erinnerung. "
                + "Ändert sich der Rhythmus, wähle das Datum, ab dem es gilt: frühere Tage bleiben, wie sie waren.")
        }
    }

    private func bringBinding(for day: Weekday) -> Binding<String> {
        Binding(get: { bringTexts[day] ?? "" }, set: { bringTexts[day] = $0 })
    }

    private var holidaySection: some View {
        Section {
            ForEach(model.data.holidays) { holiday in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(holiday.name)
                        Text("\(DueText.short(holiday.startsOn)) – \(DueText.short(holiday.endsOn))")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button {
                        Task { _ = await model.deleteHoliday(id: holiday.id) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Ferien löschen")
                }
            }
            TextField("Name (z. B. Sommerferien)", text: $holidayName)
                .accessibilityIdentifier("holiday-name")
            DatePicker("Von", selection: $holidayStart, displayedComponents: .date)
            DatePicker("Bis", selection: $holidayEnd, in: holidayStart..., displayedComponents: .date)
            Button("Ferien hinzufügen", action: addHoliday)
                .disabled(holidayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("holiday-add")
        } header: {
            Text("Ferien")
        } footer: {
            Text("In den Ferien gibt es kein Pickup, und Serien mit „Nicht in den Ferien“ pausieren.")
        }
    }

    private func binding(for day: Weekday) -> Binding<Bool> {
        Binding(
            get: { enabled.contains(day) },
            set: { isOn in
                if isOn { enabled.insert(day) } else { enabled.remove(day) }
            }
        )
    }

    private func timeBinding(for day: Weekday) -> Binding<Date> {
        Binding(
            get: { times[day] ?? Date() },
            set: { times[day] = $0 }
        )
    }

    private func save() {
        isSaving = true
        var result: [Weekday: TimeOfDay] = [:]
        for day in enabled {
            result[day] = FormDates.time(from: times[day] ?? Date())
        }
        Task {
            let timesSaved = await model.savePickups(result, remindMinutes: remindMinutes)
            let notesSaved = await model.saveRhythm(from: rhythmStart, texts: bringTexts)
            if timesSaved && notesSaved { dismiss() }
            isSaving = false
        }
    }

    private func addHoliday() {
        let name = holidayName
        let start = FormDates.iso(holidayStart)
        let end = FormDates.iso(max(holidayStart, holidayEnd))
        Task {
            if await model.addHoliday(name: name, startsOn: start, endsOn: end) {
                holidayName = ""
            }
        }
    }
}
