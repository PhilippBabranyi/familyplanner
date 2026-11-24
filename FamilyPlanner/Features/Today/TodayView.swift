import SwiftUI

/// Today: the items of the current day from the demo week.
struct TodayView: View {
    /// Tuesday, 24 November 2026 in the demo data.
    private let today = Weekday.tuesday
    private let plan = DemoData.weekPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DIENSTAG · 24. NOVEMBER")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    Text("Guten Morgen,\nAlex")
                        .font(Theme.display(32))
                        .foregroundStyle(Theme.text)
                }

                ForEach(plan.items(on: today)) { item in
                    WeekItemRow(item: item)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 110)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("screen-today")
    }
}
