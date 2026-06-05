import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var walletManager: WalletManager

    @State private var showingAddCategory = false
    @State private var editingCategory: BudgetCategory?
    @State private var showingGlobalAllocation = false
    @State private var quickAdjust: QuickAdjustContext?

    struct QuickAdjustContext: Identifiable {
        let id = UUID()
        var category: BudgetCategory
        var currency: Currency
        var adding: Bool
    }

    // MARK: - Computed

    // FIX: use calculateBalance, not wallet.balance directly
    private var totalByCurrency: [Currency: Double] {
        var totals: [Currency: Double] = [:]
        for wallet in walletManager.wallets {
            let balance = walletManager.calculateBalance(for: wallet)
            if balance != 0 { totals[wallet.currency, default: 0] += balance }
        }
        return totals
    }

    private var allocatedByCurrency: [Currency: Double] {
        var totals: [Currency: Double] = [:]
        for cat in budgetManager.categories {
            if let v = cat.asignaciones.usd, v != 0 { totals[.usd, default: 0] += v }
            if let v = cat.asignaciones.eur, v != 0 { totals[.eur, default: 0] += v }
            if let v = cat.asignaciones.cup, v != 0 { totals[.cup, default: 0] += v }
        }
        return totals
    }

    private var disponibleByCurrency: [Currency: Double] {
        var result: [Currency: Double] = [:]
        for currency in Currency.allCases {
            let total = totalByCurrency[currency] ?? 0
            let allocated = allocatedByCurrency[currency] ?? 0
            if total != 0 || allocated != 0 { result[currency] = total - allocated }
        }
        return result
    }

    private var activeCurrencies: [Currency] {
        Currency.allCases.filter { disponibleByCurrency[$0] != nil }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    compactSummaryBar
                    categoriesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .refreshable { await budgetManager.refreshFromBackend() }
        }
        .navigationTitle("Presupuesto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("Presupuesto")
                    .font(DarkFinanceTypography.toolbarTitle(size: 22))
                    .foregroundColor(DarkFinanceColors.primaryText)
            }
            ToolbarItem(placement: .subtitle) {
                Text("\(budgetManager.categories.count) categorías")
                    .font(DarkFinanceTypography.toolbarSubtitle())
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingGlobalAllocation = true
                } label: {
                    Image(systemName: "percent")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                        .frame(width: 32, height: 32)
                        .background(DarkFinanceColors.primaryAccent.opacity(0.12), in: Circle())
                }
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryText)
                        .frame(width: 32, height: 32)
                        .background(DarkFinanceColors.cardBackground, in: Circle())
                        .overlay(Circle().stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            BudgetCategoryEditorView().environmentObject(budgetManager)
        }
        .sheet(item: $editingCategory) { cat in
            BudgetCategoryEditorView(category: cat).environmentObject(budgetManager)
        }
        .sheet(isPresented: $showingGlobalAllocation) {
            BudgetGlobalAllocationView()
                .environmentObject(budgetManager)
                .environmentObject(walletManager)
        }
        .sheet(item: $quickAdjust) { ctx in
            QuickAdjustSheet(ctx: ctx) { delta in
                applyDelta(to: ctx.category, currency: ctx.currency, delta: delta)
            }
        }
    }

    private func applyDelta(to category: BudgetCategory, currency: Currency, delta: Double) {
        var cat = category
        let current = cat.asignaciones.amount(for: currency)
        let next = max(0, current + delta)
        cat.asignaciones.setAmount(next > 0 ? next : nil, for: currency)
        budgetManager.updateCategory(cat)
    }

    // MARK: - Compact summary bar

    private var compactSummaryBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sin asignar")
                    .font(DarkFinanceTypography.caption(weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Button {
                    showingGlobalAllocation = true
                } label: {
                    Label("Asignar %", systemImage: "percent")
                        .font(DarkFinanceTypography.caption(weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            if activeCurrencies.isEmpty {
                Text("Sin saldos en carteras")
                    .font(DarkFinanceTypography.body())
                    .foregroundColor(DarkFinanceColors.secondaryText)
            } else {
                HStack(spacing: 8) {
                    ForEach(activeCurrencies, id: \.self) { currency in
                        disponiblePill(currency)
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
    }

    private func disponiblePill(_ currency: Currency) -> some View {
        let disponible = disponibleByCurrency[currency] ?? 0
        let isNeg = disponible < 0
        let color: Color = isNeg ? DarkFinanceColors.errorRed : DarkFinanceColors.successGreen

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(currency.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.8))
                    .kerning(0.4)
                if isNeg {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(color)
                }
            }
            Text(formatAmount(disponible, currency: currency))
                .font(DarkFinanceTypography.monoAmount(size: 15, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Categories section

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Categorías")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                Button { showingAddCategory = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
            }

            if budgetManager.categories.isEmpty {
                emptyState
            } else {
                ForEach(budgetManager.categories) { cat in
                    categoryCard(cat)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 34))
                .foregroundColor(DarkFinanceColors.secondaryText.opacity(0.35))

            VStack(spacing: 5) {
                Text("Sin categorías aún")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text("Crea categorías y asigna a cuánto\nirá destinado tu dinero")
                    .font(DarkFinanceTypography.body())
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button { showingAddCategory = true } label: {
                Label("Crear categoría", systemImage: "plus")
                    .font(DarkFinanceTypography.action(weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .foregroundColor(DarkFinanceColors.primaryAccent)
                    .background(DarkFinanceColors.primaryAccent.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
    }

    private func categoryCard(_ category: BudgetCategory) -> some View {
        let activeCurrenciesForCat = Currency.allCases.filter { category.asignaciones.amount(for: $0) > 0 }
        let inactiveCurrencies = Currency.allCases.filter { category.asignaciones.amount(for: $0) == 0 }

        return VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DarkFinanceColors.primaryAccent.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(String(category.nombre.prefix(1)).uppercased())
                        .font(DarkFinanceTypography.sectionTitle(size: 15))
                        .foregroundColor(DarkFinanceColors.primaryAccent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.nombre)
                        .font(DarkFinanceTypography.emphasis())
                        .foregroundColor(DarkFinanceColors.primaryText)
                    if let d = category.descripcion, !d.isEmpty {
                        Text(d)
                            .font(DarkFinanceTypography.caption())
                            .foregroundColor(DarkFinanceColors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button { editingCategory = category } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DarkFinanceColors.tertiaryText)
                        .frame(width: 28, height: 28)
                        .background(DarkFinanceColors.inputBackground, in: Circle())
                }
            }

            // Currency rows with +/-
            if activeCurrenciesForCat.isEmpty {
                Text("Sin monto asignado")
                    .font(DarkFinanceTypography.caption())
                    .foregroundColor(DarkFinanceColors.tertiaryText)
                    .padding(.leading, 46)
            } else {
                VStack(spacing: 6) {
                    ForEach(activeCurrenciesForCat, id: \.self) { currency in
                        currencyAdjustRow(category: category, currency: currency)
                    }
                }
            }

            // Add-currency pills for currencies not yet assigned
            if !inactiveCurrencies.isEmpty {
                HStack(spacing: 6) {
                    ForEach(inactiveCurrencies, id: \.self) { currency in
                        Button {
                            quickAdjust = QuickAdjustContext(category: category, currency: currency, adding: true)
                        } label: {
                            Label("+ \(currency.rawValue.uppercased())", systemImage: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(currencyColor(currency).opacity(0.7))
                                .background(currencyColor(currency).opacity(0.08), in: Capsule())
                                .overlay(Capsule().stroke(currencyColor(currency).opacity(0.15), lineWidth: 1))
                        }
                    }
                    Spacer()
                }
                .padding(.leading, 46)
            }
        }
        .padding(14)
        .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { budgetManager.deleteCategory(category) } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    private func currencyAdjustRow(category: BudgetCategory, currency: Currency) -> some View {
        let amount = category.asignaciones.amount(for: currency)

        return HStack(spacing: 10) {
            Text(currency.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(currencyColor(currency))
                .frame(width: 28, alignment: .leading)
                .padding(.leading, 46)

            Spacer()

            Text(formatAmount(amount, currency: currency))
                .font(DarkFinanceTypography.monoAmount(size: 15, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    quickAdjust = QuickAdjustContext(category: category, currency: currency, adding: false)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DarkFinanceColors.errorRed)
                        .frame(width: 30, height: 30)
                        .background(DarkFinanceColors.errorRed.opacity(0.1), in: Circle())
                }
                Button {
                    quickAdjust = QuickAdjustContext(category: category, currency: currency, adding: true)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DarkFinanceColors.successGreen)
                        .frame(width: 30, height: 30)
                        .background(DarkFinanceColors.successGreen.opacity(0.1), in: Circle())
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(DarkFinanceColors.inputBackground, in: RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Helpers

    func formatAmount(_ amount: Double, currency: Currency) -> String {
        let symbol: String
        switch currency {
        case .usd: symbol = "$"
        case .eur: symbol = "€"
        case .cup: symbol = "CUP "
        }
        let abs = Swift.abs(amount)
        let formatted = abs >= 1000
            ? String(format: "%.0f", abs)
            : String(format: "%.2f", abs)
        return (amount < 0 ? "-" : "") + symbol + formatted
    }

    func currencyColor(_ currency: Currency) -> Color {
        switch currency {
        case .usd: return DarkFinanceColors.successGreen
        case .eur: return Color(hex: "3B82F6")
        case .cup: return .orange
        }
    }
}

// MARK: - Quick Adjust Sheet

struct QuickAdjustSheet: View {
    let ctx: BudgetView.QuickAdjustContext
    let onApply: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @FocusState private var focused: Bool

    private var symbol: String {
        switch ctx.currency {
        case .usd: return "$"
        case .eur: return "€"
        case .cup: return "CUP "
        }
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Current
                VStack(spacing: 4) {
                    Text("Actual en \(ctx.currency.rawValue.uppercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrent())
                        .font(.title2.monospacedDigit())
                        .fontWeight(.semibold)
                }
                .padding(.top, 8)

                // Amount field
                VStack(spacing: 8) {
                    Text(ctx.adding ? "¿Cuánto agregas?" : "¿Cuánto quitas?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Text(symbol)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .focused($focused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 32)
                }

                // Preview
                if parsedAmount > 0 {
                    let current = ctx.category.asignaciones.amount(for: ctx.currency)
                    let next = ctx.adding ? current + parsedAmount : max(0, current - parsedAmount)
                    HStack(spacing: 6) {
                        Text(formatAmt(current))
                            .strikethrough()
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatAmt(next))
                            .fontWeight(.semibold)
                            .foregroundColor(ctx.adding ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
                    }
                    .font(.subheadline.monospacedDigit())
                }

                Spacer()
            }
            .navigationTitle(ctx.adding ? "Agregar a \(ctx.category.nombre)" : "Quitar de \(ctx.category.nombre)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        if parsedAmount > 0 {
                            onApply(ctx.adding ? parsedAmount : -parsedAmount)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(parsedAmount <= 0)
                }
            }
        }
        .presentationDetents([.height(340)])
        .onAppear { focused = true }
    }

    private func formatCurrent() -> String {
        formatAmt(ctx.category.asignaciones.amount(for: ctx.currency))
    }

    private func formatAmt(_ v: Double) -> String {
        let s: String
        switch ctx.currency {
        case .usd: s = "$"
        case .eur: s = "€"
        case .cup: s = "CUP "
        }
        return s + (v >= 1000 ? String(format: "%.0f", v) : String(format: "%.2f", v))
    }
}
