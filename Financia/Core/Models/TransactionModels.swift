import Foundation

// Modelo para el lugar de la transacción
struct Lugar: Identifiable, Codable, Hashable {
    var id: UUID
    var nombre: String
    var visualKeywords: [String]?
    var backendId: String?

    init(
        id: UUID = UUID(),
        nombre: String,
        visualKeywords: [String]? = nil,
        backendId: String? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.visualKeywords = visualKeywords
        self.backendId = backendId
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

// Datos de un cambio de divisa: a qué tasa se hizo, para estadística posterior.
struct CambioDivisa: Codable, Hashable {
    var tasa: Double            // 1 monedaOrigen = tasa monedaDestino
    var monedaOrigen: String
    var monedaDestino: String
    var montoOrigen: Double
    var montoDestino: Double

    init(
        tasa: Double,
        monedaOrigen: String,
        monedaDestino: String,
        montoOrigen: Double,
        montoDestino: Double
    ) {
        self.tasa = tasa
        self.monedaOrigen = monedaOrigen
        self.monedaDestino = monedaDestino
        self.montoOrigen = montoOrigen
        self.montoDestino = montoDestino
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
    var assetId: UUID?
    var jobId: UUID?
    var liabilityId: UUID?
    var cambio: CambioDivisa?

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
        subitems: [SubItem]? = nil,
        assetId: UUID? = nil,
        jobId: UUID? = nil,
        liabilityId: UUID? = nil,
        cambio: CambioDivisa? = nil
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
        self.assetId = assetId
        self.jobId = jobId
        self.liabilityId = liabilityId
        self.cambio = cambio
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
