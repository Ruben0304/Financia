import CloudKit
import Foundation

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
            case .checking:
                return "Verificando iCloud"
            case .available:
                return "iCloud disponible"
            case .noAccount:
                return "Sin cuenta de iCloud"
            case .restricted:
                return "iCloud restringido"
            case .temporarilyUnavailable:
                return "iCloud temporalmente no disponible"
            case .unavailable:
                return "iCloud no disponible"
            }
        }

        var message: String {
            switch self {
            case .checking:
                return "Comprobando si CloudKit esta disponible en este dispositivo."
            case .available:
                return "La cuenta de iCloud del dispositivo esta disponible para CloudKit."
            case .noAccount:
                return "Inicia sesion con tu Apple ID en Ajustes del iPhone/iPad. No se inicia sesion dentro de la app."
            case .restricted:
                return "El acceso a iCloud esta restringido por controles o politicas del dispositivo."
            case .temporarilyUnavailable:
                return "La cuenta existe, pero CloudKit no esta listo todavia. Intenta de nuevo en unos minutos."
            case .unavailable(let reason):
                return reason
            }
        }

        var isAvailable: Bool {
            if case .available = self {
                return true
            }
            return false
        }

        var shouldShowSettingsAction: Bool {
            switch self {
            case .noAccount, .restricted:
                return true
            case .checking, .available, .temporarilyUnavailable, .unavailable:
                return false
            }
        }
    }

    @Published private(set) var state: State = .checking

    private let container = CKContainer(identifier: "iCloud.com.ruben.Financia")
    private var notificationTask: Task<Void, Never>?

    private init() {
        notificationTask = Task {
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                await refresh()
            }
        }

        Task {
            await refresh()
        }
    }

    deinit {
        notificationTask?.cancel()
    }

    func refresh() async {
        state = .checking

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                state = .available
            case .noAccount:
                state = .noAccount
            case .restricted:
                state = .restricted
            case .temporarilyUnavailable:
                state = .temporarilyUnavailable
            case .couldNotDetermine:
                state = .unavailable("No se pudo determinar el estado de iCloud en este momento.")
            @unknown default:
                state = .unavailable("El estado de iCloud no es compatible con esta version de la app.")
            }
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }
}
