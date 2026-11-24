import SwiftUI

struct RootView: View {
    @State private var route: Route = .start

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            content
            if route != .start {
                FloatingTabBar(selection: $route)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .start:
            StartView { route = $0 }
        case .today:
            TodayView()
        case .week:
            WeekView()
        case .ask:
            PlaceholderView(title: "Frag die Familie", message: "Hier entsteht das Familiengedächtnis.")
        case .tasks:
            PlaceholderView(title: "Aufgaben", message: "Kommt als Nächstes.")
        case .more:
            MoreView { route = $0 }
        }
    }
}
