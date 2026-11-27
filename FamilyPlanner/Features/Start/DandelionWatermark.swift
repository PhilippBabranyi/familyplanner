import SwiftUI

/// The dandelion as a faint picture behind the other screens: large, pale and partly out of the screen.
struct DandelionWatermark: View {
    var body: some View {
        DandelionView()
            .frame(width: 420, height: 420)
            .saturation(0.35)
            .opacity(0.13)
            .offset(x: 110, y: 60)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
