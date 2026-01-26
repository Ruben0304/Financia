import Foundation
import Combine

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profile: UserProfile = UserProfile()

    private let persistence = PersistenceManager.shared
    private let filename = "profile.json"

    private init() {
        loadProfile()
    }

    func loadProfile() {
        guard persistence.fileExists(filename) else {
            profile = UserProfile()
            return
        }

        do {
            profile = try persistence.load(from: filename, as: UserProfile.self)
        } catch {
            print("Error loading profile: \(error)")
            profile = UserProfile()
        }
    }

    func saveProfile(_ profile: UserProfile) {
        self.profile = profile
        do {
            try persistence.save(profile, to: filename)
        } catch {
            print("Error saving profile: \(error)")
        }
    }
}
