import Foundation
import Combine
import SwiftUI
import SwiftData

// Manager para operaciones CRUD de carteras
class WalletManager: ObservableObject {

    static let shared = WalletManager()

    @Published var wallets: [Wallet] = []

    private let container = PersistenceManager.shared.container
    private let transactionManager = TransactionManager.shared

    private init() {
        loadWallets()
    }

    // MARK: - CRUD Operations

    func loadWallets() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WalletEntity>()

        do {
            let entities = try context.fetch(descriptor)
            wallets = entities.map(Self.makeWallet(from:))
            if wallets.isEmpty {
                createDefaultWallet()
            }
        } catch {
            print("Error loading wallets: \(error)")
            createDefaultWallet()
        }
    }

    private func saveWallets() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WalletEntity>()

        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            wallets.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving wallets: \(error)")
        }
    }

    private func createDefaultWallet() {
        let defaultWallet = Wallet(
            name: "Efectivo",
            currency: .cup,
            balance: 0,
            icon: "creditcard.fill",
            color: .blue
        )
        wallets = [defaultWallet]
        saveWallets()
    }

    func addWallet(_ wallet: Wallet) {
        wallets.append(wallet)
        saveWallets()
    }

    func updateWallet(_ wallet: Wallet) {
        if let index = wallets.firstIndex(where: { $0.id == wallet.id }) {
            wallets[index] = wallet
            saveWallets()
        }
    }

    func deleteWallet(_ wallet: Wallet) {
        wallets.removeAll { $0.id == wallet.id }
        saveWallets()
    }

    func deleteWallet(id: UUID) {
        wallets.removeAll { $0.id == id }
        saveWallets()
    }

    /// Ajusta el balance base de una cartera sin crear transacción.
    /// Usar un valor positivo para sumar, negativo para restar.
    func adjustBalance(walletId: UUID, amount: Double) {
        guard let index = wallets.firstIndex(where: { $0.id == walletId }) else { return }
        wallets[index].balance += amount
        saveWallets()
    }

    // MARK: - Balance Calculation

    // Calcular balance real basado en transacciones
    func calculateBalance(for wallet: Wallet) -> Double {
        let income = transactionManager.totalIncome(for: wallet)
        let expenses = transactionManager.totalExpenses(for: wallet)
        return wallet.balance + income - expenses
    }

    // Actualizar balance de una cartera basado en transacciones
    func syncWalletBalance(for walletId: UUID) {
        guard let index = wallets.firstIndex(where: { $0.id == walletId }) else { return }

        let wallet = wallets[index]
        let calculatedBalance = calculateBalance(for: wallet)
        wallets[index].balance = calculatedBalance
        saveWallets()
    }

    // Sincronizar todos los balances
    func syncAllWalletBalances() {
        for i in wallets.indices {
            let wallet = wallets[i]
            wallets[i].balance = calculateBalance(for: wallet)
        }
        saveWallets()
    }

    // MARK: - Query Methods

    func wallet(withId id: UUID) -> Wallet? {
        return wallets.first { $0.id == id }
    }

    func totalBalance(in currency: Currency? = nil) -> Double {
        if let targetCurrency = currency {
            let exchangeManager = ExchangeRateManager.shared
            return wallets.reduce(0) { total, wallet in
                let balance = calculateBalance(for: wallet)
                if wallet.currency == targetCurrency {
                    return total + balance
                } else {
                    return total + (exchangeManager.convert(amount: balance, from: wallet.currency, to: targetCurrency) ?? 0)
                }
            }
        } else {
            // Sin conversión, simplemente sumar
            return wallets.reduce(0) { $0 + calculateBalance(for: $1) }
        }
    }

    private static func makeWallet(from entity: WalletEntity) -> Wallet {
        Wallet(
            id: entity.id,
            name: entity.name,
            currency: Currency(rawValue: entity.currencyRaw) ?? .cup,
            balance: entity.balance,
            icon: entity.icon,
            color: SwiftDataBridge.color(
                red: entity.colorRed,
                green: entity.colorGreen,
                blue: entity.colorBlue,
                opacity: entity.colorOpacity
            )
        )
    }

    private static func makeEntity(from wallet: Wallet) -> WalletEntity {
        let c = SwiftDataBridge.components(from: wallet.color)
        return WalletEntity(
            id: wallet.id,
            name: wallet.name,
            currencyRaw: wallet.currency.rawValue,
            balance: wallet.balance,
            icon: wallet.icon,
            colorRed: c.red,
            colorGreen: c.green,
            colorBlue: c.blue,
            colorOpacity: c.opacity
        )
    }
}
