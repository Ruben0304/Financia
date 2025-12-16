import SwiftUI

struct WalletsView: View {
    @StateObject private var viewModel: WalletsViewModel
    @State private var isAddingWallet = false
    
    @Binding var usdToCupRate: Double

    init(usdToCupRate: Binding<Double>) {
        _usdToCupRate = usdToCupRate
        _viewModel = StateObject(wrappedValue: WalletsViewModel(usdToCupRate: usdToCupRate.wrappedValue))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.ignoresSafeArea() // Use a clear background to show the Aurora effect from ContentView
                
                VStack {
                    TotalBalanceCard(totalBalanceUSD: viewModel.totalBalanceInUSD)
                        .padding(.horizontal)

                    List {
                        ForEach(viewModel.wallets) { wallet in
                            WalletRow(wallet: wallet, viewModel: viewModel)
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
                        viewModel.addWallet(newWallet)
                    }
                }
                .onChange(of: usdToCupRate) { newRate in
                    viewModel.usdToCupRate = newRate
                }
            }
        }
    }

    private func deleteWallet(at offsets: IndexSet) {
        viewModel.wallets.remove(atOffsets: offsets)
    }
}

struct TotalBalanceCard: View {
    let totalBalanceUSD: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Balance Total (USD)")
                .font(.headline)
                .foregroundColor(.secondary)
            
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
    @ObservedObject var viewModel: WalletsViewModel

    var body: some View {
        HStack {
            Image(systemName: wallet.icon)
                .font(.title)
                .foregroundColor(wallet.color)
                .frame(width: 50)

            VStack(alignment: .leading) {
                Text(wallet.name)
                    .font(.headline)
                Text(wallet.balance, format: .currency(code: wallet.currency.rawValue))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(viewModel.convertToUSD(amount: wallet.balance, from: wallet.currency), format: .currency(code: "USD"))
                .font(.headline)
                .foregroundColor(wallet.color)
        }
        .padding(.vertical, 8)
    }
}

struct WalletsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletsView(usdToCupRate: .constant(24.37))
    }
}