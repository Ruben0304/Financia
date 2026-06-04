import SwiftUI

@available(iOS 26.0, *)
struct Analytics3DHubView: View {
    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analíticas 3D")
                            .font(DarkFinanceTypography.sectionTitle(size: 24))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text("Explora tus finanzas con gráficos tridimensionales interactivos")
                            .font(DarkFinanceTypography.body(size: 13))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }

                    chartCard(
                        icon: "circle.hexagongrid.fill",
                        title: "Mapa de Transacciones",
                        description: "Nube de puntos 3D de tus movimientos: tiempo × monto × categoría",
                        gradient: [DarkFinanceColors.primaryAccent, Color(hex: "FF8A4C")],
                        destination: TransactionScatter3DView()
                    )

                    chartCard(
                        icon: "chart.bar.xaxis",
                        title: "Categoría × Mes",
                        description: "Barras 3D mostrando gasto por categoría en cada mes",
                        gradient: [Color(hex: "8B5CF6"), Color(hex: "A78BFA")],
                        destination: CategoryMonth3DView()
                    )

                    chartCard(
                        icon: "waveform.path.ecg",
                        title: "Superficie Financiera",
                        description: "Proyección de balance neto basada en ingresos vs gastos",
                        gradient: [DarkFinanceColors.successGreen, Color(hex: "34D399")],
                        destination: FinancialSurface3DView()
                    )

                    chartCard(
                        icon: "chart.dots.scatter",
                        title: "Mapa de Deudas",
                        description: "Tus deudas en 3D: monto × días para pagar × pago mensual",
                        gradient: [DarkFinanceColors.errorRed, Color(hex: "FB7185")],
                        destination: DebtMap3DView()
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chartCard<Destination: View>(
        icon: String,
        title: String,
        description: String,
        gradient: [Color],
        destination: Destination
    ) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: gradient[0].opacity(0.3), radius: 6, x: 0, y: 3)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DarkFinanceTypography.emphasis(size: 15))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Text(description)
                        .font(DarkFinanceTypography.body(size: 12))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DarkFinanceColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
