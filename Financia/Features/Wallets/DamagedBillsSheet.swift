import SwiftUI

/// Denominaciones disponibles por moneda
private enum BillDenominations {
    static let cup: [Int] = [1, 3, 5, 10, 20, 50, 100, 200, 500, 1000]
    static let usd: [Int] = [1, 2, 5, 10, 20, 50, 100]

    static func denominations(for currency: Currency) -> [Int] {
        switch currency {
        case .cup: return cup
        case .usd: return usd
        case .eur: return [5, 10, 20, 50, 100, 200, 500]
        }
    }
}

struct DamagedBillsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager

    let wallet: Wallet

    /// Copia local del diccionario para edición
    @State private var counts: [String: Int] = [:]

    private var denominations: [Int] {
        BillDenominations.denominations(for: wallet.currency)
    }

    private var totalDamaged: Double {
        counts.reduce(0) { total, entry in
            let denom = Double(entry.key) ?? 0
            return total + denom * Double(entry.value)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        billsCard
                        if totalDamaged > 0 {
                            totalCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Billetes Dañados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveChanges()
                        dismiss()
                    }
                    .font(DarkFinanceTypography.emphasis(size: 14))
                    .foregroundColor(DarkFinanceColors.primaryText)
                }
            }
        }
        .onAppear {
            counts = wallet.billesDañados ?? [:]
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(wallet.color)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: wallet.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.name)
                    .font(DarkFinanceTypography.emphasis(size: 15))
                    .foregroundColor(DarkFinanceColors.primaryText)
                Text("Registra los billetes que no puedes usar")
                    .font(DarkFinanceTypography.caption())
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var billsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Denominaciones (\(wallet.currency.rawValue))")
                .font(DarkFinanceTypography.caption(size: 11, weight: .semibold))
                .foregroundColor(DarkFinanceColors.tertiaryText)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(denominations, id: \.self) { denom in
                    billRow(denomination: denom)
                    if denom != denominations.last {
                        Divider()
                            .background(DarkFinanceColors.cardBorder)
                    }
                }
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private func billRow(denomination: Int) -> some View {
        let key = "\(denomination)"
        let count = counts[key] ?? 0

        return HStack(spacing: 12) {
            // Etiqueta del billete
            HStack(spacing: 4) {
                Text(wallet.currency.symbol)
                    .font(DarkFinanceTypography.caption(size: 11))
                    .foregroundColor(DarkFinanceColors.tertiaryText)
                Text("\(denomination)")
                    .font(DarkFinanceTypography.monoAmount(size: 15, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
            }
            .frame(width: 70, alignment: .leading)

            Spacer()

            // Indicador de monto total para esta denominación
            if count > 0 {
                Text("\(count) × \(denomination) = \(count * denomination)")
                    .font(DarkFinanceTypography.caption(size: 11))
                    .foregroundColor(Color(hex: "F59E0B"))
                    .transition(.opacity)
            }

            // Controles - y +
            HStack(spacing: 0) {
                Button {
                    if (counts[key] ?? 0) > 0 {
                        counts[key, default: 0] -= 1
                        if counts[key] == 0 { counts.removeValue(forKey: key) }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(count > 0 ? DarkFinanceColors.primaryText : DarkFinanceColors.tertiaryText)
                        .frame(width: 32, height: 32)
                        .background(DarkFinanceColors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(count == 0)

                Text("\(count)")
                    .font(DarkFinanceTypography.monoAmount(size: 14, weight: .medium))
                    .foregroundColor(count > 0 ? DarkFinanceColors.primaryText : DarkFinanceColors.tertiaryText)
                    .frame(width: 36, alignment: .center)

                Button {
                    counts[key, default: 0] += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryText)
                        .frame(width: 32, height: 32)
                        .background(DarkFinanceColors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.15), value: count)
    }

    private var totalCard: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Total dañado")
                    .font(DarkFinanceTypography.emphasis(size: 14))
                    .foregroundColor(DarkFinanceColors.primaryText)
            }
            Spacer()
            Text(totalDamaged, format: .currency(code: wallet.currency.rawValue))
                .font(DarkFinanceTypography.monoAmount(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "F59E0B"))
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "F59E0B").opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func saveChanges() {
        var updated = wallet
        // Limpiar ceros antes de guardar
        updated.billesDañados = counts.isEmpty ? nil : counts.filter { $0.value > 0 }
        walletManager.updateWallet(updated)
    }
}
