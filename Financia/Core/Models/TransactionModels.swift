import Foundation

// Modelo para el lugar de la transacción
struct Lugar: Identifiable, Codable, Hashable {
    var id: UUID
    var nombre: String
    var visualKeywords: [String]?

    init(
        id: UUID = UUID(),
        nombre: String,
        visualKeywords: [String]? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.visualKeywords = visualKeywords
    }
}

// Modelo para items individuales de un vale/recibo
struct SubItem: Identifiable, Codable, Hashable {
    var id: UUID
    var nombre: String
    var cantidad: Int
    var precio: Double?

    init(
        id: UUID = UUID(),
        nombre: String,
        cantidad: Int,
        precio: Double? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.cantidad = cantidad
        self.precio = precio
    }
}

// Modelo principal para transacciones persistentes
struct Transaction: Identifiable, Codable, Hashable {
    var id: UUID
    var type: TransactionType
    var amount: Double
    var date: Date
    var categoryId: UUID
    var categoryName: String
    var subcategoryId: UUID
    var subcategoryName: String
    var description: String
    var walletId: UUID
    var createdAt: Date
    var lugar: Lugar?
    var subitems: [SubItem]?

    init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Double,
        date: Date,
        categoryId: UUID,
        categoryName: String,
        subcategoryId: UUID,
        subcategoryName: String,
        description: String,
        walletId: UUID,
        createdAt: Date = Date(),
        lugar: Lugar? = nil,
        subitems: [SubItem]? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.date = date
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.subcategoryId = subcategoryId
        self.subcategoryName = subcategoryName
        self.description = description
        self.walletId = walletId
        self.createdAt = createdAt
        self.lugar = lugar
        self.subitems = subitems
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"

    var displayName: String {
        switch self {
        case .income: return "Ingreso"
        case .expense: return "Gasto"
        }
    }
}
