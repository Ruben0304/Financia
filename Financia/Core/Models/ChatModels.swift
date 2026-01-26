import Foundation

// Modelo de mensaje en el chat
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// Tipos de transacciones para incluir en el chat
enum TransactionFilter: String, CaseIterable {
    case ingresos = "Ingresos"
    case gastos = "Gastos"
    case ambos = "Ambos"

    var includeIncome: Bool {
        return self == .ingresos || self == .ambos
    }

    var includeExpenses: Bool {
        return self == .gastos || self == .ambos
    }
}

// Periodos de tiempo para filtrar transacciones
enum TimePeriod: String, CaseIterable {
    case week = "Última semana"
    case month = "Último mes"
    case threeMonths = "Últimos 3 meses"
    case sixMonths = "Últimos 6 meses"
    case year = "Último año"
    case all = "Todo"

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .all:
            return nil
        }
    }
}
