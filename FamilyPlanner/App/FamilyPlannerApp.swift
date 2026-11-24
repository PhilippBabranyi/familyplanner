import Supabase
import SwiftUI

@main
struct FamilyPlannerApp: App {
    @StateObject private var auth: AuthModel
    private let dataSource: FamilyDataSource
    private let now: Date

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uitesting") {
            _auth = StateObject(wrappedValue: AuthModel(backend: DemoAuthBackend()))
            dataSource = DemoDataSource()
            // UI tests run on the demo week: Tuesday, 24 November 2026.
            now = WeekBuilder.date(fromISO: "2026-11-24", calendar: WeekBuilder.calendar()) ?? Date()
        } else {
            let client = SupabaseClient(
                supabaseURL: AppConfig.supabaseURL,
                supabaseKey: AppConfig.supabasePublishableKey
            )
            _auth = StateObject(wrappedValue: AuthModel(backend: SupabaseAuthBackend(client: client)))
            dataSource = SupabaseDataSource(client: client)
            now = Date()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(auth: auth, dataSource: dataSource, now: now)
        }
    }
}
