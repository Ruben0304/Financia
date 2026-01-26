import SwiftUI

enum BalanceTab: String, CaseIterable, Identifiable {
    case ingresos = "Ingresos"
    case gastos = "Gastos"
    case deudas = "Deudas"

    var id: String { rawValue }
}

struct BalanceView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var debtManager: DebtManager
    @EnvironmentObject private var walletManager: WalletManager

    @State private var selectedTab: BalanceTab = .ingresos
    @State private var entrySheetKind: FinanceEntryFlow?
    @State private var isAddingDebt: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pickerCard
                statsCard
                linksCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Balance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    switch selectedTab {
                    case .ingresos:
                        entrySheetKind = .income
                    case .gastos:
                        entrySheetKind = .expense
                    case .deudas:
                        isAddingDebt = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $entrySheetKind) { kind in
            AddEntrySheet(kind: kind) { _ in }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingDebt) {
            DebtEditorView { newDebt in
                debtManager.addDebt(newDebt)
            }
        }
    }

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resumen")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("Sección", selection: $selectedTab) {
                ForEach(BalanceTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: statIcon)
                        .foregroundColor(statColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statTitle)
                        .font(.headline)
                        .foregroundColor(statColor)
                    Text(statSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Total")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(statColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statColor.opacity(0.12), in: Capsule())
            }

            if statLines.isEmpty {
                Text("--")
                    .foregroundColor(.secondary)
            } else {
                ForEach(statLines, id: \.label) { line in
                    HStack {
                        Text(line.label)
                            .font(.subheadline)
                        Spacer()
                        Text(line.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(statColor)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(statColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            HStack {
                Text("Movimientos")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(movementCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .overlay(
                    LinearGradient(
                        colors: [statColor.opacity(0.18), statColor.opacity(0.02), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(statColor.opacity(0.12), lineWidth: 1)
                )
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    private var linksCard: some View {
        VStack(spacing: 10) {
            switch selectedTab {
            case .ingresos:
                NavigationLink {
                    HistoryView(filter: .income)
                } label: {
                    Label("Ver historial de ingresos", systemImage: "clock.arrow.circlepath")
                        .foregroundColor(.primary)
                }
            case .gastos:
                NavigationLink {
                    HistoryView(filter: .expense)
                } label: {
                    Label("Ver historial de gastos", systemImage: "clock.arrow.circlepath")
                        .foregroundColor(.primary)
                }
            case .deudas:
                NavigationLink {
                    DebtsView()
                } label: {
                    Label("Gestionar deudas", systemImage: "banknote")
                        .foregroundColor(.primary)
                }
                NavigationLink {
                    HistoryView(filter: .debt)
                } label: {
                    Label("Ver historial de pagos", systemImage: "clock.arrow.circlepath")
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
    }

    private var statTitle: String {
        switch selectedTab {
        case .ingresos: return "Ingresos"
        case .gastos: return "Gastos"
        case .deudas: return "Deudas"
        }
    }

    private var statSubtitle: String {
        switch selectedTab {
        case .ingresos: return "Entradas registradas"
        case .gastos: return "Salidas registradas"
        case .deudas: return "Deudas activas"
        }
    }

    private var statIcon: String {
        switch selectedTab {
        case .ingresos: return "arrow.down.circle.fill"
        case .gastos: return "arrow.up.circle.fill"
        case .deudas: return "exclamationmark.triangle.fill"
        }
    }

    private var statColor: Color {
        switch selectedTab {
        case .ingresos: return Color(red: 0.20, green: 0.60, blue: 0.46)
        case .gastos: return Color(red: 0.86, green: 0.33, blue: 0.33)
        case .deudas: return Color(red: 0.86, green: 0.33, blue: 0.33)
        }
    }

    private struct StatLine {
        let label: String
        let value: String
    }

    private var statLines: [StatLine] {
        switch selectedTab {
        case .ingresos:
            return totalsByCurrency(for: .income).map {
                StatLine(label: $0.currency.rawValue, value: $0.total.formatted(.currency(code: $0.currency.rawValue)))
            }
        case .gastos:
            return totalsByCurrency(for: .expense).map {
                StatLine(label: $0.currency.rawValue, value: $0.total.formatted(.currency(code: $0.currency.rawValue)))
            }
        case .deudas:
            return totalsDebtsByCurrency().map {
                StatLine(label: $0.currency.rawValue, value: $0.total.formatted(.currency(code: $0.currency.rawValue)))
            }
        }
    }

    private var movementCount: Int {
        switch selectedTab {
        case .ingresos:
            return transactionManager.transactions.filter { $0.type == .income }.count
        case .gastos:
            return transactionManager.transactions.filter { $0.type == .expense }.count
        case .deudas:
            return debtManager.debts.count
        }
    }

    private func totalsByCurrency(for type: TransactionType) -> [(currency: Currency, total: Double)] {
        let filtered = transactionManager.transactions.filter { $0.type == type }
        let grouped = Dictionary(grouping: filtered, by: { transactionCurrency(for: $0) })
        let totals = grouped.compactMap { key, items -> (Currency, Double)? in
            guard let currency = key else { return nil }
            let total = items.reduce(0) { $0 + $1.amount }
            return (currency, total)
        }
        return totals.sorted { $0.0.rawValue < $1.0.rawValue }
    }

    private func totalsDebtsByCurrency() -> [(currency: Currency, total: Double)] {
        let grouped = Dictionary(grouping: debtManager.debts, by: { $0.moneda })
        return grouped.map { currency, debts in
            let total = debts.reduce(0) { $0 + $1.monto }
            return (currency, total)
        }
        .sorted { $0.0.rawValue < $1.0.rawValue }
    }

    private func transactionCurrency(for transaction: Transaction) -> Currency? {
        walletManager.wallet(withId: transaction.walletId)?.currency
    }
}
