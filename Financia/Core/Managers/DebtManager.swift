import Foundation
import Combine
import SwiftData

class DebtManager: ObservableObject {
    static let shared = DebtManager()

    @Published var debts: [Debt] = []

    private let container = PersistenceManager.shared.container

    private init() {
        loadDebts()
    }

    func loadDebts() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DebtEntity>()

        do {
            debts = try context.fetch(descriptor).map(Self.makeDebt(from:))
        } catch {
            print("Error loading debts: \(error)")
            debts = []
        }
    }

    private func saveDebts() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DebtEntity>()

        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            debts.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving debts: \(error)")
        }
    }

    func addDebt(_ debt: Debt) {
        debts.append(debt)
        saveDebts()
    }

    func updateDebt(_ debt: Debt) {
        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[index] = debt
            saveDebts()
        }
    }

    func deleteDebt(_ debt: Debt) {
        debts.removeAll { $0.id == debt.id }
        saveDebts()
    }

    private static func makeDebt(from entity: DebtEntity) -> Debt {
        Debt(
            id: entity.id,
            nombre: entity.nombre,
            motivo: entity.motivo,
            monto: entity.monto,
            moneda: Currency(rawValue: entity.monedaRaw) ?? .cup,
            plazoMeses: entity.plazoMeses,
            createdAt: entity.createdAt,
            lastEstimate: SwiftDataBridge.decode(DebtEstimateResponse.self, from: entity.lastEstimateData),
            montoOriginal: entity.montoOriginal,
            pagos: SwiftDataBridge.decode([DebtPayment].self, from: entity.pagosData) ?? []
        )
    }

    private static func makeEntity(from debt: Debt) -> DebtEntity {
        DebtEntity(
            id: debt.id,
            nombre: debt.nombre,
            motivo: debt.motivo,
            monto: debt.monto,
            monedaRaw: debt.moneda.rawValue,
            plazoMeses: debt.plazoMeses,
            createdAt: debt.createdAt,
            lastEstimateData: debt.lastEstimate.map(SwiftDataBridge.encode),
            montoOriginal: debt.montoOriginal,
            pagosData: SwiftDataBridge.encode(debt.pagos)
        )
    }
}
