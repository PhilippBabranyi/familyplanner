import XCTest
@testable import FamilyPlanner

private struct StubAuthBackend: AuthBackend {
    var hasSession = false
    var signInFails = false

    func restoreSession() async -> Bool { hasSession }

    func signIn(email: String, password: String) async throws {
        if signInFails { throw URLError(.userAuthenticationRequired) }
    }

    func signOut() async {}
}

@MainActor
final class AuthModelTests: XCTestCase {
    func testStartWithoutSessionIsSignedOut() async {
        let auth = AuthModel(backend: StubAuthBackend(hasSession: false))
        XCTAssertEqual(auth.state, .checking)
        await auth.start()
        XCTAssertEqual(auth.state, .signedOut)
    }

    func testStartWithSessionIsSignedIn() async {
        let auth = AuthModel(backend: StubAuthBackend(hasSession: true))
        await auth.start()
        XCTAssertEqual(auth.state, .signedIn)
    }

    func testSuccessfulSignIn() async {
        let auth = AuthModel(backend: StubAuthBackend())
        await auth.signIn(email: " alex@example.com ", password: "secret")
        XCTAssertEqual(auth.state, .signedIn)
        XCTAssertNil(auth.errorMessage)
    }

    func testFailedSignInShowsGenericMessageAndStaysSignedOut() async {
        let auth = AuthModel(backend: StubAuthBackend(signInFails: true))
        await auth.start()
        await auth.signIn(email: "alex@example.com", password: "wrong")
        XCTAssertEqual(auth.state, .signedOut)
        XCTAssertEqual(auth.errorMessage, "Anmeldung fehlgeschlagen. Prüfe E-Mail und Passwort.")
    }

    func testEmptyFieldsAreRejectedWithoutCallingBackend() async {
        let auth = AuthModel(backend: StubAuthBackend())
        await auth.signIn(email: "  ", password: "")
        XCTAssertNotEqual(auth.state, .signedIn)
        XCTAssertEqual(auth.errorMessage, "Bitte E-Mail und Passwort eingeben.")
    }

    func testSignOutReturnsToSignedOut() async {
        let auth = AuthModel(backend: StubAuthBackend(hasSession: true))
        await auth.start()
        await auth.signOut()
        XCTAssertEqual(auth.state, .signedOut)
    }
}
