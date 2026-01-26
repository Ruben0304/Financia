import SwiftUI

struct WalletsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var exchangeRateManager: ExchangeRateManager

    @State private var isAddingWallet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.ignoresSafeArea()

                VStack {
                    TotalBalanceCard(
                        totalBalanceUSD: walletManager.totalBalance(in: .usd),
                        exchangeRateManager: exchangeRateManager
                    )
                    .padding(.horizontal)

                    List {
                        ForEach(walletManager.wallets) { wallet in
                            WalletRow(
                                wallet: wallet,
                                balance: walletManager.calculateBalance(for: wallet),
                                exchangeRateManager: exchangeRateManager
                            )
                        }
                        .onDelete(perform: deleteWallet)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                .navigationTitle("Carteras")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isAddingWallet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                .sheet(isPresented: $isAddingWallet) {
                    AddWalletSheet { newWallet in
                        walletManager.addWallet(newWallet)
                    }
                }
            }
        }
    }

    private func deleteWallet(at offsets: IndexSet) {
        offsets.forEach { index in
            let wallet = walletManager.wallets[index]
            walletManager.deleteWallet(wallet)
        }
    }
}

struct TotalBalanceCard: View {
    let totalBalanceUSD: Double
    @ObservedObject var exchangeRateManager: ExchangeRateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Balance Total (USD)")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                if exchangeRateManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let lastUpdated = exchangeRateManager.lastUpdated {
                    Button(action: {
                        exchangeRateManager.refreshRates()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Actualizado: \(lastUpdated, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(totalBalanceUSD, format: .currency(code: "USD"))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct WalletRow: View {
    let wallet: Wallet
    let balance: Double
    @ObservedObject var exchangeRateManager: ExchangeRateManager

    var body: some View {
        HStack {
            Image(systemName: wallet.icon)
                .font(.title)
                .foregroundColor(wallet.color)
                .frame(width: 50)

            VStack(alignment: .leading) {
                Text(wallet.name)
                    .font(.headline)
                Text(balance, format: .currency(code: wallet.currency.rawValue))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let usdAmount = exchangeRateManager.convert(amount: balance, from: wallet.currency, to: .usd) {
                Text(usdAmount, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundColor(wallet.color)
            } else {
                Text("--")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct WalletsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletsView()
            .environmentObject(WalletManager.shared)
            .environmentObject(TransactionManager.shared)
            .environmentObject(ExchangeRateManager.shared)
    }
}