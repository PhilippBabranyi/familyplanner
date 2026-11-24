import SwiftUI

/// Tasks in three states. Tapping a card's button moves it to the next state.
struct TasksView: View {
    @ObservedObject var model: TasksViewModel
    @State private var filter: TaskStatus = .open

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
    }

    private var statusPicker: some View {
        HStack(spacing: 4) {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                let isSelected = status == filter
                Button {
                    filter = status
                } label: {
                    Text("\(status.title) \(model.board.count(in: status))")
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
                Text("\(personName) · \(task.due)")
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
        .background(AssigneePalette.color(for: task.assignee), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var personName: String {
        task.assignee ?? "Niemand"
    }
}
