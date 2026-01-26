import SwiftUI
import AuthenticationServices
import Combine

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var errorMessage: String?
    @State private var selectedRange: DateRange = .month
    @State private var entrySheetKind: FinanceEntryFlow?
    @State private var isReceiptScannerPresented = false
    @State private var receiptReviewData: ReceiptReviewData?

    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var categoryManager: CategoryManager
    @EnvironmentObject var exchangeRateManager: ExchangeRateManager

    var body: some View {
        ZStack {
            AuroraBackground()

            if isAuthenticated {
                authenticatedTabs
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                WelcomeScreen(
                    isAuthenticated: isAuthenticated,
                    errorMessage: errorMessage,
                    configureRequest: configureRequest,
                    handleResult: handleResult,
                    onSkip: skipLogin
                )
                .padding(.horizontal, 32)
                .padding(.vertical, 48)
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.55), value: isAuthenticated)
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
                Label("General", systemImage: "rectangle.grid.2x2.fill")
            }

            WalletsView()
            .tabItem {
                Label("Carteras", systemImage: "wallet.pass")
            }

            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label("Asistente", systemImage: "bubble.left.and.bubble.right.fill")
            }

            PlaceholderTab(
                title: "Historial",
                message: "Tu historial de movimientos aparecerá en este espacio."
            )
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .tabItem {
                Label("Historial", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    private func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard authorization.credential is ASAuthorizationAppleIDCredential else {
                errorMessage = "No se pudo leer la credencial devuelta."
                return
            }

            completeAuthentication()

        case .failure(let error):
            errorMessage = error.localizedDescription
            isAuthenticated = false
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

    private func skipLogin() {
        completeAuthentication()
    }

    private func completeAuthentication() {
        withAnimation(.easeInOut(duration: 0.6)) {
            isAuthenticated = true
        }
        errorMessage = nil
    }
}

private struct PlaceholderTab: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(AuroraColors.primaryText)

            Text(message)
                .font(.title3)
                .foregroundStyle(AuroraColors.secondaryText)
                .lineSpacing(3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ContentView()
}
