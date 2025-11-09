import SwiftUI
import AuthenticationServices

struct WelcomeScreen: View {
    let isAuthenticated: Bool
    let errorMessage: String?
    let configureRequest: (ASAuthorizationAppleIDRequest) -> Void
    let handleResult: (Result<ASAuthorization, Error>) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bienvenido")
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(AuroraColors.primaryText)
                    .shadow(color: .white.opacity(0.4), radius: 18, y: 10)

                Text("Explora Financia con una bienvenida suave y minimalista en tonos pastel.")
                    .font(.title3)
                    .foregroundStyle(AuroraColors.secondaryText)
                    .lineSpacing(4)
            }

            VStack(spacing: 18) {
                SignInWithAppleButton(.signIn, onRequest: configureRequest, onCompletion: handleResult)
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 18, y: 10)

                Button("Saltar", action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AuroraColors.primaryText)

                if isAuthenticated {
                    Text("¡Sesión iniciada correctamente!")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AuroraColors.primaryText.opacity(0.8))
                        .transition(.opacity)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .transition(.opacity)
                }
            }
        }
    }
}
