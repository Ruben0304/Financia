import Foundation
import Combine
import SwiftData

@MainActor
class TransactionManager: ObservableObject {

    static let shared = TransactionManager()

    @Published var transactions: [Transaction] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/transactions/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    // MARK: - Hydration

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            transactions = try context.fetch(FetchDescriptor<TransactionEntity>())
                .map(Self.makeTransaction(from:))
        } catch {
            print("TransactionManager cache read failed: \(error)")
        }
    }

    func refreshFromBackend() async {
        do {
            let remote: [Transaction] = try await api.getList(endpoint)
            transactions = remote
            replaceCache(with: remote)
        } catch APIError.networkUnavailable {
            // keep cache
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadTransactions() { Task { await refreshFromBackend() } }

    // MARK: - CRUD (optimistic)

    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        insertOrReplaceInCache(transaction)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.post(self.endpoint, body: transaction)
            } catch {
                self.transactions.removeAll { $0.id == transaction.id }
                self.deleteFromCache(id: transaction.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateTransaction(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        let previous = transactions[index]
        transactions[index] = transaction
        insertOrReplaceInCache(transaction)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.put("\(self.endpoint)\(transaction.id.uuidString)", body: transaction)
            } catch {
                if let i = self.transactions.firstIndex(where: { $0.id == previous.id }) {
                    self.transactions[i] = previous
                    self.insertOrReplaceInCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        deleteFromCache(id: transaction.id)
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.api.delete("\(self.endpoint)\(transaction.id.uuidString)")
            } catch {
                self.transactions.append(transaction)
                self.insertOrReplaceInCache(transaction)
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteTransaction(id: UUID) {
        if let t = transactions.first(where: { $0.id == id }) { deleteTransaction(t) }
    }

    func clearAllTransactions() {
        let snapshot = transactions
        transactions = []
        replaceCache(with: [])
        // Best-effort: delete each on backend.
        Task { [weak self] in
            guard let self else { return }
            for t in snapshot {
                do {
                    _ = try await self.api.delete("\(self.endpoint)\(t.id.uuidString)")
                } catch {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Queries (unchanged — pure functions on in-memory state)

    func transactions(for wallet: Wallet) -> [Transaction] {
        transactions.filter { $0.walletId == wallet.id }
    }

    func transactions(ofType type: TransactionType) -> [Transaction] {
        transactions.filter { $0.type == type }
    }

    func transactions(in dateRange: DateRange) -> [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -dateRange.lengthInDays, to: today) ?? today
        return transactions.filter { $0.date >= startDate && $0.date <= Date() }
    }

    func transactions(from startDate: Date, to endDate: Date) -> [Transaction] {
        transactions.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func estimatedMonthlyIncome(in currency: Currency, wallets: [Wallet], monthsToAverage: Int = 3) -> Double {
        let walletIds = Set(wallets.filter { $0.currency == currency }.map(\.id))
        guard !walletIds.isEmpty else { return 0 }
        let incomeTransactions = transactions.filter { $0.type == .income && walletIds.contains($0.walletId) }
        guard !incomeTransactions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let totalsByMonth = Dictionary(grouping: incomeTransactions) { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let recentMonths = totalsByMonth.keys.sorted(by: >).prefix(max(monthsToAverage, 1))
        guard !recentMonths.isEmpty else { return 0 }
        let total = recentMonths.reduce(0) { $0 + (totalsByMonth[$1] ?? 0) }
        return total / Double(recentMonths.count)
    }

    func totalIncome(for wallet: Wallet? = nil) -> Double {
        let filtered = wallet != nil ? transactions(for: wallet!) : transactions
        return filtered.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    func totalExpenses(for wallet: Wallet? = nil) -> Double {
        let filtered = wallet != nil ? transactions(for: wallet!) : transactions
        return filtered.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    func balance(for wallet: Wallet? = nil) -> Double {
        totalIncome(for: wallet) - totalExpenses(for: wallet)
    }

    func monthlyAveragesByCategory(in currency: Currency, wallets: [Wallet]) -> [CategoryAverageExpense] {
        let walletIds = Set(wallets.filter { $0.currency == currency }.map(\.id))
        guard !walletIds.isEmpty else { return [] }
        let expenses = transactions.filter { $0.type == .expense && walletIds.contains($0.walletId) }
        guard !expenses.isEmpty else { return [] }
        let calendar = Calendar.current
        let distinctMonths = Set(expenses.compactMap { calendar.dateInterval(of: .month, for: $0.date)?.start })
        let monthCount = max(distinctMonths.count, 1)
        let grouped = Dictionary(grouping: expenses, by: \.categoryId)
        return grouped.compactMap { id, txs in
            let total = txs.reduce(0) { $0 + $1.amount }
            let name = txs.first?.categoryName ?? "Otros"
            return CategoryAverageExpense(categoryId: id, categoryName: name,
                                          monthlyAverage: total / Double(monthCount),
                                          totalSpent: total, transactionCount: txs.count)
        }.sorted { $0.monthlyAverage > $1.monthlyAverage }
    }

    func monthlyAveragesBySubcategory(in currency: Currency, wallets: [Wallet]) -> [SubcategoryAverageExpense] {
        let walletIds = Set(wallets.filter { $0.currency == currency }.map(\.id))
        guard !walletIds.isEmpty else { return [] }
        let expenses = transactions.filter { $0.type == .expense && walletIds.contains($0.walletId) }
        guard !expenses.isEmpty else { return [] }
        let calendar = Calendar.current
        let distinctMonths = Set(expenses.compactMap { calendar.dateInterval(of: .month, for: $0.date)?.start })
        let monthCount = max(distinctMonths.count, 1)
        let grouped = Dictionary(grouping: expenses, by: \.subcategoryId)
        return grouped.compactMap { id, txs in
            let total = txs.reduce(0) { $0 + $1.amount }
            let categoryId = txs.first?.categoryId ?? UUID()
            let categoryName = txs.first?.categoryName ?? "Otros"
            let subcategoryName = txs.first?.subcategoryName ?? "Otros"
            return SubcategoryAverageExpense(categoryId: categoryId, categoryName: categoryName,
                                             subcategoryId: id, subcategoryName: subcategoryName,
                                             monthlyAverage: total / Double(monthCount),
                                             totalSpent: total, transactionCount: txs.count)
        }.sorted { $0.monthlyAverage > $1.monthlyAverage }
    }

    func projectedExpenses(for ids: Set<UUID>, months: Int, in currency: Currency, wallets: [Wallet], groupBySubcategory: Bool = false) -> Double {
        if groupBySubcategory {
            let averages = monthlyAveragesBySubcategory(in: currency, wallets: wallets)
            return averages.filter { ids.contains($0.subcategoryId) }.reduce(0) { $0 + $1.monthlyAverage } * Double(months)
        } else {
            let averages = monthlyAveragesByCategory(in: currency, wallets: wallets)
            return averages.filter { ids.contains($0.categoryId) }.reduce(0) { $0 + $1.monthlyAverage } * Double(months)
        }
    }

    // MARK: - Cache helpers

    private func replaceCache(with items: [Transaction]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<TransactionEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("TransactionManager cache replace failed: \(error)") }
    }

    private func insertOrReplaceInCache(_ tx: Transaction) {
        let context = ModelContext(container)
        let id = tx.id
        do {
            try context.fetch(FetchDescriptor<TransactionEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: tx))
            try context.save()
        } catch { print("TransactionManager cache upsert failed: \(error)") }
    }

    private func deleteFromCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<TransactionEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            try context.save()
        } catch { print("TransactionManager cache delete failed: \(error)") }
    }

    // MARK: - Bridges

    private static func makeTransaction(from e: TransactionEntity) -> Transaction {
        Transaction(
            id: e.id, type: TransactionType(rawValue: e.typeRaw) ?? .expense,
            amount: e.amount, date: e.date,
            categoryId: e.categoryId, categoryName: e.categoryName,
            subcategoryId: e.subcategoryId, subcategoryName: e.subcategoryName,
            description: e.detailText, walletId: e.walletId, createdAt: e.createdAt,
            lugar: SwiftDataBridge.decode(Lugar.self, from: e.lugarData),
            subitems: SwiftDataBridge.decode([SubItem].self, from: e.subitemsData),
            assetId: e.assetId, jobId: e.jobId, liabilityId: e.liabilityId
        )
    }

    private static func makeEntity(from t: Transaction) -> TransactionEntity {
        TransactionEntity(
            id: t.id, typeRaw: t.type.rawValue, amount: t.amount, date: t.date,
            categoryId: t.categoryId, categoryName: t.categoryName,
            subcategoryId: t.subcategoryId, subcategoryName: t.subcategoryName,
            detailText: t.description, walletId: t.walletId, createdAt: t.createdAt,
            lugarData: t.lugar.map(SwiftDataBridge.encode),
            subitemsData: t.subitems.map(SwiftDataBridge.encode),
            assetId: t.assetId, jobId: t.jobId, liabilityId: t.liabilityId
        )
    }
}

struct CategoryAverageExpense: Identifiable {
    let id = UUID()
    let categoryId: UUID
    let categoryName: String
    let monthlyAverage: Double
    let totalSpent: Double
    let transactionCount: Int
}

struct SubcategoryAverageExpense: Identifiable {
    let id = UUID()
    let categoryId: UUID
    let categoryName: String
    let subcategoryId: UUID
    let subcategoryName: String
    let monthlyAverage: Double
    let totalSpent: Double
    let transactionCount: Int
}
