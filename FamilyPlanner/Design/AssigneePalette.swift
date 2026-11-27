import SwiftUI

/// Gives every person of the family a colour of their own. The colours differ clearly from each other and
/// leave out red and orange, which mean "open" and "changed" for the pickup.
enum AssigneePalette {
    static let colors: [Color] = [
        Color(hex: 0x6C9BC4), // blue
        Color(hex: 0x7DB48A), // green
        Color(hex: 0xA68CC7), // purple
        Color(hex: 0xDCBF55), // mustard
        Color(hex: 0x5BB5B0), // teal
        Color(hex: 0xC48FB0) // mauve
    ]

    /// The people of the family, in a fixed order. Everyone gets the colour at their position.
    static var roster: [String] = []

    /// Called once the members are known: accounts and people without an account.
    static func setRoster(_ members: [Member]) {
        roster = members.sorted { $0.id < $1.id }.map(\.name)
    }

    static func index(for name: String?) -> Int {
        guard let name, !name.isEmpty else { return 0 }
        if let position = roster.firstIndex(of: name) { return position % colors.count }
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
