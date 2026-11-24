import SwiftUI

/// A single drifting seed with a label. Tapping it opens a destination.
struct SeedLink: View {
    let route: Route
    /// Rotation of the seed in degrees.
    let tilt: Double
    /// Delay so the seeds do not move in lockstep.
    let driftDelay: Double
    let action: () -> Void

    @State private var isDrifting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// UI tests pass `-uitesting` so endless animations cannot stall them.
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("-uitesting")

    private var animatesDrift: Bool { !reduceMotion && !isUITesting }

    var body: some View {
        Button(action: action) {
            VStack(spacing: -2) {
                SeedShape()
                    .stroke(Theme.seed, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .frame(width: 56, height: 70)
                    .rotationEffect(.degrees(tilt))
                Text(route.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Theme.surface, in: Capsule())
                    .shadow(color: Theme.shadow, radius: 5, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
        .offset(x: isDrifting ? 6 : 0, y: isDrifting ? -9 : 0)
        .rotationEffect(.degrees(isDrifting ? 4 : -3))
        .animation(
            animatesDrift ? .easeInOut(duration: 6).repeatForever(autoreverses: true).delay(driftDelay) : nil,
            value: isDrifting
        )
        .onAppear { isDrifting = animatesDrift }
        .accessibilityLabel(route.title)
        .accessibilityIdentifier("seed-\(route.rawValue)")
    }
}

/// Stalk plus a fan of filaments, like a dandelion seed.
struct SeedShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 56
        let scaleY = rect.height / 70
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        var path = Path()
        path.move(to: point(28, 66))
        path.addLine(to: point(28, 30))
        let fanTips: [(CGFloat, CGFloat)] = [(28, 6), (16, 9), (40, 9), (8, 16), (48, 16), (3, 26), (53, 26)]
        for (tipX, tipY) in fanTips {
            path.move(to: point(28, 30))
            path.addLine(to: point(tipX, tipY))
        }
        path.addEllipse(in: CGRect(x: point(26, 60).x, y: point(26, 60).y, width: 4 * scaleX, height: 8 * scaleY))
        return path
    }
}
