import Foundation
import Combine

struct WealthStore: Codable {
    var assets: [Asset] = []
    var jobs: [Job] = []
    var liabilities: [Liability] = []
}

final class WealthManager: ObservableObject {
    static let shared = WealthManager()

    @Published var assets: [Asset] = []
    @Published var jobs: [Job] = []
    @Published var liabilities: [Liability] = []

    private let persistence = PersistenceManager.shared
    private let filename = "wealth.json"

    private init() {
        load()
    }

    func load() {
        guard persistence.fileExists(filename) else {
            assets = []
            jobs = []
            liabilities = []
            return
        }

        do {
            let store = try persistence.load(from: filename, as: WealthStore.self)
            assets = store.assets
            jobs = store.jobs
            liabilities = store.liabilities
        } catch {
            print("Error loading wealth store: \(error)")
            assets = []
            jobs = []
            liabilities = []
        }
    }

    private func save() {
        let store = WealthStore(assets: assets, jobs: jobs, liabilities: liabilities)
        do {
            try persistence.save(store, to: filename)
        } catch {
            print("Error saving wealth store: \(error)")
        }
    }

    // MARK: - Assets
    func addAsset(_ asset: Asset) {
        assets.append(asset)
        save()
    }

    func updateAsset(_ asset: Asset) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
            save()
        }
    }

    func deleteAsset(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
        save()
    }

    func asset(withId id: UUID?) -> Asset? {
        guard let id else { return nil }
        return assets.first { $0.id == id }
    }

    // MARK: - Jobs
    func addJob(_ job: Job) {
        jobs.append(job)
        save()
    }

    func updateJob(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
            save()
        }
    }

    func deleteJob(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
        save()
    }

    func job(withId id: UUID?) -> Job? {
        guard let id else { return nil }
        return jobs.first { $0.id == id }
    }

    // MARK: - Liabilities
    func addLiability(_ liability: Liability) {
        liabilities.append(liability)
        save()
    }

    func updateLiability(_ liability: Liability) {
        if let index = liabilities.firstIndex(where: { $0.id == liability.id }) {
            liabilities[index] = liability
            save()
        }
    }

    func deleteLiability(_ liability: Liability) {
        liabilities.removeAll { $0.id == liability.id }
        save()
    }

    func liability(withId id: UUID?) -> Liability? {
        guard let id else { return nil }
        return liabilities.first { $0.id == id }
    }
}
