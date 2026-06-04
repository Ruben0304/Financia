import SwiftUI

enum HistoryRange: String, CaseIterable, Identifiable {
    case biweekly = "Quincena"
    case monthly = "Mes"

    var id: String { rawValue }
}

enum HistoryFilter {
    case all
    case income
    case expense
    case debt
}

struct HistoryView: View {
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var walletManager: WalletManager

    @State private var range: HistoryRange = .biweekly
    @State private var selectedTransaction: Transaction?
    @State private var repeatErrorMessage: String?
    @State private var isShowingRepeatError: Bool = false
    private let filter: HistoryFilter

    init(filter: HistoryFilter = .all) {
        self.filter = filter
    }

    var body: some View {
        List {
            Section {
                Picker("Rango", selection: $range) {
                    ForEach(HistoryRange.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            ForEach(groupedSections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.transactions) { transaction in
                        HistoryRow(
                            transaction: transaction,
                            category: category(for: transaction)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTransaction = transaction
                        }
                        .contextMenu {
                            Button {
                                repeatTransaction(transaction)
                            } label: {
                                Label("Repetir", systemImage: "arrow.clockwise")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                transactionManager.deleteTransaction(transaction)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    NavigationLink("Lugares") {
                        PlacesView()
                    }
                    NavigationLink("Categorías") {
                        CategoriesManagementView()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            transactionManager.loadTransactions()
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionEditView(transaction: transaction)
        }
        .alert("No se pudo repetir", isPresented: $isShowingRepeatError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(repeatErrorMessage ?? "Revisa el saldo de la cartera.")
        })
    }

    private var groupedSections: [HistorySection] {
        let sorted = filteredTransactions.sorted { $0.date > $1.date }
        let grouped = Dictionary(grouping: sorted) { transaction in
            periodStart(for: transaction.date)
        }
        return grouped
            .map { key, value in
                HistorySection(
                    startDate: key,
                    range: range,
                    transactions: value
                )
            }
            .sorted { $0.startDate > $1.startDate }
    }

    private var filteredTransactions: [Transaction] {
        switch filter {
        case .all:
            return transactionManager.transactions
        case .income:
            return transactionManager.transactions.filter { $0.type == .income }
        case .expense:
            return transactionManager.transactions.filter { $0.type == .expense }
        case .debt:
            return transactionManager.transactions.filter { $0.type == .expense && isDebtPayment($0) }
        }
    }

    private var title: String {
        switch filter {
        case .all: return "Historial"
        case .income: return "Historial ingresos"
        case .expense: return "Historial gastos"
        case .debt: return "Historial deudas"
        }
    }

    private func isDebtPayment(_ transaction: Transaction) -> Bool {
        transaction.description.lowercased().hasPrefix("pago de deuda")
    }

    private func periodStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month else {
            return date
        }
        switch range {
        case .biweekly:
            let day = components.day ?? 1
            let startDay = day <= 15 ? 1 : 16
            return calendar.date(from: DateComponents(year: year, month: month, day: startDay)) ?? date
        case .monthly:
            return calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        }
    }

    private func category(for transaction: Transaction) -> TransactionCategory? {
        if transaction.type == .income {
            return categoryManager.incomeCategories.first { $0.id == transaction.categoryId }
        }
        return categoryManager.expenseCategories.first { $0.id == transaction.categoryId }
    }

    private func repeatTransaction(_ transaction: Transaction) {
        if transaction.type == .expense {
            guard let wallet = walletManager.wallet(withId: transaction.walletId) else {
                showRepeatError("No se encontró la cartera origen.")
                return
            }
            let available = walletManager.calculateBalance(for: wallet)
            if transaction.amount > available {
                showRepeatError("El saldo de la cartera no es suficiente.")
                return
            }
        }

        let now = Date()
        let repeated = Transaction(
            type: transaction.type,
            amount: transaction.amount,
            date: now,
            categoryId: transaction.categoryId,
            categoryName: transaction.categoryName,
            subcategoryId: transaction.subcategoryId,
            subcategoryName: transaction.subcategoryName,
            description: transaction.description,
            walletId: transaction.walletId,
            createdAt: now,
            lugar: transaction.lugar,
            subitems: transaction.subitems,
            assetId: transaction.assetId,
            jobId: transaction.jobId,
            liabilityId: transaction.liabilityId
        )
        transactionManager.addTransaction(repeated)
    }

    private func showRepeatError(_ message: String) {
        repeatErrorMessage = message
        isShowingRepeatError = true
    }
}

private struct HistorySection: Identifiable {
    let id = UUID()
    let startDate: Date
    let range: HistoryRange
    let transactions: [Transaction]

    var title: String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es_ES")

        switch range {
        case .monthly:
            dateFormatter.dateFormat = "LLLL yyyy"
            return dateFormatter.string(from: startDate).capitalized
        case .biweekly:
            let day = calendar.component(.day, from: startDate)
            let endDay: Int
            if day <= 15 {
                endDay = 15
            } else {
                endDay = calendar.range(of: .day, in: .month, for: startDate)?.count ?? 30
            }
            dateFormatter.dateFormat = "LLLL yyyy"
            let monthYear = dateFormatter.string(from: startDate).capitalized
            return "\(day)-\(endDay) \(monthYear)"
        }
    }
}

private struct HistoryRow: View {
    let transaction: Transaction
    let category: TransactionCategory?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category?.color ?? Color(.systemGray4))
                .frame(width: 42, height: 42)
                .overlay(
                    CategoryIconView(
                        icon: category?.icon ?? "tag.fill",
                        color: .white,
                        size: 16
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.subcategoryName)
                    .font(.subheadline.weight(.semibold))
                Text(transaction.description.isEmpty ? transaction.categoryName : transaction.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(signedAmount)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(transaction.type == .income ? Color(red: 0.20, green: 0.60, blue: 0.46) : Color(red: 0.86, green: 0.33, blue: 0.33))
        }
        .padding(.vertical, 6)
    }

    private var signedAmount: String {
        let value = transaction.amount
        let formatted = value.formatted(.currency(code: "CUP"))
        return transaction.type == .income ? "+\(formatted)" : "-\(formatted)"
    }
}
