import SwiftUI
import Combine
import AuthenticationServices

enum AuthState: Equatable {
    case unauthenticated
    case pendingInvitation(appleUserID: String, name: String)
    case authenticated

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated), (.authenticated, .authenticated):
            return true
        case let (.pendingInvitation(a, b), .pendingInvitation(c, d)):
            return a == c && b == d
        default:
            return false
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var state: AuthState
    @Published var isLoading = false
    @Published var error: String?

    private let userIDKey = "appleUserID"
    private let service = UserService.shared

    private init() {
        state = UserDefaults.standard.string(forKey: userIDKey) != nil
            ? .authenticated
            : .unauthenticated
    }

    // MARK: - Public

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            error = "No se pudo completar el inicio de sesión."
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let appleUserID = credential.user
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            Task { await checkUser(appleUserID: appleUserID, name: name) }
        }
    }

    func register(appleUserID: String, name: String, invitationCode: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await service.register(
                appleUserID: appleUserID,
                name: name,
                invitationCode: invitationCode
            )
            UserDefaults.standard.set(appleUserID, forKey: userIDKey)
            state = .authenticated
        } catch let e as UserAPIError {
            error = e.localizedDescription
        } catch {
            self.error = "Error al registrarse. Intenta de nuevo."
        }
        isLoading = false
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        state = .unauthenticated
    }

    var currentUserID: String? {
        UserDefaults.standard.string(forKey: userIDKey)
    }

    // MARK: - Private

    private func checkUser(appleUserID: String, name: String) async {
        isLoading = true
        error = nil
        do {
            let response = try await service.auth(appleUserID: appleUserID)
            if response.exists {
                UserDefaults.standard.set(appleUserID, forKey: userIDKey)
                state = .authenticated
            } else {
                state = .pendingInvitation(appleUserID: appleUserID, name: name)
            }
        } catch {
            self.error = "Error verificando usuario. Intenta de nuevo."
        }
        isLoading = false
    }
}
