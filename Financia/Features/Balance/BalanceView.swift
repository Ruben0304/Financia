import SwiftUI
import Charts

enum BalanceTab: String, CaseIterable, Identifiable {
    case ingresos = "Ingresos"
    case gastos = "Gastos"
    case deudas = "Deudas"

    var id: String { rawValue }
}

enum DeudaSubTab: String, CaseIterable, Identifiable {
    case deudas = "Deudas"
    case prestamos = "Préstamos"

    var id: String { rawValue }
}

struct BalanceView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var debtManager: DebtManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var wealthManager: WealthManager
    @EnvironmentObject private var prestamoManager: PrestamoManager

    @State private var selectedTab: BalanceTab = .ingresos
    @State private var selectedCurrency: Currency = .cup
    @State private var entrySheetKind: FinanceEntryFlow?
    @State private var isAddingDebt: Bool = false
    @State private var isAddingPrestamo: Bool = false
    @State private var deudaSubTab: DeudaSubTab = .deudas
    @State private var repeatErrorMessage: String?
    @State private var isShowingRepeatError = false
    @State private var isShowingSubscriptions = false

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    tabPicker

                    switch selectedTab {
                    case .ingresos:
                        incomeCard
                        categoryPieSection(type: .income)
                        assetsAndJobsSection
                    case .gastos:
                        expenseCard
                        categoryPieSection(type: .expense)
                        CategoryAveragesSectionView(selectedCurrency: selectedCurrency)
                    case .deudas:
                        Picker("", selection: $deudaSubTab) {
                            ForEach(DeudaSubTab.allCases) { sub in
                                Text(sub.rawValue).tag(sub)
                            }
                        }
                        .pickerStyle(.segmented)

                        if deudaSubTab == .deudas {
                            debtCard
                        } else {
                            prestamosCard
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .principal) {
                    balanceToolbarHeader
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) {
                    balanceToolbarHeader
                }
            }

            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible)

                ToolbarItem(placement: .topBarTrailing) {
                    subscriptionsToolbarButton
                }

                ToolbarSpacer(.fixed)

                ToolbarItem(placement: .topBarTrailing) {
                    Picker("", selection: $selectedCurrency) {
                        Text("CUP").tag(Currency.cup)
                        Text("USD").tag(Currency.usd)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 104)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    subscriptionsToolbarButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Picker("", selection: $selectedCurrency) {
                        Text("CUP").tag(Currency.cup)
                        Text("USD").tag(Currency.usd)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 104)
                }
            }
        }
        .sheet(item: $entrySheetKind) { kind in
            AddEntrySheet(kind: kind) { _ in }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSubscriptions) {
            NavigationStack {
                SubscriptionsSectionView()
            }
        }
        .sheet(isPresented: $isAddingDebt) {
            DebtEditorView { newDebt in
                debtManager.addDebt(newDebt)
            }
        }
        .sheet(isPresented: $isAddingPrestamo) {
            PrestamoEditorView { newPrestamo in
                prestamoManager.addPrestamo(newPrestamo)
            }
        }
        .alert("No se pudo repetir", isPresented: $isShowingRepeatError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(repeatErrorMessage ?? "Revisa el saldo de la cartera.")
        })
    }

    private var balanceToolbarHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Balance")
                .darkFinanceToolbarTitle(size: 24)
                .foregroundColor(DarkFinanceColors.primaryText)

            if selectedTab == .ingresos {
                Text("Prox. mes: \(estimatedMonthlyIncome, format: .currency(code: selectedCurrency.rawValue))")
                    .darkFinanceToolbarSubtitle(size: 12, weight: .semibold)
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subscriptionsToolbarButton: some View {
        Button {
            isShowingSubscriptions = true
        } label: {
            Image(systemName: "rectangle.stack.badge.person.crop")
        }
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
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                NavigationLink(destination: DebtsView()) {
                    Text("Ver todas")
                        .font(DarkFinanceTypography.action())
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            if recentDebts.isEmpty {
                Text("No hay deudas registradas")
                    .font(DarkFinanceTypography.body())
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

    private var prestamosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Préstamos")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                NavigationLink(destination: PrestamosView()) {
                    Text("Ver todos")
                        .font(DarkFinanceTypography.action())
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            if recentPrestamos.isEmpty {
                Text("No hay préstamos registrados")
                    .font(DarkFinanceTypography.body())
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentPrestamos) { prestamo in
                        NavigationLink {
                            PrestamoDetailView(prestamo: prestamo)
                        } label: {
                            prestamoRow(prestamo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                isAddingPrestamo = true
            } label: {
                Label("Nuevo préstamo", systemImage: "plus.circle.fill")
                    .font(DarkFinanceTypography.action(size: 13, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryAccent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private var assetsAndJobsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activos y trabajo")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                NavigationLink(destination: AssetsAndJobsView()) {
                    Text("Ver todos")
                        .font(DarkFinanceTypography.action())
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Activos")
                    .font(DarkFinanceTypography.action(size: 13, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)

                if wealthManager.assets.isEmpty {
                    Text("Sin activos")
                        .font(DarkFinanceTypography.body(size: 13))
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

            Text(amount, format: .currency(code: selectedCurrency.rawValue))
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
    private func transactionCurrency(for transaction: Transaction) -> Currency? {
        walletManager.wallet(withId: transaction.walletId)?.currency
    }

    private var totalIncome: Double {
        transactionManager.transactions
            .filter { $0.type == .income && transactionCurrency(for: $0) == selectedCurrency }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        transactionManager.transactions
            .filter { $0.type == .expense && transactionCurrency(for: $0) == selectedCurrency }
            .reduce(0) { $0 + $1.amount }
    }

    private var estimatedMonthlyIncome: Double {
        wealthManager.forecastedMonthlyIncome(in: selectedCurrency)
    }

    private var recentIncomeTransactions: [Transaction] {
        Array(
            transactionManager.transactions
                .filter { $0.type == .income && transactionCurrency(for: $0) == selectedCurrency }
                .sorted { $0.date > $1.date }
                .prefix(4)
        )
    }

    private var recentExpenseTransactions: [Transaction] {
        Array(
            transactionManager.transactions
                .filter { $0.type == .expense && transactionCurrency(for: $0) == selectedCurrency }
                .sorted { $0.date > $1.date }
                .prefix(4)
        )
    }

    private var recentDebts: [Debt] {
        Array(debtManager.debts.sorted { $0.createdAt > $1.createdAt }.prefix(4))
    }

    private var recentPrestamos: [Prestamo] {
        Array(prestamoManager.prestamos.sorted { $0.createdAt > $1.createdAt }.prefix(4))
    }

    private func prestamoRow(_ prestamo: Prestamo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(prestamo.estaPagado ? Color(.systemGray4) : prestamo.estaVencido ? Color(red: 0.86, green: 0.33, blue: 0.33) : Color(red: 0.20, green: 0.60, blue: 0.46))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(prestamo.nombre)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text(prestamo.motivo.isEmpty ? "Préstamo" : prestamo.motivo)
                    .font(.system(size: 12))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(prestamo.monto, format: .currency(code: prestamo.moneda.rawValue))
                    .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                if let fecha = prestamo.fechaDevolucion {
                    Text(fecha, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(prestamo.estaVencido ? DarkFinanceColors.errorRed : DarkFinanceColors.secondaryText)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        let category = category(for: transaction)
        return HStack(spacing: 12) {
            Circle()
                .fill(category?.color ?? Color(.systemGray4))
                .frame(width: 36, height: 36)
                .overlay(
                    CategoryIconView(icon: category?.icon ?? "tag.fill", color: .white, size: 14)
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
        let formatted = transaction.amount.formatted(.currency(code: selectedCurrency.rawValue))
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
                VStack(spacing: 16) {
                    // 3D Donut Chart
                    ZStack {
                        // Shadow layer for 3D depth
                        Chart(slices) { slice in
                            SectorMark(
                                angle: .value("Valor", slice.value),
                                innerRadius: .ratio(0.58),
                                outerRadius: .ratio(0.95),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(slice.color.opacity(0.3))
                        }
                        .chartLegend(.hidden)
                        .frame(height: 200)
                        .offset(y: 8)
                        .blur(radius: 6)

                        // Main chart
                        Chart(slices) { slice in
                            SectorMark(
                                angle: .value("Valor", slice.value),
                                innerRadius: .ratio(0.58),
                                outerRadius: .ratio(0.95),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [slice.color.opacity(0.9), slice.color],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: slice.color.opacity(0.4), radius: 4, x: 0, y: 2)
                        }
                        .chartLegend(.hidden)
                        .frame(height: 200)

                    }
                    .rotation3DEffect(.degrees(12), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)

                    // Total
                    VStack(spacing: 2) {
                        Text("Total")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                        Text(total, format: .currency(code: selectedCurrency.rawValue))
                            .font(DarkFinanceTypography.monoAmount(size: 16, weight: .bold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Legend
                    VStack(spacing: 8) {
                        ForEach(slices.prefix(5)) { slice in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [slice.color.opacity(0.8), slice.color],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 14, height: 14)
                                    .shadow(color: slice.color.opacity(0.3), radius: 2, x: 0, y: 1)

                                Text(slice.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DarkFinanceColors.secondaryText)
                                    .lineLimit(1)

                                Spacer()

                                Text(slice.percent, format: .percent.precision(.fractionLength(0)))
                                    .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                                    .foregroundColor(DarkFinanceColors.primaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private func categorySlices(for type: TransactionType) -> [CategorySlice] {
        let transactions = transactionManager.transactions.filter { $0.type == type && transactionCurrency(for: $0) == selectedCurrency }
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

}

// MARK: - Pie Chart
private struct CategorySlice: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
    let percent: Double
}
