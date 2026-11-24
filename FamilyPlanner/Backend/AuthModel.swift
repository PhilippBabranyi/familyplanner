import Foundation
import Supabase

/// What the app needs from an authentication service. Implemented for Supabase and for demo/UI tests.
protocol AuthBackend {
    /// True if a valid saved session exists.
    func restoreSession() async -> Bool
    func signIn(email: String, password: String) async throws
    func signOut() async
}

/// Used by UI tests and previews: always signed in, no network.
struct DemoAuthBackend: AuthBackend {
    func restoreSession() async -> Bool { true }
    func signIn(email: String, password: String) async throws {}
    func signOut() async {}
}

struct SupabaseAuthBackend: AuthBackend {
    let client: SupabaseClient

    func restoreSession() async -> Bool {
        (try? await client.auth.session) != nil
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async {
        try? await client.auth.signOut()
    }
}

@MainActor
final class AuthModel: ObservableObject {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?

    private let backend: AuthBackend

    init(backend: AuthBackend) {
        self.backend = backend
    }

    /// Looks for a saved session when the app starts.
    func start() async {
        state = await backend.restoreSession() ? .signedIn : .signedOut
    }

    func signIn(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Bitte E-Mail und Passwort eingeben."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await backend.signIn(email: trimmedEmail, password: password)
            errorMessage = nil
            state = .signedIn
        } catch {
            errorMessage = "Anmeldung fehlgeschlagen. Prüfe E-Mail und Passwort."
        }
    }

    func signOut() async {
        await backend.signOut()
        errorMessage = nil
        state = .signedOut
    }
}
