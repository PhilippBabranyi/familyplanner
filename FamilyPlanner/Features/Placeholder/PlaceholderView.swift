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
    let signOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mehr")
                .font(Theme.display(36))
                .foregroundStyle(Theme.text)
            Text("Anlässe, Reisen und die Bibliothek folgen.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
            moreButton("Einkauf", systemImage: "cart", id: "open-shopping") { open(.shopping) }
            moreButton("Abmelden", systemImage: "rectangle.portrait.and.arrow.right", id: "sign-out", action: signOut)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func moreButton(
        _ title: String,
        systemImage: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
