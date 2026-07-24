import SwiftUI

struct TransferView: View {
    /// When true, the form opens pre-selecting two wallets of different
    /// currencies, so it lands directly as a "Cambio de divisa".
    var startInExchangeMode: Bool = false

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
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text(screenTitle)
                        .darkFinanceToolbarTitle(size: 22)
                        .foregroundColor(DarkFinanceColors.primaryText)
                }

                ToolbarItem(placement: .subtitle) {
                    Text(screenSubtitle)
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

    /// A cross-currency move is, natively, a currency exchange.
    private var isExchange: Bool { shouldShowRate }

    private var screenTitle: String { isExchange ? "Cambio de divisa" : "Transferir" }

    private var screenSubtitle: String {
        isExchange
            ? "Convierte entre monedas aplicando la tasa"
            : "Mueve saldo entre carteras"
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
            if startInExchangeMode, let from = fromWalletId,
               let fromCur = walletManager.wallet(withId: from)?.currency {
                let differentCurrency = walletManager.wallets.first { $0.id != from && $0.currency != fromCur }
                let anyOther = walletManager.wallets.first { $0.id != from }
                toWalletId = (differentCurrency ?? anyOther)?.id
            } else {
                let fallback = walletManager.wallets.first { $0.id != fromWalletId }
                toWalletId = fallback?.id
            }
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

        let isExchange = fromWallet.currency != toWallet.currency
        let rate = isExchange ? parseAmount(rateText) : 1
        guard rate > 0 else {
            showError("Ingresa una tasa válida.")
            return
        }

        let amountTo = isExchange ? amountFrom * rate : amountFrom
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rateNote = isExchange ? " (1 \(fromWallet.currency.rawValue) = \(formattedRate(rate)) \(toWallet.currency.rawValue))" : ""
        let verb = isExchange ? "Cambio de divisa" : "Transferencia"
        let outgoingDescription = "\(verb) a \(toWallet.name)\(rateNote)" + (note.isEmpty ? "" : " - \(note)")
        let incomingDescription = "\(verb) desde \(fromWallet.name)\(rateNote)" + (note.isEmpty ? "" : " - \(note)")

        let (expenseCategory, expenseSub) = ensureTransferCategory(isIncome: false, isExchange: isExchange)
        let (incomeCategory, incomeSub) = ensureTransferCategory(isIncome: true, isExchange: isExchange)

        let now = Date()
        let cambio = isExchange ? CambioDivisa(
            tasa: rate,
            monedaOrigen: fromWallet.currency.rawValue,
            monedaDestino: toWallet.currency.rawValue,
            montoOrigen: amountFrom,
            montoDestino: amountTo
        ) : nil

        let outgoing = Transaction(
            type: .expense,
            amount: amountFrom,
            date: now,
            categoryId: expenseCategory.id,
            categoryName: expenseCategory.name,
            subcategoryId: expenseSub.id,
            subcategoryName: expenseSub.name,
            description: outgoingDescription,
            walletId: fromWalletId,
            cambio: cambio
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
            walletId: toWalletId,
            cambio: cambio
        )

        transactionManager.addTransaction(outgoing)
        transactionManager.addTransaction(incoming)
        dismiss()
    }

    private func ensureTransferCategory(isIncome: Bool, isExchange: Bool) -> (TransactionCategory, Subcategory) {
        let categoryName = isExchange ? "Cambio de divisa" : "Transferencias"
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
            icon: isExchange ? "dollarsign.arrow.circlepath" : "arrow.left.arrow.right.circle.fill",
            color: isExchange ? .green : .blue
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
