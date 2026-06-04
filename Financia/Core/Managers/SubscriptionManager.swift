import Foundation
import Combine
import SwiftData

final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var subscriptions: [Subscription] = []
    @Published private(set) var templates: [SubscriptionTemplate] = []

    private let container = PersistenceManager.shared.container
    private let notificationManager = SubscriptionNotificationManager.shared

    private init() {
        loadData()
        scheduleNotifications()
    }

    func loadData() {
        let context = ModelContext(container)

        do {
            let subscriptionEntities = try context.fetch(FetchDescriptor<SubscriptionEntity>())
            subscriptions = subscriptionEntities.map(Self.makeSubscription).sorted { $0.createdAt > $1.createdAt }

            let templateEntities = try context.fetch(FetchDescriptor<SubscriptionTemplateEntity>())
            templates = templateEntities.map(Self.makeTemplate).sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading subscriptions: \(error)")
            subscriptions = []
            templates = []
        }
    }

    func addSubscription(_ subscription: Subscription) {
        var newSubscription = subscription
        let now = Date()
        newSubscription.createdAt = now
        newSubscription.updatedAt = now

        subscriptions.insert(newSubscription, at: 0)
        saveSubscriptions()
        upsertTemplate(from: newSubscription)
        scheduleNotifications()
    }

    func updateSubscription(_ subscription: Subscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }

        var updated = subscription
        updated.updatedAt = Date()
        subscriptions[index] = updated
        saveSubscriptions()
        upsertTemplate(from: updated)
        scheduleNotifications()
    }

    func deleteSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveSubscriptions()
        scheduleNotifications()
    }

    func cancelSubscription(_ subscription: Subscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }

        var updated = subscriptions[index]
        updated.isActive = false
        updated.updatedAt = Date()

        subscriptions[index] = updated
        saveSubscriptions()
        upsertTemplate(from: updated)
        scheduleNotifications()
    }

    func createSubscription(from template: SubscriptionTemplate) {
        let subscription = Subscription(
            platformName: template.platformName,
            planName: template.planName,
            price: template.price,
            currency: template.currency,
            logoSystemName: template.logoSystemName,
            isShared: template.isShared,
            sharedPeopleCount: template.sharedPeopleCount,
            splitEqually: template.splitEqually,
            personalShareAmount: template.personalShareAmount,
            billingDay: template.billingDay,
            isActive: true
        )
        addSubscription(subscription)
    }

    func deleteTemplate(_ template: SubscriptionTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    @discardableResult
    func registerAsExpense(_ subscription: Subscription) -> Result<Void, SubscriptionExpenseError> {
        guard subscription.isActive else {
            return .failure(.subscriptionInactive)
        }

        let walletManager = WalletManager.shared
        guard let wallet = walletManager.wallets.first(where: { $0.currency == subscription.currency }) ?? walletManager.wallets.first else {
            return .failure(.missingWallet)
        }

        let categoryManager = CategoryManager.shared
        let defaultCategory = categoryManager.expenseCategories.first
        let entertainmentCategory = categoryManager.expenseCategories.first {
            $0.name.lowercased().contains("entreten")
        }
        let category = entertainmentCategory ?? defaultCategory

        guard
            let category,
            let subcategory = category.subcategories.first(where: { $0.name.lowercased().contains("suscrip") })
                ?? category.subcategories.first
        else {
            return .failure(.missingCategory)
        }

        let amount = subscription.userExpenseAmount
        guard amount > 0 else {
            return .failure(.invalidAmount)
        }

        let description = "\(subscription.platformName) - \(subscription.planName)"

        let transaction = Transaction(
            type: .expense,
            amount: amount,
            date: Date(),
            categoryId: category.id,
            categoryName: category.name,
            subcategoryId: subcategory.id,
            subcategoryName: subcategory.name,
            description: description,
            walletId: wallet.id
        )

        TransactionManager.shared.addTransaction(transaction)
        WalletManager.shared.syncWalletBalance(for: wallet.id)
        ExpenseAnalysisManager.shared.analyzeExpense(transaction: transaction)

        return .success(())
    }

    private func saveSubscriptions() {
        let context = ModelContext(container)

        do {
            let existing = try context.fetch(FetchDescriptor<SubscriptionEntity>())
            existing.forEach { context.delete($0) }
            subscriptions.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving subscriptions: \(error)")
        }
    }

    private func saveTemplates() {
        let context = ModelContext(container)

        do {
            let existing = try context.fetch(FetchDescriptor<SubscriptionTemplateEntity>())
            existing.forEach { context.delete($0) }
            templates.map(Self.makeTemplateEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving subscription templates: \(error)")
        }
    }

    private func upsertTemplate(from subscription: Subscription) {
        let normalizedPlatform = subscription.platformName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPlan = subscription.planName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let index = templates.firstIndex(where: {
            $0.platformName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedPlatform &&
            $0.planName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedPlan
        }) {
            var updated = templates[index]
            updated.price = subscription.price
            updated.currency = subscription.currency
            updated.logoSystemName = subscription.logoSystemName
            updated.isShared = subscription.isShared
            updated.sharedPeopleCount = subscription.sharedPeopleCount
            updated.splitEqually = subscription.splitEqually
            updated.personalShareAmount = subscription.personalShareAmount
            updated.billingDay = subscription.billingDay
            updated.updatedAt = Date()
            templates[index] = updated
        } else {
            let template = SubscriptionTemplate(
                platformName: subscription.platformName,
                planName: subscription.planName,
                price: subscription.price,
                currency: subscription.currency,
                logoSystemName: subscription.logoSystemName,
                isShared: subscription.isShared,
                sharedPeopleCount: subscription.sharedPeopleCount,
                splitEqually: subscription.splitEqually,
                personalShareAmount: subscription.personalShareAmount,
                billingDay: subscription.billingDay
            )
            templates.insert(template, at: 0)
        }

        saveTemplates()
    }

    private func scheduleNotifications() {
        notificationManager.scheduleNotifications(for: subscriptions)
    }

    private static func makeSubscription(from entity: SubscriptionEntity) -> Subscription {
        Subscription(
            id: entity.id,
            platformName: entity.platformName,
            planName: entity.planName,
            price: entity.price,
            currency: Currency(rawValue: entity.currencyRaw) ?? .cup,
            logoSystemName: entity.logoSystemName,
            isShared: entity.isShared,
            sharedPeopleCount: entity.sharedPeopleCount,
            splitEqually: entity.splitEqually,
            personalShareAmount: entity.personalShareAmount,
            billingDay: entity.billingDay,
            isActive: entity.isActive,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private static func makeEntity(from subscription: Subscription) -> SubscriptionEntity {
        SubscriptionEntity(
            id: subscription.id,
            platformName: subscription.platformName,
            planName: subscription.planName,
            price: subscription.price,
            currencyRaw: subscription.currency.rawValue,
            logoSystemName: subscription.logoSystemName,
            isShared: subscription.isShared,
            sharedPeopleCount: subscription.sharedPeopleCount,
            splitEqually: subscription.splitEqually,
            personalShareAmount: subscription.personalShareAmount,
            billingDay: subscription.billingDay,
            isActive: subscription.isActive,
            createdAt: subscription.createdAt,
            updatedAt: subscription.updatedAt
        )
    }

    private static func makeTemplate(from entity: SubscriptionTemplateEntity) -> SubscriptionTemplate {
        SubscriptionTemplate(
            id: entity.id,
            platformName: entity.platformName,
            planName: entity.planName,
            price: entity.price,
            currency: Currency(rawValue: entity.currencyRaw) ?? .cup,
            logoSystemName: entity.logoSystemName,
            isShared: entity.isShared,
            sharedPeopleCount: entity.sharedPeopleCount,
            splitEqually: entity.splitEqually,
            personalShareAmount: entity.personalShareAmount,
            billingDay: entity.billingDay,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private static func makeTemplateEntity(from template: SubscriptionTemplate) -> SubscriptionTemplateEntity {
        SubscriptionTemplateEntity(
            id: template.id,
            platformName: template.platformName,
            planName: template.planName,
            price: template.price,
            currencyRaw: template.currency.rawValue,
            logoSystemName: template.logoSystemName,
            isShared: template.isShared,
            sharedPeopleCount: template.sharedPeopleCount,
            splitEqually: template.splitEqually,
            personalShareAmount: template.personalShareAmount,
            billingDay: template.billingDay,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt
        )
    }
}

enum SubscriptionExpenseError: LocalizedError {
    case subscriptionInactive
    case missingWallet
    case missingCategory
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .subscriptionInactive:
            return "La suscripción está cancelada."
        case .missingWallet:
            return "No hay carteras disponibles para registrar el gasto."
        case .missingCategory:
            return "No se encontró una categoría de gasto para suscripciones."
        case .invalidAmount:
            return "El monto de gasto calculado no es válido."
        }
    }
}
