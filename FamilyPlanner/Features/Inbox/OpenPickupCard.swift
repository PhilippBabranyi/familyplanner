import SwiftUI

/// The bell's reminder that nobody picks up yet, with a button per person to take it over right away.
struct OpenPickupCard: View {
    let pickup: OpenPickup
    let accounts: [Member]
    let label: String
    let choose: (Member) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Theme.pickupOpen).frame(width: 10, height: 10)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            Text(pickup.isToday ? "Wer holt heute um \(pickup.time) ab?" : "Wer holt morgen um \(pickup.time) ab?")
                .font(Theme.display(21))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                ForEach(accounts) { member in
                    Button { choose(member) } label: {
                        Text("\(member.name) holt ab")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("open-pickup-\(pickup.dayText)-\(member.name)")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Theme.butter.opacity(0.7), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityIdentifier("open-pickup-\(pickup.dayText)")
    }
}
