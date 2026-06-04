import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    @Published var transactionFilter: TransactionFilter = .ambos
    @Published var timePeriod: TimePeriod = .month

    private let chatService: ChatService
    private let transactionManager: TransactionManager
    private let exchangeRateManager: ExchangeRateManager
    private let walletManager: WalletManager
    private let debtManager: DebtManager
    private let prestamoManager: PrestamoManager
    private let savingsManager: SavingsGoalManager
    private let profileManager: ProfileManager
    private let subscriptionManager: SubscriptionManager
    private let contextBuilder: FinancialAIContextBuilder

    init(
        chatService: ChatService = ChatService(),
        transactionManager: TransactionManager = .shared,
        exchangeRateManager: ExchangeRateManager = .shared,
        walletManager: WalletManager = .shared,
        debtManager: DebtManager = .shared,
        prestamoManager: PrestamoManager = .shared,
        savingsManager: SavingsGoalManager = .shared,
        profileManager: ProfileManager = .shared,
        subscriptionManager: SubscriptionManager = .shared,
        contextBuilder: FinancialAIContextBuilder? = nil
    ) {
        self.chatService = chatService
        self.transactionManager = transactionManager
        self.exchangeRateManager = exchangeRateManager
        self.walletManager = walletManager
        self.debtManager = debtManager
        self.prestamoManager = prestamoManager
        self.savingsManager = savingsManager
        self.profileManager = profileManager
        self.subscriptionManager = subscriptionManager
        self.contextBuilder = contextBuilder ?? FinancialAIContextBuilder(
            transactionManager: transactionManager,
            exchangeRateManager: exchangeRateManager,
            walletManager: walletManager,
            debtManager: debtManager,
            prestamoManager: prestamoManager,
            savingsManager: savingsManager,
            profileManager: profileManager,
            subscriptionManager: subscriptionManager
        )
    }

    /// Envía un mensaje al chat incluyendo el contexto de transacciones
    func sendMessage() async {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let userMessage = currentInput
        currentInput = ""

        // Agregar mensaje del usuario
        let chatMessage = ChatMessage(content: userMessage, isUser: true)
        messages.append(chatMessage)

        isLoading = true

        do {
            // Preparar contexto con transacciones
            let context = contextBuilder.buildTransactionContext(
                transactionFilter: transactionFilter,
                timePeriod: timePeriod
            )
            let fullMessage = context + "\n\nPregunta del usuario: \(userMessage)"

            var assistantIndex: Int?
            var receivedCharacters = 0

            // Recibir respuesta en streaming
            let stream = try await chatService.sendMessage(fullMessage)

            for try await chunk in stream {
                if assistantIndex == nil {
                    isLoading = false
                    let assistantMessage = ChatMessage(content: chunk, isUser: false)
                    messages.append(assistantMessage)
                    assistantIndex = messages.count - 1
                } else if let index = assistantIndex {
                    let currentContent = messages[index].content
                    messages[index] = ChatMessage(
                        id: messages[index].id,
                        content: currentContent + chunk,
                        isUser: false,
                        timestamp: messages[index].timestamp
                    )
                }

                receivedCharacters += chunk.count
                print("[ChatStream] chunk=\(chunk.count) total=\(receivedCharacters) content=\(chunk)")
            }

            isLoading = false
        } catch {
            isLoading = false
            let message: String
            if let apiError = error as? ChatAPIError {
                switch apiError {
                case .serverError(let detail):
                    message = detail
                case .invalidResponse:
                    message = "Respuesta inválida del servidor."
                case .encodingError:
                    message = "Error al codificar el mensaje."
                case .networkError(let underlying):
                    message = "Error de red: \(underlying.localizedDescription)"
                }
            } else {
                message = "Error al enviar mensaje: \(error.localizedDescription)"
            }
            let errorMessage = ChatMessage(content: message, isUser: false)
            messages.append(errorMessage)
        }
    }

    /// Limpia el historial de mensajes
    func clearMessages() {
        messages.removeAll()
    }
}

@MainActor
final class FinancialAIContextBuilder {
    private let transactionManager: TransactionManager
    private let exchangeRateManager: ExchangeRateManager
    private let walletManager: WalletManager
    private let debtManager: DebtManager
    private let prestamoManager: PrestamoManager
    private let savingsManager: SavingsGoalManager
    private let profileManager: ProfileManager
    private let subscriptionManager: SubscriptionManager

    init(
        transactionManager: TransactionManager = .shared,
        exchangeRateManager: ExchangeRateManager = .shared,
        walletManager: WalletManager = .shared,
        debtManager: DebtManager = .shared,
        prestamoManager: PrestamoManager = .shared,
        savingsManager: SavingsGoalManager = .shared,
        profileManager: ProfileManager = .shared,
        subscriptionManager: SubscriptionManager = .shared
    ) {
        self.transactionManager = transactionManager
        self.exchangeRateManager = exchangeRateManager
        self.walletManager = walletManager
        self.debtManager = debtManager
        self.prestamoManager = prestamoManager
        self.savingsManager = savingsManager
        self.profileManager = profileManager
        self.subscriptionManager = subscriptionManager
    }

    func buildTransactionContext(
        transactionFilter: TransactionFilter,
        timePeriod: TimePeriod
    ) -> String {
        var transactions = transactionManager.transactions

        if transactionFilter == .ingresos {
            transactions = transactions.filter { $0.type == .income }
        } else if transactionFilter == .gastos {
            transactions = transactions.filter { $0.type == .expense }
        }

        if let startDate = timePeriod.startDate {
            transactions = transactions.filter { $0.date >= startDate }
        }

        transactions.sort { $0.date > $1.date }

        var context = "=== CONTEXTO DE TRANSACCIONES ===\n"
        context += "Periodo: \(timePeriod.rawValue)\n"
        context += "Tipo: \(transactionFilter.rawValue)\n"
        context += "Total de transacciones: \(transactions.count)\n"
        context += "\(usdRateContextLine())\n\n"

        if transactions.isEmpty {
            context += "No hay transacciones en el periodo seleccionado.\n"
        } else {
            context += "TRANSACCIONES:\n"
            for transaction in transactions.prefix(50) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short

                context += """
                - \(transaction.type.displayName): $\(String(format: "%.2f", transaction.amount))
                  Categoría: \(transaction.categoryName) - \(transaction.subcategoryName)
                  Fecha: \(dateFormatter.string(from: transaction.date))
                  Descripción: \(transaction.description)

                """
            }

            if transactions.count > 50 {
                context += "\n... y \(transactions.count - 50) transacciones más.\n"
            }

            let totalIncome = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let totalExpenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

            context += "\nESTADÍSTICAS:\n"
            context += "Total ingresos: $\(String(format: "%.2f", totalIncome))\n"
            context += "Total gastos: $\(String(format: "%.2f", totalExpenses))\n"
            context += "Balance: $\(String(format: "%.2f", totalIncome - totalExpenses))\n"
        }

        context += "\n=== CARTERAS ===\n"
        for wallet in walletManager.wallets {
            let balance = walletManager.calculateBalance(for: wallet)
            context += "- \(wallet.name) (\(wallet.currency.rawValue)): \(String(format: "%.2f", balance))\n"
        }

        context += "\n=== DEUDAS ===\n"
        if debtManager.debts.isEmpty {
            context += "Sin deudas registradas.\n"
        } else {
            for debt in debtManager.debts {
                context += "- \(debt.nombre): \(String(format: "%.2f", debt.monto)) \(debt.moneda.rawValue)"
                if let plazo = debt.plazoMeses {
                    context += " (plazo: \(plazo) meses)"
                }
                context += " — Motivo: \(debt.motivo)\n"
            }
        }

        context += "\n=== PRÉSTAMOS OTORGADOS ===\n"
        if prestamoManager.prestamos.isEmpty {
            context += "Sin préstamos registrados.\n"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            for prestamo in prestamoManager.prestamos {
                let estado = prestamo.estaPagado ? "devuelto" : prestamo.estaVencido ? "vencido" : "pendiente"
                context += "- \(prestamo.nombre): \(String(format: "%.2f", prestamo.monto)) \(prestamo.moneda.rawValue) [\(estado)]"
                if let fecha = prestamo.fechaDevolucion {
                    context += " — devolución pactada: \(dateFormatter.string(from: fecha))"
                }
                if !prestamo.motivo.isEmpty {
                    context += " — motivo: \(prestamo.motivo)"
                }
                context += "\n"
            }
            let pendientes = prestamoManager.prestamos.filter { !$0.estaPagado }
            if !pendientes.isEmpty {
                let currencies = Set(pendientes.map(\.moneda))
                for currency in currencies.sorted(by: { $0.rawValue < $1.rawValue }) {
                    let total = pendientes.filter { $0.moneda == currency }.reduce(0) { $0 + $1.monto }
                    context += "Total pendiente \(currency.rawValue): \(String(format: "%.2f", total))\n"
                }
            }
        }

        context += "\n=== METAS DE AHORRO ===\n"
        if savingsManager.savingsGoals.isEmpty {
            context += "Sin metas de ahorro.\n"
        } else {
            for goal in savingsManager.savingsGoals {
                let pct = goal.precioObjetivo > 0 ? (goal.ahorrado / goal.precioObjetivo) * 100 : 0
                context += "- \(goal.nombre): \(String(format: "%.2f", goal.ahorrado))/\(String(format: "%.2f", goal.precioObjetivo)) \(goal.moneda.rawValue) (\(String(format: "%.0f", pct))%)\n"
            }
        }

        context += "\n=== SUSCRIPCIONES ===\n"
        let activeSubscriptions = subscriptionManager.subscriptions.filter(\.isActive)
        let inactiveSubscriptions = subscriptionManager.subscriptions.filter { !$0.isActive }
        if subscriptionManager.subscriptions.isEmpty {
            context += "Sin suscripciones registradas.\n"
        } else {
            if !activeSubscriptions.isEmpty {
                context += "Activas:\n"
                for sub in activeSubscriptions {
                    let amount = sub.userExpenseAmount
                    let shared = sub.isShared ? " (compartida con \(sub.sharedPeopleCount) personas, tu parte: \(String(format: "%.2f", amount)) \(sub.currency.rawValue))" : ""
                    context += "- \(sub.platformName) - \(sub.planName): \(String(format: "%.2f", sub.price)) \(sub.currency.rawValue)\(shared), día de cobro: \(sub.billingDay)\n"
                }
            }
            if !inactiveSubscriptions.isEmpty {
                context += "Canceladas:\n"
                for sub in inactiveSubscriptions {
                    context += "- \(sub.platformName) - \(sub.planName): \(String(format: "%.2f", sub.price)) \(sub.currency.rawValue)\n"
                }
            }
            let currencies = Set(activeSubscriptions.map(\.currency))
            if !currencies.isEmpty {
                context += "Total mensual activo:\n"
                for currency in currencies.sorted(by: { $0.rawValue < $1.rawValue }) {
                    let total = activeSubscriptions.filter { $0.currency == currency }.reduce(0) { $0 + $1.userExpenseAmount }
                    context += "  \(currency.rawValue): \(String(format: "%.2f", total))\n"
                }
            }
        }

        let profile = profileManager.profile
        if !profile.nombre.isEmpty || !profile.situacionFinanciera.isEmpty || !profile.estrategiaFinanciera.isEmpty {
            context += "\n=== PERFIL DEL USUARIO ===\n"
            if !profile.nombre.isEmpty {
                context += "Nombre: \(profile.nombre)\n"
            }
            if !profile.situacionFinanciera.isEmpty {
                context += "Situación financiera: \(profile.situacionFinanciera)\n"
            }
            if !profile.estrategiaFinanciera.isEmpty {
                context += "Estrategia financiera: \(profile.estrategiaFinanciera)\n"
            }
        }

        return context
    }

    private func usdRateContextLine() -> String {
        if let rate = exchangeRateManager.effectiveUsdToCupRate() {
            return "Tasa USD/CUP actual (informal): 1 USD = \(String(format: "%.2f", rate)) CUP"
        }
        return "Tasa USD/CUP actual (informal): sin dato"
    }
}
