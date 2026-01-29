import SwiftUI

enum CategoryKind: String, CaseIterable, Identifiable {
    case expense = "Gastos"
    case income = "Ingresos"

    var id: String { rawValue }
}

struct CategoriesManagementView: View {
    @EnvironmentObject private var categoryManager: CategoryManager

    @State private var selectedKind: CategoryKind = .expense
    @State private var selectedCategory: TransactionCategory?
    @State private var selectedSubcategory: Subcategory?
    @State private var showingAddSubcategoryAlert = false
    @State private var newSubcategoryName = ""
    @State private var categoryToAddTo: TransactionCategory?
    @State private var isAddingCategory = false

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView {
                VStack(spacing: 16) {
                    Picker("Tipo", selection: $selectedKind) {
                        ForEach(CategoryKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                CategoryGridSelector(
                    title: "Categorías",
                    categories: categories,
                    selectedCategory: $selectedCategory,
                    selectedSubcategory: $selectedSubcategory,
                    onAddCategory: {
                        isAddingCategory = true
                    },
                    onAddSubcategory: { category in
                        categoryToAddTo = category
                        showingAddSubcategoryAlert = true
                    }
                )
                }
                .padding()
            }
        }
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Nueva Subcategoría", isPresented: $showingAddSubcategoryAlert) {
            TextField("Nombre", text: $newSubcategoryName)
            Button("Guardar") {
                if let category = categoryToAddTo, !newSubcategoryName.isEmpty {
                    addSubcategory(to: category, with: newSubcategoryName)
                    newSubcategoryName = ""
                }
            }
            Button("Cancelar", role: .cancel) {
                newSubcategoryName = ""
            }
        }
        .sheet(isPresented: $isAddingCategory) {
            AddCategoryView { newCategory in
                if selectedKind == .income {
                    categoryManager.addIncomeCategory(newCategory)
                } else {
                    categoryManager.addExpenseCategory(newCategory)
                }
                selectedCategory = newCategory
                selectedSubcategory = newCategory.subcategories.first
            }
        }
    }

    private var categories: [TransactionCategory] {
        selectedKind == .income ? categoryManager.incomeCategories : categoryManager.expenseCategories
    }

    private func addSubcategory(to category: TransactionCategory, with name: String) {
        let newSubcategory = Subcategory(name: name)
        categoryManager.addSubcategory(newSubcategory, to: category, isIncome: selectedKind == .income)
        selectedSubcategory = newSubcategory
        selectedCategory = category
    }
}
