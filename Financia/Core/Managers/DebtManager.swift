import Foundation
import Combine

class DebtManager: ObservableObject {
    static let shared = DebtManager()

    @Published var debts: [Debt] = []

    private let persistence = PersistenceManager.shared
    private let filename = "debts.json"

    private init() {
        loadDebts()
    }

    func loadDebts() {
        guard persistence.fileExists(filename) else {
            debts = []
            return
        }

        do {
            debts = try persistence.load(from: filename, as: [Debt].self)
        } catch {
            print("Error loading debts: \(error)")
            debts = []
        }
    }

    private func saveDebts() {
        do {
            try persistence.save(debts, to: filename)
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
}
