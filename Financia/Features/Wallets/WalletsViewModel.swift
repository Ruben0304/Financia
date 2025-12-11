import Foundation
import Combine
import SwiftUI

class WalletsViewModel: ObservableObject {
    @Published var wallets: [Wallet] = [
        // Sample data
        Wallet(name: "Cartera Principal", currency: .usd, balance: 1500.0, icon: "creditcard.fill", color: .blue),
        Wallet(name: "Ahorros", currency: .eur, balance: 2500.0, icon: "banknote.fill", color: .green),
        Wallet(name: "Efectivo", currency: .cup, balance: 5000.0, icon: "dollarsign.circle.fill", color: .orange)
    ]
    
    @Published var usdToEurRate: Double = 0.92 // Placeholder, should be fetched
    @Published var usdToCupRate: Double // Passed from ContentView

    var totalBalanceInUSD: Double {
        wallets.reduce(0) { total, wallet in
            total + convertToUSD(amount: wallet.balance, from: wallet.currency)
        }
    }
    
    init(usdToCupRate: Double) {
        self.usdToCupRate = usdToCupRate
    }

    func addWallet(_ wallet: Wallet) {
        wallets.append(wallet)
    }

    func convertToUSD(amount: Double, from currency: Currency) -> Double {
        switch currency {
        case .usd:
            return amount
        case .eur:
            return amount / usdToEurRate
        case .cup:
            return amount / usdToCupRate
        }
    }
}