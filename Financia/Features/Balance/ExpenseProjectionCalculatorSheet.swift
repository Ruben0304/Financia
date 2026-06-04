import SwiftUI

// MARK: - Projection Range

enum ProjectionRange: String, CaseIterable, Identifiable {
    case thisMonth = "Este mes"
    case thisAndNext = "Este + próximo"
    case nextMonth = "Próximo mes"
    case custom = "Personalizado"

    var id: String { rawValue }
}

// MARK: - Sheet View

struct ExpenseProjectionCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var categoryManager: CategoryManager

    let selectedCurrency: Currency

    @State private var groupBySubcategory = false
    @State private var selectedIds: Set<UUID> = []
    @State private var projectionRange: ProjectionRange = .thisMonth
    @State private var customMonths: Double = 1

    // MARK: - Computed

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

    private var effectiveMonths: Int {
        switch projectionRange {
        case .thisMonth: return 1
        case .thisAndNext: return 2
        case .nextMonth: return 1
        case .custom: return Int(customMonths)
        }
    }

    private var totalProjectedExpense: Double {
        transactionManager.projectedExpenses(
            for: selectedIds,
            months: effectiveMonths,
            in: selectedCurrency,
            wallets: walletManager.wallets,
            groupBySubcategory: groupBySubcategory
        )
    }

    private var currentBalance: Double {
        walletManager.totalBalance(in: selectedCurrency)
    }

    private var projectedRemaining: Double {
        currentBalance - totalProjectedExpense
    }

    private var allSelected: Bool {
        if groupBySubcategory {
            return !subcategoryAverages.isEmpty && selectedIds.count == subcategoryAverages.count
        } else {
            return !categoryAverages.isEmpty && selectedIds.count == categoryAverages.count
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Group toggle
                Picker("Agrupar por", selection: $groupBySubcategory) {
                    Text("Categorías").tag(false)
                    Text("Subcategorías").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: groupBySubcategory) { _, _ in
                    selectedIds.removeAll()
                }

                selectionSection

                rangeSection

                if !selectedIds.isEmpty {
                    resultsCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(DarkFinanceBackground())
        .navigationTitle("Proyección de gastos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
    }

    // MARK: - Selection Section

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Seleccionar categorías")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                Button(allSelected ? "Deseleccionar" : "Seleccionar todas") {
                    toggleAll()
                }
                .font(DarkFinanceTypography.action(size: 12, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryAccent)
            }

            if groupBySubcategory {
                subcategorySelectionList
            } else {
                categorySelectionList
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 16)
    }

    private func toggleAll() {
        if allSelected {
            selectedIds.removeAll()
        } else {
            if groupBySubcategory {
                selectedIds = Set(subcategoryAverages.map(\.subcategoryId))
            } else {
                selectedIds = Set(categoryAverages.map(\.categoryId))
            }
        }
    }

    // MARK: - Category Selection

    private var categorySelectionList: some View {
        VStack(spacing: 8) {
            ForEach(categoryAverages) { item in
                let isSelected = selectedIds.contains(item.categoryId)
                let category = categoryManager.expenseCategories.first { $0.id == item.categoryId }

                Button {
                    if isSelected {
                        selectedIds.remove(item.categoryId)
                    } else {
                        selectedIds.insert(item.categoryId)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? DarkFinanceColors.primaryAccent : DarkFinanceColors.tertiaryText)

                        Circle()
                            .fill(category?.color ?? Color(.systemGray4))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: category?.icon ?? "tag.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        Text(item.categoryName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DarkFinanceColors.primaryText)

                        Spacer()

                        Text(item.monthlyAverage, format: .currency(code: selectedCurrency.rawValue))
                            .font(DarkFinanceTypography.monoAmount(size: 12, weight: .medium))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                        Text("/mes")
                            .font(.system(size: 10))
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Subcategory Selection

    private var subcategorySelectionList: some View {
        VStack(spacing: 8) {
            ForEach(subcategoryAverages) { item in
                let isSelected = selectedIds.contains(item.subcategoryId)
                let category = categoryManager.expenseCategories.first { $0.id == item.categoryId }

                Button {
                    if isSelected {
                        selectedIds.remove(item.subcategoryId)
                    } else {
                        selectedIds.insert(item.subcategoryId)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? DarkFinanceColors.primaryAccent : DarkFinanceColors.tertiaryText)

                        Circle()
                            .fill(category?.color ?? Color(.systemGray4))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: category?.icon ?? "tag.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.subcategoryName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DarkFinanceColors.primaryText)
                            Text(item.categoryName)
                                .font(.system(size: 11))
                                .foregroundColor(DarkFinanceColors.tertiaryText)
                        }

                        Spacer()

                        Text(item.monthlyAverage, format: .currency(code: selectedCurrency.rawValue))
                            .font(DarkFinanceTypography.monoAmount(size: 12, weight: .medium))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                        Text("/mes")
                            .font(.system(size: 10))
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Range Section

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Periodo de proyección")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProjectionRange.allCases) { range in
                        Button {
                            projectionRange = range
                        } label: {
                            Text(range.rawValue)
                                .font(DarkFinanceTypography.action(size: 13, weight: .semibold))
                                .foregroundColor(projectionRange == range ? .white : DarkFinanceColors.secondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(projectionRange == range
                                              ? DarkFinanceColors.primaryAccent
                                              : DarkFinanceColors.inputBackground)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if projectionRange == .custom {
                VStack(spacing: 4) {
                    HStack {
                        Text("Meses:")
                            .font(DarkFinanceTypography.body(size: 13))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                        Spacer()
                        Text("\(Int(customMonths))")
                            .font(DarkFinanceTypography.monoAmount(size: 16, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                    }
                    Slider(value: $customMonths, in: 1...12, step: 1)
                        .tint(DarkFinanceColors.primaryAccent)
                }
                .padding(.top, 4)
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Results Card

    private var resultsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Balance actual")
                    .font(DarkFinanceTypography.body(size: 14))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                Spacer()
                Text(currentBalance, format: .currency(code: selectedCurrency.rawValue))
                    .font(DarkFinanceTypography.monoAmount(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
            }

            Divider().background(DarkFinanceColors.cardBorder)

            HStack {
                Text("Gasto proyectado (\(effectiveMonths) \(effectiveMonths == 1 ? "mes" : "meses"))")
                    .font(DarkFinanceTypography.body(size: 14))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                Spacer()
                Text(totalProjectedExpense, format: .currency(code: selectedCurrency.rawValue))
                    .font(DarkFinanceTypography.monoAmount(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.errorRed)
            }

            Divider().background(DarkFinanceColors.cardBorder)

            HStack {
                Text("Balance proyectado")
                    .font(DarkFinanceTypography.emphasis(size: 14))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                Text(projectedRemaining, format: .currency(code: selectedCurrency.rawValue))
                    .font(DarkFinanceTypography.monoAmount(size: 20, weight: .bold))
                    .foregroundColor(projectedRemaining >= 0 ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
            }

            if projectedRemaining < 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DarkFinanceColors.errorRed)
                    Text("El balance proyectado es negativo. Considera reducir gastos en estas categorías.")
                        .font(DarkFinanceTypography.caption(size: 12))
                        .foregroundColor(DarkFinanceColors.errorRed.opacity(0.8))
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }
}
