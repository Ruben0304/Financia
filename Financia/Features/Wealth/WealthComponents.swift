import SwiftUI

struct MonthlyEstimateEditor: View {
    @Binding var estimates: [MonthlyEstimate]
    @State private var newAmount: Double = 0
    @State private var newCurrency: Currency = .cup

    var body: some View {
        VStack(spacing: 12) {
            ForEach(estimates.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    Text(estimates[index].currency.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                        .frame(width: 44, alignment: .leading)

                    TextField("0.00", value: Binding(
                        get: { estimates[index].amount },
                        set: { estimates[index].amount = $0 }
                    ), format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()

                    Button {
                        estimates.remove(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                }
            }

            HStack(spacing: 10) {
                Picker("Moneda", selection: $newCurrency) {
                    ForEach(Currency.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100, alignment: .leading)

                TextField("0.00", value: $newAmount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()

                Button("Agregar") {
                    guard newAmount > 0 else { return }
                    estimates.append(MonthlyEstimate(currency: newCurrency, amount: newAmount))
                    newAmount = 0
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)
            }
        }
    }
}
