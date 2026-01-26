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

    init(
        chatService: ChatService = ChatService(),
        transactionManager: TransactionManager = .shared
    ) {
        self.chatService = chatService
        self.transactionManager = transactionManager
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
            let context = buildTransactionContext()
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
            // Agregar mensaje de error
            let errorMessage = ChatMessage(
                content: "Error al enviar mensaje: \(error.localizedDescription)",
                isUser: false
            )
            messages.append(errorMessage)
        }
    }

    /// Construye el contexto con las transacciones filtradas
    private func buildTransactionContext() -> String {
        var transactions = transactionManager.transactions

        // Filtrar por tipo
        if transactionFilter == .ingresos {
            transactions = transactions.filter { $0.type == .income }
        } else if transactionFilter == .gastos {
            transactions = transactions.filter { $0.type == .expense }
        }

        // Filtrar por periodo de tiempo
        if let startDate = timePeriod.startDate {
            transactions = transactions.filter { $0.date >= startDate }
        }

        // Ordenar por fecha
        transactions.sort { $0.date > $1.date }

        // Formatear contexto
        var context = "=== CONTEXTO DE TRANSACCIONES ===\n"
        context += "Periodo: \(timePeriod.rawValue)\n"
        context += "Tipo: \(transactionFilter.rawValue)\n"
        context += "Total de transacciones: \(transactions.count)\n\n"

        if transactions.isEmpty {
            context += "No hay transacciones en el periodo seleccionado.\n"
        } else {
            context += "TRANSACCIONES:\n"
            for transaction in transactions.prefix(50) { // Limitar a 50 transacciones
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

            // Agregar estadísticas
            let totalIncome = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let totalExpenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

            context += "\nESTADÍSTICAS:\n"
            context += "Total ingresos: $\(String(format: "%.2f", totalIncome))\n"
            context += "Total gastos: $\(String(format: "%.2f", totalExpenses))\n"
            context += "Balance: $\(String(format: "%.2f", totalIncome - totalExpenses))\n"
        }

        return context
    }

    /// Limpia el historial de mensajes
    func clearMessages() {
        messages.removeAll()
    }
}
