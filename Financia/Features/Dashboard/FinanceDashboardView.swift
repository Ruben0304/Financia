import SwiftUI
import UIKit

struct FinanceDashboardView: View {
    @Binding var selectedRange: DateRange
    var onAddIncome: () -> Void = {}
    var onAddExpense: () -> Void = {}
    var onScanReceipt: () -> Void = {}

    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var automatedDraftManager: AutomatedDraftManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var categoryManager: CategoryManager
    @EnvironmentObject var debtManager: DebtManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var wealthManager: WealthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager

    @State private var selectedCurrency: Currency = .cup
    @State private var didSetInitialCurrency: Bool = false
    @State private var showAssistant: Bool = false
    @AppStorage("financeDashboard.isBalanceHidden") private var isBalanceHidden: Bool = false
    @State private var isTransferring: Bool = false
    @State private var isShowingTimeline: Bool = false
    @State private var isShowingFinancialBreathing: Bool = false
    @State private var draftNameEdits: [UUID: String] = [:]
    @State private var selectedDraftForCompletion: AutomatedTransactionDraft?

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

    private var totalDamagedBills: Double {
        walletManager.wallets
            .filter { $0.currency == selectedCurrency }
            .reduce(0) { $0 + $1.totalBillesDañados }
    }

    private var remainingAfterGoals: Double {
        currentBalance - savingsGoalManager.totalProjectedCurrentReservation(
            in: selectedCurrency,
            availableCurrent: currentBalance
        )
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

    private var visibleDrafts: [AutomatedTransactionDraft] {
        automatedDraftManager.drafts.filter { $0.currency == selectedCurrency }
    }

  
    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        balanceCard
                        automatedDraftsSection
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
        .sheet(isPresented: $isShowingTimeline) {
            FinancialTimelineSheet(currency: selectedCurrency)
        }
        .sheet(isPresented: $isShowingFinancialBreathing) {
            FinancialBreathingSheet()
        }
        .sheet(item: $selectedDraftForCompletion) { draft in
            AddEntrySheet(
                kind: draft.type == .income ? .income : .expense,
                prefill: automatedDraftManager.prefill(for: draft),
                allowsEntryTypeToggle: false,
                preferredWalletId: profileManager.profile.automationWalletId
            ) { _ in
                automatedDraftManager.deleteDraft(id: draft.id)
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

    // MARK: - Header
    private var headerLeadingSimple: some View {
        HStack(spacing: 12) {
            profileAvatar

            Text("Hola, \(userName)")
                .font(DarkFinanceTypography.emphasis(size: 14))
                .foregroundColor(DarkFinanceColors.primaryText)
        }
        .frame(width: 140)
    }

    private var profileAvatar: some View {
        Group {
            if let avatarData = profileManager.profile.avatarData,
               let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(accentGradient)

                    Text(initials)
                        .font(DarkFinanceTypography.emphasis(size: 16))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 35, height: 35)
        .clipShape(Circle())
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
                    .font(DarkFinanceTypography.body(size: 14))
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

            // Indicador de billetes dañados
            if !isBalanceHidden && totalDamagedBills > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "F59E0B"))
                    Text("Billetes dañados: -\(totalDamagedBills.formatted(.currency(code: selectedCurrency.rawValue)))")
                        .font(DarkFinanceTypography.caption(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "F59E0B"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(hex: "F59E0B").opacity(0.12))
                )
            }

            if !isBalanceHidden {
                Text("Restante después de metas: \(remainingAfterGoals, format: .currency(code: selectedCurrency.rawValue))")
                    .font(DarkFinanceTypography.body(size: 13))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            // Change indicator
            HStack {
                if balanceChange != 0 {
                    HStack(spacing: 8) {
                        Image(systemName: balanceChange > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%+.1f%% este mes", balanceChangePercent))
                            .font(DarkFinanceTypography.action(size: 13))
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

    private var automatedDraftsSection: some View {
        Group {
            if !visibleDrafts.isEmpty {
                VStack(spacing: 14) {
                    ForEach(visibleDrafts) { draft in
                        automatedDraftRow(draft)
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsRow: some View {
        VStack(spacing: 12) {
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

            Button {
                isShowingTimeline = true
            } label: {
                dashboardFeatureButton(
                    title: "Timeline financiero",
                    subtitle: "Próximos cobros, pagos y cierre estimado",
                    icon: "calendar.badge.clock",
                    iconBackground: accentGradient,
                    arrowColor: accentColor
                )
            }
            .buttonStyle(.plain)

            Button {
                isShowingFinancialBreathing = true
            } label: {
                dashboardFeatureButton(
                    title: "Respiración financiera",
                    subtitle: "Cuánto aguanta cada cartera hasta tu próximo cobro",
                    icon: "wind",
                    iconBackground: LinearGradient(
                        colors: [Color(hex: "0EA5E9"), Color(hex: "22C55E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    arrowColor: Color(hex: "22C55E")
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func dashboardFeatureButton(
        title: String,
        subtitle: String,
        icon: String,
        iconBackground: LinearGradient,
        arrowColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(DarkFinanceTypography.emphasis(size: 15))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(subtitle)
                            .font(DarkFinanceTypography.caption())
                            .foregroundColor(DarkFinanceColors.secondaryText)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(arrowColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DarkFinanceColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                )
        )
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

    private func automatedDraftRow(_ draft: AutomatedTransactionDraft) -> some View {
        let editedName = draftNameBinding(for: draft)
        let title = editedName.wrappedValue.isEmpty ? draft.resolvedName : editedName.wrappedValue

        return IntelligenceDraftCard(
            draft: draft,
            name: editedName,
            onSaveName: {
                saveDraftNameIfNeeded(for: draft)
            },
            onComplete: {
                saveDraftNameIfNeeded(for: draft)
                selectedDraftForCompletion = refreshedDraft(for: draft, fallbackTitle: title)
            },
            onDiscard: {
                automatedDraftManager.deleteDraft(id: draft.id)
                draftNameEdits[draft.id] = nil
            }
        )
    }

    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transacciones Recientes")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                Button {
                    // Navigate to all transactions
                } label: {
                    Text("Ver todo")
                        .font(DarkFinanceTypography.action())
                        .foregroundColor(accentColor)
                }
            }

            if recentTransactions.isEmpty {
                Text("No hay transacciones recientes")
                    .font(DarkFinanceTypography.body())
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
                    CategoryIconView(icon: category?.icon ?? "tag.fill", color: .white, size: 18)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.subcategoryName)
                    .font(DarkFinanceTypography.emphasis(size: 14))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(DarkFinanceTypography.caption())
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

    private func draftNameBinding(for draft: AutomatedTransactionDraft) -> Binding<String> {
        Binding(
            get: {
                draftNameEdits[draft.id] ?? draft.suggestedName ?? ""
            },
            set: { newValue in
                draftNameEdits[draft.id] = newValue
            }
        )
    }

    private func saveDraftNameIfNeeded(for draft: AutomatedTransactionDraft) {
        let editedName = draftNameEdits[draft.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard editedName != (draft.suggestedName ?? "") else { return }
        automatedDraftManager.updateSuggestedName(for: draft.id, name: editedName)
    }

    private func refreshedDraft(for draft: AutomatedTransactionDraft, fallbackTitle: String) -> AutomatedTransactionDraft {
        if let updated = automatedDraftManager.drafts.first(where: { $0.id == draft.id }) {
            return updated
        }

        var copy = draft
        copy.suggestedName = fallbackTitle
        return copy
    }
}

private struct IntelligenceDraftCard: View {
    let draft: AutomatedTransactionDraft
    @Binding var name: String
    let onSaveName: () -> Void
    let onComplete: () -> Void
    let onDiscard: () -> Void

    private var palette: [Color] {
        if draft.type == .income {
            return [
                Color(hex: "F59E0B"),
                Color(hex: "84CC16"),
                Color(hex: "22C55E"),
                Color(hex: "06B6D4")
            ]
        }

        return [
            Color(hex: "F97316"),
            Color(hex: "EF4444"),
            Color(hex: "EC4899"),
            Color(hex: "8B5CF6")
        ]
    }

    private var amountColor: Color {
        draft.type == .income ? DarkFinanceColors.successGreen : Color(hex: "FB7185")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.sourceKind.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(draft.occurredAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                }

                Spacer()

                Text((draft.type == .income ? "+" : "-") + draft.amount.formatted(.currency(code: draft.currency.rawValue)))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(amountColor)
            }

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: draft.sourceKind.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Borrador detectado")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                    if let note = draft.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
            }

            TextField("Nombre del borrador", text: $name)
                .textInputAutocapitalization(.words)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                )

            if !draft.rawMessage.isEmpty {
                Text(draft.rawMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.black.opacity(0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
                    )
            }

            HStack(spacing: 10) {
                Button(action: onSaveName) {
                    Text("Guardar nombre")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onComplete) {
                    Text(draft.type == .income ? "Agregar ingreso" : "Agregar gasto")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: onDiscard) {
                Text("Descartar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.58))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(
            AIGlassBackground(colors: palette)
        )
    }
}
