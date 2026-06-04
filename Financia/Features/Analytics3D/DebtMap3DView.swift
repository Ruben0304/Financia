import SwiftUI
import Charts

// MARK: - Data Point for Debt Map
@available(iOS 26.0, *)
private struct DebtPoint3D: Identifiable {
    let id: UUID
    let pendingAmount: Double
    let estimatedDays: Double
    let monthlyPayment: Double
    let name: String
    let characterization: String
}

@available(iOS 26.0, *)
struct DebtMap3DView: View {
    @EnvironmentObject private var debtManager: DebtManager

    @State private var pose: Chart3DPose = .default

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if dataPoints.isEmpty {
                        emptyState
                    } else {
                        chartSection
                        legendSection
                        debtListSection
                    }
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
            Text("Mapa de Deudas")
                .font(DarkFinanceTypography.sectionTitle(size: 20))
                .foregroundColor(DarkFinanceColors.primaryText)
            Text("Cada punto es una deuda: monto pendiente, días estimados para pagar y pago mensual")
                .font(DarkFinanceTypography.body(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 40))
                .foregroundColor(DarkFinanceColors.secondaryText)
            Text("No hay deudas con estimación IA")
                .font(DarkFinanceTypography.body())
                .foregroundColor(DarkFinanceColors.secondaryText)
            Text("Analiza tus deudas con IA para verlas aquí")
                .font(DarkFinanceTypography.caption(size: 12))
                .foregroundColor(DarkFinanceColors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private var chartSection: some View {
        Chart3D(dataPoints) {
            PointMark(
                x: .value("Monto pendiente", $0.pendingAmount),
                y: .value("Días estimados", $0.estimatedDays),
                z: .value("Pago mensual", $0.monthlyPayment)
            )
            .foregroundStyle(by: .value("Estado", $0.characterization))
            .symbolSize(0.08)
            .symbol(.sphere)
        }
        .chart3DCameraProjection(.perspective)
        .chart3DPose($pose)
        .chartForegroundStyleScale([
            "Buena": Color(DarkFinanceColors.successGreen),
            "Regular": Color(hex: "F59E0B"),
            "Mala": Color(DarkFinanceColors.errorRed),
            "Muy mala": Color(hex: "991B1B")
        ])
        .frame(height: 360)
        .darkFinanceCard(cornerRadius: 20, padding: 16)
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estado de la deuda")
                .font(DarkFinanceTypography.emphasis(size: 13))
                .foregroundColor(DarkFinanceColors.primaryText)

            HStack(spacing: 16) {
                legendDot(color: DarkFinanceColors.successGreen, label: "Buena")
                legendDot(color: Color(hex: "F59E0B"), label: "Regular")
                legendDot(color: DarkFinanceColors.errorRed, label: "Mala")
                legendDot(color: Color(hex: "991B1B"), label: "Muy mala")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var debtListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detalle")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            ForEach(dataPoints) { point in
                HStack {
                    Circle()
                        .fill(colorForCharacterization(point.characterization))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.name)
                            .font(DarkFinanceTypography.emphasis(size: 14))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text("\(Int(point.estimatedDays)) días est.")
                            .font(DarkFinanceTypography.caption(size: 11))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(point.pendingAmount, specifier: "%.0f")")
                            .font(DarkFinanceTypography.monoAmount(size: 13, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text("$\(point.monthlyPayment, specifier: "%.0f")/mes")
                            .font(DarkFinanceTypography.caption(size: 11))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    // MARK: - Helpers

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(DarkFinanceTypography.caption(size: 11))
                .foregroundColor(DarkFinanceColors.secondaryText)
        }
    }

    private func colorForCharacterization(_ char: String) -> Color {
        switch char {
        case "Buena": return DarkFinanceColors.successGreen
        case "Regular": return Color(hex: "F59E0B")
        case "Mala": return DarkFinanceColors.errorRed
        case "Muy mala": return Color(hex: "991B1B")
        default: return DarkFinanceColors.secondaryText
        }
    }

    // MARK: - Data

    private var dataPoints: [DebtPoint3D] {
        debtManager.debts.compactMap { debt in
            guard let estimate = debt.lastEstimate,
                  let moderate = estimate.escenarios.first(where: { $0.escenario == "moderada" })
                    ?? estimate.escenarios.first
            else { return nil }

            let charLabel: String
            switch estimate.caracterizacion.lowercased() {
            case "good", "buena": charLabel = "Buena"
            case "regular": charLabel = "Regular"
            case "bad", "mala": charLabel = "Mala"
            case "muy mala", "very bad": charLabel = "Muy mala"
            default: charLabel = "Regular"
            }

            return DebtPoint3D(
                id: debt.id,
                pendingAmount: debt.monto,
                estimatedDays: Double(moderate.diasPromedio),
                monthlyPayment: moderate.pagoMensual,
                name: debt.nombre,
                characterization: charLabel
            )
        }
    }
}
