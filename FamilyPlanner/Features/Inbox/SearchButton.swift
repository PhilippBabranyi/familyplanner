import SwiftUI

/// Magnifier next to the bell. Opens "Frag die Familie".
struct SearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .background(Theme.surface, in: Circle())
                .shadow(color: Theme.shadow.opacity(0.5), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fragen")
        .accessibilityIdentifier("search-button")
    }
}
