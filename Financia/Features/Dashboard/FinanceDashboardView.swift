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

    private var remainingPercentageText: String {
        guard currentBalance > 0 else { return "--" }
        let ratio = (remainingAfterDebt / currentBalance) - 1
        return ratio.formatted(.percent.precision(.fractionLength(1)))
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
            List {
                Section("Moneda") {
                    Picker("Moneda", selection: $selectedCurrency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Resumen") {
                    summarySection
                }

                Section("Gastos por categoría") {
                    expensesPieSection
                }

                Section("Movimientos recientes") {
                    movementFilterPicker

                    ForEach(displayedTransactions) { transaction in
                        transactionRow(for: transaction)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Resumen")
            .scrollDismissesKeyboard(.interactively)
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

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentBalance, format: .currency(code: selectedCurrency.rawValue))
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingresos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalIncome, format: .currency(code: selectedCurrency.rawValue))
                        .font(.subheadline.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gastos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalExpenses, format: .currency(code: selectedCurrency.rawValue))
                        .font(.subheadline.weight(.semibold))
                }
            }

            HStack(spacing: 8) {
                Text("Después de deuda: \(remainingAfterDebt.formatted(.currency(code: selectedCurrency.rawValue)))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(remainingColor)
                Text(remainingPercentageText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(remainingColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(remainingColor)
                Button {
                    showDebtInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }

            Picker("Intervalo", selection: $selectedRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            variationSummary(for: filteredEntries)
        }
        .alert("Detalle de deuda", isPresented: $showDebtInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Deuda total: \(totalDebtForCurrency.formatted(.currency(code: selectedCurrency.rawValue)))\nSaldo actual: \(currentBalance.formatted(.currency(code: selectedCurrency.rawValue)))\nRestante: \(remainingAfterDebt.formatted(.currency(code: selectedCurrency.rawValue)))")
        }
    }

    private var expensesPieSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if expenseSlices.isEmpty {
                Text("Sin gastos para \(selectedCurrency.rawValue).")
                    .foregroundStyle(.secondary)
            } else {
                PieChartView(slices: expenseSlices)
                    .frame(height: 220)

                VStack(spacing: 8) {
                    ForEach(expenseSlices) { slice in
                        HStack {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 10, height: 10)
                            Text(slice.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(slice.value, format: .currency(code: selectedCurrency.rawValue))
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func variationSummary(for entries: [FinanceEntry]) -> some View {
        let deltaText = balanceDeltaText(for: entries)
        let percentage = balanceDeltaPercentage(for: entries)
        let color = balanceDeltaColor(for: entries)
        let symbol = balanceDeltaSymbol(for: entries)
        let hasReference = entries.count > 1 && entries.first?.value != 0
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(8)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                if hasReference {
                    Text("\(deltaText) (\(percentage.formatted(.percent.precision(.fractionLength(2)))))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                } else {
                    Text(deltaText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }

                Text("Últimos \(selectedRange.lengthInDays) días")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var movementFilterPicker: some View {
        Picker("Filtro", selection: $selectedMovementFilter) {
            ForEach(MovementFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var quickActions: some View {
        HStack(spacing: 14) {
            quickActionButton(
                title: "Agregar ingreso",
                subtitle: "Deposita al instante",
                icon: "arrow.down.left.circle.fill",
                isEmphasized: false,
                action: onAddIncome
            )

            quickActionButton(
                title: "Registrar gasto",
                subtitle: "Controla tu flujo",
                icon: "arrow.up.right.circle.fill",
                isEmphasized: true,
                action: onAddExpense
            )
        }
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        icon: String,
        isEmphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let backgroundGradient = LinearGradient(
            colors: isEmphasized
                ? [
                    Color(red: 0.74, green: 0.44, blue: 0.99),
                    Color(red: 0.45, green: 0.34, blue: 0.98)
                ]
                : [
                    Color.white.opacity(0.55),
                    Color.white.opacity(0.55)
                ],
            startPoint: .leading,
            endPoint: .trailing
        )

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isEmphasized ? Color.white : .primary)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(isEmphasized ? 0.25 : 0.35))
                    )

                Text(title)
                    .font(.headline)
                    .foregroundStyle(isEmphasized ? Color.white : .primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isEmphasized ? Color.white.opacity(0.85) : .secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(backgroundGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .shadow(
            color: isEmphasized ? Color(red: 0.58, green: 0.43, blue: 0.95).opacity(0.35) : Color.black.opacity(0.05),
            radius: isEmphasized ? 20 : 12,
            y: isEmphasized ? 14 : 8
        )
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
                Text(transaction.description.isEmpty ? transaction.categoryName : transaction.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(signedAmount)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isIncome ? Color(red: 0.20, green: 0.60, blue: 0.46) : Color(red: 0.86, green: 0.33, blue: 0.33))
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
}

private struct PieChartView: View {
    let slices: [FinanceDashboardView.PieSliceData]

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
                    .fill(Color(.systemBackground))
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
