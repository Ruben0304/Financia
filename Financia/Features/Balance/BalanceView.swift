import SwiftUI

enum BalanceTab: String, CaseIterable, Identifiable {
    case ingresos = "Ingresos"
    case gastos = "Gastos"
    case deudas = "Deudas"

    var id: String { rawValue }
}

struct BalanceView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var debtManager: DebtManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var wealthManager: WealthManager

    @State private var selectedTab: BalanceTab = .ingresos
    @State private var entrySheetKind: FinanceEntryFlow?
    @State private var isAddingDebt: Bool = false
    @State private var selectedPeriod: String = getCurrentMonthYear()
    @State private var repeatErrorMessage: String?
    @State private var isShowingRepeatError = false

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerView
                    tabPicker

                    switch selectedTab {
                    case .ingresos:
                        incomeCard
                        categoryPieSection(type: .income)
                        assetsAndJobsSection
                    case .gastos:
                        expenseCard
                        categoryPieSection(type: .expense)
                        liabilitiesSection
                    case .deudas:
                        debtCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .sheet(item: $entrySheetKind) { kind in
            AddEntrySheet(kind: kind) { _ in }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingDebt) {
            DebtEditorView { newDebt in
                debtManager.addDebt(newDebt)
            }
        }
        .alert("No se pudo repetir", isPresented: $isShowingRepeatError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(repeatErrorMessage ?? "Revisa el saldo de la cartera.")
        })
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("Estadísticas")
                .font(.custom("Georgia", size: 28))
                .foregroundColor(DarkFinanceColors.primaryText)

            Spacer()

            Menu {
                Button("Enero 2025") { selectedPeriod = "Enero 2025" }
                Button("Febrero 2025") { selectedPeriod = "Febrero 2025" }
                Button("Marzo 2025") { selectedPeriod = "Marzo 2025" }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedPeriod)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "1A1A1D"))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        Picker("Vista", selection: $selectedTab) {
            ForEach(BalanceTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Cards
    private var incomeCard: some View {
        transactionCard(
            title: "Ingresos",
            amount: totalIncome,
            color: DarkFinanceColors.successGreen,
            transactions: recentIncomeTransactions,
            filter: .income
        )
    }

    private var expenseCard: some View {
        transactionCard(
            title: "Gastos",
            amount: totalExpenses,
            color: DarkFinanceColors.errorRed,
            transactions: recentExpenseTransactions,
            filter: .expense
        )
    }

    private var debtCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Deudas")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                NavigationLink(destination: DebtsView()) {
                    Text("Ver todas")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            if recentDebts.isEmpty {
                Text("No hay deudas registradas")
                    .font(.system(size: 14))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentDebts) { debt in
                        NavigationLink {
                            DebtDetailView(debt: debt)
                        } label: {
                            debtRow(debt)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private var assetsAndJobsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activos y trabajo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                NavigationLink(destination: AssetsAndJobsView()) {
                    Text("Ver todos")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Activos")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)

                if wealthManager.assets.isEmpty {
                    Text("Sin activos")
                        .font(.system(size: 13))
                        .foregroundColor(DarkFinanceColors.tertiaryText)
                } else {
                    ForEach(wealthManager.assets.prefix(3)) { asset in
                        NavigationLink {
                            AssetDetailView(asset: asset)
                        } label: {
                            simpleWealthRow(title: asset.name, subtitle: "Activo")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Trabajo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)

                if wealthManager.jobs.isEmpty {
                    Text("Sin trabajos")
                        .font(.system(size: 13))
                        .foregroundColor(DarkFinanceColors.tertiaryText)
                } else {
                    ForEach(wealthManager.jobs.prefix(3)) { job in
                        NavigationLink {
                            JobDetailView(job: job)
                        } label: {
                            simpleWealthRow(title: job.name, subtitle: "Trabajo")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private var liabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pasivos")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                NavigationLink(destination: LiabilitiesView()) {
                    Text("Ver todos")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            if wealthManager.liabilities.isEmpty {
                Text("Sin pasivos")
                    .font(.system(size: 13))
                    .foregroundColor(DarkFinanceColors.tertiaryText)
            } else {
                VStack(spacing: 12) {
                    ForEach(wealthManager.liabilities.prefix(3)) { liability in
                        NavigationLink {
                            LiabilityDetailView(liability: liability)
                        } label: {
                            simpleWealthRow(title: liability.name, subtitle: "Pasivo")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private func simpleWealthRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
        .contentShape(Rectangle())
    }

    private func transactionCard(
        title: String,
        amount: Double,
        color: Color,
        transactions: [Transaction],
        filter: HistoryFilter
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                NavigationLink(destination: HistoryView(filter: filter)) {
                    Text("Ver todos")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            Text(amount, format: .currency(code: "CUP"))
                .font(DarkFinanceTypography.monoAmount(size: 30, weight: .medium))
                .foregroundColor(color)

            if transactions.isEmpty {
                Text("No hay movimientos recientes")
                    .font(.system(size: 14))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(transactions) { transaction in
                        NavigationLink {
                            TransactionEditView(transaction: transaction)
                        } label: {
                            transactionRow(transaction)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                                repeatTransaction(transaction)
                            }
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    // MARK: - Computed Properties
    private var totalIncome: Double {
        transactionManager.transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        transactionManager.transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private static func getCurrentMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }

    private var recentIncomeTransactions: [Transaction] {
        Array(
            transactionManager.transactions
                .filter { $0.type == .income }
                .sorted { $0.date > $1.date }
                .prefix(4)
        )
    }

    private var recentExpenseTransactions: [Transaction] {
        Array(
            transactionManager.transactions
                .filter { $0.type == .expense }
                .sorted { $0.date > $1.date }
                .prefix(4)
        )
    }

    private var recentDebts: [Debt] {
        Array(debtManager.debts.sorted { $0.createdAt > $1.createdAt }.prefix(4))
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        let category = category(for: transaction)
        return HStack(spacing: 12) {
            Circle()
                .fill(category?.color ?? Color(.systemGray4))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: category?.icon ?? "tag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.subcategoryName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text(transaction.description.isEmpty ? transaction.categoryName : transaction.description)
                    .font(.system(size: 12))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            Spacer()

            Text(signedAmount(for: transaction))
                .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                .foregroundColor(transaction.type == .income ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
        }
        .contentShape(Rectangle())
    }

    private func debtRow(_ debt: Debt) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(debt.nombre)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text(debt.motivo)
                    .font(.system(size: 12))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            Spacer()

            Text(debt.monto, format: .currency(code: debt.moneda.rawValue))
                .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)
        }
        .contentShape(Rectangle())
    }

    private func signedAmount(for transaction: Transaction) -> String {
        let formatted = transaction.amount.formatted(.currency(code: "CUP"))
        return transaction.type == .income ? "+\(formatted)" : "-\(formatted)"
    }

    private func category(for transaction: Transaction) -> TransactionCategory? {
        if transaction.type == .income {
            return categoryManager.incomeCategories.first { $0.id == transaction.categoryId }
        }
        return categoryManager.expenseCategories.first { $0.id == transaction.categoryId }
    }

    private func repeatTransaction(_ transaction: Transaction) {
        if transaction.type == .expense {
            guard let wallet = walletManager.wallet(withId: transaction.walletId) else {
                showRepeatError("No se encontró la cartera origen.")
                return
            }
            let available = walletManager.calculateBalance(for: wallet)
            if transaction.amount > available {
                showRepeatError("El saldo de la cartera no es suficiente.")
                return
            }
        }

        let now = Date()
        let repeated = Transaction(
            type: transaction.type,
            amount: transaction.amount,
            date: now,
            categoryId: transaction.categoryId,
            categoryName: transaction.categoryName,
            subcategoryId: transaction.subcategoryId,
            subcategoryName: transaction.subcategoryName,
            description: transaction.description,
            walletId: transaction.walletId,
            createdAt: now,
            lugar: transaction.lugar,
            subitems: transaction.subitems,
            assetId: transaction.assetId,
            jobId: transaction.jobId,
            liabilityId: transaction.liabilityId
        )
        transactionManager.addTransaction(repeated)
        walletManager.syncWalletBalance(for: transaction.walletId)
    }

    private func showRepeatError(_ message: String) {
        repeatErrorMessage = message
        isShowingRepeatError = true
    }

    // MARK: - Category Pie
    private func categoryPieSection(type: TransactionType) -> some View {
        let slices = categorySlices(for: type)
        let total = slices.reduce(0) { $0 + $1.value }

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(type == .income ? "Ingresos por categoría" : "Gastos por categoría")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
            }

            if slices.isEmpty {
                Text("No hay datos para mostrar")
                    .font(.system(size: 14))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                            PieSlice(
                                startAngle: startAngle(for: index, in: slices),
                                endAngle: endAngle(for: index, in: slices),
                                color: slice.color
                            )
                        }

                        VStack(spacing: 4) {
                            Text(total, format: .currency(code: "CUP"))
                                .font(DarkFinanceTypography.monoAmount(size: 14, weight: .semibold))
                                .foregroundColor(DarkFinanceColors.primaryText)
                            Text("Total")
                                .font(.system(size: 11))
                                .foregroundColor(DarkFinanceColors.secondaryText)
                        }
                        .padding(10)
                        .background(
                            Circle()
                                .fill(DarkFinanceColors.cardBackground.opacity(0.9))
                        )
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(slices.prefix(5)) { slice in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(slice.color)
                                    .frame(width: 10, height: 10)
                                Text(slice.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DarkFinanceColors.secondaryText)
                                    .lineLimit(1)
                                Spacer()
                                Text(slice.percent, format: .percent.precision(.fractionLength(0)))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(DarkFinanceColors.primaryText)
                            }
                        }
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private func categorySlices(for type: TransactionType) -> [CategorySlice] {
        let transactions = transactionManager.transactions.filter { $0.type == type }
        let grouped = Dictionary(grouping: transactions, by: { $0.categoryId })
        let total = transactions.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let slices = grouped.compactMap { key, items -> CategorySlice? in
            let value = items.reduce(0) { $0 + $1.amount }
            guard value > 0 else { return nil }
            let category = type == .income
                ? categoryManager.incomeCategories.first { $0.id == key }
                : categoryManager.expenseCategories.first { $0.id == key }
            return CategorySlice(
                name: category?.name ?? "Otros",
                value: value,
                color: category?.color ?? Color(.systemGray4),
                percent: value / total
            )
        }

        return slices.sorted { $0.value > $1.value }
    }

    private func startAngle(for index: Int, in slices: [CategorySlice]) -> Angle {
        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else { return .degrees(0) }
        let sum = slices.prefix(index).reduce(0) { $0 + $1.value }
        return .degrees((sum / total) * 360 - 90)
    }

    private func endAngle(for index: Int, in slices: [CategorySlice]) -> Angle {
        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else { return .degrees(0) }
        let sum = slices.prefix(index + 1).reduce(0) { $0 + $1.value }
        return .degrees((sum / total) * 360 - 90)
    }
}

// MARK: - Pie Chart
private struct CategorySlice: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
    let percent: Double
}

private struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2

            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}
