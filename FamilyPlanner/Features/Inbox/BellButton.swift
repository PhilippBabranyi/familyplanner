import SwiftUI

/// Bell in the top corner. The number shows how many suggestions from the mails are waiting.
struct BellButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: count > 0 ? "bell.fill" : "bell")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .background(Theme.surface, in: Circle())
                .shadow(color: Theme.shadow.opacity(0.5), radius: 5, x: 0, y: 2)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text("\(min(count, 99))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.surface)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.peach, in: Capsule())
                            .offset(x: 4, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "Glocke, \(count) neu" : "Glocke")
        .accessibilityIdentifier("bell-button")
    }
}
