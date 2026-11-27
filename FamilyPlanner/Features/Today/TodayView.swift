import SwiftUI

/// Today: the items of the current day from the demo week.
struct TodayView: View {
    @ObservedObject var model: WeekViewModel
    @State private var editor: ItemEditorTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dateTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    Text(greeting)
                        .font(Theme.display(32))
                        .foregroundStyle(Theme.text)
                }

                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }

                if let pickup = model.todayPickup {
                    PickupTodayRow(pickup: pickup)
                }

                ForEach(model.plan.items(on: model.todayWeekday)) { item in
                    WeekItemRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { edit(item) }
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
        .accessibilityIdentifier("screen-today")
        .addButton(identifier: "add-item") {
            editor = ItemEditorTarget(item: nil, defaultDate: model.today)
        }
        .sheet(item: $editor) { target in
            ItemFormSheet(model: model, target: target)
        }
    }

    private func edit(_ item: WeekItem) {
        guard let sourceId = item.sourceId, let stored = model.storedItem(id: sourceId) else { return }
        editor = ItemEditorTarget(item: stored, defaultDate: model.today)
    }

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE · d. MMMM"
        return formatter.string(from: model.today).uppercased()
    }

    private var greeting: String {
        if let name = model.memberName { return "Guten Tag,\n\(name)" }
        return "Guten Tag"
    }
}
