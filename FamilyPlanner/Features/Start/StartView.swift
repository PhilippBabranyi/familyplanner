import SwiftUI

/// Start screen: a dandelion whose seeds lead into the app's functions.
struct StartView: View {
    /// Display name of the signed-in person; the greeting has no name until it is known.
    let name: String?
    let open: (Route) -> Void

    private struct Placement {
        let route: Route
        /// Position of the seed's center as a fraction of the screen size.
        let x: Double
        let y: Double
        let tilt: Double
        let delay: Double
    }

    private let placements = [
        Placement(route: .today, x: 0.71, y: 0.14, tilt: 14, delay: 0),
        Placement(route: .week, x: 0.18, y: 0.17, tilt: -18, delay: 1.5),
        Placement(route: .tasks, x: 0.85, y: 0.28, tilt: 26, delay: 3),
        Placement(route: .ask, x: 0.11, y: 0.34, tilt: -30, delay: 4.5),
        Placement(route: .more, x: 0.80, y: 0.55, tilt: 38, delay: 2)
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let headCenter = CGPoint(x: width * 0.5, y: height * 0.355)

            ZStack {
                Circle()
                    .fill(Color(hex: 0xEFE9DC))
                    .frame(width: 312, height: 312)
                    .position(headCenter)
                Circle()
                    .fill(Theme.sageLight)
                    .frame(width: 236, height: 236)
                    .position(headCenter)

                stem(from: CGPoint(x: headCenter.x, y: headCenter.y + 98), to: height * 0.88)

                DandelionView()
                    .frame(width: 220, height: 220)
                    .position(headCenter)

                ForEach(placements, id: \.route) { placement in
                    SeedLink(route: placement.route, tilt: placement.tilt, driftDelay: placement.delay) {
                        open(placement.route)
                    }
                    .position(x: width * placement.x, y: height * placement.y)
                }

                greetingCard
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 16 + 74) // room for the tab bar
            }
        }
    }

    private func stem(from start: CGPoint, to bottom: CGFloat) -> some View {
        Path { path in
            path.move(to: start)
            path.addCurve(
                to: CGPoint(x: start.x + 1, y: bottom),
                control1: CGPoint(x: start.x - 7, y: start.y + 70),
                control2: CGPoint(x: start.x + 11, y: bottom - 160)
            )
        }
        .stroke(Theme.stem, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        .accessibilityHidden(true)
    }

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FAMILIENPLANER")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            Text(name.map { "Hallo \($0)" } ?? "Hallo")
                .font(Theme.display(28))
                .foregroundStyle(Theme.text)
            Text("Jeder Samen trägt dich an einen Ort. Tippe einen an.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
    }
}
