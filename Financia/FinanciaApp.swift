import SwiftUI
import SwiftData

@main
struct FinanciaApp: App {

    init() {
        _ = WalletManager.shared
        _ = CategoryManager.shared
        _ = TransactionManager.shared
        _ = BudgetManager.shared
        _ = AutomatedDraftManager.shared
        _ = LugarManager.shared
        _ = DebtManager.shared
        _ = ProfileManager.shared
        _ = SavingsGoalManager.shared
        _ = WealthManager.shared
        _ = ExpenseAnalysisManager.shared
        _ = SubscriptionManager.shared
        _ = CloudKitStatusManager.shared
        _ = PrestamoManager.shared
        _ = ExchangeRateManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthManager.shared)
                .environmentObject(WalletManager.shared)
                .environmentObject(BudgetManager.shared)
                .environmentObject(CategoryManager.shared)
                .environmentObject(TransactionManager.shared)
                .environmentObject(AutomatedDraftManager.shared)
                .environmentObject(ExchangeRateManager.shared)
                .environmentObject(LugarManager.shared)
                .environmentObject(DebtManager.shared)
                .environmentObject(ProfileManager.shared)
                .environmentObject(SavingsGoalManager.shared)
                .environmentObject(WealthManager.shared)
                .environmentObject(ExpenseAnalysisManager.shared)
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(CloudKitStatusManager.shared)
                .environmentObject(PrestamoManager.shared)
                .modelContainer(PersistenceManager.shared.container)
        }
    }
}
