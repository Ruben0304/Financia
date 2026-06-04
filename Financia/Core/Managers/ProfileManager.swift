import Foundation
import Combine
import SwiftData

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profile: UserProfile = UserProfile()

    private let container = PersistenceManager.shared.container
    private let profileKey = "main"

    private init() {
        loadProfile()
    }

    func loadProfile() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ProfileEntity>(
            predicate: #Predicate { $0.key == "main" }
        )

        do {
            if let entity = try context.fetch(descriptor).first {
                profile = UserProfile(
                    nombre: entity.nombre,
                    avatarData: entity.avatarData,
                    situacionFinanciera: entity.situacionFinanciera,
                    estrategiaFinanciera: entity.estrategiaFinanciera,
                    accentColorHex: entity.accentColorHex
                )
            } else {
                profile = UserProfile()
            }
        } catch {
            print("Error loading profile: \(error)")
            profile = UserProfile()
        }
    }

    func saveProfile(_ profile: UserProfile) {
        self.profile = profile
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ProfileEntity>(
            predicate: #Predicate { $0.key == "main" }
        )

        do {
            if let entity = try context.fetch(descriptor).first {
                entity.nombre = profile.nombre
                entity.avatarData = profile.avatarData
                entity.situacionFinanciera = profile.situacionFinanciera
                entity.estrategiaFinanciera = profile.estrategiaFinanciera
                entity.accentColorHex = profile.accentColorHex
            } else {
                context.insert(
                    ProfileEntity(
                        key: profileKey,
                        nombre: profile.nombre,
                        avatarData: profile.avatarData,
                        situacionFinanciera: profile.situacionFinanciera,
                        estrategiaFinanciera: profile.estrategiaFinanciera,
                        accentColorHex: profile.accentColorHex
                    )
                )
            }
            try context.save()
        } catch {
            print("Error saving profile: \(error)")
        }
    }
}
