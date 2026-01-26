import SwiftUI

struct DebtsView: View {
    @EnvironmentObject private var debtManager: DebtManager
    @State private var isAddingDebt = false

    var body: some View {
        List {
            if debtManager.debts.isEmpty {
                Text("No hay deudas registradas.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(debtManager.debts) { debt in
                    NavigationLink {
                        DebtDetailView(debt: debt)
                    } label: {
                        HStack {
                            Circle()
                                .fill(debtRatingColor(for: debt))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(debt.nombre)
                                    .font(.headline)
                                Text(debt.motivo)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(debt.monto, format: .currency(code: debt.moneda.rawValue))
                                    .font(.subheadline.weight(.semibold))
                                if let plazo = debt.plazoMeses {
                                    Text("\(plazo) meses")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .onDelete { indices in
                    indices.map { debtManager.debts[$0] }.forEach { debt in
                        debtManager.deleteDebt(debt)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Deudas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddingDebt = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingDebt) {
            DebtEditorView { newDebt in
                debtManager.addDebt(newDebt)
            }
        }
    }

    private func debtRatingColor(for debt: Debt) -> Color {
        guard let rating = debt.lastEstimate?.caracterizacion.lowercased() else {
            return Color(.systemGray4)
        }
        switch rating {
        case "buena":
            return Color(red: 0.20, green: 0.60, blue: 0.46)
        case "regular":
            return Color(red: 0.94, green: 0.71, blue: 0.31)
        case "mala":
            return Color(red: 0.86, green: 0.33, blue: 0.33)
        case "muy mala":
            return Color(red: 0.58, green: 0.19, blue: 0.19)
        default:
            return Color(.systemGray4)
        }
    }
}

struct DebtEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nombre: String = ""
    @State private var motivo: String = ""
    @State private var monto: Double = 0
    @State private var moneda: Currency = .cup
    @State private var plazoMeses: String = ""

    let onSave: (Debt) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Deuda") {
                    TextField("Nombre", text: $nombre)
                    TextField("Motivo", text: $motivo)
                }

                Section("Monto") {
                    TextField("0.00", value: $monto, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                    Picker("Moneda", selection: $moneda) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                }

                Section("Plazo (opcional)") {
                    TextField("Meses", text: $plazoMeses)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Nueva deuda")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let plazo = Int(plazoMeses.trimmingCharacters(in: .whitespacesAndNewlines))
                        let debt = Debt(
                            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                            motivo: motivo.trimmingCharacters(in: .whitespacesAndNewlines),
                            monto: monto,
                            moneda: moneda,
                            plazoMeses: plazo,
                            montoOriginal: monto,
                            pagos: []
                        )
                        onSave(debt)
                        dismiss()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || monto <= 0)
                }
            }
        }
    }
}

struct DebtDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var debtManager: DebtManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var exchangeRateManager: ExchangeRateManager

    @State private var debt: Debt
    @State private var paymentAmount: Double = 0
    @State private var selectedWallet: Wallet?
    @State private var isEstimating = false
    @State private var estimateError: String?
    @State private var displayUnit: TimeUnit = .months
    @State private var aiSpin: Bool = false

    init(debt: Debt) {
        _debt = State(initialValue: debt)
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Text("Deuda actual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(debt.monto, format: .currency(code: debt.moneda.rawValue))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(debtRatingColor)

                    if debt.montoOriginal > 0 {
                        Text("Deuda original \(debt.montoOriginal.formatted(.currency(code: debt.moneda.rawValue)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let ratingText = debtRatingText {
                        Text(ratingText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(debtRatingColor)
                    }
                }
                .frame(maxWidth: .infinity)

                Button {
                    Task {
                        await estimateDebt()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .rotationEffect(.degrees(aiSpin ? 360 : 0))
                            .animation(
                                isEstimating ? .linear(duration: 1.2).repeatForever(autoreverses: false) : .default,
                                value: aiSpin
                            )
                        Text(isEstimating ? "Analizando..." : "Analizar")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.49, green: 0.32, blue: 0.94), Color(red: 0.29, green: 0.60, blue: 0.97)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .disabled(isEstimating)

                if let estimate = debt.lastEstimate {
                    Picker("Unidad", selection: $displayUnit) {
                        ForEach(TimeUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: scenarioColumns, spacing: 10) {
                        ForEach(estimate.escenarios, id: \.self) { scenario in
                            ScenarioCard(
                                scenario: scenario,
                                unit: displayUnit,
                                currency: debt.moneda
                            )
                        }
                    }

                    Text(estimate.mensaje)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if let message = estimateError {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("Detalles") {
                TextField("Nombre", text: $debt.nombre)
                TextField("Motivo", text: $debt.motivo)
                TextField("Plazo (meses)", text: plazoBinding)
                    .keyboardType(.numberPad)
            }

            Section("Pagar deuda") {
                TextField("Monto a pagar", value: $paymentAmount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)

                Menu {
                    ForEach(availableWallets) { wallet in
                        Button(action: { selectedWallet = wallet }) {
                            HStack {
                                Image(systemName: wallet.icon)
                                Text("\(wallet.name) (\(wallet.currency.symbol))")
                                if selectedWallet?.id == wallet.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedWallet?.icon ?? "wallet.pass")
                            .foregroundColor(selectedWallet?.color ?? .blue)
                        Text(selectedWallet?.name ?? "Seleccionar Cartera")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Registrar pago") {
                    applyPayment()
                }
                .disabled(!canPay)
            }

            if !debt.pagos.isEmpty {
                Section("Historial de pagos") {
                    ForEach(debt.pagos.sorted { $0.date > $1.date }) { pago in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pago.amount, format: .currency(code: debt.moneda.rawValue))
                                    .font(.subheadline.weight(.semibold))
                                Text(pago.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }

        }
        .navigationTitle(debt.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneToolbar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    debtManager.updateDebt(debt)
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedWallet = availableWallets.first
            aiSpin = true
        }
    }

    private var scenarioColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 10)]
    }

    private var plazoBinding: Binding<String> {
        Binding<String>(
            get: {
                if let plazo = debt.plazoMeses {
                    return String(plazo)
                }
                return ""
            },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    debt.plazoMeses = nil
                } else {
                    debt.plazoMeses = Int(trimmed)
                }
            }
        )
    }

    private var availableWallets: [Wallet] {
        walletManager.wallets.filter { $0.currency == debt.moneda }
    }

    private var canPay: Bool {
        guard let wallet = selectedWallet else { return false }
        let balance = walletManager.calculateBalance(for: wallet)
        return paymentAmount > 0 && paymentAmount <= debt.monto && paymentAmount <= balance
    }

    private func applyPayment() {
        guard let wallet = selectedWallet else { return }
        let balance = walletManager.calculateBalance(for: wallet)
        guard paymentAmount > 0, paymentAmount <= debt.monto, paymentAmount <= balance else { return }

        let (category, subcategory) = ensureDebtCategory()

        let transaction = Transaction(
            type: .expense,
            amount: paymentAmount,
            date: Date(),
            categoryId: category.id,
            categoryName: category.name,
            subcategoryId: subcategory.id,
            subcategoryName: subcategory.name,
            description: "Pago de deuda: \(debt.nombre)",
            walletId: wallet.id
        )
        transactionManager.addTransaction(transaction)

        let payment = DebtPayment(amount: paymentAmount, walletId: wallet.id)
        debt.pagos.append(payment)
        debt.monto = max(0, debt.monto - paymentAmount)
        paymentAmount = 0
        debtManager.updateDebt(debt)
    }

    private func ensureDebtCategory() -> (TransactionCategory, Subcategory) {
        if let existing = categoryManager.expenseCategories.first(where: { $0.name.lowercased() == "deudas" }) {
            if let sub = existing.subcategories.first(where: { $0.name.lowercased() == "pago" }) {
                return (existing, sub)
            }
            let newSub = Subcategory(name: "Pago")
            categoryManager.addSubcategory(newSub, to: existing, isIncome: false)
            return (existing, newSub)
        }

        let newSub = Subcategory(name: "Pago")
        let newCategory = TransactionCategory(
            name: "Deudas",
            subcategories: [newSub],
            icon: "creditcard.fill",
            color: .orange
        )
        categoryManager.addExpenseCategory(newCategory)
        return (newCategory, newSub)
    }

    private func buildPrompt() -> String {
        let monthlyIncome = monthlyTotal(for: .income)
        let monthlyExpense = monthlyTotal(for: .expense)
        let situacion = profileManager.profile.situacionFinanciera
        let estrategia = profileManager.profile.estrategiaFinanciera
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        let saldoActual = currentBalanceForDebtCurrency
        let restanteDespuesDeuda = saldoActual - debt.monto

        var prompt = """
        Deuda en \(debt.moneda.rawValue): \(debt.montoOriginal).
        Estado actual: resta \(debt.monto).
        Saldo actual: \(saldoActual). Restante despues de deuda: \(restanteDespuesDeuda).
        Ingresos \(monthlyIncome)/mes, gastos \(monthlyExpense)/mes.
        """

        if let rate = exchangeRateManager.effectiveUsdToCupRate() {
            prompt += "\nTasa USD/CUP actual (informal): 1 USD = \(String(format: "%.2f", rate)) CUP."
        } else {
            prompt += "\nTasa USD/CUP actual (informal): sin dato."
        }

        if !debt.motivo.isEmpty {
            prompt += "\nMotivo: \(debt.motivo)."
        }
        if let plazo = debt.plazoMeses {
            prompt += "\nPlazo deseado: \(plazo) meses."
        }
        if !debt.pagos.isEmpty {
            let pagosTexto = debt.pagos
                .sorted { $0.date < $1.date }
                .map { pago in
                    "Pago \(dateFormatter.string(from: pago.date)): \(pago.amount)"
                }
                .joined(separator: ". ")
            prompt += "\nPagos registrados: \(pagosTexto)."
        } else {
            prompt += "\nPagos registrados: ninguno."
        }
        prompt += "\nSituacion: \(situacion.isEmpty ? "Sin información." : situacion)"
        prompt += "\nEstrategia: \(estrategia.isEmpty ? "Sin información." : estrategia)"
        return prompt
    }

    private func monthlyTotal(for type: TransactionType) -> Double {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let transactions = transactionManager.transactions.filter { transaction in
            guard transaction.type == type else { return false }
            guard transactionCurrency(for: transaction) == debt.moneda else { return false }
            return transaction.date >= startDate
        }
        return transactions.reduce(0) { $0 + $1.amount }
    }

    private func transactionCurrency(for transaction: Transaction) -> Currency? {
        walletManager.wallet(withId: transaction.walletId)?.currency
    }

    private var currentBalanceForDebtCurrency: Double {
        let wallets = walletManager.wallets.filter { $0.currency == debt.moneda }
        return wallets.reduce(0) { $0 + walletManager.calculateBalance(for: $1) }
    }

    private func estimateDebt() async {
        isEstimating = true
        estimateError = nil
        let service = DebtEstimateService()
        let prompt = buildPrompt()

        do {
            print("[DebtEstimate] Prompt:\n\(prompt)")
            let response = try await service.estimateDebt(prompt: prompt)
            print("[DebtEstimate] Response: \(response)")
            debt.lastEstimate = response
            debtManager.updateDebt(debt)
        } catch {
            print("[DebtEstimate] Error: \(error)")
            if let apiError = error as? DebtAPIError {
                switch apiError {
                case .serverError(let detail):
                    estimateError = detail
                case .invalidResponse:
                    estimateError = "Respuesta inválida del servidor."
                case .encodingError:
                    estimateError = "Error al codificar la solicitud."
                case .networkError(let underlying):
                    estimateError = "Error de red: \(underlying.localizedDescription)"
                }
            } else {
                estimateError = "No se pudo calcular la estimación."
            }
        }
        isEstimating = false
    }

    private var debtRatingText: String? {
        debt.lastEstimate?.caracterizacion.capitalized
    }

    private var debtRatingColor: Color {
        guard let rating = debt.lastEstimate?.caracterizacion.lowercased() else {
            return .primary
        }
        switch rating {
        case "buena":
            return Color(red: 0.20, green: 0.60, blue: 0.46)
        case "regular":
            return Color(red: 0.94, green: 0.71, blue: 0.31)
        case "mala":
            return Color(red: 0.86, green: 0.33, blue: 0.33)
        case "muy mala":
            return Color(red: 0.58, green: 0.19, blue: 0.19)
        default:
            return .primary
        }
    }
}

enum TimeUnit: String, CaseIterable, Identifiable {
    case days = "Días"
    case biweekly = "Quincenas"
    case months = "Meses"

    var id: String { rawValue }

    var title: String { rawValue }

    func format(days: Int) -> String {
        switch self {
        case .days:
            return "\(days) días"
        case .biweekly:
            return "\(max(1, days / 15)) quincenas"
        case .months:
            return "\(max(1, days / 30)) meses"
        }
    }
}

private struct ScenarioCard: View {
    let scenario: DebtScenario
    let unit: TimeUnit
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scenarioTitle)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(unit.format(days: scenario.diasPromedio))
                .font(.subheadline.weight(.semibold))
            Text(scenario.pagoMensual, format: .currency(code: currency.rawValue))
                .font(.caption.weight(.semibold))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scenarioColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(scenarioColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var scenarioTitle: String {
        switch scenario.escenario.lowercased() {
        case "pesimista": return "Pesimista"
        case "moderada": return "Moderado"
        case "optimista": return "Optimista"
        default: return scenario.escenario.capitalized
        }
    }

    private var scenarioColor: Color {
        switch scenario.escenario.lowercased() {
        case "pesimista": return Color(red: 0.86, green: 0.33, blue: 0.33)
        case "moderada": return Color(red: 0.94, green: 0.71, blue: 0.31)
        case "optimista": return Color(red: 0.20, green: 0.60, blue: 0.46)
        default: return .blue
        }
    }
}
