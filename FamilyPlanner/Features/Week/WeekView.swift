import SwiftUI

/// Week overview: pick a day, see pickup time and items.
struct WeekView: View {
    @ObservedObject var model: WeekViewModel
    @State private var selectedDay: Weekday?
    @State private var editor: ItemEditorTarget?
    @State private var showsPickups = false

    /// In the current week the selected day defaults to today, in any other week to Monday.
    private var day: Weekday { selectedDay ?? (model.isShowingCurrentWeek ? model.todayWeekday : .monday) }
    private var plan: WeekPlan { model.shownPlan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rangeTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    HStack(alignment: .firstTextBaseline) {
                        Text(weekTitle)
                            .font(Theme.display(36))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Button("Abholung & Ferien") { showsPickups = true }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.surface, in: Capsule())
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("open-pickups")
                    }
                }

                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }

                weekNavigator

                dayPicker

                if let pickup = plan.pickup.time(on: day) {
                    pickupCard(time: pickup, isException: plan.pickup.isException(on: day))
                }

                if let holiday = plan.holidays[day] {
                    Text("Ferien: \(holiday) · keine Abholung")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.sage, in: Capsule())
                }

                ForEach(plan.items(on: day)) { item in
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
        .accessibilityIdentifier("screen-week")
        .addButton(identifier: "add-item") {
            editor = ItemEditorTarget(item: nil, defaultDate: model.shownDate(of: day))
        }
        .sheet(item: $editor) { target in
            ItemFormSheet(model: model, target: target)
        }
        .sheet(isPresented: $showsPickups) {
            PickupSheet(model: model)
        }
    }

    private func edit(_ item: WeekItem) {
        guard let sourceId = item.sourceId, let stored = model.storedItem(id: sourceId) else { return }
        editor = ItemEditorTarget(item: stored, defaultDate: model.shownDate(of: day))
    }

    private var rangeTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM"
        let calendar = WeekBuilder.calendar()
        let first = calendar.component(.day, from: model.shownWeekStart)
        let last = formatter.string(from: model.shownDate(of: .sunday))
        return "\(first).–\(last)".uppercased()
    }

    private var weekTitle: String {
        switch model.shownWeekOffset {
        case 0: return "Diese Woche"
        case 1: return "Nächste Woche"
        case -1: return "Letzte Woche"
        default: return "Woche \(WeekBuilder.calendar().component(.weekOfYear, from: model.shownWeekStart))"
        }
    }

    /// Buttons for the previous and the next week, a jump to today and a date picker to go to any week.
    private var weekNavigator: some View {
        HStack(spacing: 8) {
            navButton("chevron.left", label: "Vorherige Woche", id: "week-previous") {
                selectedDay = nil
                model.showWeek(offsetBy: -1)
            }
            Button {
                selectedDay = nil
                model.showCurrentWeek()
            } label: {
                Text("Heute")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Theme.surface, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(model.isShowingCurrentWeek)
            .opacity(model.isShowingCurrentWeek ? 0.5 : 1)
            .accessibilityIdentifier("week-today")
            navButton("chevron.right", label: "Nächste Woche", id: "week-next") {
                selectedDay = nil
                model.showWeek(offsetBy: 1)
            }
            Spacer()
            DatePicker(
                "Zu Datum springen",
                selection: Binding(
                    get: { model.shownDate(of: day) },
                    set: { date in
                        model.showWeek(containing: date)
                        selectedDay = WeekBuilder.weekday(of: date, calendar: WeekBuilder.calendar())
                    }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .accessibilityIdentifier("week-jump")
        }
    }

    private func navButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 38, height: 38)
                .background(Theme.surface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private var dayPicker: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { weekday in
                let isSelected = weekday == day
                Button {
                    selectedDay = weekday
                } label: {
                    VStack(spacing: 2) {
                        Text(weekday.shortName)
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(model.shownDayNumber(weekday))")
                            .font(Theme.display(19))
                        Circle()
                            .fill(plan.pickup.isException(on: weekday) ? Color(hex: 0xC98F6B) : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .foregroundStyle(isSelected ? Theme.surface : Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.longName)
                .accessibilityIdentifier("day-\(weekday.shortName)")
            }
        }
    }

    private func pickupCard(time: TimeOfDay, isException: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.text)
            VStack(alignment: .leading, spacing: 2) {
                Text("ABHOLUNG")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                Text(time.description)
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            Text(isException ? "Ausnahme: eine Stunde später" : "wie an den meisten Tagen")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: 120, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            isException ? Theme.butter : Theme.surfaceAlt,
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
    }
}

/// What the item form is opened for: an existing item, or nothing for a new one.
struct ItemEditorTarget: Identifiable {
    let id = UUID()
    let item: StoredCalendarItem?
    let defaultDate: Date
}

/// Loads the family members, then shows the item form.
struct ItemFormSheet: View {
    @ObservedObject var model: WeekViewModel
    let target: ItemEditorTarget
    @State private var members: [Member] = []

    var body: some View {
        CalendarItemFormView(
            existing: target.item,
            defaultDate: target.defaultDate,
            members: members,
            onSave: { await model.save($0) },
            onDelete: { await model.deleteItem(id: $0) }
        )
        .task { members = await model.members() }
    }
}
