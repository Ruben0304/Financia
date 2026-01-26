import SwiftUI

struct WalletsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var exchangeRateManager: ExchangeRateManager

    @State private var isAddingWallet = false
    @State private var isTransferring = false

    var body: some View {
        NavigationStack {
            List {
                Section("Balance total") {
                    TotalBalanceCard(
                        totalBalanceUSD: walletManager.totalBalance(in: .usd),
                        exchangeRateManager: exchangeRateManager
                    )
                }

                Section("Carteras") {
                    ForEach(walletManager.wallets) { wallet in
                        WalletRow(
                            wallet: wallet,
                            balance: walletManager.calculateBalance(for: wallet),
                            exchangeRateManager: exchangeRateManager
                        )
                    }
                    .onDelete(perform: deleteWallet)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Carteras")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isTransferring = true }) {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isAddingWallet = true }) {
                        Image(systemName: "plus")
                    }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Balance total (USD)")
                    .font(.subheadline)
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
                    Text("Actualizado \(lastUpdated, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(totalBalanceUSD, format: .currency(code: "USD"))
                .font(.title.bold())
                .foregroundColor(.primary)
        }
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
