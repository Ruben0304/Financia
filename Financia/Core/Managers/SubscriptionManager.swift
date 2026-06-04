import Foundation
import Combine
import SwiftData

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var subscriptions: [Subscription] = []
    @Published private(set) var templates: [SubscriptionTemplate] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let subsEndpoint = "/subscriptions/"
    private let templatesEndpoint = "/subscription-templates/"
    private let notificationManager = SubscriptionNotificationManager.shared

    private init() {
        loadFromCache()
        Task {
            await refreshFromBackend()
            scheduleNotifications()
        }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            subscriptions = try context.fetch(FetchDescriptor<SubscriptionEntity>())
                .map(Self.makeSubscription).sorted { $0.createdAt > $1.createdAt }
            templates = try context.fetch(FetchDescriptor<SubscriptionTemplateEntity>())
                .map(Self.makeTemplate).sorted { $0.updatedAt > $1.updatedAt }
        } catch { print("SubscriptionManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        // Sequential awaits (rather than `async let`) — from a
        // @MainActor context, `async let` makes Swift treat the model's
        // Decodable conformance as MainActor-isolated, which then can't
        // be used by the non-isolated URLSession decode pipeline.
        do {
            let subs: [Subscription] = try await api.getList(subsEndpoint)
            let tpls: [SubscriptionTemplate] = try await api.getList(templatesEndpoint)
            subscriptions = subs.sorted { $0.createdAt > $1.createdAt }
            templates = tpls.sorted { $0.updatedAt > $1.updatedAt }
            replaceSubsCache(with: subscriptions)
            replaceTemplatesCache(with: templates)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func loadData() { Task { await refreshFromBackend() } }

    // MARK: - Subscriptions CRUD

    func addSubscription(_ subscription: Subscription) {
        var new = subscription
        let now = Date()
        new.createdAt = now
        new.updatedAt = now
        subscriptions.insert(new, at: 0)
        insertSubCache(new)
        print("📝 [SubMgr] addSubscription \(new.platformName)/\(new.planName) id=\(new.id.uuidString.prefix(8))")
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.post(self.subsEndpoint, body: new)
                print("✅ [SubMgr] saved subscription \(new.platformName) to backend")
            } catch {
                print("❌ [SubMgr] FAILED save subscription \(new.platformName): \(error.localizedDescription)")
                self.subscriptions.removeAll { $0.id == new.id }
                self.deleteSubCache(id: new.id)
                self.lastError = error.localizedDescription
            }
        }
        upsertTemplate(from: new)
        scheduleNotifications()
    }

    func updateSubscription(_ subscription: Subscription) {
        guard let i = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        let previous = subscriptions[i]
        var updated = subscription
        updated.updatedAt = Date()
        subscriptions[i] = updated
        insertSubCache(updated)
        print("📝 [SubMgr] updateSubscription \(updated.platformName) id=\(updated.id.uuidString.prefix(8))")
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.put("\(self.subsEndpoint)\(updated.id.uuidString)", body: updated)
                print("✅ [SubMgr] updated subscription \(updated.platformName) on backend")
            } catch {
                print("❌ [SubMgr] FAILED update subscription \(updated.platformName): \(error.localizedDescription)")
                if let j = self.subscriptions.firstIndex(where: { $0.id == previous.id }) {
                    self.subscriptions[j] = previous
                    self.insertSubCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
        upsertTemplate(from: updated)
        scheduleNotifications()
    }

    func deleteSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        deleteSubCache(id: subscription.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.subsEndpoint)\(subscription.id.uuidString)") }
            catch {
                self.subscriptions.append(subscription)
                self.insertSubCache(subscription)
                self.lastError = error.localizedDescription
            }
        }
        scheduleNotifications()
    }

    func cancelSubscription(_ subscription: Subscription) {
        guard let i = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        var updated = subscriptions[i]
        updated.isActive = false
        updated.updatedAt = Date()
        updateSubscription(updated)
    }

    func createSubscription(from template: SubscriptionTemplate) {
        let subscription = Subscription(
            platformName: template.platformName, planName: template.planName,
            price: template.price, currency: template.currency,
            logoImageData: template.logoImageData, logoURLString: template.logoURLString,
            logoImageFormat: template.logoImageFormat,
            isShared: template.isShared, sharedPeopleCount: template.sharedPeopleCount,
            splitEqually: template.splitEqually, personalShareAmount: template.personalShareAmount,
            billingDay: template.billingDay, isActive: true
        )
        addSubscription(subscription)
    }

    func deleteTemplate(_ template: SubscriptionTemplate) {
        templates.removeAll { $0.id == template.id }
        deleteTemplateCache(id: template.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.templatesEndpoint)\(template.id.uuidString)") }
            catch {
                self.templates.append(template)
                self.insertTemplateCache(template)
                self.lastError = error.localizedDescription
            }
        }
    }

    @discardableResult
    func registerAsExpense(_ subscription: Subscription) -> Result<Void, SubscriptionExpenseError> {
        guard subscription.isActive else { return .failure(.subscriptionInactive) }

        let walletManager = WalletManager.shared
        guard let wallet = walletManager.wallets.first(where: { $0.currency == subscription.currency }) ?? walletManager.wallets.first else {
            return .failure(.missingWallet)
        }
        let categoryManager = CategoryManager.shared
        let defaultCategory = categoryManager.expenseCategories.first
        let entertainmentCategory = categoryManager.expenseCategories.first { $0.name.lowercased().contains("entreten") }
        let category = entertainmentCategory ?? defaultCategory
        guard let category,
              let subcategory = category.subcategories.first(where: { $0.name.lowercased().contains("suscrip") }) ?? category.subcategories.first else {
            return .failure(.missingCategory)
        }
        let amount = subscription.userExpenseAmount
        guard amount > 0 else { return .failure(.invalidAmount) }
        let description = "\(subscription.platformName) - \(subscription.planName)"
        let transaction = Transaction(
            type: .expense, amount: amount, date: Date(),
            categoryId: category.id, categoryName: category.name,
            subcategoryId: subcategory.id, subcategoryName: subcategory.name,
            description: description, walletId: wallet.id
        )
        TransactionManager.shared.addTransaction(transaction)
        ExpenseAnalysisManager.shared.analyzeExpense(transaction: transaction)
        return .success(())
    }

    // MARK: - Templates (server-side too)

    private func upsertTemplate(from subscription: Subscription) {
        let normalizedPlatform = subscription.platformName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPlan = subscription.planName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let i = templates.firstIndex(where: {
            $0.platformName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedPlatform &&
            $0.planName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedPlan
        }) {
            var updated = templates[i]
            updated.price = subscription.price
            updated.currency = subscription.currency
            updated.logoImageData = subscription.logoImageData
            updated.logoURLString = subscription.logoURLString
            updated.logoImageFormat = subscription.logoImageFormat
            updated.isShared = subscription.isShared
            updated.sharedPeopleCount = subscription.sharedPeopleCount
            updated.splitEqually = subscription.splitEqually
            updated.personalShareAmount = subscription.personalShareAmount
            updated.billingDay = subscription.billingDay
            updated.updatedAt = Date()
            templates[i] = updated
            insertTemplateCache(updated)
            Task { [weak self] in
                guard let self else { return }
                do { let _: Empty = try await self.api.put("\(self.templatesEndpoint)\(updated.id.uuidString)", body: updated) }
                catch {
                    print("❌ [SubMgr] FAILED update template \(updated.platformName): \(error.localizedDescription)")
                    self.lastError = error.localizedDescription
                }
            }
        } else {
            let template = SubscriptionTemplate(
                platformName: subscription.platformName, planName: subscription.planName,
                price: subscription.price, currency: subscription.currency,
                logoImageData: subscription.logoImageData, logoURLString: subscription.logoURLString,
                logoImageFormat: subscription.logoImageFormat,
                isShared: subscription.isShared, sharedPeopleCount: subscription.sharedPeopleCount,
                splitEqually: subscription.splitEqually, personalShareAmount: subscription.personalShareAmount,
                billingDay: subscription.billingDay
            )
            templates.insert(template, at: 0)
            insertTemplateCache(template)
            Task { [weak self] in
                guard let self else { return }
                do { let _: Empty = try await self.api.post(self.templatesEndpoint, body: template) }
                catch {
                    print("❌ [SubMgr] FAILED create template \(template.platformName): \(error.localizedDescription)")
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func scheduleNotifications() {
        let current = subscriptions
        Task { @MainActor in notificationManager.scheduleNotifications(for: current) }
    }

    // MARK: - Caches

    private func replaceSubsCache(with items: [Subscription]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<SubscriptionEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("SubscriptionManager subs cache replace failed: \(error)") }
    }
    private func replaceTemplatesCache(with items: [SubscriptionTemplate]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<SubscriptionTemplateEntity>()).forEach { context.delete($0) }
            items.map(Self.makeTemplateEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("SubscriptionManager template cache replace failed: \(error)") }
    }
    private func insertSubCache(_ s: Subscription) {
        let context = ModelContext(container); let id = s.id
        do {
            try context.fetch(FetchDescriptor<SubscriptionEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: s))
            try context.save()
        } catch {}
    }
    private func deleteSubCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<SubscriptionEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            try context.save()
        } catch {}
    }
    private func insertTemplateCache(_ t: SubscriptionTemplate) {
        let context = ModelContext(container); let id = t.id
        do {
            try context.fetch(FetchDescriptor<SubscriptionTemplateEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            context.insert(Self.makeTemplateEntity(from: t))
            try context.save()
        } catch {}
    }
    private func deleteTemplateCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<SubscriptionTemplateEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            try context.save()
        } catch {}
    }

    // MARK: - Bridges

    private static func makeSubscription(from e: SubscriptionEntity) -> Subscription {
        Subscription(
            id: e.id, platformName: e.platformName, planName: e.planName,
            price: e.price, currency: Currency(rawValue: e.currencyRaw) ?? .cup,
            logoImageData: e.logoImageData, logoURLString: e.logoURLString, logoImageFormat: e.logoImageFormat,
            isShared: e.isShared, sharedPeopleCount: e.sharedPeopleCount,
            splitEqually: e.splitEqually, personalShareAmount: e.personalShareAmount,
            billingDay: e.billingDay, isActive: e.isActive, createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
    private static func makeEntity(from s: Subscription) -> SubscriptionEntity {
        SubscriptionEntity(
            id: s.id, platformName: s.platformName, planName: s.planName,
            price: s.price, currencyRaw: s.currency.rawValue,
            logoImageData: s.logoImageData, logoURLString: s.logoURLString, logoImageFormat: s.logoImageFormat,
            isShared: s.isShared, sharedPeopleCount: s.sharedPeopleCount,
            splitEqually: s.splitEqually, personalShareAmount: s.personalShareAmount,
            billingDay: s.billingDay, isActive: s.isActive, createdAt: s.createdAt, updatedAt: s.updatedAt
        )
    }
    private static func makeTemplate(from e: SubscriptionTemplateEntity) -> SubscriptionTemplate {
        SubscriptionTemplate(
            id: e.id, platformName: e.platformName, planName: e.planName,
            price: e.price, currency: Currency(rawValue: e.currencyRaw) ?? .cup,
            logoImageData: e.logoImageData, logoURLString: e.logoURLString, logoImageFormat: e.logoImageFormat,
            isShared: e.isShared, sharedPeopleCount: e.sharedPeopleCount,
            splitEqually: e.splitEqually, personalShareAmount: e.personalShareAmount,
            billingDay: e.billingDay, createdAt: e.createdAt, updatedAt: e.updatedAt
        )
    }
    private static func makeTemplateEntity(from t: SubscriptionTemplate) -> SubscriptionTemplateEntity {
        SubscriptionTemplateEntity(
            id: t.id, platformName: t.platformName, planName: t.planName,
            price: t.price, currencyRaw: t.currency.rawValue,
            logoImageData: t.logoImageData, logoURLString: t.logoURLString, logoImageFormat: t.logoImageFormat,
            isShared: t.isShared, sharedPeopleCount: t.sharedPeopleCount,
            splitEqually: t.splitEqually, personalShareAmount: t.personalShareAmount,
            billingDay: t.billingDay, createdAt: t.createdAt, updatedAt: t.updatedAt
        )
    }
}

enum SubscriptionExpenseError: LocalizedError {
    case subscriptionInactive, missingWallet, missingCategory, invalidAmount
    var errorDescription: String? {
        switch self {
        case .subscriptionInactive: return "La suscripción está cancelada."
        case .missingWallet: return "No hay carteras disponibles para registrar el gasto."
        case .missingCategory: return "No se encontró una categoría de gasto para suscripciones."
        case .invalidAmount: return "El monto de gasto calculado no es válido."
        }
    }
}
