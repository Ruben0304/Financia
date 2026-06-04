import SwiftUI
import Charts

@available(iOS 26.0, *)
struct FinancialSurface3DView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var walletManager: WalletManager

    @State private var selectedCurrency: Currency = .cup
    @State private var pose: Chart3DPose = .default

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    Picker("", selection: $selectedCurrency) {
                        Text("CUP").tag(Currency.cup)
                        Text("USD").tag(Currency.usd)
                    }
                    .pickerStyle(.segmented)

                    chartSection

                    explanationSection
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
            Text("Superficie Financiera")
                .font(DarkFinanceTypography.sectionTitle(size: 20))
                .foregroundColor(DarkFinanceColors.primaryText)
            Text("Proyección de tu balance neto basada en patrones de ingreso y gasto")
                .font(DarkFinanceTypography.body(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
    }

    private var chartSection: some View {
        let stats = financialStats
        let avgIncome = stats.avgMonthlyIncome
        let avgExpense = stats.avgMonthlyExpense
        let maxVal = max(avgIncome, avgExpense, 1)

        return Chart3D {
            // Surface: y = f(x, z) where x = income factor, z = expense factor
            // y represents net balance projection
            SurfacePlot(x: "Ingreso", y: "Balance", z: "Gasto") { x, z in
                // x ranges 0..1 (income factor), z ranges 0..1 (expense factor)
                let income = x * avgIncome * 2
                let expense = z * avgExpense * 2
                return (income - expense) / maxVal
            }
            .foregroundStyle(
                .heightBased(
                    Gradient(colors: [
                        DarkFinanceColors.errorRed,
                        Color(hex: "FF8A4C"),
                        DarkFinanceColors.successGreen
                    ])
                )
            )
        }
        .chartXScale(domain: 0...1)
        .chartYScale(domain: -1...1)
        .chartZScale(domain: 0...1)
        .chart3DCameraProjection(.perspective)
        .chart3DPose($pose)
        .frame(height: 360)
        .darkFinanceCard(cornerRadius: 20, padding: 16)
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cómo leer la superficie")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            explanationRow(
                icon: "arrow.up.right",
                color: DarkFinanceColors.successGreen,
                title: "Zonas verdes (altas)",
                text: "Escenarios donde tus ingresos superan los gastos"
            )

            explanationRow(
                icon: "arrow.down.right",
                color: DarkFinanceColors.errorRed,
                title: "Zonas rojas (bajas)",
                text: "Escenarios donde los gastos superan los ingresos"
            )

            explanationRow(
                icon: "hand.point.up.left",
                color: DarkFinanceColors.primaryAccent,
                title: "Interactivo",
                text: "Arrastra para rotar la superficie y explorar los escenarios"
            )

            let stats = financialStats
            HStack(spacing: 12) {
                miniStat(
                    label: "Ingreso prom.",
                    value: stats.avgMonthlyIncome,
                    color: DarkFinanceColors.successGreen
                )
                miniStat(
                    label: "Gasto prom.",
                    value: stats.avgMonthlyExpense,
                    color: DarkFinanceColors.errorRed
                )
            }
            .padding(.top, 4)
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    // MARK: - Helpers

    private func explanationRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DarkFinanceTypography.emphasis(size: 13))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text(text)
                    .font(DarkFinanceTypography.body(size: 12))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }
        }
    }

    private func miniStat(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .currency(code: selectedCurrency.rawValue))
                .font(DarkFinanceTypography.monoAmount(size: 15, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(DarkFinanceTypography.caption(size: 11))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Data

    private struct FinancialStats {
        let avgMonthlyIncome: Double
        let avgMonthlyExpense: Double
    }

    private var financialStats: FinancialStats {
        let calendar = Calendar.current
        let now = Date()
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now

        let recent = transactionManager.transactions.filter { t in
            t.date >= threeMonthsAgo &&
            walletManager.wallet(withId: t.walletId)?.currency == selectedCurrency
        }

        let income = recent.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = recent.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

        return FinancialStats(
            avgMonthlyIncome: max(income / 3, 1),
            avgMonthlyExpense: max(expense / 3, 1)
        )
    }
}
