import SwiftUI
import LocalAuthentication
import Combine

/// Controls the optional Face ID / Touch ID / passcode lock that gates the app.
///
/// The feature is off by default. When the user turns it on, we first make them
/// authenticate so they can't lock themselves out. While enabled, the app locks
/// whenever it goes to the background and requires authentication to return.
@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    private let enabledKey = "appLockEnabled"

    /// Whether the user has turned biometric/passcode lock on.
    @Published private(set) var isEnabled: Bool

    /// Whether the app is currently locked and awaiting authentication.
    @Published private(set) var isLocked: Bool

    /// Set while an authentication prompt is on screen, so a scene-phase change
    /// caused by the system biometric sheet doesn't re-lock or double-prompt.
    private var isAuthenticating = false

    private init() {
        let enabled = UserDefaults.standard.bool(forKey: enabledKey)
        self.isEnabled = enabled
        // Start locked when the feature is on so the first foreground needs auth.
        self.isLocked = enabled
    }

    // MARK: - Device capability

    /// The kind of biometric available on this device, if any.
    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    /// True when the device can authenticate the owner (biometrics or passcode).
    var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Human label for the available authentication method.
    var methodName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "código"
        }
    }

    /// SF Symbol that represents the available authentication method.
    var methodIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    // MARK: - Enable / disable

    /// Turns the lock on, requiring a successful authentication first.
    /// Returns `false` (leaving the feature off) if the user cancels or fails.
    @discardableResult
    func enable() async -> Bool {
        let ok = await evaluate(reason: "Confirma tu identidad para activar el bloqueo.")
        if ok {
            isEnabled = true
            UserDefaults.standard.set(true, forKey: enabledKey)
            isLocked = false
        }
        return ok
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
        isLocked = false
    }

    // MARK: - Lock lifecycle

    /// Called when the app leaves the foreground.
    func lockIfNeeded() {
        guard isEnabled, !isAuthenticating else { return }
        isLocked = true
    }

    /// Prompts for authentication if the app is currently locked.
    func authenticate() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        let ok = await evaluate(reason: "Desbloquea FinancIA para ver tus finanzas.")
        isAuthenticating = false
        if ok { isLocked = false }
    }

    // MARK: - Private

    private func evaluate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Usar código"
        var error: NSError?
        // `.deviceOwnerAuthentication` falls back to the device passcode when
        // biometrics are unavailable. If the device has neither, we can't lock,
        // so treat it as authenticated to avoid trapping the user.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
