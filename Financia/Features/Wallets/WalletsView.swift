import SwiftUI

struct WalletsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var exchangeRateManager: ExchangeRateManager

    @State private var isAddingWallet = false
    @State private var isTransferring = false
    @State private var walletToAdjust: Wallet?

    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerView
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
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isAddingWallet) {
            AddWalletSheet { newWallet in
                walletManager.addWallet(newWallet)
            }
        }
        .sheet(isPresented: $isTransferring) {
            TransferView()
        }
        .sheet(item: $walletToAdjust) { wallet in
            AdjustBalanceSheet(wallet: wallet)
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Carteras")
                .font(DarkFinanceTypography.title(size: 28))
                .foregroundColor(DarkFinanceColors.primaryText)

            Spacer()

            headerActionButton(systemName: "arrow.left.arrow.right") {
                isTransferring = true
            }

            headerActionButton(systemName: "plus") {
                isAddingWallet = true
            }
        }
    }

    private func headerActionButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DarkFinanceColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var walletsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tus carteras")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)

                Spacer()

                Text("\(walletManager.wallets.count)")
                    .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            Text("Crea tu primera cartera para comenzar.")
                .font(.system(size: 13))
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

        return HStack(spacing: 14) {
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)

                Text(wallet.currency.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(balance, format: .currency(code: wallet.currency.rawValue))
                    .font(DarkFinanceTypography.monoAmount(size: 16, weight: .semibold))
                    .foregroundColor(wallet.color)

                if let usdAmount {
                    Text(usdAmount, format: .currency(code: "USD"))
                        .font(.system(size: 12))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                } else {
                    Text("Sin tasa")
                        .font(.system(size: 12))
                        .foregroundColor(DarkFinanceColors.tertiaryText)
                }
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            walletToAdjust = wallet
        }
        .contextMenu {
            Button {
                walletToAdjust = wallet
            } label: {
                Label("Ajustar saldo", systemImage: "plusminus.circle")
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DarkFinanceColors.secondaryText)

                Spacer()

                if exchangeRateManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(DarkFinanceColors.secondaryText)
                } else if let lastUpdated = exchangeRateManager.lastUpdated {
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
                    .font(.system(size: 12))
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
