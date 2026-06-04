import SwiftUI
import AuthenticationServices

struct WelcomeScreen: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(alignment: .leading, spacing: 40) {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Bienvenido")
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .foregroundStyle(AuroraColors.primaryText)
                        .shadow(color: .white.opacity(0.4), radius: 18, y: 10)

                    Text("Tu finanza personal, organizada y con inteligencia.")
                        .font(.title3)
                        .foregroundStyle(AuroraColors.secondaryText)
                        .lineSpacing(4)
                }

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn, onRequest: configureRequest, onCompletion: handleResult)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 18, y: 10)
                        .disabled(authManager.isLoading)

                    if authManager.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Verificando...")
                                .font(.subheadline)
                                .foregroundStyle(AuroraColors.secondaryText)
                        }
                    }

                    if let error = authManager.error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.3), value: authManager.isLoading)
            .animation(.easeInOut(duration: 0.3), value: authManager.error)
        }
        .ignoresSafeArea()
    }

    private func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        authManager.handleAppleSignIn(result)
    }
}
