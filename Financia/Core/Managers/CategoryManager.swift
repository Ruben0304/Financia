import Foundation
import Combine

// Manager para operaciones CRUD de categorías
class CategoryManager: ObservableObject {

    static let shared = CategoryManager()

    @Published var incomeCategories: [TransactionCategory] = []
    @Published var expenseCategories: [TransactionCategory] = []

    private let persistence = PersistenceManager.shared
    private let incomeCategoriesFilename = "income_categories.json"
    private let expenseCategoriesFilename = "expense_categories.json"

    private init() {
        loadCategories()
    }

    // MARK: - Load/Save

    func loadCategories() {
        // Cargar categorías de ingresos
        if persistence.fileExists(incomeCategoriesFilename) {
            do {
                incomeCategories = try persistence.load(from: incomeCategoriesFilename, as: [TransactionCategory].self)
            } catch {
                print("Error loading income categories: \(error)")
                incomeCategories = CategoriesData.incomeCategories
                saveIncomeCategories()
            }
        } else {
            incomeCategories = CategoriesData.incomeCategories
            saveIncomeCategories()
        }

        // Cargar categorías de gastos
        if persistence.fileExists(expenseCategoriesFilename) {
            do {
                expenseCategories = try persistence.load(from: expenseCategoriesFilename, as: [TransactionCategory].self)
            } catch {
                print("Error loading expense categories: \(error)")
                expenseCategories = CategoriesData.expenseCategories
                saveExpenseCategories()
            }
        } else {
            expenseCategories = CategoriesData.expenseCategories
            saveExpenseCategories()
        }
    }

    private func saveIncomeCategories() {
        do {
            try persistence.save(incomeCategories, to: incomeCategoriesFilename)
        } catch {
            print("Error saving income categories: \(error)")
        }
    }

    private func saveExpenseCategories() {
        do {
            try persistence.save(expenseCategories, to: expenseCategoriesFilename)
        } catch {
            print("Error saving expense categories: \(error)")
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
}
