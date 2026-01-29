import Foundation

struct MonthlyEstimate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var currency: Currency
    var amount: Double
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
