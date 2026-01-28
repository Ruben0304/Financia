import SwiftUI

struct DebtHistoryView: View {
    @EnvironmentObject private var debtManager: DebtManager

    var body: some View {
        List {
            if paidDebts.isEmpty {
                Text("No hay deudas pagadas.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(paidDebts) { debt in
                    NavigationLink {
                        DebtDetailView(debt: debt)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(red: 0.20, green: 0.60, blue: 0.46).opacity(0.18))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(red: 0.20, green: 0.60, blue: 0.46))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(debt.nombre)
                                    .font(.subheadline.weight(.semibold))
                                Text(statusText(for: debt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(debt.montoOriginal, format: .currency(code: debt.moneda.rawValue))
                                    .font(.subheadline.weight(.semibold))
                                Text(lastPaymentDate(for: debt), style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Historial de deudas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var paidDebts: [Debt] {
        debtManager.debts
            .filter { $0.monto <= 0 }
            .sorted { lastPaymentDate(for: $0) > lastPaymentDate(for: $1) }
    }

    private func lastPaymentDate(for debt: Debt) -> Date {
        debt.pagos.map(\.date).max() ?? debt.createdAt
    }

    private func statusText(for debt: Debt) -> String {
        let count = debt.pagos.count
        if count == 0 {
            return "Pagada"
        }
        return "Pagada con \(count) pago\(count == 1 ? "" : "s")"
    }
}
