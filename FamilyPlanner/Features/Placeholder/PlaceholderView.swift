import SwiftUI

/// Stand-in for screens that are not built yet.
struct PlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.display(36))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "Mehr": entry point to the secondary screens. Only the way back to the start screen works for now.
struct MoreView: View {
    let open: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mehr")
                .font(Theme.display(36))
                .foregroundStyle(Theme.text)
            Text("Anlässe, Einkauf, Reisen und die Bibliothek folgen.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
            Button {
                open(.start)
            } label: {
                Label("Zur Pusteblume", systemImage: "leaf")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.surface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("open-start")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
