import SwiftUI

struct AssetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var wealthManager: WealthManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var walletManager: WalletManager

    @State private var asset: Asset

    init(asset: Asset) {
        _asset = State(initialValue: asset)
    }

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    formCard
                    estimatesCard
                    performanceCard
                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Activo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    asset.updatedAt = Date()
                    wealthManager.updateAsset(asset)
                }
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthField(label: "Nombre") {
                TextField("Nombre", text: $asset.name)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }

            wealthField(label: "Notas") {
                TextField("Opcional", text: $asset.notes, axis: .vertical)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var estimatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimado mensual")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            MonthlyEstimateEditor(estimates: $asset.monthlyEstimates)
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var performanceCard: some View {
        let performances = monthlyPerformances(for: asset.id, type: .income)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Desempeño este mes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            if performances.isEmpty {
                Text("Sin datos suficientes")
                    .font(.system(size: 13))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            } else {
                ForEach(performances, id: \.currency.rawValue) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.currency.rawValue) · \(item.current.formatted(.currency(code: item.currency.rawValue)))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(item.label)
                            .font(.system(size: 12))
                            .foregroundColor(item.isAbove ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            wealthManager.deleteAsset(asset)
            dismiss()
        } label: {
            Text("Eliminar activo")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }
}

struct JobDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var wealthManager: WealthManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var walletManager: WalletManager

    @State private var job: Job

    init(job: Job) {
        _job = State(initialValue: job)
    }

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    formCard
                    estimatesCard
                    performanceCard
                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Trabajo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    job.updatedAt = Date()
                    wealthManager.updateJob(job)
                }
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthField(label: "Nombre") {
                TextField("Nombre", text: $job.name)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }

            wealthField(label: "Notas") {
                TextField("Opcional", text: $job.notes, axis: .vertical)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var estimatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimado mensual")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            MonthlyEstimateEditor(estimates: $job.monthlyEstimates)
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var performanceCard: some View {
        let performances = monthlyPerformances(for: job.id, type: .income)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Desempeño este mes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            if performances.isEmpty {
                Text("Sin datos suficientes")
                    .font(.system(size: 13))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            } else {
                ForEach(performances, id: \.currency.rawValue) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.currency.rawValue) · \(item.current.formatted(.currency(code: item.currency.rawValue)))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(item.label)
                            .font(.system(size: 12))
                            .foregroundColor(item.isAbove ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            wealthManager.deleteJob(job)
            dismiss()
        } label: {
            Text("Eliminar trabajo")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }
}

struct LiabilityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var wealthManager: WealthManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var walletManager: WalletManager

    @State private var liability: Liability

    init(liability: Liability) {
        _liability = State(initialValue: liability)
    }

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    formCard
                    estimatesCard
                    performanceCard
                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Pasivo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    liability.updatedAt = Date()
                    wealthManager.updateLiability(liability)
                }
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthField(label: "Nombre") {
                TextField("Nombre", text: $liability.name)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }

            wealthField(label: "Notas") {
                TextField("Opcional", text: $liability.notes, axis: .vertical)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var estimatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimado mensual")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            MonthlyEstimateEditor(estimates: $liability.monthlyEstimates)
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var performanceCard: some View {
        let performances = monthlyPerformances(for: liability.id, type: .expense)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Desempeño este mes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            if performances.isEmpty {
                Text("Sin datos suficientes")
                    .font(.system(size: 13))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            } else {
                ForEach(performances, id: \.currency.rawValue) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.currency.rawValue) · \(item.current.formatted(.currency(code: item.currency.rawValue)))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(item.label)
                            .font(.system(size: 12))
                            .foregroundColor(item.isAbove ? DarkFinanceColors.successGreen : DarkFinanceColors.errorRed)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            wealthManager.deleteLiability(liability)
            dismiss()
        } label: {
            Text("Eliminar pasivo")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }
}

private func wealthField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(label)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(DarkFinanceColors.secondaryText)
        content()
    }
}

private struct PerformanceItem {
    let currency: Currency
    let current: Double
    let average: Double

    var isAbove: Bool { current >= average }

    var label: String {
        guard average > 0 else { return "Sin promedio" }
        let diff = (current - average) / average
        let percent = diff.formatted(.percent.precision(.fractionLength(0)))
        return diff >= 0 ? "Por encima del promedio \(percent)" : "Por debajo del promedio \(percent)"
    }
}

private extension AssetDetailView {
    func monthlyPerformances(for id: UUID, type: TransactionType) -> [PerformanceItem] {
        let transactions = transactionManager.transactions.filter { $0.type == type && $0.assetId == id }
        return performanceItems(from: transactions)
    }

    func performanceItems(from transactions: [Transaction]) -> [PerformanceItem] {
        performanceItemsForTransactions(transactions, walletManager: walletManager)
    }
}

private extension JobDetailView {
    func monthlyPerformances(for id: UUID, type: TransactionType) -> [PerformanceItem] {
        let transactions = transactionManager.transactions.filter { $0.type == type && $0.jobId == id }
        return performanceItems(from: transactions)
    }

    func performanceItems(from transactions: [Transaction]) -> [PerformanceItem] {
        performanceItemsForTransactions(transactions, walletManager: walletManager)
    }
}

private extension LiabilityDetailView {
    func monthlyPerformances(for id: UUID, type: TransactionType) -> [PerformanceItem] {
        let transactions = transactionManager.transactions.filter { $0.type == type && $0.liabilityId == id }
        return performanceItems(from: transactions)
    }

    func performanceItems(from transactions: [Transaction]) -> [PerformanceItem] {
        performanceItemsForTransactions(transactions, walletManager: walletManager)
    }
}

private func performanceItemsForTransactions(
    _ transactions: [Transaction],
    walletManager: WalletManager
) -> [PerformanceItem] {
    let calendar = Calendar.current
    let now = Date()
    let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

    var perCurrencyMonthly: [Currency: [Date: Double]] = [:]

    for transaction in transactions {
        guard let wallet = walletManager.wallet(withId: transaction.walletId) else { continue }
        let currency = wallet.currency
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: transaction.date)) ?? transaction.date
        var totals = perCurrencyMonthly[currency, default: [:]]
        totals[monthStart, default: 0] += transaction.amount
        perCurrencyMonthly[currency] = totals
    }

    return perCurrencyMonthly
        .map { currency, totals in
            let current = totals[currentMonthStart] ?? 0
            let average = totals.values.isEmpty ? 0 : totals.values.reduce(0, +) / Double(totals.values.count)
            return PerformanceItem(currency: currency, current: current, average: average)
        }
        .sorted { $0.currency.rawValue < $1.currency.rawValue }
}
