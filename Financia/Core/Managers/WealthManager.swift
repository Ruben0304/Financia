import Foundation
import Combine
import SwiftData

final class WealthManager: ObservableObject {
    static let shared = WealthManager()

    @Published var assets: [Asset] = []
    @Published var jobs: [Job] = []
    @Published var liabilities: [Liability] = []

    private let container = PersistenceManager.shared.container

    private init() {
        load()
    }

    func load() {
        let context = ModelContext(container)

        do {
            assets = try context.fetch(FetchDescriptor<AssetEntity>()).map(Self.makeAsset(from:))
            jobs = try context.fetch(FetchDescriptor<JobEntity>()).map(Self.makeJob(from:))
            liabilities = try context.fetch(FetchDescriptor<LiabilityEntity>()).map(Self.makeLiability(from:))
        } catch {
            print("Error loading wealth store: \(error)")
            assets = []
            jobs = []
            liabilities = []
        }
    }

    private func save() {
        let context = ModelContext(container)

        do {
            try context.fetch(FetchDescriptor<AssetEntity>()).forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<JobEntity>()).forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<LiabilityEntity>()).forEach { context.delete($0) }

            assets.map(Self.makeAssetEntity).forEach { context.insert($0) }
            jobs.map(Self.makeJobEntity).forEach { context.insert($0) }
            liabilities.map(Self.makeLiabilityEntity).forEach { context.insert($0) }

            try context.save()
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

    private static func makeAsset(from entity: AssetEntity) -> Asset {
        Asset(
            id: entity.id,
            name: entity.name,
            notes: entity.notes,
            monthlyEstimates: SwiftDataBridge.decode([MonthlyEstimate].self, from: entity.monthlyEstimatesData) ?? [],
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private static func makeJob(from entity: JobEntity) -> Job {
        Job(
            id: entity.id,
            name: entity.name,
            notes: entity.notes,
            monthlyEstimates: SwiftDataBridge.decode([MonthlyEstimate].self, from: entity.monthlyEstimatesData) ?? [],
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private static func makeLiability(from entity: LiabilityEntity) -> Liability {
        Liability(
            id: entity.id,
            name: entity.name,
            notes: entity.notes,
            monthlyEstimates: SwiftDataBridge.decode([MonthlyEstimate].self, from: entity.monthlyEstimatesData) ?? [],
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private static func makeAssetEntity(from asset: Asset) -> AssetEntity {
        AssetEntity(
            id: asset.id,
            name: asset.name,
            notes: asset.notes,
            monthlyEstimatesData: SwiftDataBridge.encode(asset.monthlyEstimates),
            createdAt: asset.createdAt,
            updatedAt: asset.updatedAt
        )
    }

    private static func makeJobEntity(from job: Job) -> JobEntity {
        JobEntity(
            id: job.id,
            name: job.name,
            notes: job.notes,
            monthlyEstimatesData: SwiftDataBridge.encode(job.monthlyEstimates),
            createdAt: job.createdAt,
            updatedAt: job.updatedAt
        )
    }

    private static func makeLiabilityEntity(from liability: Liability) -> LiabilityEntity {
        LiabilityEntity(
            id: liability.id,
            name: liability.name,
            notes: liability.notes,
            monthlyEstimatesData: SwiftDataBridge.encode(liability.monthlyEstimates),
            createdAt: liability.createdAt,
            updatedAt: liability.updatedAt
        )
    }
}
