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
    @State private var selectedWalletId: UUID?

    // MARK: - Computed

    private var availableWallets: [Wallet] {
        walletManager.wallets.filter { $0.currency == selectedCurrency }
    }

    private var selectedWallet: Wallet? {
        guard let selectedWalletId else { return nil }
        return availableWallets.first { $0.id == selectedWalletId }
    }

    private var walletsForProjection: [Wallet] {
        selectedWallet.map { [$0] } ?? []
    }

    private var categoryAverages: [CategoryAverageExpense] {
        transactionManager.monthlyAveragesByCategory(
            in: selectedCurrency,
            wallets: walletsForProjection
        )
    }

    private var subcategoryAverages: [SubcategoryAverageExpense] {
        transactionManager.monthlyAveragesBySubcategory(
            in: selectedCurrency,
            wallets: walletsForProjection
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
            wallets: walletsForProjection,
            groupBySubcategory: groupBySubcategory
        )
    }

    private var currentBalance: Double {
        guard let selectedWallet else { return 0 }
        return walletManager.calculateBalance(for: selectedWallet)
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
                walletSection

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
        .onAppear {
            ensureSelectedWallet()
        }
        .onChange(of: walletManager.wallets) { _, _ in
            ensureSelectedWallet()
        }
        .onChange(of: selectedCurrency) { _, _ in
            selectedIds.removeAll()
            selectedWalletId = nil
            ensureSelectedWallet()
        }
        .onChange(of: selectedWalletId) { _, _ in
            selectedIds.removeAll()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
    }

    // MARK: - Wallet Section

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cartera")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            if availableWallets.isEmpty {
                Text("No hay carteras en \(selectedCurrency.rawValue).")
                    .font(DarkFinanceTypography.body(size: 13))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            } else {
                Picker("Cartera", selection: $selectedWalletId) {
                    ForEach(availableWallets) { wallet in
                        Text(wallet.name).tag(Optional(wallet.id))
                    }
                }
                .pickerStyle(.menu)

                if let selectedWallet {
                    HStack(spacing: 10) {
                        Image(systemName: selectedWallet.icon)
                            .foregroundColor(selectedWallet.color)
                        Text(selectedWallet.name)
                            .font(DarkFinanceTypography.body(size: 14))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Spacer()
                        Text(walletManager.calculateBalance(for: selectedWallet), format: .currency(code: selectedCurrency.rawValue))
                            .font(DarkFinanceTypography.monoAmount(size: 14, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 16)
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
                                CategoryIconView(icon: category?.icon ?? "tag.fill", color: .white, size: 12)
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
                                CategoryIconView(icon: category?.icon ?? "tag.fill", color: .white, size: 12)
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

    private func ensureSelectedWallet() {
        let validWalletIds = Set(availableWallets.map(\.id))

        if let selectedWalletId, validWalletIds.contains(selectedWalletId) {
            return
        }

        selectedWalletId = availableWallets.first?.id
    }
}
