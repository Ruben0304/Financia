//
//  FinanciaApp.swift
//  Financia
//
//  Created by Ruben on 11/8/25.
//

import SwiftUI

@main
struct FinanciaApp: App {

    init() {
        // Configurar ExchangeRateManager con token de API
        // TODO: Mover token a un archivo de configuración seguro
        let apiToken = "YOUR_API_TOKEN_HERE"
        ExchangeRateManager.shared.configure(token: apiToken)

        // Pre-cargar managers
        _ = WalletManager.shared
        _ = CategoryManager.shared
        _ = TransactionManager.shared
        _ = LugarManager.shared
        _ = DebtManager.shared
        _ = ProfileManager.shared
        _ = SavingsGoalManager.shared
        _ = WealthManager.shared
        _ = ExpenseAnalysisManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WalletManager.shared)
                .environmentObject(CategoryManager.shared)
                .environmentObject(TransactionManager.shared)
                .environmentObject(ExchangeRateManager.shared)
                .environmentObject(LugarManager.shared)
                .environmentObject(DebtManager.shared)
                .environmentObject(ProfileManager.shared)
                .environmentObject(SavingsGoalManager.shared)
                .environmentObject(WealthManager.shared)
                .environmentObject(ExpenseAnalysisManager.shared)
                .preferredColorScheme(.dark)
        }
    }
}
