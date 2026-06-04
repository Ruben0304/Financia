import Foundation
import Combine
import SwiftData

@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profile: UserProfile = UserProfile()
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/profile/"
    private let profileKey = "main"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            if let e = try context.fetch(FetchDescriptor<ProfileEntity>(predicate: #Predicate { $0.key == "main" })).first {
                profile = UserProfile(
                    nombre: e.nombre, avatarData: e.avatarData,
                    situacionFinanciera: e.situacionFinanciera,
                    estrategiaFinanciera: e.estrategiaFinanciera,
                    accentColorHex: e.accentColorHex,
                    automationWalletId: e.automationWalletId
                )
            }
        } catch { print("ProfileManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        do {
            let remote: UserProfile = try await api.get(endpoint)
            profile = remote
            saveCache(remote)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func loadProfile() { Task { await refreshFromBackend() } }

    /// Replaces the profile on the backend (singleton). Optimistic: we
    /// update memory + cache immediately and roll back on failure.
    func saveProfile(_ profile: UserProfile) {
        let previous = self.profile
        self.profile = profile
        saveCache(profile)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put(self.endpoint, body: profile) }
            catch {
                self.profile = previous
                self.saveCache(previous)
                self.lastError = error.localizedDescription
            }
        }
    }

    private func saveCache(_ profile: UserProfile) {
        let context = ModelContext(container)
        do {
            if let e = try context.fetch(FetchDescriptor<ProfileEntity>(predicate: #Predicate { $0.key == "main" })).first {
                e.nombre = profile.nombre
                e.avatarData = profile.avatarData
                e.situacionFinanciera = profile.situacionFinanciera
                e.estrategiaFinanciera = profile.estrategiaFinanciera
                e.accentColorHex = profile.accentColorHex
                e.automationWalletId = profile.automationWalletId
            } else {
                context.insert(ProfileEntity(
                    key: profileKey, nombre: profile.nombre, avatarData: profile.avatarData,
                    situacionFinanciera: profile.situacionFinanciera,
                    estrategiaFinanciera: profile.estrategiaFinanciera,
                    accentColorHex: profile.accentColorHex,
                    automationWalletId: profile.automationWalletId
                ))
            }
            try context.save()
        } catch { print("ProfileManager cache save failed: \(error)") }
    }
}
