import SwiftUI

/// Form for a new or an existing calendar item, one-off or as a series.
struct CalendarItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let existing: StoredCalendarItem?
    let members: [Member]
    let onSave: (CalendarItemDraft) async -> Bool
    let onDelete: (String) async -> Bool

    @State private var title: String
    @State private var note: String
    @State private var date: Date
    @State private var time: Date
    @State private var isSeries: Bool
    @State private var weekdays: Set<Weekday>
    @State private var hasEnd: Bool
    @State private var endDate: Date
    @State private var skipHolidays: Bool
    @State private var assigneeId: String?
    @State private var cash: String
    @State private var isSaving = false

    init(
        existing: StoredCalendarItem?,
        defaultDate: Date,
        members: [Member],
        onSave: @escaping (CalendarItemDraft) async -> Bool,
        onDelete: @escaping (String) async -> Bool
    ) {
        self.existing = existing
        self.members = members
        self.onSave = onSave
        self.onDelete = onDelete
        let start = FormDates.date(fromISO: existing?.startsOn) ?? defaultDate
        let end = FormDates.date(fromISO: existing?.repeatUntil)
        _title = State(initialValue: existing?.title ?? "")
        _note = State(initialValue: existing?.note ?? "")
        _date = State(initialValue: start)
        _time = State(initialValue: FormDates.date(from: existing?.time ?? .at(9, 0)))
        _isSeries = State(initialValue: existing?.isSeries ?? false)
        _weekdays = State(initialValue: existing?.weekdays ?? [])
        _hasEnd = State(initialValue: end != nil)
        _endDate = State(initialValue: end ?? Calendar.current.date(byAdding: .month, value: 3, to: start) ?? start)
        _skipHolidays = State(initialValue: existing?.skipHolidays ?? false)
        _assigneeId = State(initialValue: existing?.assigneeId)
        _cash = State(initialValue: FormDates.text(fromCents: existing?.cashCents))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $title)
                        .accessibilityIdentifier("item-title")
                    TextField("Notiz (z. B. Buch mitnehmen)", text: $note)
                    PersonPicker(title: "Für", noneLabel: "Alle", members: members, selection: $assigneeId)
                }
                Section {
                    DatePicker(isSeries ? "Ab" : "Tag", selection: $date, displayedComponents: .date)
                    DatePicker("Uhrzeit", selection: $time, displayedComponents: .hourAndMinute)
                    Toggle("Wiederholen (Serie)", isOn: $isSeries)
                        .accessibilityIdentifier("item-series")
                }
                if isSeries {
                    seriesSection
                }
                Section("Bargeld") {
                    TextField("Betrag in € (optional)", text: $cash)
                        .keyboardType(.decimalPad)
                }
                if let existing {
                    Section {
                        DestructiveRow(
                            title: existing.isSeries ? "Ganze Serie löschen" : "Termin löschen",
                            identifier: "item-delete",
                            confirmation: existing.isSeries ? "Die ganze Serie löschen?" : "Diesen Termin löschen?"
                        ) {
                            if await onDelete(existing.id) { dismiss() }
                        }
                    }
                }
            }
            .softFormStyle()
            .navigationTitle(existing == nil ? "Neuer Termin" : "Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!canSave || isSaving)
                        .accessibilityIdentifier("item-save")
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (!isSeries || !weekdays.isEmpty)
    }

    private var seriesSection: some View {
        Section("Serie") {
            HStack(spacing: 6) {
                ForEach(Weekday.allCases) { day in
                    let isOn = weekdays.contains(day)
                    Button {
                        if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                    } label: {
                        Text(day.shortName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isOn ? Theme.surface : Theme.text)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(isOn ? Theme.accent : Theme.surfaceAlt, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.longName)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("weekday-\(day.shortName)")
                }
            }
            Toggle("Endet am", isOn: $hasEnd)
            if hasEnd {
                DatePicker("Letzter Tag", selection: $endDate, in: date..., displayedComponents: .date)
            }
            Toggle("Nicht in den Ferien", isOn: $skipHolidays)
        }
    }

    private func save() {
        isSaving = true
        let draft = CalendarItemDraft(
            id: existing?.id,
            title: title,
            note: note,
            startsOn: FormDates.iso(date),
            time: FormDates.time(from: time),
            weekdays: isSeries ? weekdays : [],
            repeatUntil: isSeries && hasEnd ? FormDates.iso(endDate) : nil,
            skipHolidays: isSeries && skipHolidays,
            assigneeId: assigneeId,
            cashCents: FormDates.cents(from: cash)
        )
        Task {
            if await onSave(draft) { dismiss() }
            isSaving = false
        }
    }
}
