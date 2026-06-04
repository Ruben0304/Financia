import SwiftUI

struct AllCategoryAveragesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var categoryManager: CategoryManager

    let selectedCurrency: Currency
    @Binding var groupBySubcategory: Bool

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

    private var totalMonthlyAverage: Double {
        categoryAverages.reduce(0) { $0 + $1.monthlyAverage }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Agrupar por", selection: $groupBySubcategory) {
                    Text("Categorías").tag(false)
                    Text("Subcategorías").tag(true)
                }
                .pickerStyle(.segmented)

                // Total summary
                VStack(spacing: 4) {
                    Text("Promedio mensual total")
                        .font(DarkFinanceTypography.body(size: 13))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                    Text(totalMonthlyAverage, format: .currency(code: selectedCurrency.rawValue))
                        .font(DarkFinanceTypography.monoAmount(size: 24, weight: .bold))
                        .foregroundColor(DarkFinanceColors.errorRed)
                }
                .padding(.vertical, 8)

                if groupBySubcategory {
                    ForEach(subcategoryAverages) { item in
                        subcategoryRow(item)
                    }
                } else {
                    ForEach(categoryAverages) { item in
                        categoryRow(item)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(DarkFinanceBackground())
        .navigationTitle("Promedios de gastos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
    }

    // MARK: - Category Row

    private func categoryRow(_ item: CategoryAverageExpense) -> some View {
        let category = categoryManager.expenseCategories.first { $0.id == item.categoryId }
        return HStack(spacing: 12) {
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
        .darkFinanceCard(cornerRadius: 16, padding: 12)
    }

    // MARK: - Subcategory Row

    private func subcategoryRow(_ item: SubcategoryAverageExpense) -> some View {
        let category = categoryManager.expenseCategories.first { $0.id == item.categoryId }
        return HStack(spacing: 12) {
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
        .darkFinanceCard(cornerRadius: 16, padding: 12)
    }
}
