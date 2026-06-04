import Foundation
import Combine
import SwiftData

class ExpenseAnalysisManager: ObservableObject {
    static let shared = ExpenseAnalysisManager()

    @Published var lastAnalysis: String?
    @Published var isAnalyzing: Bool = false
    @Published var showNotification: Bool = false

    private let container = PersistenceManager.shared.container
    private let cacheKey = "last_expense_analysis"
    private let chatService = ChatService()

    private init() {
        loadAnalysis()
    }

    // MARK: - Persistence

    private func loadAnalysis() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ExpenseAnalysisEntity>(
            predicate: #Predicate { $0.key == "last_expense_analysis" }
        )

        do {
            lastAnalysis = try context.fetch(descriptor).first?.analysis
        } catch {
            print("Error loading expense analysis: \(error)")
        }
    }

    private func saveAnalysis() {
        guard let analysis = lastAnalysis else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ExpenseAnalysisEntity>(
            predicate: #Predicate { $0.key == "last_expense_analysis" }
        )

        do {
            if let entity = try context.fetch(descriptor).first {
                entity.analysis = analysis
            } else {
                context.insert(ExpenseAnalysisEntity(key: cacheKey, analysis: analysis))
            }
            try context.save()
        } catch {
            print("Error saving expense analysis: \(error)")
        }
    }

    // MARK: - Analysis

    func analyzeExpense(transaction: Transaction) {
        isAnalyzing = true

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let prompt = self.buildPrompt(for: transaction)
                let stream = try await self.chatService.sendMessage(prompt)

                var result = ""
                for try await chunk in stream {
                    result += chunk
                }

                await MainActor.run {
                    self.lastAnalysis = result
                    self.saveAnalysis()
                    self.isAnalyzing = false
                    self.showNotification = true
                }

                // Auto-hide notification after 4 seconds
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    self.showNotification = false
                }
            } catch {
                print("Error analyzing expense: \(error)")
                await MainActor.run {
                    self.isAnalyzing = false
                }
            }
        }
    }

    // MARK: - Prompt

    private func buildPrompt(for transaction: Transaction) -> String {
        let transactionManager = TransactionManager.shared
        let walletManager = WalletManager.shared
        let debtManager = DebtManager.shared
        let savingsManager = SavingsGoalManager.shared
        let profileManager = ProfileManager.shared

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let recentTransactions = transactionManager.transactions.filter { $0.date >= thirtyDaysAgo }
        let totalRecentExpenses = recentTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let totalRecentIncome = recentTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }

        let walletCurrency = walletManager.wallet(withId: transaction.walletId)?.currency ?? .cup

        let walletSummary = walletManager.wallets.map { wallet -> String in
            let balance = walletManager.calculateBalance(for: wallet)
            return "\(wallet.name) (\(wallet.currency.rawValue)): \(String(format: "%.2f", balance))"
        }.joined(separator: ", ")

        let debtSummary = debtManager.debts.isEmpty
            ? "Sin deudas"
            : debtManager.debts.map { "\($0.nombre): \(String(format: "%.2f", $0.monto)) \($0.moneda.rawValue)" }.joined(separator: "; ")

        let savingsSummary = savingsManager.savingsGoals.isEmpty
            ? "Sin metas de ahorro"
            : savingsManager.savingsGoals.map { "\($0.nombre): \(String(format: "%.2f", $0.ahorrado))/\(String(format: "%.2f", $0.precioObjetivo)) \($0.moneda.rawValue)" }.joined(separator: "; ")

        let profile = profileManager.profile

        var prompt = """
        === ANÁLISIS AUTOMÁTICO DE GASTO ===

        GASTO REGISTRADO:
        - Categoría: \(transaction.categoryName) › \(transaction.subcategoryName)
        - Monto: \(String(format: "%.2f", transaction.amount)) \(walletCurrency.rawValue)
        - Descripción: \(transaction.description.isEmpty ? "Sin descripción" : transaction.description)

        CONTEXTO FINANCIERO (último 30 días):
        - Total ingresos: \(String(format: "%.2f", totalRecentIncome))
        - Total gastos: \(String(format: "%.2f", totalRecentExpenses))
        - Balance mensual: \(String(format: "%.2f", totalRecentIncome - totalRecentExpenses))
        - Carteras: \(walletSummary)
        - Deudas: \(debtSummary)
        - Metas de ahorro: \(savingsSummary)
        """

        if !profile.situacionFinanciera.isEmpty {
            prompt += "\n- Situación financiera del usuario: \(profile.situacionFinanciera)"
        }
        if !profile.estrategiaFinanciera.isEmpty {
            prompt += "\n- Estrategia financiera del usuario: \(profile.estrategiaFinanciera)"
        }

        prompt += """


        Basándote en el gasto registrado y el contexto financiero, escribe un análisis muy breve (máximo 2-3 oraciones cortas). Menciona si el gasto es proporcional al presupuesto mensual, si impacta metas o deudas, y una sugerencia concreta si aplica. Solo el análisis puro, sin encabezados ni preguntas.
        """

        return prompt
    }
}
