import SwiftUI

// MARK: - Loans List

struct PrestamosView: View {
    @EnvironmentObject private var prestamoManager: PrestamoManager
    @State private var isAddingPrestamo = false

    var body: some View {
        List {
            if prestamoManager.prestamos.isEmpty {
                Text("No hay préstamos registrados.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(prestamoManager.prestamos.sorted { $0.createdAt > $1.createdAt }) { prestamo in
                    NavigationLink {
                        PrestamoDetailView(prestamo: prestamo)
                    } label: {
                        prestamoRow(prestamo)
                    }
                }
                .onDelete { indices in
                    let sorted = prestamoManager.prestamos.sorted { $0.createdAt > $1.createdAt }
                    indices.map { sorted[$0] }.forEach { prestamoManager.deletePrestamo($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Préstamos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { isAddingPrestamo = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingPrestamo) {
            PrestamoEditorView { newPrestamo in
                prestamoManager.addPrestamo(newPrestamo)
            }
        }
    }

    private func prestamoRow(_ prestamo: Prestamo) -> some View {
        HStack {
            Circle()
                .fill(statusColor(for: prestamo))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(prestamo.nombre)
                    .font(.headline)
                Text(prestamo.motivo.isEmpty ? "Sin motivo" : prestamo.motivo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(prestamo.monto, format: .currency(code: prestamo.moneda.rawValue))
                    .font(.subheadline.weight(.semibold))
                if let fecha = prestamo.fechaDevolucion {
                    Text(fecha, style: .date)
                        .font(.caption2)
                        .foregroundColor(prestamo.estaVencido ? .red : .secondary)
                }
            }
        }
    }

    private func statusColor(for prestamo: Prestamo) -> Color {
        if prestamo.estaPagado { return Color(.systemGray4) }
        if prestamo.estaVencido { return Color(red: 0.86, green: 0.33, blue: 0.33) }
        return Color(red: 0.20, green: 0.60, blue: 0.46)
    }
}

// MARK: - Loan Editor

struct PrestamoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager

    @State private var nombre: String = ""
    @State private var motivo: String = ""
    @State private var monto: Double = 0
    @State private var moneda: Currency = .cup
    @State private var fechaPrestamo: Date = Date()
    @State private var tieneDevolucion: Bool = false
    @State private var fechaDevolucion: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedWallet: Wallet?

    let onSave: (Prestamo) -> Void

    private var availableWallets: [Wallet] {
        walletManager.wallets.filter { $0.currency == moneda }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Préstamo") {
                    TextField("A quién le prestas", text: $nombre)
                    TextField("Motivo (opcional)", text: $motivo)
                }

                Section("Monto") {
                    TextField("0.00", value: $monto, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                    Picker("Moneda", selection: $moneda) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                    .onChange(of: moneda) { _, _ in
                        selectedWallet = availableWallets.first
                    }
                }

                Section("Cartera origen") {
                    if availableWallets.isEmpty {
                        Text("No hay carteras en \(moneda.rawValue)")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(availableWallets) { wallet in
                            Button {
                                selectedWallet = wallet
                            } label: {
                                HStack {
                                    Image(systemName: wallet.icon)
                                        .foregroundColor(wallet.color)
                                    Text(wallet.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedWallet?.id == wallet.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Fechas") {
                    DatePicker("Fecha del préstamo", selection: $fechaPrestamo, displayedComponents: .date)
                    Toggle("Fecha pactada de devolución", isOn: $tieneDevolucion)
                    if tieneDevolucion {
                        DatePicker("Devolución", selection: $fechaDevolucion, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Nuevo préstamo")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .onAppear {
                selectedWallet = availableWallets.first
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let prestamo = Prestamo(
                            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                            motivo: motivo.trimmingCharacters(in: .whitespacesAndNewlines),
                            monto: monto,
                            moneda: moneda,
                            fechaPrestamo: fechaPrestamo,
                            fechaDevolucion: tieneDevolucion ? fechaDevolucion : nil
                        )
                        onSave(prestamo)
                        // Deduct from the selected wallet
                        if let wallet = selectedWallet {
                            let (cat, sub) = ensurePrestamoExpenseCategory()
                            let tx = Transaction(
                                type: .expense,
                                amount: monto,
                                date: fechaPrestamo,
                                categoryId: cat.id,
                                categoryName: cat.name,
                                subcategoryId: sub.id,
                                subcategoryName: sub.name,
                                description: "Préstamo a \(nombre.trimmingCharacters(in: .whitespacesAndNewlines))",
                                walletId: wallet.id
                            )
                            transactionManager.addTransaction(tx)
                        }
                        dismiss()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || monto <= 0 || selectedWallet == nil)
                }
            }
        }
    }

    private func ensurePrestamoExpenseCategory() -> (TransactionCategory, Subcategory) {
        if let existing = categoryManager.expenseCategories.first(where: { $0.name.lowercased() == "préstamos" }) {
            if let sub = existing.subcategories.first(where: { $0.name.lowercased() == "préstamo otorgado" }) {
                return (existing, sub)
            }
            let newSub = Subcategory(name: "Préstamo otorgado")
            categoryManager.addSubcategory(newSub, to: existing, isIncome: false)
            return (existing, newSub)
        }
        let newSub = Subcategory(name: "Préstamo otorgado")
        let newCategory = TransactionCategory(
            name: "Préstamos",
            subcategories: [newSub],
            icon: "arrow.up.arrow.down",
            color: .teal
        )
        categoryManager.addExpenseCategory(newCategory)
        return (newCategory, newSub)
    }
}

// MARK: - Loan Detail

struct PrestamoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var prestamoManager: PrestamoManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager

    @State private var prestamo: Prestamo
    @State private var cobroPorcentaje: Double = 0       // 0.0 – 1.0
    @State private var selectedWallet: Wallet?
    @State private var tieneDevolucion: Bool

    init(prestamo: Prestamo) {
        _prestamo = State(initialValue: prestamo)
        _tieneDevolucion = State(initialValue: prestamo.fechaDevolucion != nil)
    }

    private var cobroAmount: Double {
        (prestamo.monto * cobroPorcentaje).rounded(toPlaces: 2)
    }

    var body: some View {
        Form {
            // Summary
            Section {
                VStack(spacing: 10) {
                    Text(prestamo.estaPagado ? "Devuelto" : "Pendiente de cobro")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prestamo.monto, format: .currency(code: prestamo.moneda.rawValue))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(statusColor)
                    if prestamo.montoOriginal != prestamo.monto {
                        Text("Préstamo original \(prestamo.montoOriginal.formatted(.currency(code: prestamo.moneda.rawValue)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if prestamo.estaVencido {
                        Label("Vencido", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(red: 0.86, green: 0.33, blue: 0.33))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Details
            Section("Detalles") {
                TextField("A quién", text: $prestamo.nombre)
                TextField("Motivo", text: $prestamo.motivo)
                DatePicker("Fecha del préstamo", selection: $prestamo.fechaPrestamo, displayedComponents: .date)
                Toggle("Fecha pactada de devolución", isOn: $tieneDevolucion)
                    .onChange(of: tieneDevolucion) { _, newValue in
                        if !newValue { prestamo.fechaDevolucion = nil }
                        else if prestamo.fechaDevolucion == nil {
                            prestamo.fechaDevolucion = Calendar.current.date(byAdding: .month, value: 1, to: Date())
                        }
                    }
                if tieneDevolucion {
                    DatePicker("Devolución", selection: Binding(
                        get: { prestamo.fechaDevolucion ?? Date() },
                        set: { prestamo.fechaDevolucion = $0 }
                    ), displayedComponents: .date)
                }
            }

            // Cobro con slider
            if !prestamo.estaPagado {
                Section("Registrar cobro") {
                    // Wallet selector
                    if availableWallets.isEmpty {
                        Text("No hay carteras en \(prestamo.moneda.rawValue)")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
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
                                Text(selectedWallet?.name ?? "Seleccionar cartera")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Slider de porcentaje
                    VStack(spacing: 12) {
                        HStack {
                            Text("Porcentaje devuelto")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(cobroPorcentaje, format: .percent.precision(.fractionLength(0)))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }

                        Slider(value: $cobroPorcentaje, in: 0...1, step: 0.01)
                            .tint(.teal)

                        HStack {
                            Spacer()
                            Text(cobroAmount, format: .currency(code: prestamo.moneda.rawValue))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(cobroAmount > 0 ? .teal : .secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        applyCobro()
                    } label: {
                        Text("Aceptar")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canCobrar)
                }
            }

            // Historial de cobros
            if !prestamo.cobros.isEmpty {
                Section("Historial de cobros") {
                    ForEach(prestamo.cobros.sorted { $0.date > $1.date }) { cobro in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cobro.amount, format: .currency(code: prestamo.moneda.rawValue))
                                    .font(.subheadline.weight(.semibold))
                                Text(cobro.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(prestamo.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneToolbar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    prestamoManager.updatePrestamo(prestamo)
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedWallet = availableWallets.first
        }
    }

    private var availableWallets: [Wallet] {
        walletManager.wallets.filter { $0.currency == prestamo.moneda }
    }

    private var canCobrar: Bool {
        selectedWallet != nil && cobroAmount > 0
    }

    private var statusColor: Color {
        if prestamo.estaPagado { return Color(red: 0.20, green: 0.60, blue: 0.46) }
        if prestamo.estaVencido { return Color(red: 0.86, green: 0.33, blue: 0.33) }
        return .primary
    }

    private func applyCobro() {
        guard let wallet = selectedWallet, cobroAmount > 0 else { return }

        let (category, subcategory) = ensureCobroCategory()
        let transaction = Transaction(
            type: .income,
            amount: cobroAmount,
            date: Date(),
            categoryId: category.id,
            categoryName: category.name,
            subcategoryId: subcategory.id,
            subcategoryName: subcategory.name,
            description: "Cobro de préstamo: \(prestamo.nombre)",
            walletId: wallet.id
        )
        transactionManager.addTransaction(transaction)

        prestamo.cobros.append(PrestamoCobro(amount: cobroAmount, walletId: wallet.id))
        prestamo.monto = max(0, prestamo.monto - cobroAmount)
        cobroPorcentaje = 0
        prestamoManager.updatePrestamo(prestamo)
    }

    private func ensureCobroCategory() -> (TransactionCategory, Subcategory) {
        if let existing = categoryManager.incomeCategories.first(where: { $0.name.lowercased() == "préstamos" }) {
            if let sub = existing.subcategories.first(where: { $0.name.lowercased() == "cobro" }) {
                return (existing, sub)
            }
            let newSub = Subcategory(name: "Cobro")
            categoryManager.addSubcategory(newSub, to: existing, isIncome: true)
            return (existing, newSub)
        }
        let newSub = Subcategory(name: "Cobro")
        let newCategory = TransactionCategory(
            name: "Préstamos",
            subcategories: [newSub],
            icon: "arrow.up.arrow.down",
            color: .teal
        )
        categoryManager.addIncomeCategory(newCategory)
        return (newCategory, newSub)
    }
}

// MARK: - Helpers

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
