import SwiftUI

struct RootView: View {
    @ObservedObject var auth: AuthModel
    let dataSource: FamilyDataSource
    @StateObject private var tasks: TasksViewModel
    @StateObject private var shopping: ShoppingViewModel
    @StateObject private var week: WeekViewModel
    @StateObject private var inbox: InboxViewModel
    @State private var route: Route = .start
    @State private var showSuggestions = false
    @Environment(\.scenePhase) private var scenePhase

    init(auth: AuthModel, dataSource: FamilyDataSource, now: Date = Date()) {
        self.auth = auth
        self.dataSource = dataSource
        _tasks = StateObject(wrappedValue: TasksViewModel(source: dataSource))
        _shopping = StateObject(wrappedValue: ShoppingViewModel(source: dataSource))
        _week = StateObject(wrappedValue: WeekViewModel(source: dataSource, now: now))
        _inbox = StateObject(wrappedValue: InboxViewModel(source: dataSource))
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
        // Once per sign-in (not once per screen): load the bell and ask for push.
        .task(id: auth.state) {
            guard auth.state == .signedIn else { return }
            await week.load()
            await inbox.load()
            await PushPermission.request()
            openSuggestionsIfRequested()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, auth.state == .signedIn else { return }
            Task { await inbox.load() }
            openSuggestionsIfRequested()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushTokenReceived)) { note in
            guard let token = note.object as? String else { return }
            Task { await inbox.registerDevice(token: token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSuggestions)) { _ in
            if auth.state == .signedIn { openSuggestionsIfRequested() }
        }
        .sheet(isPresented: $showSuggestions) {
            SuggestionsSheet(inbox: inbox, tasks: tasks, week: week)
        }
    }

    @ViewBuilder
    private var signedInContent: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if route != .start { topBar }
            }
            .overlay(alignment: .topTrailing) {
                // The start screen has no top bar, but the bell must be reachable from there too.
                if route == .start { bell.padding(.horizontal, 20).padding(.top, 4) }
            }
        // The menu stays reachable from the start screen too (no tab is highlighted there).
        FloatingTabBar(selection: $route)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }

    private var bell: some View {
        BellButton(count: inbox.count) { showSuggestions = true }
    }

    private func openSuggestionsIfRequested() {
        guard PushState.openSuggestionsRequested else { return }
        PushState.openSuggestionsRequested = false
        showSuggestions = true
    }

    /// Always-visible way back to the dandelion start screen, and the bell.
    private var topBar: some View {
        HStack {
            Button {
                route = .start
            } label: {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(Theme.surface, in: Circle())
                    .shadow(color: Theme.shadow.opacity(0.5), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zur Startseite")
            .accessibilityIdentifier("home-button")
            Spacer()
            bell
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .start:
            StartView(name: week.memberName) { route = $0 }
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
