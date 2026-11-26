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
        .padding(.horizontal, 6)
        .frame(height: 66)
        .background(Theme.surface, in: Capsule())
        .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
    }

    private func button(for route: Route) -> some View {
        let isSelected = route == selection.tab
        return Button {
            selection = route
        } label: {
            HStack(spacing: 6) {
                if route == .start {
                    DandelionIcon().frame(width: 24, height: 24)
                } else {
                    Image(systemName: route.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
                // The dandelion stays a plain icon so that six buttons fit on a small phone.
                if isSelected && route != .start {
                    Text(route.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(isSelected ? Theme.surface : Theme.muted)
            .padding(.horizontal, isSelected && route != .start ? 12 : 0)
            .frame(minWidth: 44, minHeight: 48)
            .background(isSelected ? Theme.accent : Color.clear, in: Capsule())
            // Without this only the drawn icon reacts; the three dots of "Mehr" are tiny and often missed.
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(route.title)
        .accessibilityIdentifier("tab-\(route.rawValue)")
    }
}
