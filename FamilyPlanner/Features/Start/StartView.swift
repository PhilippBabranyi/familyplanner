import SwiftUI

/// Start screen: a dandelion whose seeds lead into the app's functions.
struct StartView: View {
    @ObservedObject var model: WeekViewModel
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
        Placement(route: .week, x: 0.18, y: 0.12, tilt: -18, delay: 1.5),
        Placement(route: .tasks, x: 0.85, y: 0.20, tilt: 26, delay: 3),
        Placement(route: .more, x: 0.82, y: 0.40, tilt: 38, delay: 2)
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let headCenter = CGPoint(x: width * 0.5, y: height * 0.27)

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
        VStack(alignment: .leading, spacing: 10) {
            Text(dateTitle)
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            Text(model.memberName.map { "Hallo \($0)" } ?? "Hallo")
                .font(Theme.display(28))
                .foregroundStyle(Theme.text)
            todayList
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
    }

    /// The day: the pickup with the person, the items, and the cash to take along.
    private var todayList: some View {
        let items = model.plan.items(on: model.todayWeekday)
        let cash = model.plan.cashNeededCents(on: model.todayWeekday)
        return VStack(alignment: .leading, spacing: 8) {
            if let pickup = model.todayPickup {
                HStack(spacing: 8) {
                    Circle().fill(dotColor(for: pickup)).frame(width: 10, height: 10)
                    Text(pickupText(pickup))
                }
                .foregroundStyle(Theme.text)
            }
            if let bring = model.plan.bringByDay[model.todayWeekday] {
                Text("🎒 \(bring)")
                    .foregroundStyle(Theme.text)
                    .accessibilityIdentifier("start-bring")
            }
            ForEach(items.prefix(Self.maxItems)) { item in
                let someoneElse = item.isForSomeoneElse(than: model.memberName)
                HStack(spacing: 10) {
                    Text(item.time.description)
                        .frame(width: 44, alignment: .leading)
                        .foregroundStyle(Theme.muted)
                    Text(item.title).lineLimit(1)
                        .fontWeight(someoneElse ? .regular : .semibold)
                    if someoneElse, let name = item.assignee {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .foregroundStyle(someoneElse ? Theme.muted : Theme.text)
                .opacity(model.hasStarted(item) ? 0.5 : 1)
            }
            if items.count > Self.maxItems {
                Text("… und \(items.count - Self.maxItems) weitere")
                    .foregroundStyle(Theme.muted)
            }
            if cash > 0 {
                Text("Bargeld: \(formattedEuros(cents: cash))")
                    .foregroundStyle(Theme.muted)
            }
            if items.isEmpty && model.todayPickup == nil {
                Text("Heute steht nichts an.")
                    .foregroundStyle(Theme.muted)
            }
        }
        .font(.system(size: 15))
        .accessibilityIdentifier("start-today")
    }

    private static let maxItems = 4

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE · d. MMMM"
        return formatter.string(from: model.today).uppercased()
    }

    private func pickupText(_ pickup: TodayPickup) -> String {
        guard let driver = pickup.driver else { return "\(model.pickupLabel) \(pickup.time): noch niemand eingetragen" }
        return "\(model.pickupLabel) \(pickup.time): \(driver) holt ab"
    }

    private func dotColor(for pickup: TodayPickup) -> Color {
        switch pickup.mark {
        case .open: Theme.pickupOpen
        case .changed: Theme.pickupChanged
        case .assigned: AssigneePalette.color(for: pickup.driver)
        }
    }
}
