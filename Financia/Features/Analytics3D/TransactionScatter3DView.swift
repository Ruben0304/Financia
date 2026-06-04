import SwiftUI
import Charts

// MARK: - Data Point for 3D Scatter
@available(iOS 26.0, *)
private struct TransactionPoint3D: Identifiable {
    let id: UUID
    let dayOffset: Double
    let amount: Double
    let categoryIndex: Double
    let categoryName: String
    let typeName: String
    let isIncome: Bool
}

@available(iOS 26.0, *)
struct TransactionScatter3DView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager
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

                    legendSection

                    statsSection
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
            Text("Mapa de Transacciones")
                .font(DarkFinanceTypography.sectionTitle(size: 20))
                .foregroundColor(DarkFinanceColors.primaryText)
            Text("Visualiza tus movimientos en 3 dimensiones: tiempo, monto y categoría")
                .font(DarkFinanceTypography.body(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
    }

    private var chartSection: some View {
        Chart3D(dataPoints) {
            PointMark(
                x: .value("Día", $0.dayOffset),
                y: .value("Monto", $0.amount),
                z: .value("Categoría", $0.categoryIndex)
            )
            .foregroundStyle(by: .value("Tipo", $0.typeName))
            .symbolSize(0.06)
            .symbol(.sphere)
        }
        .chart3DCameraProjection(.perspective)
        .chart3DPose($pose)
        .chartForegroundStyleScale([
            "Ingreso": Color(DarkFinanceColors.successGreen),
            "Gasto": Color(DarkFinanceColors.errorRed)
        ])
        .frame(height: 360)
        .darkFinanceCard(cornerRadius: 20, padding: 16)
    }

    private var legendSection: some View {
        HStack(spacing: 20) {
            legendItem(color: DarkFinanceColors.successGreen, label: "Ingresos")
            legendItem(color: DarkFinanceColors.errorRed, label: "Gastos")
        }
        .frame(maxWidth: .infinity)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            let points = dataPoints
            let incomeCount = points.filter { $0.isIncome }.count
            let expenseCount = points.filter { !$0.isIncome }.count
            let categories = Set(points.map { $0.categoryName }).count

            HStack(spacing: 12) {
                statCard(value: "\(incomeCount)", label: "Ingresos", color: DarkFinanceColors.successGreen)
                statCard(value: "\(expenseCount)", label: "Gastos", color: DarkFinanceColors.errorRed)
                statCard(value: "\(categories)", label: "Categorías", color: DarkFinanceColors.primaryAccent)
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    // MARK: - Helpers

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(DarkFinanceTypography.body(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DarkFinanceTypography.monoAmount(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(DarkFinanceTypography.caption(size: 11))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Data

    private var dataPoints: [TransactionPoint3D] {
        let now = Date()
        let calendar = Calendar.current
        let allCategories = categoryManager.incomeCategories + categoryManager.expenseCategories
        let categoryIds = allCategories.map { $0.id }

        return transactionManager.transactions.compactMap { t in
            guard walletManager.wallet(withId: t.walletId)?.currency == selectedCurrency else { return nil }

            let dayOffset = Double(calendar.dateComponents([.day], from: t.date, to: now).day ?? 0)
            let catIndex = Double(categoryIds.firstIndex(of: t.categoryId) ?? 0)

            return TransactionPoint3D(
                id: t.id,
                dayOffset: dayOffset,
                amount: t.amount,
                categoryIndex: catIndex,
                categoryName: t.categoryName,
                typeName: t.type == .income ? "Ingreso" : "Gasto",
                isIncome: t.type == .income
            )
        }
    }
}
