import SwiftUI
import Combine

struct ContentView: View {
    @AppStorage("invitationValidated") private var invitationValidated = false
    @State private var selectedRange: DateRange = .month
    @State private var entrySheetKind: FinanceEntryFlow?
    @State private var isReceiptScannerPresented = false
    @State private var receiptReviewData: ReceiptReviewData?

    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var categoryManager: CategoryManager
    @EnvironmentObject var exchangeRateManager: ExchangeRateManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var wealthManager: WealthManager

    var body: some View {
        ZStack {
            Color(.systemBackground)

            if invitationValidated {
                authenticatedTabs
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                InvitationAccessView()
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .tint(accentColor)
        .animation(.easeInOut(duration: 0.55), value: invitationValidated)
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
            .tabItem {
                Label("Inicio", systemImage: "house.fill")
            }

            NavigationStack {
                BalanceView()
            }
            .tabItem {
                Label("Balance", systemImage: "chart.bar.xaxis")
            }

            WalletsView()
            .tabItem {
                Label("Carteras", systemImage: "wallet.pass")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Perfil", systemImage: "person.crop.circle")
            }
        }
    }

    private func handleIncome() {
        entrySheetKind = .income
    }

    private func handleExpense() {
        entrySheetKind = .expense
    }

    private func handleScanReceipt() {
        isReceiptScannerPresented = true
    }

    private func handleNewEntry(_ result: FinanceEntrySheetResult) {
        // La transacción ya fue guardada en AddEntrySheet
        // Aquí podríamos agregar lógica adicional si es necesario
    }

    private var accentColor: Color {
        Color(hex: profileManager.profile.accentColorHex ?? "FF5C00")
    }
}

#Preview {
    ContentView()
}
