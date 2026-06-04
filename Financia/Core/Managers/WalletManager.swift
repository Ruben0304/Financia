import Foundation
import Combine
import SwiftUI
import SwiftData

/// Manages user wallets.
///
/// Architecture (shared with all CRUD managers):
/// - Backend is the source of truth.
/// - SwiftData is a local read-only cache so UI is instant.
/// - Public CRUD methods stay synchronous (optimistic): they update
///   in-memory state and the cache immediately, then fire a Task that
///   confirms the write against the backend. If the backend rejects,
///   we roll the in-memory + cache state back and surface `lastError`.
/// - Boot order: load cache → publish → refresh from backend in background.
@MainActor
class WalletManager: ObservableObject {

    static let shared = WalletManager()

    @Published var wallets: [Wallet] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/wallets/"
    private let transactionManager = TransactionManager.shared
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        observeTransactions()
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    // MARK: - Hydration

    private func loadFromCache() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WalletEntity>()
        do {
            wallets = try context.fetch(descriptor).map(Self.makeWallet(from:))
        } catch {
            print("WalletManager: cache read failed: \(error)")
        }
    }

    func refreshFromBackend() async {
        do {
            let remote: [Wallet] = try await api.getList(endpoint)
            wallets = remote
            replaceCache(with: remote)
            if remote.isEmpty {
                let defaultWallet = Wallet(name: "Efectivo", currency: .cup, balance: 0, icon: "creditcard.fill", color: .blue)
                addWallet(defaultWallet)
            }
        } catch APIError.networkUnavailable {
            // keep cache
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadWallets() { Task { await refreshFromBackend() } }

    // MARK: - CRUD (optimistic)

    func addWallet(_ wallet: Wallet) {
        wallets.append(wallet)
        insertOrReplaceInCache(wallet)
        Task { [weak self] in
            guard let self else { return }
            do {
                let confirmed: Wallet = try await self.api.post(self.endpoint, body: wallet)
                if let idx = self.wallets.firstIndex(where: { $0.id == confirmed.id }) {
                    self.wallets[idx] = confirmed
                    self.insertOrReplaceInCache(confirmed)
                }
            } catch {
                self.wallets.removeAll { $0.id == wallet.id }
                self.deleteFromCache(id: wallet.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateWallet(_ wallet: Wallet) {
        guard let index = wallets.firstIndex(where: { $0.id == wallet.id }) else { return }
        let previous = wallets[index]
        wallets[index] = wallet
        insertOrReplaceInCache(wallet)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.put("\(self.endpoint)\(wallet.id.uuidString)", body: wallet)
            } catch {
                if let i = self.wallets.firstIndex(where: { $0.id == previous.id }) {
                    self.wallets[i] = previous
                    self.insertOrReplaceInCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteWallet(_ wallet: Wallet) {
        wallets.removeAll { $0.id == wallet.id }
        deleteFromCache(id: wallet.id)
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.api.delete("\(self.endpoint)\(wallet.id.uuidString)")
            } catch {
                self.wallets.append(wallet)
                self.insertOrReplaceInCache(wallet)
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteWallet(id: UUID) {
        if let wallet = wallets.first(where: { $0.id == id }) {
            deleteWallet(wallet)
        }
    }

    func adjustBalance(walletId: UUID, amount: Double) {
        guard var wallet = wallets.first(where: { $0.id == walletId }) else { return }
        wallet.balance += amount
        updateWallet(wallet)
    }

    // MARK: - Cache helpers

    private func replaceCache(with wallets: [Wallet]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<WalletEntity>()).forEach { context.delete($0) }
            wallets.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("WalletManager cache replace failed: \(error)") }
    }

    private func insertOrReplaceInCache(_ wallet: Wallet) {
        let context = ModelContext(container)
        let id = wallet.id
        do {
            try context.fetch(FetchDescriptor<WalletEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: wallet))
            try context.save()
        } catch { print("WalletManager cache upsert failed: \(error)") }
    }

    private func deleteFromCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<WalletEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            try context.save()
        } catch { print("WalletManager cache delete failed: \(error)") }
    }

    // MARK: - Balance / Query

    func calculateBalance(for wallet: Wallet) -> Double {
        let income = transactionManager.totalIncome(for: wallet)
        let expenses = transactionManager.totalExpenses(for: wallet)
        return wallet.balance + income - expenses
    }

    func syncWalletBalance(for walletId: UUID) {
        guard wallets.contains(where: { $0.id == walletId }) else { return }
        objectWillChange.send()
    }

    func syncAllWalletBalances() { objectWillChange.send() }

    func wallet(withId id: UUID) -> Wallet? { wallets.first { $0.id == id } }

    func totalBalance(in currency: Currency? = nil) -> Double {
        if let targetCurrency = currency {
            let exchangeManager = ExchangeRateManager.shared
            return wallets.reduce(0) { total, wallet in
                let balance = calculateBalance(for: wallet)
                if wallet.currency == targetCurrency { return total + balance }
                return total + (exchangeManager.convert(amount: balance, from: wallet.currency, to: targetCurrency) ?? 0)
            }
        } else {
            return wallets.reduce(0) { $0 + calculateBalance(for: $1) }
        }
    }

    // MARK: - Bridges

    private static func makeWallet(from entity: WalletEntity) -> Wallet {
        var billesDañados: [String: Int]? = nil
        if let data = entity.billetesData {
            billesDañados = try? JSONDecoder().decode([String: Int].self, from: data)
        }
        return Wallet(
            id: entity.id, name: entity.name,
            currency: Currency(rawValue: entity.currencyRaw) ?? .cup,
            balance: entity.balance, icon: entity.icon,
            color: SwiftDataBridge.color(red: entity.colorRed, green: entity.colorGreen, blue: entity.colorBlue, opacity: entity.colorOpacity),
            billesDañados: billesDañados
        )
    }

    private static func makeEntity(from wallet: Wallet) -> WalletEntity {
        let c = SwiftDataBridge.components(from: wallet.color)
        let billetesData = wallet.billesDañados.flatMap { try? JSONEncoder().encode($0) }
        return WalletEntity(
            id: wallet.id, name: wallet.name, currencyRaw: wallet.currency.rawValue,
            balance: wallet.balance, icon: wallet.icon,
            colorRed: c.red, colorGreen: c.green, colorBlue: c.blue, colorOpacity: c.opacity,
            billetesData: billetesData
        )
    }

    private func observeTransactions() {
        transactionManager.$transactions
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
