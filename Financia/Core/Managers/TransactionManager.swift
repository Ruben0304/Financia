import Foundation
import Combine

// Manager para operaciones CRUD de transacciones
class TransactionManager: ObservableObject {

    static let shared = TransactionManager()

    @Published var transactions: [Transaction] = []

    private let persistence = PersistenceManager.shared
    private let filename = "transactions.json"

    private init() {
        loadTransactions()
    }

    // MARK: - CRUD Operations

    func loadTransactions() {
        guard persistence.fileExists(filename) else {
            transactions = []
            return
        }

        do {
            transactions = try persistence.load(from: filename, as: [Transaction].self)
        } catch {
            print("Error loading transactions: \(error)")
            transactions = []
        }
    }

    private func saveTransactions() {
        do {
            try persistence.save(transactions, to: filename)
        } catch {
            print("Error saving transactions: \(error)")
        }
    }

    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        saveTransactions()
    }

    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            saveTransactions()
        }
    }

    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveTransactions()
    }

    func deleteTransaction(id: UUID) {
        transactions.removeAll { $0.id == id }
        saveTransactions()
    }

    // MARK: - Query Methods

    func transactions(for wallet: Wallet) -> [Transaction] {
        return transactions.filter { $0.walletId == wallet.id }
    }

    func transactions(ofType type: TransactionType) -> [Transaction] {
        return transactions.filter { $0.type == type }
    }

    func transactions(in dateRange: DateRange) -> [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -dateRange.lengthInDays, to: today) ?? today

        return transactions.filter { $0.date >= startDate && $0.date <= Date() }
    }

    func transactions(from startDate: Date, to endDate: Date) -> [Transaction] {
        return transactions.filter { $0.date >= startDate && $0.date <= endDate }
    }

    // MARK: - Statistics

    func totalIncome(for wallet: Wallet? = nil) -> Double {
        let filtered = wallet != nil ? transactions(for: wallet!) : transactions
        return filtered
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    func totalExpenses(for wallet: Wallet? = nil) -> Double {
        let filtered = wallet != nil ? transactions(for: wallet!) : transactions
        return filtered
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    func balance(for wallet: Wallet? = nil) -> Double {
        return totalIncome(for: wallet) - totalExpenses(for: wallet)
    }

    // MARK: - Clear Data

    func clearAllTransactions() {
        transactions = []
        saveTransactions()
    }
}
