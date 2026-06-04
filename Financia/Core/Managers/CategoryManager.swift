import Foundation
import Combine
import SwiftData

@MainActor
class CategoryManager: ObservableObject {

    static let shared = CategoryManager()

    @Published var incomeCategories: [TransactionCategory] = []
    @Published var expenseCategories: [TransactionCategory] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let incomeEndpoint = "/categories/income/"
    private let expenseEndpoint = "/categories/expense/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            let entities = try context.fetch(FetchDescriptor<CategoryEntity>())
            incomeCategories = entities.filter(\.isIncome).map(Self.makeCategory(from:))
            expenseCategories = entities.filter { !$0.isIncome }.map(Self.makeCategory(from:))
        } catch {
            print("CategoryManager cache read failed: \(error)")
        }
    }

    func refreshFromBackend() async {
        do {
            let income: [TransactionCategory] = try await api.getList(incomeEndpoint)
            let expense: [TransactionCategory] = try await api.getList(expenseEndpoint)
            incomeCategories = income
            expenseCategories = expense
            replaceCache(income: income, expense: expense)

            if incomeCategories.isEmpty {
                CategoriesData.incomeCategories.forEach { addIncomeCategory($0) }
            }
            if expenseCategories.isEmpty {
                CategoriesData.expenseCategories.forEach { addExpenseCategory($0) }
            }
        } catch APIError.networkUnavailable {
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadCategories() { Task { await refreshFromBackend() } }

    // MARK: - Income CRUD

    func addIncomeCategory(_ category: TransactionCategory) {
        incomeCategories.append(category)
        insertCache(category, isIncome: true)
        Task { [weak self] in
            guard let self else { return }
            do {
                // Use Empty to skip response decoding — a decode error must not
                // roll back a category that the backend already persisted.
                let _: Empty = try await self.api.post(self.incomeEndpoint, body: category)
            } catch {
                self.incomeCategories.removeAll { $0.id == category.id }
                self.deleteCache(id: category.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateIncomeCategory(_ category: TransactionCategory) {
        guard let i = incomeCategories.firstIndex(where: { $0.id == category.id }) else { return }
        let previous = incomeCategories[i]
        incomeCategories[i] = category
        insertCache(category, isIncome: true)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.put("\(self.incomeEndpoint)\(category.id.uuidString)", body: category)
            } catch {
                if let j = self.incomeCategories.firstIndex(where: { $0.id == previous.id }) {
                    self.incomeCategories[j] = previous
                    self.insertCache(previous, isIncome: true)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteIncomeCategory(_ category: TransactionCategory) {
        incomeCategories.removeAll { $0.id == category.id }
        deleteCache(id: category.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.incomeEndpoint)\(category.id.uuidString)") }
            catch {
                self.incomeCategories.append(category)
                self.insertCache(category, isIncome: true)
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Expense CRUD

    func addExpenseCategory(_ category: TransactionCategory) {
        expenseCategories.append(category)
        insertCache(category, isIncome: false)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.post(self.expenseEndpoint, body: category)
            } catch {
                self.expenseCategories.removeAll { $0.id == category.id }
                self.deleteCache(id: category.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateExpenseCategory(_ category: TransactionCategory) {
        guard let i = expenseCategories.firstIndex(where: { $0.id == category.id }) else { return }
        let previous = expenseCategories[i]
        expenseCategories[i] = category
        insertCache(category, isIncome: false)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await self.api.put("\(self.expenseEndpoint)\(category.id.uuidString)", body: category)
            } catch {
                if let j = self.expenseCategories.firstIndex(where: { $0.id == previous.id }) {
                    self.expenseCategories[j] = previous
                    self.insertCache(previous, isIncome: false)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteExpenseCategory(_ category: TransactionCategory) {
        expenseCategories.removeAll { $0.id == category.id }
        deleteCache(id: category.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.expenseEndpoint)\(category.id.uuidString)") }
            catch {
                self.expenseCategories.append(category)
                self.insertCache(category, isIncome: false)
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Subcategories (delegates to update)

    func addSubcategory(_ subcategory: Subcategory, to category: TransactionCategory, isIncome: Bool) {
        if isIncome {
            if let i = incomeCategories.firstIndex(where: { $0.id == category.id }) {
                incomeCategories[i].subcategories.append(subcategory)
                updateIncomeCategory(incomeCategories[i])
            }
        } else {
            if let i = expenseCategories.firstIndex(where: { $0.id == category.id }) {
                expenseCategories[i].subcategories.append(subcategory)
                updateExpenseCategory(expenseCategories[i])
            }
        }
    }

    // MARK: - Queries

    func category(withId id: UUID, isIncome: Bool) -> TransactionCategory? {
        (isIncome ? incomeCategories : expenseCategories).first { $0.id == id }
    }

    func subcategory(withId id: UUID, in category: TransactionCategory) -> Subcategory? {
        category.subcategories.first { $0.id == id }
    }

    // MARK: - Cache

    private func replaceCache(income: [TransactionCategory], expense: [TransactionCategory]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<CategoryEntity>()).forEach { context.delete($0) }
            income.map { Self.makeEntity(from: $0, isIncome: true) }.forEach { context.insert($0) }
            expense.map { Self.makeEntity(from: $0, isIncome: false) }.forEach { context.insert($0) }
            try context.save()
        } catch { print("CategoryManager cache replace failed: \(error)") }
    }

    private func insertCache(_ c: TransactionCategory, isIncome: Bool) {
        let context = ModelContext(container)
        let id = c.id
        do {
            try context.fetch(FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: c, isIncome: isIncome))
            try context.save()
        } catch { print("CategoryManager cache upsert failed: \(error)") }
    }

    private func deleteCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            try context.save()
        } catch { print("CategoryManager cache delete failed: \(error)") }
    }

    private static func makeCategory(from entity: CategoryEntity) -> TransactionCategory {
        TransactionCategory(
            id: entity.id, name: entity.name,
            subcategories: SwiftDataBridge.decode([Subcategory].self, from: entity.subcategoriesData) ?? [],
            icon: entity.icon,
            color: SwiftDataBridge.color(red: entity.colorRed, green: entity.colorGreen, blue: entity.colorBlue, opacity: entity.colorOpacity)
        )
    }

    private static func makeEntity(from c: TransactionCategory, isIncome: Bool) -> CategoryEntity {
        let color = SwiftDataBridge.components(from: c.color)
        return CategoryEntity(
            id: c.id, name: c.name, isIncome: isIncome, icon: c.icon,
            colorRed: color.red, colorGreen: color.green, colorBlue: color.blue, colorOpacity: color.opacity,
            subcategoriesData: SwiftDataBridge.encode(c.subcategories)
        )
    }
}
