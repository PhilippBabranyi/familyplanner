import SwiftUI

/// Today's pickup on the today screen: time and who picks up, or a red hint if nobody is entered yet.
struct PickupTodayRow: View {
    let pickup: TodayPickup

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.text)
            VStack(alignment: .leading, spacing: 2) {
                Text("ABHOLUNG")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                Text(pickup.time.description)
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(dotColor).frame(width: 10, height: 10)
                Text(pickup.driver.map { "\($0) holt ab" } ?? "Noch niemand eingetragen")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surface, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            pickup.mark == .changed ? Theme.butter : Theme.surfaceAlt,
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today-pickup")
    }

    private var dotColor: Color {
        switch pickup.mark {
        case .open: Theme.pickupOpen
        case .changed: Theme.pickupChanged
        case .assigned: AssigneePalette.color(for: pickup.driver)
        }
    }
}
