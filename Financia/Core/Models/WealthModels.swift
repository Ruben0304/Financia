import Foundation

struct MonthlyEstimate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var currency: Currency
    var amount: Double
    var dayOfMonth: Int

    init(
        id: UUID = UUID(),
        currency: Currency,
        amount: Double,
        dayOfMonth: Int = 1
    ) {
        self.id = id
        self.currency = currency
        self.amount = amount
        self.dayOfMonth = min(max(dayOfMonth, 1), 31)
    }

    enum CodingKeys: String, CodingKey {
        case id, currency, amount, dayOfMonth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        currency = try container.decode(Currency.self, forKey: .currency)
        amount = try container.decode(Double.self, forKey: .amount)
        dayOfMonth = min(max(try container.decodeIfPresent(Int.self, forKey: .dayOfMonth) ?? 1, 1), 31)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(currency, forKey: .currency)
        try container.encode(amount, forKey: .amount)
        try container.encode(dayOfMonth, forKey: .dayOfMonth)
    }
}

struct Asset: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var monthlyEstimates: [MonthlyEstimate]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        monthlyEstimates: [MonthlyEstimate] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.monthlyEstimates = monthlyEstimates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Job: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var monthlyEstimates: [MonthlyEstimate]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        monthlyEstimates: [MonthlyEstimate] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.monthlyEstimates = monthlyEstimates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Liability: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var monthlyEstimates: [MonthlyEstimate]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        monthlyEstimates: [MonthlyEstimate] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.monthlyEstimates = monthlyEstimates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
