import SwiftUI

struct RootView: View {
    @ObservedObject var auth: AuthModel
    let dataSource: FamilyDataSource
    @StateObject private var tasks: TasksViewModel
    @StateObject private var shopping: ShoppingViewModel
    @StateObject private var week: WeekViewModel
    @State private var route: Route = .start

    init(auth: AuthModel, dataSource: FamilyDataSource) {
        self.auth = auth
        self.dataSource = dataSource
        _tasks = StateObject(wrappedValue: TasksViewModel(source: dataSource))
        _shopping = StateObject(wrappedValue: ShoppingViewModel(source: dataSource))
        _week = StateObject(wrappedValue: WeekViewModel(source: dataSource))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            switch auth.state {
            case .checking:
                ProgressView().tint(Theme.accent)
            case .signedOut:
                LoginView(auth: auth)
            case .signedIn:
                signedInContent
            }
        }
        .task { await auth.start() }
        .onChange(of: auth.state) { _, _ in route = .start }
    }

    @ViewBuilder
    private var signedInContent: some View {
        content
        if route != .start {
            FloatingTabBar(selection: $route)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .start:
            StartView { route = $0 }
        case .today:
            TodayView(model: week)
        case .week:
            WeekView(model: week)
        case .ask:
            PlaceholderView(title: "Frag die Familie", message: "Hier entsteht das Familiengedächtnis.")
        case .tasks:
            TasksView(model: tasks)
        case .shopping:
            ShoppingView(model: shopping)
        case .more:
            MoreView(open: { route = $0 }, signOut: { Task { await auth.signOut() } })
        }
    }
}
