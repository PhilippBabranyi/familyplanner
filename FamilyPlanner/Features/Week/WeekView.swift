import SwiftUI

/// Week overview: pick a day, see pickup time and items.
struct WeekView: View {
    @ObservedObject var model: WeekViewModel
    @State private var selectedDay: Weekday?

    private var day: Weekday { selectedDay ?? model.todayWeekday }
    private var plan: WeekPlan { model.plan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rangeTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    Text("Diese Woche")
                        .font(Theme.display(36))
                        .foregroundStyle(Theme.text)
                }

                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }

                dayPicker

                if let pickup = plan.pickup.time(on: day) {
                    pickupCard(time: pickup, isException: plan.pickup.isException(on: day))
                }

                ForEach(plan.items(on: day)) { item in
                    WeekItemRow(item: item)
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
    }

    private var rangeTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM"
        let calendar = WeekBuilder.calendar()
        let first = calendar.component(.day, from: model.weekStart)
        let last = formatter.string(from: model.date(of: .sunday))
        return "\(first).–\(last)".uppercased()
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
                        Text("\(model.dayNumber(weekday))")
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
