import SwiftUI

/// A short confirmation, for example after saving.
struct NoticeBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.sage, in: Capsule())
            .accessibilityIdentifier("saved-banner")
    }
}
