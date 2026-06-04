import SwiftUI

struct MonthlyEstimateEditor: View {
    @Binding var estimates: [MonthlyEstimate]
    @State private var newAmount: Double = 0
    @State private var newCurrency: Currency = .cup
    @State private var newDayOfMonth: Int = 1

    var body: some View {
        VStack(spacing: 12) {
            ForEach(estimates.indices, id: \.self) { index in
                VStack(spacing: 10) {
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

                    HStack(spacing: 10) {
                        Text("Día de cobro")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DarkFinanceColors.secondaryText)

                        Spacer()

                        Stepper(value: Binding(
                            get: { estimates[index].dayOfMonth },
                            set: { estimates[index].dayOfMonth = min(max($0, 1), 31) }
                        ), in: 1...31) {
                            Text("\(estimates[index].dayOfMonth)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DarkFinanceColors.primaryText)
                        }
                        .labelsHidden()

                        Text("día \(estimates[index].dayOfMonth)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                    }
                }
            }

            VStack(spacing: 10) {
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
                        estimates.append(MonthlyEstimate(currency: newCurrency, amount: newAmount, dayOfMonth: newDayOfMonth))
                        newAmount = 0
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
                }

                HStack {
                    Text("Día del mes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                    Spacer()
                    Stepper(value: $newDayOfMonth, in: 1...31) {
                        EmptyView()
                    }
                    .labelsHidden()
                    Text("día \(newDayOfMonth)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryText)
                }
            }
        }
    }
}
