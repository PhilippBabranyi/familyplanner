import SwiftUI

/// Rounded, floating navigation bar. The selected tab shows its label.
struct FloatingTabBar: View {
    @Binding var selection: Route

    var body: some View {
        HStack {
            ForEach(Route.tabs) { route in
                button(for: route)
                if route != Route.tabs.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 66)
        .background(Theme.surface, in: Capsule())
        .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
    }

    private func button(for route: Route) -> some View {
        let isSelected = route == selection
        return Button {
            selection = route
        } label: {
            HStack(spacing: 6) {
                Image(systemName: route.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                if isSelected {
                    Text(route.title)
                        .font(.system(size: 13.5, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? Theme.surface : Theme.muted)
            .padding(.horizontal, isSelected ? 15 : 0)
            .frame(minWidth: 50, minHeight: 48)
            .background(isSelected ? Theme.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(route.title)
        .accessibilityIdentifier("tab-\(route.rawValue)")
    }
}
