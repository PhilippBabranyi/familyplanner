import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Muted, nature-inspired palette. Mirrors the design prototype.
enum Theme {
    static let background = Color(hex: 0xF4EFE6)
    static let surface = Color(hex: 0xFBF8F2)
    static let surfaceAlt = Color(hex: 0xEBE4D6)
    static let text = Color(hex: 0x2F2E28)
    static let muted = Color(hex: 0x6B675A)
    static let accent = Color(hex: 0x4A6550)
    static let sage = Color(hex: 0xB3C3A3)
    static let sageLight = Color(hex: 0xE4EAD8)
    static let stem = Color(hex: 0x8FAE86)
    static let butter = Color(hex: 0xE5D8A9)
    static let peach = Color(hex: 0xD5AE9B)
    static let blue = Color(hex: 0xA9B9C2)
    static let lavender = Color(hex: 0xBDB6C7)
    static let seed = Color(hex: 0x8C8672)
    /// A pickup that nobody has taken over yet.
    static let pickupOpen = Color(hex: 0xC8473F)
    /// A pickup that was changed for one day, outside the weekly plan.
    static let pickupChanged = Color(hex: 0xE08A3C)
    static let shadow = Color.black.opacity(0.12)

    /// Headline font. A serif system font for now; a custom font can be bundled later.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}
