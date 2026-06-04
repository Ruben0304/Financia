import Foundation

struct Subscription: Identifiable, Codable, Hashable {
    var id: UUID
    var platformName: String
    var planName: String
    var price: Double
    var currency: Currency
    var logoSystemName: String
    var isShared: Bool
    var sharedPeopleCount: Int
    var splitEqually: Bool
    var personalShareAmount: Double?
    var billingDay: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        platformName: String,
        planName: String,
        price: Double,
        currency: Currency,
        logoSystemName: String,
        isShared: Bool,
        sharedPeopleCount: Int,
        splitEqually: Bool = true,
        personalShareAmount: Double? = nil,
        billingDay: Int,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.platformName = platformName
        self.planName = planName
        self.price = price
        self.currency = currency
        self.logoSystemName = logoSystemName
        self.isShared = isShared
        self.sharedPeopleCount = max(1, sharedPeopleCount)
        self.splitEqually = splitEqually
        self.personalShareAmount = personalShareAmount
        self.billingDay = min(max(1, billingDay), 31)
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var userExpenseAmount: Double {
        guard isShared else { return price }
        if splitEqually {
            return price / Double(max(1, sharedPeopleCount))
        }
        guard let personalShareAmount else { return price }
        return min(max(0, personalShareAmount), price)
    }
}

struct SubscriptionTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var platformName: String
    var planName: String
    var price: Double
    var currency: Currency
    var logoSystemName: String
    var isShared: Bool
    var sharedPeopleCount: Int
    var splitEqually: Bool
    var personalShareAmount: Double?
    var billingDay: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        platformName: String,
        planName: String,
        price: Double,
        currency: Currency,
        logoSystemName: String,
        isShared: Bool,
        sharedPeopleCount: Int,
        splitEqually: Bool = true,
        personalShareAmount: Double? = nil,
        billingDay: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.platformName = platformName
        self.planName = planName
        self.price = price
        self.currency = currency
        self.logoSystemName = logoSystemName
        self.isShared = isShared
        self.sharedPeopleCount = max(1, sharedPeopleCount)
        self.splitEqually = splitEqually
        self.personalShareAmount = personalShareAmount
        self.billingDay = min(max(1, billingDay), 31)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
