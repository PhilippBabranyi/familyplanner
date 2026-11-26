import SwiftUI

/// Form for a new or an existing task.
struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss

    let existing: TaskItem?
    let members: [Member]
    let onSave: (TaskDraft) async -> Bool
    let onDelete: (String) async -> Bool

    @State private var title: String
    @State private var assigneeId: String?
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var cash: String
    @State private var isSaving = false

    init(
        existing: TaskItem?,
        members: [Member],
        prefill: TaskDraft? = nil,
        onSave: @escaping (TaskDraft) async -> Bool,
        onDelete: @escaping (String) async -> Bool
    ) {
        self.existing = existing
        self.members = members
        self.onSave = onSave
        self.onDelete = onDelete
        // A suggestion from a mail fills the form of a new task; an existing task always wins.
        _title = State(initialValue: existing?.title ?? prefill?.title ?? "")
        _assigneeId = State(initialValue: existing?.assigneeId ?? prefill?.assigneeId)
        _cash = State(initialValue: FormDates.text(fromCents: existing?.cashCents ?? prefill?.cashCents))
        let date = FormDates.date(fromISO: existing?.dueOn ?? prefill?.dueOn)
        _hasDue = State(initialValue: date != nil)
        _due = State(initialValue: date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Was ist zu tun?", text: $title)
                        .accessibilityIdentifier("task-title")
                    PersonPicker(title: "Wer", noneLabel: "Niemand", members: members, selection: $assigneeId)
                }
                Section {
                    Toggle("Mit Datum", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Bis", selection: $due, displayedComponents: .date)
                    }
                }
                Section("Bargeld") {
                    TextField("Betrag in € (optional)", text: $cash)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("task-cash")
                }
                if let existing {
                    Section {
                        DestructiveRow(
                            title: "Aufgabe löschen",
                            identifier: "task-delete",
                            confirmation: "Diese Aufgabe löschen?"
                        ) {
                            if await onDelete(existing.id) { dismiss() }
                        }
                    }
                }
            }
            .softFormStyle()
            .navigationTitle(existing == nil ? "Neue Aufgabe" : "Aufgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .accessibilityIdentifier("task-save")
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let draft = TaskDraft(
            id: existing?.id,
            title: title,
            assigneeId: assigneeId,
            dueOn: hasDue ? FormDates.iso(due) : nil,
            cashCents: FormDates.cents(from: cash)
        )
        Task {
            if await onSave(draft) { dismiss() }
            isSaving = false
        }
    }
}
