import Foundation
import Combine
import SwiftData

@MainActor
class DebtManager: ObservableObject {
    static let shared = DebtManager()

    @Published var debts: [Debt] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/debts/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            debts = try context.fetch(FetchDescriptor<DebtEntity>()).map(Self.makeDebt(from:))
        } catch { print("DebtManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        do {
            let remote: [Debt] = try await api.getList(endpoint)
            debts = remote
            replaceCache(with: remote)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func loadDebts() { Task { await refreshFromBackend() } }

    // MARK: - CRUD (optimistic)

    func addDebt(_ debt: Debt) {
        debts.append(debt)
        insertCache(debt)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.endpoint, body: debt) }
            catch {
                self.debts.removeAll { $0.id == debt.id }
                self.deleteCache(id: debt.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateDebt(_ debt: Debt) {
        guard let i = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        let previous = debts[i]
        debts[i] = debt
        insertCache(debt)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.endpoint)\(debt.id.uuidString)", body: debt) }
            catch {
                if let j = self.debts.firstIndex(where: { $0.id == previous.id }) {
                    self.debts[j] = previous
                    self.insertCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteDebt(_ debt: Debt) {
        debts.removeAll { $0.id == debt.id }
        deleteCache(id: debt.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.endpoint)\(debt.id.uuidString)") }
            catch {
                self.debts.append(debt)
                self.insertCache(debt)
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Cache

    private func replaceCache(with items: [Debt]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<DebtEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("DebtManager cache replace failed: \(error)") }
    }

    private func insertCache(_ d: Debt) {
        let context = ModelContext(container)
        let id = d.id
        do {
            try context.fetch(FetchDescriptor<DebtEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: d))
            try context.save()
        } catch { print("DebtManager cache upsert failed: \(error)") }
    }

    private func deleteCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<DebtEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            try context.save()
        } catch { print("DebtManager cache delete failed: \(error)") }
    }

    private static func makeDebt(from e: DebtEntity) -> Debt {
        Debt(
            id: e.id, nombre: e.nombre, motivo: e.motivo, monto: e.monto,
            moneda: Currency(rawValue: e.monedaRaw) ?? .cup, plazoMeses: e.plazoMeses,
            createdAt: e.createdAt,
            lastEstimate: SwiftDataBridge.decode(DebtEstimateResponse.self, from: e.lastEstimateData),
            montoOriginal: e.montoOriginal,
            pagos: SwiftDataBridge.decode([DebtPayment].self, from: e.pagosData) ?? []
        )
    }

    private static func makeEntity(from d: Debt) -> DebtEntity {
        DebtEntity(
            id: d.id, nombre: d.nombre, motivo: d.motivo, monto: d.monto,
            monedaRaw: d.moneda.rawValue, plazoMeses: d.plazoMeses, createdAt: d.createdAt,
            lastEstimateData: d.lastEstimate.map(SwiftDataBridge.encode),
            montoOriginal: d.montoOriginal,
            pagosData: SwiftDataBridge.encode(d.pagos)
        )
    }
}
