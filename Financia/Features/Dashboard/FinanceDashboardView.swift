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
    @EnvironmentObject var profileManager: ProfileManager

    @State private var selectedCurrency: Currency = .cup
    @State private var didSetInitialCurrency: Bool = false
    @State private var showAssistant: Bool = false
    @State private var isBalanceHidden: Bool = false
    @State private var isTransferring: Bool = false

    init(
        selectedRange: Binding<DateRange>,
        onAddIncome: @escaping () -> Void = {},
        onAddExpense: @escaping () -> Void = {},
        onScanReceipt: @escaping () -> Void = {}
    ) {
        self._selectedRange = selectedRange
        self.onAddIncome = onAddIncome
        self.onAddExpense = onAddExpense
        self.onScanReceipt = onScanReceipt
    }

    private var currentBalance: Double {
        let wallets = walletManager.wallets.filter { $0.currency == selectedCurrency }
        return wallets.reduce(0) { $0 + walletManager.calculateBalance(for: $1) }
    }

    private var accentColor: Color {
        Color(hex: profileManager.profile.accentColorHex ?? "FF5C00")
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    private var recentTransactions: [Transaction] {
        Array(filteredTransactions.sorted { $0.date > $1.date }.prefix(4))
    }

    private var balanceChange: Double {
        totalIncome - totalExpenses
    }

    private var balanceChangePercent: Double {
        guard totalExpenses > 0 else { return 0 }
        return (balanceChange / totalExpenses) * 100
    }

  
    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        balanceCard
                        quickActionsRow
                        transactionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
           
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        headerLeadingSimple
                    }.sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        headerLeadingSimple
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    headerTrailing
                }
            }
        }
        .onAppear {
            if !didSetInitialCurrency, let firstWallet = walletManager.wallets.first {
                selectedCurrency = firstWallet.currency
                didSetInitialCurrency = true
            }
        }
        .sheet(isPresented: $isTransferring) {
            TransferView()
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

    // MARK: - Header
    private var headerLeadingSimple: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accentGradient)
                .frame(width: 35, height: 35)
                .overlay(
                    Text(initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            Text("Hola, \(userName)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)
        }
        .frame(width: 140)
    }

    private var headerTrailing: some View {
        HStack(spacing: 16) {
            Button {
                showAssistant = true
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            NavigationLink(destination: SavingsGoalsView()) {
                Image(systemName: "circle.circle")
                    .font(.system(size: 20))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }
        }
    }

    private var userName: String {
        let name = profileManager.profile.nombre
        return name.isEmpty ? "Usuario" : name
    }

    private var initials: String {
        let name = profileManager.profile.nombre
        if name.isEmpty { return "U" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Balance Card
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Balance Total label with eye icon
            HStack {
                Text("Balance Total")
                    .font(.system(size: 14))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                Spacer()
                Button {
                    isBalanceHidden.toggle()
                } label: {
                    Image(systemName: isBalanceHidden ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundColor(DarkFinanceColors.tertiaryText)
                }
                .buttonStyle(.plain)
            }

            // Amount
            Group {
                if isBalanceHidden {
                    Text("••••")
                } else {
                    Text(currentBalance, format: .currency(code: selectedCurrency.rawValue))
                }
            }
            .font(DarkFinanceTypography.monoAmount(size: 36, weight: .medium))
            .foregroundColor(DarkFinanceColors.primaryText)

            // Change indicator
            HStack {
                if balanceChange != 0 {
                    HStack(spacing: 8) {
                        Image(systemName: balanceChange > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%+.1f%% este mes", balanceChangePercent))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(balanceChange > 0 ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill((balanceChange > 0 ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed).opacity(0.15))
                    )
                }
                Spacer()
                Picker("", selection: $selectedCurrency) {
                    Text("CUP").tag(Currency.cup)
                    Text("USD").tag(Currency.usd)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 24)
    }

    // MARK: - Quick Actions
    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            actionButton(title: "Ingreso", icon: "arrow.down.circle.fill", isPrimary: true) {
                onAddIncome()
            }
            actionButton(title: "Gasto", icon: "arrow.up.circle.fill") {
                onAddExpense()
            }
            actionButton(title: "Transfer", icon: "arrow.left.arrow.right") {
                isTransferring = true
            }
            actionButton(title: "Escanear", icon: "doc.viewfinder") {
                onScanReceipt()
            }
        }
    }

    private func actionButton(title: String, icon: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isPrimary ? accentGradient : LinearGradient(colors: [Color(hex: "1A1A1D")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DarkFinanceColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transacciones Recientes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                Button {
                    // Navigate to all transactions
                } label: {
                    Text("Ver todo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(accentColor)
                }
            }

            if recentTransactions.isEmpty {
                Text("No hay transacciones recientes")
                    .font(.system(size: 14))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentTransactions) { transaction in
                        transactionRow(transaction)
                    }
                }
            }
        }
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        let category = categoryFor(transaction)
        let isIncome = transaction.type == .income

        return HStack(spacing: 14) {
            // Icon
            Circle()
                .fill(isIncome ? DarkFinanceColors.successGreen : accentColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: category?.icon ?? "tag.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.subcategoryName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            Spacer()

            Text((isIncome ? "+" : "") + transaction.amount.formatted(.currency(code: selectedCurrency.rawValue)))
                .font(DarkFinanceTypography.monoAmount(size: 14, weight: .semibold))
                .foregroundColor(isIncome ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DarkFinanceColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                )
        )
    }

    private func categoryFor(_ transaction: Transaction) -> TransactionCategory? {
        if transaction.type == .income {
            return categoryManager.incomeCategories.first { $0.id == transaction.categoryId }
        }
        return categoryManager.expenseCategories.first { $0.id == transaction.categoryId }
    }
}
