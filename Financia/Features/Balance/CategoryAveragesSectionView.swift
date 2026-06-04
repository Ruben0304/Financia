import SwiftUI

struct CategoryAveragesSectionView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var categoryManager: CategoryManager

    let selectedCurrency: Currency

    @State private var groupBySubcategory = false
    @State private var showingAllAverages = false
    @State private var showingProjectionCalculator = false

    // MARK: - Computed Data

    private var categoryAverages: [CategoryAverageExpense] {
        transactionManager.monthlyAveragesByCategory(
            in: selectedCurrency,
            wallets: walletManager.wallets
        )
    }

    private var subcategoryAverages: [SubcategoryAverageExpense] {
        transactionManager.monthlyAveragesBySubcategory(
            in: selectedCurrency,
            wallets: walletManager.wallets
        )
    }

    private var top3Categories: [CategoryAverageExpense] {
        Array(categoryAverages.prefix(3))
    }

    private var top3Subcategories: [SubcategoryAverageExpense] {
        Array(subcategoryAverages.prefix(3))
    }

    private var hasMoreThan3: Bool {
        groupBySubcategory ? subcategoryAverages.count > 3 : categoryAverages.count > 3
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            groupToggle

            if groupBySubcategory {
                if top3Subcategories.isEmpty {
                    emptyState
                } else {
                    subcategoryRows(top3Subcategories)
                }
            } else {
                if top3Categories.isEmpty {
                    emptyState
                } else {
                    categoryRows(top3Categories)
                }
            }

            if hasMoreThan3 {
                Button {
                    showingAllAverages = true
                } label: {
                    HStack {
                        Text("Ver todos")
                            .font(DarkFinanceTypography.action(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(DarkFinanceColors.primaryAccent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
        .sheet(isPresented: $showingAllAverages) {
            NavigationStack {
                AllCategoryAveragesSheet(
                    selectedCurrency: selectedCurrency,
                    groupBySubcategory: $groupBySubcategory
                )
            }
        }
        .sheet(isPresented: $showingProjectionCalculator) {
            NavigationStack {
                ExpenseProjectionCalculatorSheet(
                    selectedCurrency: selectedCurrency
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Promedios de gastos")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)
            Spacer()
            Button {
                showingProjectionCalculator = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Proyección")
                        .font(DarkFinanceTypography.action(size: 12, weight: .semibold))
                }
                .foregroundColor(DarkFinanceColors.primaryAccent)
            }
        }
    }

    // MARK: - Toggle

    private var groupToggle: some View {
        Picker("Agrupar por", selection: $groupBySubcategory) {
            Text("Categorías").tag(false)
            Text("Subcategorías").tag(true)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("No hay datos de gastos para calcular promedios")
            .font(DarkFinanceTypography.body(size: 13))
            .foregroundColor(DarkFinanceColors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }

    // MARK: - Category Rows

    @ViewBuilder
    private func categoryRows(_ items: [CategoryAverageExpense]) -> some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                let category = categoryManager.expenseCategories.first { $0.id == item.categoryId }
                HStack(spacing: 12) {
                    Circle()
                        .fill(category?.color ?? Color(.systemGray4))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: category?.icon ?? "tag.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.categoryName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text("\(item.transactionCount) transacciones")
                            .font(.system(size: 12))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.monthlyAverage, format: .currency(code: selectedCurrency.rawValue))
                            .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.errorRed)
                        Text("/mes")
                            .font(.system(size: 10))
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                }
            }
        }
    }

    // MARK: - Subcategory Rows

    @ViewBuilder
    private func subcategoryRows(_ items: [SubcategoryAverageExpense]) -> some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                let category = categoryManager.expenseCategories.first { $0.id == item.categoryId }
                HStack(spacing: 12) {
                    Circle()
                        .fill(category?.color ?? Color(.systemGray4))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: category?.icon ?? "tag.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.subcategoryName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(item.categoryName)
                            .font(.system(size: 12))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.monthlyAverage, format: .currency(code: selectedCurrency.rawValue))
                            .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.errorRed)
                        Text("/mes")
                            .font(.system(size: 10))
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                }
            }
        }
    }
}
