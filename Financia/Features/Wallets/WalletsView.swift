import SwiftUI

struct WalletsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var exchangeRateManager: ExchangeRateManager
    @EnvironmentObject var budgetManager: BudgetManager

    @State private var isAddingWallet = false
    @State private var isTransferring = false
    @State private var walletToAdjust: Wallet?
    @State private var walletForDamagedBills: Wallet?
    @State private var isShowingBreathing = false
    @State private var isShowingBudget = false

    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        TotalBalanceCard(
                            totalBalanceUSD: walletManager.totalBalance(in: .usd),
                            exchangeRateManager: exchangeRateManager
                        )
                        walletsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Carteras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Carteras")
                        .font(DarkFinanceTypography.toolbarTitle(size: 24))
                        .foregroundColor(DarkFinanceColors.primaryText)
                }

                ToolbarItem(placement: .subtitle) {
                    Text(walletsSubtitle)
                        .font(DarkFinanceTypography.toolbarSubtitle())
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    toolbarActionButton(systemName: "arrow.left.arrow.right") {
                        isTransferring = true
                    }

                    toolbarActionButton(systemName: "wind") {
                        isShowingBreathing = true
                    }

                    toolbarActionButton(systemName: "chart.pie") {
                        isShowingBudget = true
                    }

                    toolbarActionButton(systemName: "plus") {
                        isAddingWallet = true
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingBudget) {
                BudgetView()
                    .environmentObject(budgetManager)
                    .environmentObject(walletManager)
            }
        }
        .sheet(isPresented: $isAddingWallet) {
            AddWalletSheet { newWallet in
                walletManager.addWallet(newWallet)
            }
        }
        .sheet(isPresented: $isTransferring) {
            TransferView()
        }
        .sheet(isPresented: $isShowingBreathing) {
            FinancialBreathingSheet()
        }
        .sheet(item: $walletToAdjust) { wallet in
            AdjustBalanceSheet(wallet: wallet)
        }
        .sheet(item: $walletForDamagedBills) { wallet in
            DamagedBillsSheet(wallet: wallet) { updated in
                walletManager.updateWallet(updated)
            }
        }
    }

    private var walletsSubtitle: String {
        let count = walletManager.wallets.count
        return count == 1 ? "1 cartera activa" : "\(count) carteras activas"
    }

    private func toolbarActionButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)
        }
        .buttonStyle(.plain)
    }

    private var walletsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tus carteras")
                    .font(DarkFinanceTypography.sectionTitle())
                    .foregroundColor(DarkFinanceColors.primaryText)

                Spacer()

                Text("\(walletManager.wallets.count)")
                    .font(DarkFinanceTypography.caption(weight: .semibold))
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DarkFinanceColors.cardBackground)
                    )
            }

            if walletManager.wallets.isEmpty {
                emptyStateCard
            } else {
                VStack(spacing: 12) {
                    ForEach(walletManager.wallets) { wallet in
                        walletCard(wallet)
                    }
                }
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 40))
                .foregroundColor(DarkFinanceColors.secondaryText)

            Text("No tienes carteras")
                .font(DarkFinanceTypography.sectionTitle())
                .foregroundColor(DarkFinanceColors.primaryText)

            Text("Crea tu primera cartera para comenzar.")
                .font(DarkFinanceTypography.body(size: 13))
                .foregroundColor(DarkFinanceColors.secondaryText)
                .multilineTextAlignment(.center)

            Button("Crear cartera") {
                isAddingWallet = true
            }
            .buttonStyle(DarkPrimaryButton(color: DarkFinanceColors.primaryGradient))
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }

    private func walletCard(_ wallet: Wallet) -> some View {
        let balance = walletManager.calculateBalance(for: wallet)
        let usdAmount = exchangeRateManager.convert(amount: balance, from: wallet.currency, to: .usd)
        let damaged = wallet.totalBillesDañados

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Circle()
                    .fill(wallet.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: wallet.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.name)
                        .font(DarkFinanceTypography.emphasis(size: 14))
                        .foregroundColor(DarkFinanceColors.primaryText)

                    Text(wallet.currency.rawValue)
                        .font(DarkFinanceTypography.caption())
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(balance, format: .currency(code: wallet.currency.rawValue))
                        .font(DarkFinanceTypography.monoAmount(size: 16, weight: .semibold))
                        .foregroundColor(wallet.color)

                    if let usdAmount {
                        Text(usdAmount, format: .currency(code: "USD"))
                            .font(DarkFinanceTypography.caption())
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    } else {
                        Text("Sin tasa")
                            .font(DarkFinanceTypography.caption())
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                }
            }

            // Indicador de billetes dañados
            if damaged > 0 {
                Divider()
                    .background(DarkFinanceColors.cardBorder)
                    .padding(.vertical, 10)

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "F59E0B"))

                    Text("Billetes dañados:")
                        .font(DarkFinanceTypography.caption(size: 11))
                        .foregroundColor(DarkFinanceColors.secondaryText)

                    Text(damaged, format: .currency(code: wallet.currency.rawValue))
                        .font(DarkFinanceTypography.monoAmount(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "F59E0B"))

                    Spacer()

                    Button {
                        walletForDamagedBills = wallet
                    } label: {
                        Text("Editar")
                            .font(DarkFinanceTypography.caption(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "F59E0B"))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Fila de acciones (siempre visible)
            Divider()
                .background(DarkFinanceColors.cardBorder)
                .padding(.top, damaged > 0 ? 0 : 10)
                .padding(.bottom, 6)

            HStack(spacing: 0) {
                Button {
                    walletToAdjust = wallet
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plusminus.circle")
                            .font(.system(size: 13))
                        Text("Ajustar saldo")
                            .font(DarkFinanceTypography.caption(size: 12, weight: .medium))
                    }
                    .foregroundColor(DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 20)
                    .background(DarkFinanceColors.cardBorder)

                Button {
                    walletForDamagedBills = wallet
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "banknote")
                            .font(.system(size: 13))
                        Text("Billetes dañados")
                            .font(DarkFinanceTypography.caption(size: 12, weight: .medium))
                    }
                    .foregroundColor(damaged > 0 ? Color(hex: "F59E0B") : DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button {
                walletToAdjust = wallet
            } label: {
                Label("Ajustar saldo", systemImage: "plusminus.circle")
            }

            Button {
                walletForDamagedBills = wallet
            } label: {
                Label("Billetes dañados", systemImage: "banknote")
            }

            Button(role: .destructive) {
                walletManager.deleteWallet(wallet)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
}

struct TotalBalanceCard: View {
    let totalBalanceUSD: Double
    @ObservedObject var exchangeRateManager: ExchangeRateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Balance total (USD)")
                    .font(DarkFinanceTypography.action(size: 13))
                    .foregroundColor(DarkFinanceColors.secondaryText)

                Spacer()

                if exchangeRateManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(DarkFinanceColors.secondaryText)
                } else if exchangeRateManager.lastUpdated != nil {
                    Button(action: {
                        exchangeRateManager.refreshRates()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                }
            }

            Text(totalBalanceUSD, format: .currency(code: "USD"))
                .font(DarkFinanceTypography.monoAmount(size: 32, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            if let lastUpdated = exchangeRateManager.lastUpdated {
                Text("Actualizado \(lastUpdated, style: .relative)")
                    .font(DarkFinanceTypography.caption())
                    .foregroundColor(DarkFinanceColors.tertiaryText)
            }
        }
        .darkFinanceCard(cornerRadius: 20, padding: 20)
    }
}

struct WalletsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletsView()
            .environmentObject(WalletManager.shared)
            .environmentObject(ExchangeRateManager.shared)
    }
}
