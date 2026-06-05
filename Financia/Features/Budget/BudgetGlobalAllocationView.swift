import SwiftUI

struct BudgetGlobalAllocationView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCurrency: Currency = .cup
    @State private var percentages: [UUID: String] = [:]   // categoryId -> "20"
    @State private var showingSavePreset = false
    @State private var presetName = ""

    // MARK: - Computed

    private var totalForCurrency: Double {
        walletManager.wallets.reduce(0) { sum, wallet in
            guard wallet.currency == selectedCurrency else { return sum }
            return sum + walletManager.calculateBalance(for: wallet)
        }
    }

    private func pct(_ id: UUID) -> Double {
        Double(percentages[id]?.replacingOccurrences(of: ",", with: ".") ?? "") ?? 0
    }

    private func allocatedAmount(_ id: UUID) -> Double {
        totalForCurrency * (pct(id) / 100.0)
    }

    private var totalPct: Double {
        budgetManager.categories.reduce(0) { $0 + pct($1.id) }
    }

    private var totalPctColor: Color {
        if totalPct > 100 { return DarkFinanceColors.errorRed }
        if totalPct == 100 { return DarkFinanceColors.successGreen }
        return DarkFinanceColors.secondaryText
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        currencyPicker
                        totalCard
                        allocationList
                        if !budgetManager.presets.isEmpty { presetsSection }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Asignación por %")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        presetName = ""
                        showingSavePreset = true
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 13))
                            .foregroundColor(DarkFinanceColors.primaryAccent)
                    }
                    Button("Aplicar", action: apply)
                        .fontWeight(.semibold)
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                        .disabled(budgetManager.categories.isEmpty)
                }
            }
            .alert("Guardar preset", isPresented: $showingSavePreset) {
                TextField("Nombre del preset", text: $presetName)
                Button("Guardar") { savePreset() }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Guarda esta distribución de porcentajes para usarla después.")
            }
        }
        .onAppear { prefillFromCurrentAllocations() }
    }

    // MARK: - Currency picker

    private var currencyPicker: some View {
        Picker("Moneda", selection: $selectedCurrency) {
            ForEach(Currency.allCases) { currency in
                Text(currency.rawValue.uppercased()).tag(currency)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Total card

    private var totalCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Total en \(selectedCurrency.rawValue.uppercased())")
                    .font(DarkFinanceTypography.caption(weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                Text(formatAmt(totalForCurrency))
                    .font(DarkFinanceTypography.monoAmount(size: 28, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("% Asignado")
                    .font(DarkFinanceTypography.caption(weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                Text(String(format: "%.1f%%", totalPct))
                    .font(DarkFinanceTypography.monoAmount(size: 24, weight: .semibold))
                    .foregroundColor(totalPctColor)
            }
        }
        .padding(16)
        .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
    }

    // MARK: - Allocation list

    private var allocationList: some View {
        VStack(spacing: 10) {
            if budgetManager.categories.isEmpty {
                Text("Crea categorías primero")
                    .font(DarkFinanceTypography.body())
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .padding(20)
            } else {
                ForEach(budgetManager.categories) { cat in
                    allocationRow(cat)
                }
            }
        }
    }

    private func allocationRow(_ cat: BudgetCategory) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(DarkFinanceColors.primaryAccent.opacity(0.1))
                    .frame(width: 36, height: 36)
                Text(String(cat.nombre.prefix(1)).uppercased())
                    .font(DarkFinanceTypography.sectionTitle(size: 14))
                    .foregroundColor(DarkFinanceColors.primaryAccent)
            }

            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(cat.nombre)
                    .font(DarkFinanceTypography.emphasis())
                    .foregroundColor(DarkFinanceColors.primaryText)
                // Live amount preview
                let amt = allocatedAmount(cat.id)
                if amt > 0 {
                    Text("= \(formatAmt(amt))")
                        .font(DarkFinanceTypography.caption(weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            Spacer()

            // % input
            HStack(spacing: 4) {
                TextField("0", text: Binding(
                    get: { percentages[cat.id] ?? "" },
                    set: { percentages[cat.id] = $0 }
                ))
                .keyboardType(.decimalPad)
                .font(DarkFinanceTypography.monoAmount(size: 16, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(DarkFinanceColors.inputBackground, in: RoundedRectangle(cornerRadius: 8))

                Text("%")
                    .font(DarkFinanceTypography.caption(weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }
        }
        .padding(12)
        .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
    }

    // MARK: - Presets section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets guardados")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            ForEach(budgetManager.presets) { preset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.nombre)
                            .font(DarkFinanceTypography.emphasis())
                            .foregroundColor(DarkFinanceColors.primaryText)
                        let count = preset.porcentajes.values.filter { $0 > 0 }.count
                        Text("\(count) categorías con %")
                            .font(DarkFinanceTypography.caption())
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                    Spacer()
                    Button("Cargar") {
                        loadPreset(preset)
                    }
                    .font(DarkFinanceTypography.action(weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DarkFinanceColors.primaryAccent.opacity(0.1), in: Capsule())
                }
                .padding(12)
                .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        budgetManager.deletePreset(id: preset.id)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func apply() {
        for cat in budgetManager.categories {
            let p = pct(cat.id)
            var updated = cat
            let amount = p > 0 ? totalForCurrency * (p / 100.0) : 0
            updated.asignaciones.setAmount(amount > 0 ? amount : nil, for: selectedCurrency)
            budgetManager.updateCategory(updated)
        }
        dismiss()
    }

    private func savePreset() {
        let nombre = presetName.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }
        var porcentajes: [String: Double] = [:]
        for cat in budgetManager.categories {
            let p = pct(cat.id)
            if p > 0 { porcentajes[cat.id.uuidString] = p }
        }
        budgetManager.addPreset(BudgetAllocationPreset(nombre: nombre, porcentajes: porcentajes))
    }

    private func loadPreset(_ preset: BudgetAllocationPreset) {
        for cat in budgetManager.categories {
            if let p = preset.porcentajes[cat.id.uuidString] {
                percentages[cat.id] = p.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", p)
                    : String(format: "%.1f", p)
            } else {
                percentages[cat.id] = ""
            }
        }
    }

    private func prefillFromCurrentAllocations() {
        for cat in budgetManager.categories {
            let current = cat.asignaciones.amount(for: selectedCurrency)
            if current > 0 && totalForCurrency > 0 {
                let p = (current / totalForCurrency) * 100
                percentages[cat.id] = p.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", p)
                    : String(format: "%.1f", p)
            }
        }
    }

    // MARK: - Helpers

    private func formatAmt(_ v: Double) -> String {
        let s: String
        switch selectedCurrency {
        case .usd: s = "$"
        case .eur: s = "€"
        case .cup: s = "CUP "
        }
        return s + (v >= 1000 ? String(format: "%.0f", v) : String(format: "%.2f", v))
    }
}
