import SwiftUI

struct FinancialBreathingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var wealthManager: WealthManager
    @EnvironmentObject private var profileManager: ProfileManager

    @State private var selectedWalletID: UUID?

    private let breathingManager = FinancialBreathingManager.shared

    private var accentColor: Color {
        Color(hex: profileManager.profile.accentColorHex ?? "FF5C00")
    }

    private var selectedWallet: Wallet? {
        guard let selectedWalletID else { return walletManager.wallets.first }
        return walletManager.wallet(withId: selectedWalletID) ?? walletManager.wallets.first
    }

    private var insight: WalletBreathingInsight? {
        guard let wallet = selectedWallet else { return nil }
        return breathingManager.insight(
            for: wallet,
            currentBalance: walletManager.calculateBalance(for: wallet),
            transactions: transactionManager.transactions,
            wealthManager: wealthManager
        )
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header

                if walletManager.wallets.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            walletSelector

                            if let insight {
                                breathingCards(insight)
                                supportingMetrics(insight)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            selectedWalletID = selectedWallet?.id ?? walletManager.wallets.first?.id
        }
        .onChange(of: walletManager.wallets) { _, wallets in
            guard let selectedWalletID else {
                self.selectedWalletID = wallets.first?.id
                return
            }

            if wallets.contains(where: { $0.id == selectedWalletID }) == false {
                self.selectedWalletID = wallets.first?.id
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Respiración")
                    .font(.custom("Georgia", size: 28))
                    .foregroundColor(DarkFinanceColors.primaryText)

                Text("Resistencia real por cartera y gasto diario hasta tu próximo cobro")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(DarkFinanceColors.cardBackground.opacity(0.95))
                            .overlay(
                                Circle()
                                    .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var walletSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cartera")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DarkFinanceColors.secondaryText)

            Menu {
                ForEach(walletManager.wallets) { wallet in
                    Button {
                        selectedWalletID = wallet.id
                    } label: {
                        Label(wallet.name, systemImage: wallet.icon)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(selectedWallet?.color ?? accentColor)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: selectedWallet?.icon ?? "wallet.pass.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedWallet?.name ?? "Selecciona una cartera")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)

                        if let selectedWallet {
                            Text(selectedWallet.currency.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DarkFinanceColors.secondaryText)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DarkFinanceColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func breathingCards(_ insight: WalletBreathingInsight) -> some View {
        VStack(spacing: 14) {
            metricCard(
                title: "Días que puedes respirar",
                value: survivalDaysLabel(for: insight),
                subtitle: learnedSpendLabel(for: insight),
                tint: selectedWallet?.color ?? accentColor
            )

            metricCard(
                title: "Puedes gastar por día",
                value: dailySpendLabel(for: insight),
                subtitle: nextIncomeLabel(for: insight),
                tint: Color(hex: "0EA5E9")
            )
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DarkFinanceColors.secondaryText)

            Text(value)
                .font(DarkFinanceTypography.monoAmount(size: 32, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(DarkFinanceColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DarkFinanceColors.cardBackground,
                            tint.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func supportingMetrics(_ insight: WalletBreathingInsight) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cómo lo está aprendiendo")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            metricRow(
                title: "Balance actual",
                value: insight.currentBalance.formatted(.currency(code: insight.wallet.currency.rawValue))
            )
            metricRow(
                title: "Gasto diario aprendido",
                value: insight.learnedDailySpend > 0
                    ? insight.learnedDailySpend.formatted(.currency(code: insight.wallet.currency.rawValue))
                    : "Sin historial"
            )
            metricRow(
                title: "Próximo ingreso",
                value: upcomingIncomeValue(for: insight)
            )
            metricRow(
                title: "Reservado antes de cobrar",
                value: insight.reservedExpensesUntilNextIncome > 0
                    ? insight.reservedExpensesUntilNextIncome.formatted(.currency(code: insight.wallet.currency.rawValue))
                    : "0"
            )
            metricRow(
                title: "Historial observado",
                value: "\(insight.observedDays) días · \(insight.expenseDays) con gasto"
            )
            metricRow(
                title: "Confianza",
                value: confidenceLabel(for: insight.confidence)
            )
        }
        .darkFinanceCard(cornerRadius: 22, padding: 20)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DarkFinanceColors.secondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(DarkFinanceColors.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "wind")
                .font(.system(size: 42))
                .foregroundColor(DarkFinanceColors.secondaryText)

            Text("No tienes carteras")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            Text("Crea una cartera y algunos gastos para calcular la respiración financiera.")
                .font(.system(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var background: some View {
        ZStack {
            DarkFinanceBackground()

            LinearGradient(
                colors: [accentColor.opacity(0.10), Color.clear, Color(hex: "0EA5E9").opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(accentColor.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 150, y: -260)

            Circle()
                .fill(Color(hex: "0EA5E9").opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -160, y: 160)
        }
        .ignoresSafeArea()
    }

    private func survivalDaysLabel(for insight: WalletBreathingInsight) -> String {
        guard insight.hasEnoughHistory, let survivalDays = insight.survivalDays else {
            return "Sin base"
        }

        return "\(survivalDays) días"
    }

    private func learnedSpendLabel(for insight: WalletBreathingInsight) -> String {
        guard insight.hasEnoughHistory else {
            return "Necesita más historial en esta cartera para aprender bien tu ritmo real."
        }

        let formatted = insight.learnedDailySpend.formatted(.currency(code: insight.wallet.currency.rawValue))
        return "Aprendido desde tu historial: \(formatted) por día."
    }

    private func dailySpendLabel(for insight: WalletBreathingInsight) -> String {
        guard let amount = insight.safeDailySpendUntilNextIncome else {
            return "Sin cobro"
        }

        return amount.formatted(.currency(code: insight.wallet.currency.rawValue))
    }

    private func nextIncomeLabel(for insight: WalletBreathingInsight) -> String {
        guard let nextIncomeDate = insight.nextIncomeDate else {
            return "No hay ingresos programados por trabajos o activos en \(insight.wallet.currency.rawValue)."
        }

        let date = nextIncomeDate.formatted(date: .abbreviated, time: .omitted)
        return "Hasta \(date), sin mezclar otras carteras."
    }

    private func upcomingIncomeValue(for insight: WalletBreathingInsight) -> String {
        guard let nextIncomeDate = insight.nextIncomeDate else {
            return "No programado"
        }

        let amount = insight.nextIncomeAmount.formatted(.currency(code: insight.wallet.currency.rawValue))
        let date = nextIncomeDate.formatted(date: .abbreviated, time: .omitted)
        return "\(amount) · \(date)"
    }

    private func confidenceLabel(for confidence: Double) -> String {
        switch confidence {
        case 0.8...:
            return "Alta"
        case 0.5..<0.8:
            return "Media"
        default:
            return "Baja"
        }
    }
}

#Preview {
    FinancialBreathingSheet()
        .environmentObject(WalletManager.shared)
        .environmentObject(TransactionManager.shared)
        .environmentObject(WealthManager.shared)
        .environmentObject(ProfileManager.shared)
}
