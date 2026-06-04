import Foundation
import Combine
import SwiftData

// Manager para operaciones CRUD de transacciones
class TransactionManager: ObservableObject {

    static let shared = TransactionManager()

    @Published var transactions: [Transaction] = []

    private let container = PersistenceManager.shared.container

    private init() {
        loadTransactions()
    }

    // MARK: - CRUD Operations

    func loadTransactions() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TransactionEntity>()

        do {
            transactions = try context.fetch(descriptor).map(Self.makeTransaction(from:))
        } catch {
            print("Error loading transactions: \(error)")
            transactions = []
        }
    }

    private func saveTransactions() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TransactionEntity>()

        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            transactions.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
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

    private static func makeTransaction(from entity: TransactionEntity) -> Transaction {
        Transaction(
            id: entity.id,
            type: TransactionType(rawValue: entity.typeRaw) ?? .expense,
            amount: entity.amount,
            date: entity.date,
            categoryId: entity.categoryId,
            categoryName: entity.categoryName,
            subcategoryId: entity.subcategoryId,
            subcategoryName: entity.subcategoryName,
            description: entity.detailText,
            walletId: entity.walletId,
            createdAt: entity.createdAt,
            lugar: SwiftDataBridge.decode(Lugar.self, from: entity.lugarData),
            subitems: SwiftDataBridge.decode([SubItem].self, from: entity.subitemsData),
            assetId: entity.assetId,
            jobId: entity.jobId,
            liabilityId: entity.liabilityId
        )
    }

    private static func makeEntity(from transaction: Transaction) -> TransactionEntity {
        TransactionEntity(
            id: transaction.id,
            typeRaw: transaction.type.rawValue,
            amount: transaction.amount,
            date: transaction.date,
            categoryId: transaction.categoryId,
            categoryName: transaction.categoryName,
            subcategoryId: transaction.subcategoryId,
            subcategoryName: transaction.subcategoryName,
            detailText: transaction.description,
            walletId: transaction.walletId,
            createdAt: transaction.createdAt,
            lugarData: transaction.lugar.map(SwiftDataBridge.encode),
            subitemsData: transaction.subitems.map(SwiftDataBridge.encode),
            assetId: transaction.assetId,
            jobId: transaction.jobId,
            liabilityId: transaction.liabilityId
        )
    }
}
