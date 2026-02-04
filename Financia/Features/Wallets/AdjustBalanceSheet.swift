import SwiftUI

struct AdjustBalanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager

    let wallet: Wallet

    @State private var isAdding = true
    @State private var amountText: String = ""

    private var currentBalance: Double {
        walletManager.calculateBalance(for: wallet)
    }

    private var parsedAmount: Double {
        let normalized = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private var previewBalance: Double {
        isAdding ? currentBalance + parsedAmount : currentBalance - parsedAmount
    }

    private var canSave: Bool {
        parsedAmount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Cartera")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(wallet.name)
                            .font(.subheadline.weight(.semibold))
                    }

                    HStack {
                        Text("Saldo actual")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(currentBalance, format: .currency(code: wallet.currency.rawValue))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Section("Ajuste") {
                    Picker("Tipo", selection: $isAdding) {
                        Text("Sumar").tag(true)
                        Text("Restar").tag(false)
                    }
                    .pickerStyle(.segmented)

                    TextField("Monto", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                if parsedAmount > 0 {
                    Section {
                        HStack {
                            Text("Nuevo saldo")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(previewBalance, format: .currency(code: wallet.currency.rawValue))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(previewBalance < 0 ? .red : .primary)
                        }
                    }
                }
            }
            .navigationTitle("Ajustar saldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let delta = isAdding ? parsedAmount : -parsedAmount
                        walletManager.adjustBalance(walletId: wallet.id, amount: delta)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
