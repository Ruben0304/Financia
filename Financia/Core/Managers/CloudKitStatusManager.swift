import Combine
import Foundation

/// Reports the sync status of the app to the UI.
///
/// CloudKit is no longer the sync layer — the FinancIA backend is. This
/// manager survives only so existing views that depended on it keep
/// compiling, and to give the user a visible signal that the app is now
/// in "backend sync" mode.
@MainActor
final class CloudKitStatusManager: ObservableObject {
    static let shared = CloudKitStatusManager()

    enum State: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case unavailable(String)

        var title: String {
            switch self {
            case .checking: return "Verificando sincronización"
            case .available: return "Sincronización con backend activa"
            case .noAccount: return "Backend desconectado"
            case .restricted: return "Sincronización restringida"
            case .temporarilyUnavailable: return "Backend temporalmente no disponible"
            case .unavailable: return "Sincronización no disponible"
            }
        }

        var message: String {
            switch self {
            case .checking: return "Comprobando si el backend está disponible."
            case .available: return "Los datos se sincronizan automáticamente con el servidor de FinancIA."
            case .noAccount: return "No se pudo contactar el backend. Verifica tu conexión a internet o la API key."
            case .restricted: return "La sincronización con el backend está restringida."
            case .temporarilyUnavailable: return "El backend está temporalmente no disponible. Reintenta en unos minutos."
            case .unavailable(let reason): return reason
            }
        }

        var isAvailable: Bool {
            if case .available = self { return true }
            return false
        }

        var shouldShowSettingsAction: Bool {
            switch self {
            case .noAccount, .restricted: return true
            case .checking, .available, .temporarilyUnavailable, .unavailable: return false
            }
        }
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var persistenceMessage: String = "SwiftData en modo cache local. Backend es la fuente de verdad."
    @Published private(set) var isUsingCloudKitStore: Bool = false

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        state = .checking
        refreshPersistenceMode()
        // Probe the backend with the lightest available endpoint.
        do {
            let _: [String: AnyHashable]? = try? await pingBackend()
            state = .available
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    func refreshPersistenceMode() {
        switch PersistenceManager.shared.syncMode {
        case .cloudKit:
            isUsingCloudKitStore = true
            persistenceMessage = "SwiftData arrancó con el store de CloudKit."
        case .localFallback(let reason):
            isUsingCloudKitStore = false
            persistenceMessage = "Sincronización via backend FinancIA. Cache local SwiftData. \(reason)"
        }
    }

    private func pingBackend() async throws -> [String: AnyHashable]? {
        // Profile endpoint is cheap and always succeeds when backend is up.
        let _: UserProfile = try await APIClient.shared.get("/profile/")
        return nil
    }
}
