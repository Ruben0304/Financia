import SwiftUI

struct TransferView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var exchangeRateManager: ExchangeRateManager

    @State private var fromWalletId: UUID?
    @State private var toWalletId: UUID?
    @State private var amountText: String = ""
    @State private var rateText: String = ""
    @State private var noteText: String = ""
    @State private var errorMessage: String?
    @State private var isShowingError: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Carteras") {
                    walletSelector

                    if walletManager.wallets.count < 2 {
                        Text("Necesitas al menos dos carteras para transferir.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Monto") {
                    TextField("Monto a transferir", text: $amountText)
                        .keyboardType(.decimalPad)

                    HStack {
                        Text("Recibirás")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formattedAmountTo)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if shouldShowRate {
                    Section("Tasa de cambio") {
                        HStack {
                            Text("1 \(fromCurrency.rawValue)")
                            Spacer()
                            TextField("Tasa", text: $rateText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text(toCurrency.rawValue)
                        }

                        if let suggested = suggestedRateText {
                            HStack {
                                Text("Sugerido")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Usar \(suggested)") {
                                    rateText = suggested
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                Section("Nota") {
                    TextField("Opcional", text: $noteText)
                }
            }
            .navigationTitle("Transferir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Transferir")
                        .darkFinanceToolbarTitle(size: 22)
                        .foregroundColor(DarkFinanceColors.primaryText)
                }

                ToolbarItem(placement: .subtitle) {
                    Text("Mueve saldo entre carteras y ajusta la tasa si hace falta")
                        .darkFinanceToolbarSubtitle(size: 12, weight: .medium)
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        performTransfer()
                    }
                    .disabled(!canTransfer)
                }
            }
            .alert("No se pudo transferir", isPresented: $isShowingError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(errorMessage ?? "Revisa los datos e intenta de nuevo.")
            })
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .onAppear {
                setDefaultWallets()
                updateSuggestedRate()
            }
            .onChange(of: fromWalletId) { _, _ in
                ensureDifferentWallets()
                updateSuggestedRate()
            }
            .onChange(of: toWalletId) { _, _ in
                ensureDifferentWallets()
                updateSuggestedRate()
            }
        }
    }

    private var walletSelector: some View {
        ZStack {
            VStack(spacing: 12) {
                walletRow(title: "Origen", walletId: $fromWalletId)
                Divider()
                walletRow(title: "Destino", walletId: $toWalletId)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            Button {
                swapWallets()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color(.systemBackground), in: Circle())
                    .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
            }
            .disabled(walletManager.wallets.count < 2)
        }
    }

    private func walletRow(title: String, walletId: Binding<UUID?>) -> some View {
        let selectedWallet = walletId.wrappedValue.flatMap { walletManager.wallet(withId: $0) }

        return Menu {
            ForEach(walletManager.wallets) { wallet in
                Button {
                    walletId.wrappedValue = wallet.id
                } label: {
                    HStack {
                        Text(wallet.name)
                        Spacer()
                        Text(wallet.currency.rawValue)
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedWallet?.name ?? "Selecciona cartera")
                        .font(.headline)
                }

                Spacer()

                Text(selectedWallet?.currency.rawValue ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    private var fromCurrency: Currency {
        walletManager.wallet(withId: fromWalletId ?? UUID())?.currency ?? .usd
    }

    private var toCurrency: Currency {
        walletManager.wallet(withId: toWalletId ?? UUID())?.currency ?? .cup
    }

    private var shouldShowRate: Bool {
        fromCurrency != toCurrency
    }

    private var canTransfer: Bool {
        guard walletManager.wallets.count >= 2 else { return false }
        guard fromWalletId != nil, toWalletId != nil else { return false }
        guard fromWalletId != toWalletId else { return false }
        guard parseAmount(amountText) > 0 else { return false }
        if shouldShowRate {
            return parseAmount(rateText) > 0
        }
        return true
    }

    private var formattedAmountTo: String {
        let amount = parseAmount(amountText)
        if amount <= 0 {
            return "--"
        }
        let result = shouldShowRate ? amount * max(parseAmount(rateText), 0) : amount
        return result.formatted(.currency(code: toCurrency.rawValue))
    }

    private var suggestedRateText: String? {
        guard shouldShowRate else { return nil }
        guard let rate = suggestedRate(for: fromCurrency, to: toCurrency) else { return nil }
        return formattedRate(rate)
    }

    private func setDefaultWallets() {
        guard walletManager.wallets.count >= 2 else { return }
        if fromWalletId == nil {
            fromWalletId = walletManager.wallets.first?.id
        }
        if toWalletId == nil {
            let fallback = walletManager.wallets.first { $0.id != fromWalletId }
            toWalletId = fallback?.id
        }
    }

    private func ensureDifferentWallets() {
        guard let fromId = fromWalletId else { return }
        if fromId == toWalletId {
            toWalletId = walletManager.wallets.first { $0.id != fromId }?.id
        }
    }

    private func swapWallets() {
        let temp = fromWalletId
        fromWalletId = toWalletId
        toWalletId = temp
    }

    private func updateSuggestedRate() {
        guard shouldShowRate else {
            rateText = ""
            return
        }
        rateText = suggestedRateText ?? ""
    }

    private func suggestedRate(for from: Currency, to: Currency) -> Double? {
        if let converted = exchangeRateManager.convert(amount: 1, from: from, to: to) {
            return converted
        }
        if from == .usd && to == .cup {
            return exchangeRateManager.effectiveUsdToCupRate()
        }
        if from == .cup && to == .usd, let rate = exchangeRateManager.effectiveUsdToCupRate() {
            return 1 / rate
        }
        return nil
    }

    private func performTransfer() {
        guard let fromWalletId, let toWalletId else {
            showError("Selecciona carteras válidas.")
            return
        }
        guard fromWalletId != toWalletId else {
            showError("Selecciona carteras diferentes.")
            return
        }
        guard let fromWallet = walletManager.wallet(withId: fromWalletId),
              let toWallet = walletManager.wallet(withId: toWalletId) else {
            showError("Carteras inválidas.")
            return
        }

        let amountFrom = parseAmount(amountText)
        guard amountFrom > 0 else {
            showError("Ingresa un monto válido.")
            return
        }

        let availableBalance = walletManager.calculateBalance(for: fromWallet)
        guard amountFrom <= availableBalance else {
            showError("El saldo de la cartera origen no es suficiente.")
            return
        }

        let rate = shouldShowRate ? parseAmount(rateText) : 1
        guard rate > 0 else {
            showError("Ingresa una tasa válida.")
            return
        }

        let amountTo = shouldShowRate ? amountFrom * rate : amountFrom
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rateNote = shouldShowRate ? " (1 \(fromWallet.currency.rawValue) = \(formattedRate(rate)) \(toWallet.currency.rawValue))" : ""
        let outgoingDescription = "Transferencia a \(toWallet.name)\(rateNote)" + (note.isEmpty ? "" : " - \(note)")
        let incomingDescription = "Transferencia desde \(fromWallet.name)\(rateNote)" + (note.isEmpty ? "" : " - \(note)")

        let (expenseCategory, expenseSub) = ensureTransferCategory(isIncome: false)
        let (incomeCategory, incomeSub) = ensureTransferCategory(isIncome: true)

        let now = Date()
        let outgoing = Transaction(
            type: .expense,
            amount: amountFrom,
            date: now,
            categoryId: expenseCategory.id,
            categoryName: expenseCategory.name,
            subcategoryId: expenseSub.id,
            subcategoryName: expenseSub.name,
            description: outgoingDescription,
            walletId: fromWalletId
        )

        let incoming = Transaction(
            type: .income,
            amount: amountTo,
            date: now,
            categoryId: incomeCategory.id,
            categoryName: incomeCategory.name,
            subcategoryId: incomeSub.id,
            subcategoryName: incomeSub.name,
            description: incomingDescription,
            walletId: toWalletId
        )

        transactionManager.addTransaction(outgoing)
        transactionManager.addTransaction(incoming)
        dismiss()
    }

    private func ensureTransferCategory(isIncome: Bool) -> (TransactionCategory, Subcategory) {
        let categoryName = "Transferencias"
        let subName = isIncome ? "Entrada" : "Salida"
        let categories = isIncome ? categoryManager.incomeCategories : categoryManager.expenseCategories

        if let existing = categories.first(where: { $0.name == categoryName }) {
            if let sub = existing.subcategories.first(where: { $0.name == subName }) {
                return (existing, sub)
            }

            let newSub = Subcategory(name: subName)
            categoryManager.addSubcategory(newSub, to: existing, isIncome: isIncome)
            return (existing, newSub)
        }

        let newSub = Subcategory(name: subName)
        let newCategory = TransactionCategory(
            name: categoryName,
            subcategories: [newSub],
            icon: "arrow.left.arrow.right.circle.fill",
            color: .blue
        )

        if isIncome {
            categoryManager.addIncomeCategory(newCategory)
        } else {
            categoryManager.addExpenseCategory(newCategory)
        }

        return (newCategory, newSub)
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }

    private func parseAmount(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private func formattedRate(_ value: Double) -> String {
        if value < 1 {
            return String(format: "%.4f", value)
        }
        return String(format: "%.2f", value)
    }
}

#Preview {
    TransferView()
        .environmentObject(WalletManager.shared)
        .environmentObject(TransactionManager.shared)
        .environmentObject(CategoryManager.shared)
        .environmentObject(ExchangeRateManager.shared)
}
