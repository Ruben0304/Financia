import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingAddCategory = false
    @State private var editingCategory: BudgetCategory?

    // MARK: - Computed values

    private var totalByCurrency: [Currency: Double] {
        var totals: [Currency: Double] = [:]
        for wallet in walletManager.wallets {
            totals[wallet.currency, default: 0] += wallet.balance
        }
        return totals
    }

    private var allocatedByCurrency: [Currency: Double] {
        var totals: [Currency: Double] = [:]
        for cat in budgetManager.categories {
            if let usd = cat.asignaciones.usd, usd != 0 { totals[.usd, default: 0] += usd }
            if let eur = cat.asignaciones.eur, eur != 0 { totals[.eur, default: 0] += eur }
            if let cup = cat.asignaciones.cup, cup != 0 { totals[.cup, default: 0] += cup }
        }
        return totals
    }

    private var disponibleByCurrency: [Currency: Double] {
        var result: [Currency: Double] = [:]
        for currency in Currency.allCases {
            let total = totalByCurrency[currency] ?? 0
            let allocated = allocatedByCurrency[currency] ?? 0
            if total != 0 || allocated != 0 {
                result[currency] = total - allocated
            }
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
                VStack(spacing: 20) {
                    summaryCard
                    categoriesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .refreshable {
                await budgetManager.refreshFromBackend()
            }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryText)
                        .frame(width: 32, height: 32)
                        .background(DarkFinanceColors.cardBackground, in: Circle())
                        .overlay(Circle().stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            BudgetCategoryEditorView()
                .environmentObject(budgetManager)
        }
        .sheet(item: $editingCategory) { category in
            BudgetCategoryEditorView(category: category)
                .environmentObject(budgetManager)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sin asignar")
                        .font(DarkFinanceTypography.caption(weight: .semibold))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                        .textCase(.uppercase)
                        .kerning(0.8)
                    Text("Por moneda")
                        .font(DarkFinanceTypography.sectionTitle(size: 20))
                        .foregroundColor(DarkFinanceColors.primaryText)
                }
                Spacer()
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 22))
                    .foregroundColor(DarkFinanceColors.primaryAccent.opacity(0.8))
            }
            .padding(20)

            Divider()
                .background(DarkFinanceColors.cardBorder)
                .padding(.horizontal, 20)

            if activeCurrencies.isEmpty {
                Text("No hay saldos en las carteras")
                    .font(DarkFinanceTypography.body())
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .padding(24)
            } else {
                ForEach(Array(activeCurrencies.enumerated()), id: \.element) { idx, currency in
                    currencyRow(for: currency)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    if idx < activeCurrencies.count - 1 {
                        Divider()
                            .background(DarkFinanceColors.cardBorder)
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
        .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
    }

    private func currencyRow(for currency: Currency) -> some View {
        let total = totalByCurrency[currency] ?? 0
        let allocated = allocatedByCurrency[currency] ?? 0
        let disponible = total - allocated
        let isNegative = disponible < 0
        let ratio = total > 0 ? min(allocated / total, 1.0) : 0.0

        return VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.rawValue.uppercased())
                        .font(DarkFinanceTypography.caption(weight: .semibold))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                        .kerning(0.5)
                    Text(formatAmount(disponible, currency: currency))
                        .font(DarkFinanceTypography.monoAmount(size: 26, weight: .semibold))
                        .foregroundColor(isNegative ? DarkFinanceColors.errorRed : DarkFinanceColors.successGreen)
                }
                Spacer()
                if isNegative {
                    Label("Excedido", systemImage: "exclamationmark.triangle.fill")
                        .font(DarkFinanceTypography.caption(weight: .semibold))
                        .foregroundColor(DarkFinanceColors.errorRed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DarkFinanceColors.errorRed.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 0) {
                summaryPill(label: "Total", value: formatAmount(total, currency: currency), color: DarkFinanceColors.primaryText)
                Spacer()
                summaryPill(label: "Asignado", value: formatAmount(allocated, currency: currency), color: .orange)
            }

            if total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DarkFinanceColors.inputBackground)
                            .frame(height: 5)
                        Capsule()
                            .fill(isNegative ? DarkFinanceColors.errorRed : Color.orange)
                            .frame(width: geo.size.width * ratio, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
    }

    private func summaryPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DarkFinanceTypography.caption())
                .foregroundColor(DarkFinanceColors.secondaryText)
            Text(value)
                .font(DarkFinanceTypography.emphasis())
                .foregroundColor(color)
        }
    }

    // MARK: - Categories Section

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Categorías")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Spacer()
                Text("\(budgetManager.categories.count)")
                    .font(DarkFinanceTypography.caption())
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            if budgetManager.categories.isEmpty {
                emptyState
            } else {
                ForEach(budgetManager.categories) { category in
                    categoryCard(category)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 36))
                .foregroundColor(DarkFinanceColors.secondaryText.opacity(0.4))

            VStack(spacing: 6) {
                Text("Sin categorías aún")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text("Crea categorías para decidir a dónde\nirá destinado tu dinero")
                    .font(DarkFinanceTypography.body())
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingAddCategory = true
            } label: {
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DarkFinanceColors.primaryAccent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(category.nombre.prefix(1)).uppercased())
                    .font(DarkFinanceTypography.sectionTitle(size: 18))
                    .foregroundColor(DarkFinanceColors.primaryAccent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(category.nombre)
                    .font(DarkFinanceTypography.emphasis())
                    .foregroundColor(DarkFinanceColors.primaryText)

                if let desc = category.descripcion, !desc.isEmpty {
                    Text(desc)
                        .font(DarkFinanceTypography.caption())
                        .foregroundColor(DarkFinanceColors.secondaryText)
                        .lineLimit(1)
                }

                amountChips(for: category)
            }

            Spacer()

            Button {
                editingCategory = category
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(DarkFinanceColors.inputBackground, in: Circle())
            }
        }
        .padding(16)
        .background(DarkFinanceColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DarkFinanceColors.cardBorder, lineWidth: 1))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                budgetManager.deleteCategory(category)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func amountChips(for category: BudgetCategory) -> some View {
        let items: [(Double, Currency)] = [
            (category.asignaciones.usd ?? 0, .usd),
            (category.asignaciones.eur ?? 0, .eur),
            (category.asignaciones.cup ?? 0, .cup),
        ].filter { $0.0 > 0 }

        if items.isEmpty {
            Text("Sin monto asignado")
                .font(DarkFinanceTypography.caption())
                .foregroundColor(DarkFinanceColors.tertiaryText)
        } else {
            HStack(spacing: 6) {
                ForEach(items, id: \.1) { amount, currency in
                    Text(formatAmount(amount, currency: currency))
                        .font(DarkFinanceTypography.caption(weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundColor(currencyColor(currency))
                        .background(currencyColor(currency).opacity(0.12), in: Capsule())
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Double, currency: Currency) -> String {
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

    private func currencyColor(_ currency: Currency) -> Color {
        switch currency {
        case .usd: return DarkFinanceColors.successGreen
        case .eur: return Color(hex: "3B82F6")
        case .cup: return .orange
        }
    }
}
