import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var errorMessage: String?
    @State private var selectedRange: DateRange = .month
    @State private var financeEntries: [FinanceEntry] = FinanceEntry.sampleHistory
    @State private var usdToCupRate: Double = 24.37
    @State private var entrySheetKind: FinanceEntryFlow?

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
    }

    private var authenticatedTabs: some View {
        TabView {
            FinanceDashboardView(
                selectedRange: $selectedRange,
                entries: financeEntries,
                usdToCupRate: usdToCupRate,
                onAddIncome: handleIncome,
                onAddExpense: handleExpense
            )
            .ignoresSafeArea()
            .tabItem {
                Label("General", systemImage: "rectangle.grid.2x2.fill")
            }

            PlaceholderTab(
                title: "Carteras",
                message: "Aquí podrás revisar y crear nuevas carteras muy pronto."
            )
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .tabItem {
                Label("Carteras", systemImage: "wallet.pass")
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

    private func handleNewEntry(_ result: FinanceEntrySheetResult) {
        let signedAmount = result.kind == .income ? result.amount : -result.amount
        let currentBalance = financeEntries.last?.value ?? 0
        let updatedBalance = currentBalance + signedAmount
        let newEntry = FinanceEntry(date: Date(), value: updatedBalance)
        financeEntries.append(newEntry)
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
