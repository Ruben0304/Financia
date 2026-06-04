import SwiftUI
import Charts

// MARK: - Data Point for Category × Month 3D bars
@available(iOS 26.0, *)
private struct CategoryMonthBar: Identifiable {
    let id = UUID()
    let monthIndex: Double
    let monthLabel: String
    let amount: Double
    let categoryIndex: Double
    let categoryName: String
}

@available(iOS 26.0, *)
struct CategoryMonth3DView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var walletManager: WalletManager

    @State private var selectedCurrency: Currency = .cup
    @State private var showIncome: Bool = false
    @State private var pose: Chart3DPose = .default

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    HStack(spacing: 12) {
                        Picker("", selection: $selectedCurrency) {
                            Text("CUP").tag(Currency.cup)
                            Text("USD").tag(Currency.usd)
                        }
                        .pickerStyle(.segmented)

                        Picker("", selection: $showIncome) {
                            Text("Gastos").tag(false)
                            Text("Ingresos").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }

                    chartSection

                    breakdownSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Categoría × Mes")
                .font(DarkFinanceTypography.sectionTitle(size: 20))
                .foregroundColor(DarkFinanceColors.primaryText)
            Text("Barras 3D mostrando gasto por categoría en cada mes")
                .font(DarkFinanceTypography.body(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
    }

    private var chartSection: some View {
        let bars = dataBars
        let maxAmount = bars.map(\.amount).max() ?? 1

        return Chart3D(bars) { bar in
            let barWidth = 0.35
            RectangleMark(
                x: .value("Mes", (bar.monthIndex - barWidth / 2)..<(bar.monthIndex + barWidth / 2)),
                y: .value("Monto", 0.0..<bar.amount),
                z: .value("Categoría", bar.categoryIndex)
            )
            .foregroundStyle(by: .value("Categoría", bar.categoryName))
        }
        .chart3DCameraProjection(.perspective)
        .chart3DPose($pose)
        .chartYScale(domain: 0...maxAmount)
        .frame(height: 360)
        .darkFinanceCard(cornerRadius: 20, padding: 16)
    }

    private var breakdownSection: some View {
        let bars = dataBars
        let grouped = Dictionary(grouping: bars, by: { $0.categoryName })
        let sorted = grouped.map { (name: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Desglose")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            if sorted.isEmpty {
                Text("No hay datos para mostrar")
                    .font(DarkFinanceTypography.body())
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(sorted.prefix(8), id: \.name) { item in
                    HStack {
                        Text(item.name)
                            .font(DarkFinanceTypography.body(size: 14, weight: .medium))
                            .foregroundColor(DarkFinanceColors.primaryText)
                            .lineLimit(1)
                        Spacer()
                        Text(item.total, format: .currency(code: selectedCurrency.rawValue))
                            .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                            .foregroundColor(showIncome ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    // MARK: - Data

    private var dataBars: [CategoryMonthBar] {
        let calendar = Calendar.current
        let type: TransactionType = showIncome ? .income : .expense
        let categories = showIncome ? categoryManager.incomeCategories : categoryManager.expenseCategories
        let categoryIds = categories.map { $0.id }

        let filtered = transactionManager.transactions.filter { t in
            t.type == type && walletManager.wallet(withId: t.walletId)?.currency == selectedCurrency
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var bars: [CategoryMonthBar] = []

        // Last 6 months
        let now = Date()
        for monthOffset in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let monthComponents = calendar.dateComponents([.year, .month], from: monthDate)

            let monthTransactions = filtered.filter {
                let tc = calendar.dateComponents([.year, .month], from: $0.date)
                return tc.year == monthComponents.year && tc.month == monthComponents.month
            }

            let grouped = Dictionary(grouping: monthTransactions, by: { $0.categoryId })

            for (catId, transactions) in grouped {
                let amount = transactions.reduce(0) { $0 + $1.amount }
                guard amount > 0 else { continue }
                let catIndex = Double(categoryIds.firstIndex(of: catId) ?? 0)
                let catName = categories.first(where: { $0.id == catId })?.name ?? "Otro"

                bars.append(CategoryMonthBar(
                    monthIndex: Double(5 - monthOffset),
                    monthLabel: formatter.string(from: monthDate),
                    amount: amount,
                    categoryIndex: catIndex,
                    categoryName: catName
                ))
            }
        }

        return bars
    }
}
