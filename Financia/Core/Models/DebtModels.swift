import Foundation

struct Debt: Identifiable, Codable, Hashable {
    var id: UUID
    var nombre: String
    var motivo: String
    var monto: Double
    var moneda: Currency
    var plazoMeses: Int?
    var createdAt: Date
    var lastEstimate: DebtEstimateResponse?
    var montoOriginal: Double
    var pagos: [DebtPayment]

    init(
        id: UUID = UUID(),
        nombre: String,
        motivo: String,
        monto: Double,
        moneda: Currency,
        plazoMeses: Int? = nil,
        createdAt: Date = Date(),
        lastEstimate: DebtEstimateResponse? = nil,
        montoOriginal: Double? = nil,
        pagos: [DebtPayment] = []
    ) {
        self.id = id
        self.nombre = nombre
        self.motivo = motivo
        self.monto = monto
        self.moneda = moneda
        self.plazoMeses = plazoMeses
        self.createdAt = createdAt
        self.lastEstimate = lastEstimate
        self.montoOriginal = montoOriginal ?? monto
        self.pagos = pagos
    }

    enum CodingKeys: String, CodingKey {
        case id, nombre, motivo, monto, moneda, plazoMeses, createdAt, lastEstimate, montoOriginal, pagos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        nombre = try container.decode(String.self, forKey: .nombre)
        motivo = try container.decode(String.self, forKey: .motivo)
        monto = try container.decode(Double.self, forKey: .monto)
        moneda = try container.decode(Currency.self, forKey: .moneda)
        plazoMeses = try container.decodeIfPresent(Int.self, forKey: .plazoMeses)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastEstimate = try container.decodeIfPresent(DebtEstimateResponse.self, forKey: .lastEstimate)
        montoOriginal = try container.decodeIfPresent(Double.self, forKey: .montoOriginal) ?? monto
        pagos = try container.decodeIfPresent([DebtPayment].self, forKey: .pagos) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(nombre, forKey: .nombre)
        try container.encode(motivo, forKey: .motivo)
        try container.encode(monto, forKey: .monto)
        try container.encode(moneda, forKey: .moneda)
        try container.encode(plazoMeses, forKey: .plazoMeses)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastEstimate, forKey: .lastEstimate)
        try container.encode(montoOriginal, forKey: .montoOriginal)
        try container.encode(pagos, forKey: .pagos)
    }
}

struct DebtPayment: Identifiable, Codable, Hashable {
    var id: UUID
    var amount: Double
    var date: Date
    var walletId: UUID

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        walletId: UUID
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.walletId = walletId
    }
}

// MARK: - Loan Models

struct Prestamo: Identifiable, Codable, Hashable {
    var id: UUID
    var nombre: String          // A quién se prestó
    var motivo: String
    var monto: Double           // Monto pendiente
    var moneda: Currency
    var fechaPrestamo: Date
    var fechaDevolucion: Date?  // Fecha pactada de devolución
    var montoOriginal: Double
    var cobros: [PrestamoCobro]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        nombre: String,
        motivo: String,
        monto: Double,
        moneda: Currency,
        fechaPrestamo: Date = Date(),
        fechaDevolucion: Date? = nil,
        montoOriginal: Double? = nil,
        cobros: [PrestamoCobro] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.nombre = nombre
        self.motivo = motivo
        self.monto = monto
        self.moneda = moneda
        self.fechaPrestamo = fechaPrestamo
        self.fechaDevolucion = fechaDevolucion
        self.montoOriginal = montoOriginal ?? monto
        self.cobros = cobros
        self.createdAt = createdAt
    }

    var estaVencido: Bool {
        guard let fecha = fechaDevolucion else { return false }
        return Date() > fecha && monto > 0
    }

    var estaPagado: Bool { monto <= 0 }
}

struct PrestamoCobro: Identifiable, Codable, Hashable {
    var id: UUID
    var amount: Double
    var date: Date
    var walletId: UUID

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        walletId: UUID
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.walletId = walletId
    }
}

struct DebtEstimateRequest: Codable {
    let prompt: String
}

struct DebtEstimateResponse: Codable, Hashable {
    let moneda: String
    let caracterizacion: String
    let escenarios: [DebtScenario]
    let mensaje: String
}

struct DebtScenario: Codable, Hashable {
    let escenario: String
    let diasPromedio: Int
    let pagoMensual: Double
}
