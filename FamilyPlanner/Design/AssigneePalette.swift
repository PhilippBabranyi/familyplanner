import SwiftUI

/// Gives every person a stable soft colour, derived from the name.
enum AssigneePalette {
    static let colors: [Color] = [Theme.peach, Theme.blue, Theme.sage, Theme.lavender, Theme.butter]

    static func index(for name: String?) -> Int {
        guard let name, !name.isEmpty else { return 0 }
        // Not hashValue: that changes between launches.
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1_000_003 }
        return sum % colors.count
    }

    static func color(for name: String?) -> Color {
        guard name != nil else { return Theme.surfaceAlt }
        return colors[index(for: name)]
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.butter, in: Capsule())
            .accessibilityIdentifier("error-banner")
    }
}
