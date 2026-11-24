import SwiftUI

struct LoginView: View {
    @ObservedObject var auth: AuthModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DandelionView()
                    .frame(width: 220, height: 220)
                    .padding(.top, 40)

                Text("Familienplaner")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.text)

                VStack(spacing: 12) {
                    TextField("E-Mail", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .modifier(FieldStyle())
                        .accessibilityIdentifier("login-email")
                    SecureField("Passwort", text: $password)
                        .textContentType(.password)
                        .modifier(FieldStyle())
                        .accessibilityIdentifier("login-password")
                }

                if let message = auth.errorMessage {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.butter, in: Capsule())
                        .accessibilityIdentifier("login-error")
                }

                Button {
                    Task { await auth.signIn(email: email, password: password) }
                } label: {
                    Group {
                        if auth.isBusy {
                            ProgressView().tint(Theme.surface)
                        } else {
                            Text("Anmelden")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(Theme.surface)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(auth.isBusy)
                .accessibilityIdentifier("login-submit")
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 420)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Theme.surface, in: Capsule())
    }
}
