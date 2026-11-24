import SwiftUI

/// Week overview: pick a day, see pickup time and items.
struct WeekView: View {
    @State private var selectedDay: Weekday = .tuesday
    private let plan = DemoData.weekPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("23.–29. NOVEMBER")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    Text("Diese Woche")
                        .font(Theme.display(36))
                        .foregroundStyle(Theme.text)
                }

                SampleDataChip()

                dayPicker

                if let pickup = plan.pickup.time(on: selectedDay) {
                    pickupCard(time: pickup, isException: plan.pickup.isException(on: selectedDay))
                }

                ForEach(plan.items(on: selectedDay)) { item in
                    WeekItemRow(item: item)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 110)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("screen-week")
    }

    private var dayPicker: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let isSelected = day == selectedDay
                Button {
                    selectedDay = day
                } label: {
                    VStack(spacing: 2) {
                        Text(day.shortName)
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(DemoData.dayNumber(day))")
                            .font(Theme.display(19))
                        Circle()
                            .fill(plan.pickup.isException(on: day) ? Color(hex: 0xC98F6B) : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .foregroundStyle(isSelected ? Theme.surface : Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.longName)
                .accessibilityIdentifier("day-\(day.shortName)")
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
