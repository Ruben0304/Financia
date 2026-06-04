import Foundation
import Combine
import SwiftData

// Manager para operaciones CRUD de categorías
class CategoryManager: ObservableObject {

    static let shared = CategoryManager()

    @Published var incomeCategories: [TransactionCategory] = []
    @Published var expenseCategories: [TransactionCategory] = []

    private let container = PersistenceManager.shared.container

    private init() {
        loadCategories()
    }

    // MARK: - Load/Save

    func loadCategories() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CategoryEntity>()

        do {
            let entities = try context.fetch(descriptor)
            incomeCategories = entities.filter(\ .isIncome).map(Self.makeCategory(from:))
            expenseCategories = entities.filter { !$0.isIncome }.map(Self.makeCategory(from:))

            if incomeCategories.isEmpty {
                incomeCategories = CategoriesData.incomeCategories
                saveIncomeCategories()
            }

            if expenseCategories.isEmpty {
                expenseCategories = CategoriesData.expenseCategories
                saveExpenseCategories()
            }
        } catch {
            print("Error loading categories: \(error)")
            incomeCategories = CategoriesData.incomeCategories
            expenseCategories = CategoriesData.expenseCategories
            saveIncomeCategories()
            saveExpenseCategories()
        }
    }

    private func saveIncomeCategories() {
        save(categories: incomeCategories, isIncome: true)
    }

    private func saveExpenseCategories() {
        save(categories: expenseCategories, isIncome: false)
    }

    private func save(categories: [TransactionCategory], isIncome: Bool) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CategoryEntity>(
            predicate: #Predicate { $0.isIncome == isIncome }
        )

        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            categories.map { Self.makeEntity(from: $0, isIncome: isIncome) }.forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving categories: \(error)")
        }
    }

    // MARK: - CRUD Operations - Income Categories

    func addIncomeCategory(_ category: TransactionCategory) {
        incomeCategories.append(category)
        saveIncomeCategories()
    }

    func updateIncomeCategory(_ category: TransactionCategory) {
        if let index = incomeCategories.firstIndex(where: { $0.id == category.id }) {
            incomeCategories[index] = category
            saveIncomeCategories()
        }
    }

    func deleteIncomeCategory(_ category: TransactionCategory) {
        incomeCategories.removeAll { $0.id == category.id }
        saveIncomeCategories()
    }

    // MARK: - CRUD Operations - Expense Categories

    func addExpenseCategory(_ category: TransactionCategory) {
        expenseCategories.append(category)
        saveExpenseCategories()
    }

    func updateExpenseCategory(_ category: TransactionCategory) {
        if let index = expenseCategories.firstIndex(where: { $0.id == category.id }) {
            expenseCategories[index] = category
            saveExpenseCategories()
        }
    }

    func deleteExpenseCategory(_ category: TransactionCategory) {
        expenseCategories.removeAll { $0.id == category.id }
        saveExpenseCategories()
    }

    // MARK: - Subcategories

    func addSubcategory(_ subcategory: Subcategory, to category: TransactionCategory, isIncome: Bool) {
        if isIncome {
            if let index = incomeCategories.firstIndex(where: { $0.id == category.id }) {
                incomeCategories[index].subcategories.append(subcategory)
                saveIncomeCategories()
            }
        } else {
            if let index = expenseCategories.firstIndex(where: { $0.id == category.id }) {
                expenseCategories[index].subcategories.append(subcategory)
                saveExpenseCategories()
            }
        }
    }

    // MARK: - Query Methods

    func category(withId id: UUID, isIncome: Bool) -> TransactionCategory? {
        if isIncome {
            return incomeCategories.first { $0.id == id }
        } else {
            return expenseCategories.first { $0.id == id }
        }
    }

    func subcategory(withId id: UUID, in category: TransactionCategory) -> Subcategory? {
        return category.subcategories.first { $0.id == id }
    }

    private static func makeCategory(from entity: CategoryEntity) -> TransactionCategory {
        TransactionCategory(
            id: entity.id,
            name: entity.name,
            subcategories: SwiftDataBridge.decode([Subcategory].self, from: entity.subcategoriesData) ?? [],
            icon: entity.icon,
            color: SwiftDataBridge.color(
                red: entity.colorRed,
                green: entity.colorGreen,
                blue: entity.colorBlue,
                opacity: entity.colorOpacity
            )
        )
    }

    private static func makeEntity(from category: TransactionCategory, isIncome: Bool) -> CategoryEntity {
        let color = SwiftDataBridge.components(from: category.color)
        return CategoryEntity(
            id: category.id,
            name: category.name,
            isIncome: isIncome,
            icon: category.icon,
            colorRed: color.red,
            colorGreen: color.green,
            colorBlue: color.blue,
            colorOpacity: color.opacity,
            subcategoriesData: SwiftDataBridge.encode(category.subcategories)
        )
    }
}
