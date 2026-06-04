import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var automatedDraftManager: AutomatedDraftManager
    @EnvironmentObject var categoryManager: CategoryManager
    @EnvironmentObject var exchangeRateManager: ExchangeRateManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var wealthManager: WealthManager
    @EnvironmentObject var expenseAnalysisManager: ExpenseAnalysisManager

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedRange: DateRange = .month
    @State private var entrySheetKind: FinanceEntryFlow?
    @State private var isReceiptScannerPresented = false
    @State private var receiptReviewData: ReceiptReviewData?

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)

            switch authManager.state {
            case .unauthenticated:
                WelcomeScreen()
                    .transition(.opacity)

            case .pendingInvitation(let appleUserID, let name):
                InvitationAccessView(appleUserID: appleUserID, appleName: name)
                    .transition(.opacity)

            case .authenticated:
                authenticatedTabs
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if expenseAnalysisManager.showNotification {
                AINotificationBanner()
                    .padding(.top, 60)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .ignoresSafeArea()
        .tint(accentColor)
        .animation(.easeInOut(duration: 0.55), value: authManager.state)
        .animation(.easeInOut(duration: 0.4), value: expenseAnalysisManager.showNotification)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                automatedDraftManager.loadDrafts()
            }
        }
        .sheet(item: $entrySheetKind) { kind in
            AddEntrySheet(kind: kind) { result in
                handleNewEntry(result)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isReceiptScannerPresented) {
            ReceiptScannerView { extraction in
                receiptReviewData = ReceiptReviewData(extraction: extraction)
                isReceiptScannerPresented = false
            }
        }
        .sheet(item: $receiptReviewData, onDismiss: {
            receiptReviewData = nil
        }) { data in
            ReceiptReviewView(data: data)
        }
        .onOpenURL { url in
            if url.host == "import-draft" || url.host == "import-drafts" {
                _ = automatedDraftManager.importFromURL(url)
            } else if case .authenticated = authManager.state {
                if url.host == "add-expense" { entrySheetKind = .expense }
                else if url.host == "add-income" { entrySheetKind = .income }
            }
        }
    }

    private var authenticatedTabs: some View {
        TabView {
            FinanceDashboardView(
                selectedRange: $selectedRange,
                onAddIncome: handleIncome,
                onAddExpense: handleExpense,
                onScanReceipt: handleScanReceipt
            )
            .ignoresSafeArea()
            .tabItem { Label("Inicio", systemImage: "house.fill") }

            NavigationStack { BalanceView() }
                .tabItem { Label("Balance", systemImage: "chart.bar.xaxis") }

            WalletsView()
                .tabItem { Label("Carteras", systemImage: "wallet.pass") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
    }

    private func handleIncome()      { entrySheetKind = .income }
    private func handleExpense()     { entrySheetKind = .expense }
    private func handleScanReceipt() { isReceiptScannerPresented = true }
    private func handleNewEntry(_ result: FinanceEntrySheetResult) {}

    private var accentColor: Color {
        Color(hex: profileManager.profile.accentColorHex ?? "FF5C00")
    }
}

// MARK: - AI Notification Banner

struct AINotificationBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("FinancIA")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text("Análisis de gasto listo")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "C026D3"), Color(hex: "7E22CE")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(hex: "C026D3").opacity(0.45), radius: 14, x: 0, y: 6)
        )
    }
}

#Preview {
    ContentView()
}
