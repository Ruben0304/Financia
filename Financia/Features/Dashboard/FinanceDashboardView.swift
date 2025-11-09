import SwiftUI
import Charts

struct FinanceDashboardView: View {
    @Binding var selectedRange: DateRange
    let entries: [FinanceEntry]
    let usdToCupRate: Double
    var onAddIncome: () -> Void = {}
    var onAddExpense: () -> Void = {}

    private var filteredEntries: [FinanceEntry] {
        guard let start = Calendar.current.date(byAdding: .day, value: -selectedRange.lengthInDays, to: Date()) else {
            return entries
        }
        return entries.filter { $0.date >= start }
    }

    private var currentBalance: Double {
        entries.last?.value ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack{
                AuroraBackground().ignoresSafeArea()
                ScrollView{
                    
                    HStack(spacing: 18) {
                        metricCard(
                            title: "Saldo actual",
                            icon: "creditcard",
                            value: Text(currentBalance, format: .currency(code: "USD"))
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .foregroundColor(AuroraColors.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, alignment: .leading),
                            subtitle: Text(balanceDeltaText(for: filteredEntries))
                                .font(.footnote.weight(.medium))
                                .foregroundColor(balanceDeltaColor(for: filteredEntries))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                        
                        //                    metricCard(
                        //                        title: "USD → CUP",
                        //                        icon: "dollarsign.arrow.circlepath",
                        //                        value: Text(usdToCupRate, format: .number.precision(.fractionLength(2)))
                        //                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        //                            .foregroundColor(AuroraColors.primaryText)
                        //                            .lineLimit(1)
                        //                            .minimumScaleFactor(0.75)
                        //                            .frame(maxWidth: .infinity, alignment: .leading),
                        //                        subtitle: Text("Última actualización hace 2 h")
                        //                            .font(.footnote)
                        //                            .foregroundColor(AuroraColors.secondaryText.opacity(0.9))
                        //                            .frame(maxWidth: .infinity, alignment: .leading)
                        //                    )
                    }
                    
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Histórico de finanzas")
                                .font(.headline)
                                .foregroundStyle(AuroraColors.primaryText)
                            Spacer()
                            Picker("Intervalo", selection: $selectedRange) {
                                ForEach(DateRange.allCases) { range in
                                    Text(range.title).tag(range)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 260)
                        }
                        
                        chartView(entries: filteredEntries)
                            .frame(height: 220)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 25, y: 14)
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Agregar ingreso", action: onAddIncome)
                        Button("Agregar gasto", action: onAddExpense)
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "person.circle.fill")
                    }
                }
            }
        }
    }

    private func metricCard<Value: View, Subtitle: View>(
        title: String,
        icon: String,
        value: Value,
        subtitle: Subtitle
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AuroraColors.secondaryText)
            } icon: {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AuroraColors.primaryText.opacity(0.7))
            }

            value

            subtitle
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 12)
    }

    private func chartView(entries: [FinanceEntry]) -> some View {
        Chart(entries) { entry in
            AreaMark(
                x: .value("Fecha", entry.date),
                y: .value("Saldo", entry.value)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [
                        Color(red: 0.54, green: 0.75, blue: 0.98).opacity(0.4),
                        Color.white.opacity(0.01)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Fecha", entry.date),
                y: .value("Saldo", entry.value)
            )
            .foregroundStyle(Color(red: 0.32, green: 0.49, blue: 0.86))
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.day().month())
                            .foregroundStyle(AuroraColors.secondaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
    }

    private func balanceDeltaText(for entries: [FinanceEntry]) -> String {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value else {
            return "Sin variación reciente"
        }
        let delta = lastValue - firstValue
        let formatted = delta.magnitude.formatted(.currency(code: "USD"))
        let prefix = delta == 0 ? "" : delta > 0 ? "+" : "-"
        return "\(prefix)\(formatted)"
    }

    private func balanceDeltaColor(for entries: [FinanceEntry]) -> Color {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value else {
            return AuroraColors.secondaryText
        }
        let delta = lastValue - firstValue
        if delta > 0 {
            return Color(red: 0.20, green: 0.60, blue: 0.46)
        } else if delta < 0 {
            return Color(red: 0.86, green: 0.33, blue: 0.33)
        } else {
            return AuroraColors.secondaryText
        }
    }
}
