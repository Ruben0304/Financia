import Foundation
import Combine
import SwiftData

@MainActor
final class WealthManager: ObservableObject {
    static let shared = WealthManager()

    @Published var assets: [Asset] = []
    @Published var jobs: [Job] = []
    @Published var liabilities: [Liability] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let assetsEndpoint = "/wealth/assets/"
    private let jobsEndpoint = "/wealth/jobs/"
    private let liabilitiesEndpoint = "/wealth/liabilities/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            assets = try context.fetch(FetchDescriptor<AssetEntity>()).map(Self.makeAsset(from:))
            jobs = try context.fetch(FetchDescriptor<JobEntity>()).map(Self.makeJob(from:))
            liabilities = try context.fetch(FetchDescriptor<LiabilityEntity>()).map(Self.makeLiability(from:))
        } catch { print("WealthManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        // Sequential awaits (not `async let`) — see SubscriptionManager
        // for the reason. Three round-trips on boot is fine.
        do {
            let assets: [Asset] = try await api.getList(assetsEndpoint)
            let jobs: [Job] = try await api.getList(jobsEndpoint)
            let liabilities: [Liability] = try await api.getList(liabilitiesEndpoint)
            self.assets = assets
            self.jobs = jobs
            self.liabilities = liabilities
            replaceCache(assets: assets, jobs: jobs, liabilities: liabilities)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func load() { Task { await refreshFromBackend() } }

    // MARK: - Assets

    func addAsset(_ asset: Asset) {
        assets.append(asset)
        insertAssetCache(asset)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.assetsEndpoint, body: asset) }
            catch {
                self.assets.removeAll { $0.id == asset.id }
                self.deleteAssetCache(id: asset.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateAsset(_ asset: Asset) {
        guard let i = assets.firstIndex(where: { $0.id == asset.id }) else { return }
        let previous = assets[i]
        assets[i] = asset
        insertAssetCache(asset)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.assetsEndpoint)\(asset.id.uuidString)", body: asset) }
            catch {
                if let j = self.assets.firstIndex(where: { $0.id == previous.id }) {
                    self.assets[j] = previous
                    self.insertAssetCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteAsset(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
        deleteAssetCache(id: asset.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.assetsEndpoint)\(asset.id.uuidString)") }
            catch {
                self.assets.append(asset)
                self.insertAssetCache(asset)
                self.lastError = error.localizedDescription
            }
        }
    }

    func asset(withId id: UUID?) -> Asset? { id.flatMap { id in assets.first { $0.id == id } } }

    // MARK: - Jobs

    func addJob(_ job: Job) {
        jobs.append(job)
        insertJobCache(job)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.jobsEndpoint, body: job) }
            catch {
                self.jobs.removeAll { $0.id == job.id }
                self.deleteJobCache(id: job.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateJob(_ job: Job) {
        guard let i = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        let previous = jobs[i]
        jobs[i] = job
        insertJobCache(job)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.jobsEndpoint)\(job.id.uuidString)", body: job) }
            catch {
                if let j = self.jobs.firstIndex(where: { $0.id == previous.id }) {
                    self.jobs[j] = previous
                    self.insertJobCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteJob(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
        deleteJobCache(id: job.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.jobsEndpoint)\(job.id.uuidString)") }
            catch {
                self.jobs.append(job)
                self.insertJobCache(job)
                self.lastError = error.localizedDescription
            }
        }
    }

    func job(withId id: UUID?) -> Job? { id.flatMap { id in jobs.first { $0.id == id } } }

    // MARK: - Liabilities

    func addLiability(_ liability: Liability) {
        liabilities.append(liability)
        insertLiabilityCache(liability)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.liabilitiesEndpoint, body: liability) }
            catch {
                self.liabilities.removeAll { $0.id == liability.id }
                self.deleteLiabilityCache(id: liability.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateLiability(_ liability: Liability) {
        guard let i = liabilities.firstIndex(where: { $0.id == liability.id }) else { return }
        let previous = liabilities[i]
        liabilities[i] = liability
        insertLiabilityCache(liability)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.liabilitiesEndpoint)\(liability.id.uuidString)", body: liability) }
            catch {
                if let j = self.liabilities.firstIndex(where: { $0.id == previous.id }) {
                    self.liabilities[j] = previous
                    self.insertLiabilityCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteLiability(_ liability: Liability) {
        liabilities.removeAll { $0.id == liability.id }
        deleteLiabilityCache(id: liability.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.liabilitiesEndpoint)\(liability.id.uuidString)") }
            catch {
                self.liabilities.append(liability)
                self.insertLiabilityCache(liability)
                self.lastError = error.localizedDescription
            }
        }
    }

    func liability(withId id: UUID?) -> Liability? { id.flatMap { id in liabilities.first { $0.id == id } } }

    // MARK: - Forecast queries (unchanged)

    func forecastedMonthlyIncome(in currency: Currency) -> Double {
        let a = assets.reduce(0) { $0 + $1.monthlyEstimates.filter { $0.currency == currency }.reduce(0) { $0 + $1.amount } }
        let j = jobs.reduce(0) { $0 + $1.monthlyEstimates.filter { $0.currency == currency }.reduce(0) { $0 + $1.amount } }
        return a + j
    }

    func incomeEvents(in currency: Currency) -> [ProjectedIncomeEvent] {
        let assetEvents = assets.flatMap { asset in
            asset.monthlyEstimates.filter { $0.currency == currency }.map {
                ProjectedIncomeEvent(sourceName: asset.name, sourceType: .asset, currency: currency, amount: $0.amount, dayOfMonth: $0.dayOfMonth)
            }
        }
        let jobEvents = jobs.flatMap { job in
            job.monthlyEstimates.filter { $0.currency == currency }.map {
                ProjectedIncomeEvent(sourceName: job.name, sourceType: .job, currency: currency, amount: $0.amount, dayOfMonth: $0.dayOfMonth)
            }
        }
        return (assetEvents + jobEvents).sorted {
            $0.dayOfMonth == $1.dayOfMonth ? $0.amount > $1.amount : $0.dayOfMonth < $1.dayOfMonth
        }
    }

    func allIncomeEvents() -> [ProjectedIncomeEvent] {
        let assetEvents = assets.flatMap { asset in
            asset.monthlyEstimates.map {
                ProjectedIncomeEvent(sourceName: asset.name, sourceType: .asset, currency: $0.currency, amount: $0.amount, dayOfMonth: $0.dayOfMonth)
            }
        }
        let jobEvents = jobs.flatMap { job in
            job.monthlyEstimates.map {
                ProjectedIncomeEvent(sourceName: job.name, sourceType: .job, currency: $0.currency, amount: $0.amount, dayOfMonth: $0.dayOfMonth)
            }
        }
        return (assetEvents + jobEvents).sorted {
            $0.dayOfMonth == $1.dayOfMonth ? $0.amount > $1.amount : $0.dayOfMonth < $1.dayOfMonth
        }
    }

    func liabilityEvents(in currency: Currency) -> [ProjectedExpenseEvent] {
        // Broken up explicitly: the chained flatMap+filter+map+sorted
        // form was tripping Swift's type inference timeout.
        var events: [ProjectedExpenseEvent] = []
        for liability in liabilities {
            for estimate in liability.monthlyEstimates where estimate.currency == currency {
                events.append(ProjectedExpenseEvent(
                    sourceName: liability.name,
                    currency: currency,
                    amount: estimate.amount,
                    dayOfMonth: estimate.dayOfMonth
                ))
            }
        }
        events.sort { lhs, rhs in
            if lhs.dayOfMonth == rhs.dayOfMonth { return lhs.amount > rhs.amount }
            return lhs.dayOfMonth < rhs.dayOfMonth
        }
        return events
    }

    func allLiabilityEvents() -> [ProjectedExpenseEvent] {
        var events: [ProjectedExpenseEvent] = []
        for liability in liabilities {
            for estimate in liability.monthlyEstimates {
                events.append(ProjectedExpenseEvent(
                    sourceName: liability.name,
                    currency: estimate.currency,
                    amount: estimate.amount,
                    dayOfMonth: estimate.dayOfMonth
                ))
            }
        }
        events.sort { lhs, rhs in
            if lhs.dayOfMonth == rhs.dayOfMonth { return lhs.amount > rhs.amount }
            return lhs.dayOfMonth < rhs.dayOfMonth
        }
        return events
    }

    // MARK: - Cache helpers (per entity type)

    private func replaceCache(assets: [Asset], jobs: [Job], liabilities: [Liability]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<AssetEntity>()).forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<JobEntity>()).forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<LiabilityEntity>()).forEach { context.delete($0) }
            assets.map(Self.makeAssetEntity).forEach { context.insert($0) }
            jobs.map(Self.makeJobEntity).forEach { context.insert($0) }
            liabilities.map(Self.makeLiabilityEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("WealthManager cache replace failed: \(error)") }
    }

    private func insertAssetCache(_ a: Asset) {
        let context = ModelContext(container); let id = a.id
        do {
            try context.fetch(FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            context.insert(Self.makeAssetEntity(from: a))
            try context.save()
        } catch { print("WealthManager asset cache upsert failed: \(error)") }
    }
    private func deleteAssetCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            try context.save()
        } catch {}
    }

    private func insertJobCache(_ j: Job) {
        let context = ModelContext(container); let id = j.id
        do {
            try context.fetch(FetchDescriptor<JobEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            context.insert(Self.makeJobEntity(from: j))
            try context.save()
        } catch { print("WealthManager job cache upsert failed: \(error)") }
    }
    private func deleteJobCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<JobEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            try context.save()
        } catch {}
    }

    private func insertLiabilityCache(_ l: Liability) {
        let context = ModelContext(container); let id = l.id
        do {
            try context.fetch(FetchDescriptor<LiabilityEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            context.insert(Self.makeLiabilityEntity(from: l))
            try context.save()
        } catch { print("WealthManager liability cache upsert failed: \(error)") }
    }
    private func deleteLiabilityCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<LiabilityEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            try context.save()
        } catch {}
    }

    // MARK: - Bridges

    private static func makeAsset(from e: AssetEntity) -> Asset {
        Asset(id: e.id, name: e.name, notes: e.notes,
              monthlyEstimates: SwiftDataBridge.decode([MonthlyEstimate].self, from: e.monthlyEstimatesData) ?? [],
              createdAt: e.createdAt, updatedAt: e.updatedAt)
    }
    private static func makeJob(from e: JobEntity) -> Job {
        Job(id: e.id, name: e.name, notes: e.notes,
            monthlyEstimates: SwiftDataBridge.decode([MonthlyEstimate].self, from: e.monthlyEstimatesData) ?? [],
            createdAt: e.createdAt, updatedAt: e.updatedAt)
    }
    private static func makeLiability(from e: LiabilityEntity) -> Liability {
        Liability(id: e.id, name: e.name, notes: e.notes,
                  monthlyEstimates: SwiftDataBridge.decode([MonthlyEstimate].self, from: e.monthlyEstimatesData) ?? [],
                  createdAt: e.createdAt, updatedAt: e.updatedAt)
    }
    private static func makeAssetEntity(from a: Asset) -> AssetEntity {
        AssetEntity(id: a.id, name: a.name, notes: a.notes,
                    monthlyEstimatesData: SwiftDataBridge.encode(a.monthlyEstimates),
                    createdAt: a.createdAt, updatedAt: a.updatedAt)
    }
    private static func makeJobEntity(from j: Job) -> JobEntity {
        JobEntity(id: j.id, name: j.name, notes: j.notes,
                  monthlyEstimatesData: SwiftDataBridge.encode(j.monthlyEstimates),
                  createdAt: j.createdAt, updatedAt: j.updatedAt)
    }
    private static func makeLiabilityEntity(from l: Liability) -> LiabilityEntity {
        LiabilityEntity(id: l.id, name: l.name, notes: l.notes,
                        monthlyEstimatesData: SwiftDataBridge.encode(l.monthlyEstimates),
                        createdAt: l.createdAt, updatedAt: l.updatedAt)
    }
}

struct ProjectedIncomeEvent: Identifiable, Hashable {
    enum SourceType: Hashable { case asset, job }
    let id = UUID()
    let sourceName: String
    let sourceType: SourceType
    let currency: Currency
    let amount: Double
    let dayOfMonth: Int
}

struct ProjectedExpenseEvent: Identifiable, Hashable {
    let id = UUID()
    let sourceName: String
    let currency: Currency
    let amount: Double
    let dayOfMonth: Int
}
