import SwiftUI

/// Tasks in three states. Tapping a card's button moves it to the next state.
struct TasksView: View {
    @ObservedObject var model: TasksViewModel
    @State private var filter: TaskStatus = .open
    @State private var editor: TaskEditorTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Aufgaben")
                    .font(Theme.display(36))
                    .foregroundStyle(Theme.text)

                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }

                statusPicker

                ForEach(model.board.tasks(in: filter)) { task in
                    TaskCard(task: task) { Task { await model.advance(task.id) } }
                        .contentShape(Rectangle())
                        .onTapGesture { editor = TaskEditorTarget(task: task) }
                }

                if model.board.tasks(in: filter).isEmpty && !model.isLoading {
                    Text("Hier ist nichts mehr offen.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 90)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 110)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.load() }
        .task { await model.load() }
        .addButton(identifier: "add-task") { editor = TaskEditorTarget(task: nil) }
        .sheet(item: $editor) { target in
            TaskFormSheet(model: model, target: target)
        }
    }

    private var statusPicker: some View {
        HStack(spacing: 4) {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                let isSelected = status == filter
                Button {
                    filter = status
                } label: {
                    Text("\(status.title) (\(model.board.count(in: status)))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.text : Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(isSelected ? Theme.surface : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("status-\(status.title)")
            }
        }
        .padding(5)
        .background(Theme.surfaceAlt, in: Capsule())
    }
}

private struct TaskCard: View {
    let task: TaskItem
    let advance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.title)
                .font(Theme.display(21))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(detailText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button(action: advance) {
                    Text(task.status.actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.surface)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("advance-\(task.id)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            AssigneePalette.color(for: task.assignee),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
    }

    private var personName: String {
        task.assignee ?? "Niemand"
    }

    /// "Alex · bis 4.12." and, if cash is needed, " · 5 €".
    private var detailText: String {
        let base = "\(personName) · \(task.due)" + (task.dueTime.map { " \($0) Uhr" } ?? "")
        guard let cents = task.cashCents else { return base }
        return "\(base) · \(FormDates.text(fromCents: cents)) €"
    }
}

/// What the task form is opened for: an existing task, or nothing for a new one.
struct TaskEditorTarget: Identifiable {
    let id = UUID()
    let task: TaskItem?
}

/// Loads the family members, then shows the task form.
private struct TaskFormSheet: View {
    @ObservedObject var model: TasksViewModel
    let target: TaskEditorTarget
    @State private var members: [Member] = []

    var body: some View {
        TaskFormView(
            existing: target.task,
            members: members,
            onSave: { await model.save($0) },
            onDelete: { await model.delete(id: $0) }
        )
        .task { members = await model.members() }
    }
}
