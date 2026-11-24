import Supabase
import SwiftUI

@main
struct FamilyPlannerApp: App {
    @StateObject private var auth: AuthModel
    private let dataSource: FamilyDataSource

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uitesting") {
            _auth = StateObject(wrappedValue: AuthModel(backend: DemoAuthBackend()))
            dataSource = DemoDataSource()
        } else {
            let client = SupabaseClient(
                supabaseURL: AppConfig.supabaseURL,
                supabaseKey: AppConfig.supabasePublishableKey
            )
            _auth = StateObject(wrappedValue: AuthModel(backend: SupabaseAuthBackend(client: client)))
            dataSource = SupabaseDataSource(client: client)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(auth: auth, dataSource: dataSource)
        }
    }
}
