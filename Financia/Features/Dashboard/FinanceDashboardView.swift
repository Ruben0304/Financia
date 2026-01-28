import SwiftUI

struct FinanceDashboardView: View {
    @Binding var selectedRange: DateRange
    var onAddIncome: () -> Void = {}
    var onAddExpense: () -> Void = {}
    var onScanReceipt: () -> Void = {}

    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var categoryManager: CategoryManager
    @EnvironmentObject var debtManager: DebtManager
    @State private var selectedMovementFilter: MovementFilter = .all
    @State private var selectedCurrency: Currency = .cup
    @State private var didSetInitialCurrency: Bool = false
    @State private var showAssistant: Bool = false
    @State private var showDebtInfo: Bool = false
    @State private var repeatErrorMessage: String?
    @State private var isShowingRepeatError: Bool = false
    @State private var selectedHomeTab: HomeTab = .home

    // Convertir transacciones a FinanceEntry para el gráfico (balance acumulado)
    private var entries: [FinanceEntry] {
        let allTransactions = filteredTransactions.sorted { $0.date < $1.date }
        var cumulativeBalance: Double = 0
        return allTransactions.map { transaction in
            let amount = transaction.type == .income ? transaction.amount : -transaction.amount
            cumulativeBalance += amount
            return FinanceEntry(date: transaction.date, value: cumulativeBalance)
        }
    }

    private var orderedEntries: [FinanceEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var filteredEntries: [FinanceEntry] {
        guard let start = Calendar.current.date(byAdding: .day, value: -selectedRange.lengthInDays, to: Date()) else {
            return orderedEntries
        }
        return orderedEntries.filter { $0.date >= start }
    }

    private var currentBalance: Double { selectedCurrencyBalance }
    private var selectedCurrencyBalance: Double {
        let wallets = walletManager.wallets.filter { $0.currency == selectedCurrency }
        return wallets.reduce(0) { $0 + walletManager.calculateBalance(for: $1) }
    }

    private var totalDebtForCurrency: Double {
        debtManager.debts
            .filter { $0.moneda == selectedCurrency }
            .reduce(0) { $0 + $1.monto }
    }

    private var remainingAfterDebt: Double {
        currentBalance - totalDebtForCurrency
    }

    private var remainingColor: Color {
        if totalDebtForCurrency > currentBalance {
            return Color(red: 0.86, green: 0.33, blue: 0.33)
        }
        if currentBalance >= totalDebtForCurrency * 3 {
            return Color(red: 0.20, green: 0.60, blue: 0.46)
        }
        return Color(red: 0.94, green: 0.71, blue: 0.31)
    }

    private var filteredTransactions: [Transaction] {
        transactionManager.transactions.filter { transactionCurrency(for: $0) == selectedCurrency }
    }

    private func transactionCurrency(for transaction: Transaction) -> Currency? {
        walletManager.wallet(withId: transaction.walletId)?.currency
    }

    private var totalIncome: Double {
        filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        homeTabs
                        balanceCard
                        actionRow
                        highlightCard
                        expensesCard
                        movementsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Inicio")
            .onAppear {
                if !didSetInitialCurrency, let firstWallet = walletManager.wallets.first {
                    selectedCurrency = firstWallet.currency
                    didSetInitialCurrency = true
                }
            }
            .alert("No se pudo repetir", isPresented: $isShowingRepeatError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(repeatErrorMessage ?? "Revisa el saldo de la cartera.")
            })
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Agregar ingreso", action: onAddIncome)
                        Button("Agregar gasto", action: onAddExpense)
                        Button("Escanear vale", action: onScanReceipt)
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAssistant = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                    }
                }
            }
            .fullScreenCover(isPresented: $showAssistant) {
                NavigationStack {
                    ChatView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cerrar") {
                                    showAssistant = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var homeTabs: some View {
        HStack(spacing: 10) {
            ForEach(HomeTab.allCases) { tab in
                Button {
                    selectedHomeTab = tab
                } label: {
                    Text(tab.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(selectedHomeTab == tab ? Color.white : Color.white.opacity(0.6))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(selectedHomeTab == tab ? dashboardAccent.opacity(0.25) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Saldo total")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                Spacer()
                currencyPills
            }

            Text(currentBalance, format: .currency(code: selectedCurrency.rawValue))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 12) {
                deltaBadge
                variationSummary(for: filteredEntries)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingresos")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(totalIncome, format: .currency(code: selectedCurrency.rawValue))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gastos")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(totalExpenses, format: .currency(code: selectedCurrency.rawValue))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    showDebtInfo = true
                } label: {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Disponible")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.6))
                        Text(remainingAfterDebt, format: .currency(code: selectedCurrency.rawValue))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(remainingColor)
                    }
                }
                .buttonStyle(.plain)
            }

            rangePills
        }
        .padding(18)
        .background(cardSurface)
        .alert("Detalle de deuda", isPresented: $showDebtInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Deuda total: \(totalDebtForCurrency.formatted(.currency(code: selectedCurrency.rawValue)))\nSaldo actual: \(currentBalance.formatted(.currency(code: selectedCurrency.rawValue)))\nRestante: \(remainingAfterDebt.formatted(.currency(code: selectedCurrency.rawValue)))")
        }
    }

    private var actionRow: some View {
        HStack(spacing: 18) {
            actionButton(title: "Ingreso", icon: "arrow.down.left", action: onAddIncome)
            actionButton(title: "Gasto", icon: "arrow.up.right", action: onAddExpense)
            actionButton(title: "Escanear", icon: "viewfinder", action: onScanReceipt)
            actionButton(title: "Asistente", icon: "sparkles", action: { showAssistant = true })
        }
    }

    private var highlightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plan inteligente")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("7 días")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }

            Text("Ajusta gastos y alcanza tu meta mensual")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Recibe alertas sobre categorías con mayor variación.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.65))

            Button(action: {}) {
                Text("Ver recomendaciones")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(dashboardAccent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardSurface)
    }

    private var expensesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gastos por categoría")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if expenseSlices.isEmpty {
                Text("Sin gastos para \(selectedCurrency.rawValue).")
                    .foregroundStyle(Color.white.opacity(0.6))
            } else {
                PieChartView(slices: expenseSlices, centerColor: dashboardSurface)
                    .frame(height: 200)

                VStack(spacing: 10) {
                    ForEach(expenseSlices.prefix(4)) { slice in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 10, height: 10)
                            Text(slice.name)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.7))
                            Spacer()
                            Text(slice.value, format: .currency(code: selectedCurrency.rawValue))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(cardSurface)
    }

    private var movementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Movimientos recientes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                movementFilterPills
            }

            if displayedTransactions.isEmpty {
                Text("Aún no hay movimientos para esta moneda.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.6))
            } else {
                VStack(spacing: 10) {
                    ForEach(displayedTransactions) { transaction in
                        transactionRow(for: transaction)
                    }
                }
            }
        }
        .padding(18)
        .background(cardSurface)
    }

    private var currencyPills: some View {
        HStack(spacing: 6) {
            ForEach(Currency.allCases) { currency in
                Button {
                    selectedCurrency = currency
                } label: {
                    Text(currency.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedCurrency == currency ? .white : Color.white.opacity(0.55))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(selectedCurrency == currency ? dashboardAccent.opacity(0.35) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rangePills: some View {
        HStack(spacing: 8) {
            ForEach(DateRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedRange == range ? .white : Color.white.opacity(0.55))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? dashboardAccent.opacity(0.35) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var movementFilterPills: some View {
        HStack(spacing: 6) {
            ForEach(MovementFilter.allCases) { filter in
                Button {
                    selectedMovementFilter = filter
                } label: {
                    Text(filter.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedMovementFilter == filter ? .white : Color.white.opacity(0.55))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(selectedMovementFilter == filter ? dashboardAccent.opacity(0.35) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var deltaBadge: some View {
        let deltaText = balanceDeltaText(for: filteredEntries)
        let percentage = balanceDeltaPercentage(for: filteredEntries)
        let color = balanceDeltaColor(for: filteredEntries)
        let symbol = balanceDeltaSymbol(for: filteredEntries)
        let hasReference = filteredEntries.count > 1 && filteredEntries.first?.value != 0
        return HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.bold())
            Text(hasReference ? "\(deltaText) (\(percentage.formatted(.percent.precision(.fractionLength(1)))))" : deltaText)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(color.opacity(0.18))
        )
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(dashboardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [dashboardAccent, dashboardAccent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: dashboardAccent.opacity(0.35), radius: 10, y: 6)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private func transactionRow(for transaction: Transaction) -> some View {
        let category = categoryFor(transaction)
        let isIncome = transaction.type == .income
        let amountText = transaction.amount.formatted(.currency(code: selectedCurrency.rawValue))
        let signedAmount = isIncome ? "+\(amountText)" : "-\(amountText)"

        return HStack(spacing: 12) {
            Circle()
                .fill(category?.color ?? Color(.systemGray4))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: category?.icon ?? "tag.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.subcategoryName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(transaction.description.isEmpty ? transaction.categoryName : transaction.description)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.6))
                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(Color.white.opacity(0.45))
            }

            Spacer()

            Text(signedAmount)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isIncome ? Color(red: 0.20, green: 0.82, blue: 0.62) : Color(red: 0.96, green: 0.46, blue: 0.46))
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button {
                repeatTransaction(transaction)
            } label: {
                Label("Repetir", systemImage: "arrow.clockwise")
            }
        }
    }

    private func variationSummary(for entries: [FinanceEntry]) -> some View {
        let hasReference = entries.count > 1 && entries.first?.value != 0
        let text = hasReference ? "Últimos \(selectedRange.lengthInDays) días" : "Sin variación reciente"
        return Text(text)
            .font(.caption)
            .foregroundStyle(Color.white.opacity(0.6))
    }

    private var displayedTransactions: [Transaction] {
        let base: [Transaction]
        switch selectedMovementFilter {
        case .all:
            base = filteredTransactions
        case .incomes:
            base = filteredTransactions.filter { $0.type == .income }
        case .expenses:
            base = filteredTransactions.filter { $0.type == .expense }
        }
        return Array(base.sorted { $0.date > $1.date }.prefix(8))
    }

    private func categoryFor(_ transaction: Transaction) -> TransactionCategory? {
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
            subitems: transaction.subitems
        )
        transactionManager.addTransaction(repeated)
        walletManager.syncWalletBalance(for: transaction.walletId)
    }

    private func showRepeatError(_ message: String) {
        repeatErrorMessage = message
        isShowingRepeatError = true
    }

    private enum MovementFilter: String, CaseIterable, Identifiable {
        case all
        case incomes
        case expenses

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .incomes: return "Ingresos"
            case .expenses: return "Gastos"
            }
        }
    }

    private func balanceDeltaPercentage(for entries: [FinanceEntry]) -> Double {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value, firstValue != 0 else {
            return 0
        }
        return (lastValue - firstValue) / firstValue
    }

    private func balanceDeltaSymbol(for entries: [FinanceEntry]) -> String {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value else {
            return "minus"
        }
        let delta = lastValue - firstValue
        if delta > 0 { return "arrow.up.right" }
        if delta < 0 { return "arrow.down.right" }
        return "minus"
    }

    private func balanceDeltaText(for entries: [FinanceEntry]) -> String {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value else {
            return "Sin variación reciente"
        }
        let delta = lastValue - firstValue
        let formatted = delta.magnitude.formatted(.currency(code: selectedCurrency.rawValue))
        let prefix = delta == 0 ? "" : delta > 0 ? "+" : "-"
        return "\(prefix)\(formatted)"
    }

    private func balanceDeltaColor(for entries: [FinanceEntry]) -> Color {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value else {
            return .secondary
        }
        let delta = lastValue - firstValue
        if delta > 0 {
            return Color(red: 0.20, green: 0.60, blue: 0.46)
        } else if delta < 0 {
            return Color(red: 0.86, green: 0.33, blue: 0.33)
        } else {
            return .secondary
        }
    }

    private var expenseSlices: [PieSliceData] {
        let expenses = filteredTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: { $0.categoryId })
        let slices: [PieSliceData] = grouped.compactMap { key, transactions in
            let total = transactions.reduce(0) { $0 + $1.amount }
            guard total > 0 else { return nil as PieSliceData? }
            let category = categoryManager.expenseCategories.first { $0.id == key }
            return PieSliceData(
                name: category?.name ?? "Otros",
                value: total,
                color: category?.color ?? Color(.systemGray4)
            )
        }
        return slices.sorted { $0.value > $1.value }
    }

    fileprivate struct PieSliceData: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let color: Color
    }

    private enum HomeTab: String, CaseIterable, Identifiable {
        case home
        case budgets
        case goals
        case wallets

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: return "Home"
            case .budgets: return "Presupuestos"
            case .goals: return "Metas"
            case .wallets: return "Carteras"
            }
        }
    }

    private let dashboardSurface = Color(red: 0.07, green: 0.10, blue: 0.18)
    private let dashboardAccent = Color(red: 0.10, green: 0.55, blue: 1.0)
}

private struct PieChartView: View {
    let slices: [FinanceDashboardView.PieSliceData]
    let centerColor: Color

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2
            let total = slices.reduce(0) { $0 + $1.value }

            ZStack {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    let startAngle = angle(for: slices, index: index, total: total)
                    let endAngle = angle(for: slices, index: index + 1, total: total)
                    PieSliceShape(startAngle: startAngle, endAngle: endAngle)
                        .fill(slice.color)
                }

                Circle()
                    .fill(centerColor)
                    .frame(width: radius * 0.6, height: radius * 0.6)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .position(center)
        }
    }

    private func angle(for slices: [FinanceDashboardView.PieSliceData], index: Int, total: Double) -> Angle {
        guard total > 0 else { return .degrees(0) }
        let sum = slices.prefix(index).reduce(0) { $0 + $1.value }
        return .degrees((sum / total) * 360.0 - 90)
    }
}

private struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct DashboardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.05, green: 0.08, blue: 0.16),
                    Color(red: 0.07, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(red: 0.15, green: 0.28, blue: 0.55).opacity(0.35), Color.clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 320
            )
            .offset(x: -60, y: -120)

            RadialGradient(
                colors: [Color(red: 0.12, green: 0.45, blue: 0.80).opacity(0.25), Color.clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 300
            )
            .offset(x: 100, y: 80)

            Group {
                Circle().fill(Color.white.opacity(0.25)).frame(width: 2, height: 2).offset(x: -120, y: -220)
                Circle().fill(Color.white.opacity(0.18)).frame(width: 3, height: 3).offset(x: 140, y: -180)
                Circle().fill(Color.white.opacity(0.22)).frame(width: 2, height: 2).offset(x: -40, y: -40)
                Circle().fill(Color.white.opacity(0.18)).frame(width: 2, height: 2).offset(x: 160, y: 60)
                Circle().fill(Color.white.opacity(0.22)).frame(width: 3, height: 3).offset(x: -160, y: 140)
            }
        }
        .ignoresSafeArea()
    }
}
