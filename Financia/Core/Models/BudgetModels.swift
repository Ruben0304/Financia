import Foundation

struct BudgetAsignaciones: Codable, Equatable {
    var usd: Double?
    var eur: Double?
    var cup: Double?

    func amount(for currency: Currency) -> Double {
        switch currency {
        case .usd: return usd ?? 0
        case .eur: return eur ?? 0
        case .cup: return cup ?? 0
        }
    }

    mutating func setAmount(_ amount: Double?, for currency: Currency) {
        switch currency {
        case .usd: usd = amount
        case .eur: eur = amount
        case .cup: cup = amount
        }
    }
}

struct BudgetCategory: Identifiable, Codable {
    var id: UUID
    var nombre: String
    var descripcion: String?
    var asignaciones: BudgetAsignaciones
    var createdAt: Date

    init(
        id: UUID = UUID(),
        nombre: String,
        descripcion: String? = nil,
        asignaciones: BudgetAsignaciones = BudgetAsignaciones(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.nombre = nombre
        self.descripcion = descripcion
        self.asignaciones = asignaciones
        self.createdAt = createdAt
    }
}
