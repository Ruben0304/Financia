import SwiftUI
import Charts

struct FinanceDashboardView: View {
    @Binding var selectedRange: DateRange
    let entries: [FinanceEntry]
    let usdToCupRate: Double
    var onAddIncome: () -> Void = {}
    var onAddExpense: () -> Void = {}
    @State private var selectedMovementFilter: MovementFilter = .all

    private var orderedEntries: [FinanceEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var filteredEntries: [FinanceEntry] {
        guard let start = Calendar.current.date(byAdding: .day, value: -selectedRange.lengthInDays, to: Date()) else {
            return orderedEntries
        }
        return orderedEntries.filter { $0.date >= start }
    }

    private var currentBalance: Double {
        orderedEntries.last?.value ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 16) {
                            balanceHeader(entries: filteredEntries)
                            portfolioCard(entries: filteredEntries)
                        }
                        recentMovementsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Agregar ingreso", action: onAddIncome)
                        Button("Agregar gasto", action: onAddExpense)
                    } label: {
                        Image(systemName: "plus.circle.fill")
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

    private func balanceHeader(entries: [FinanceEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentBalance, format: .currency(code: "CUP"))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AuroraColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            usdConversionView()

            variationSummary(for: entries)
        }
    }

    private func portfolioCard(entries: [FinanceEntry]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.58, blue: 0.98),
                                Color(red: 0.53, green: 0.36, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Saldo histórico")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AuroraColors.secondaryText)
                    
                }

                Spacer()

                Picker("Intervalo", selection: $selectedRange) {
                    ForEach(DateRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            chartView(entries: entries)
                .frame(height: 220)
                .padding(.top, 6)

            HStack {
                Label {
                    Text("USD → CUP \(usdToCupRate, format: .number.precision(.fractionLength(2)))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AuroraColors.primaryText)
                } icon: {
                    Circle()
                        .fill(Color(red: 0.49, green: 0.38, blue: 0.96))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "dollarsign.arrow.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }

                Spacer()

                Text("Actualizado hoy")
                    .font(.caption)
                    .foregroundStyle(AuroraColors.secondaryText)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.3))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 32, y: 18)
    }

    @ViewBuilder
    private func variationSummary(for entries: [FinanceEntry]) -> some View {
        let deltaText = balanceDeltaText(for: entries)
        let percentage = balanceDeltaPercentage(for: entries)
        let color = balanceDeltaColor(for: entries)
        let symbol = balanceDeltaSymbol(for: entries)
        let hasReference = entries.count > 1 && entries.first?.value != 0
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(8)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                if hasReference {
                    Text("\(deltaText) (\(percentage.formatted(.percent.precision(.fractionLength(2)))))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                } else {
                    Text(deltaText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }

                Text("Últimos \(selectedRange.lengthInDays) días")
                    .font(.caption)
                    .foregroundStyle(AuroraColors.secondaryText)
            }
        }
    }

    private var recentMovementsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            movementFilterChips

            VStack(spacing: 12) {
                ForEach(displayedMovements) { movement in
                    movementRow(for: movement)
                }
            }
        }.padding()
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.3))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 32, y: 18)
    }

    private var movementFilterChips: some View {
        HStack(spacing: 24) {
            ForEach(MovementFilter.allCases) { filter in
                Button {
                    selectedMovementFilter = filter
                } label: {
                    VStack(spacing: 8) {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedMovementFilter == filter ? AuroraColors.primaryText : AuroraColors.secondaryText.opacity(0.7))

                        if selectedMovementFilter == filter {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(red: 0.49, green: 0.32, blue: 0.94))
                                .frame(height: 3)
                        } else {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var quickActions: some View {
        HStack(spacing: 14) {
            quickActionButton(
                title: "Agregar ingreso",
                subtitle: "Deposita al instante",
                icon: "arrow.down.left.circle.fill",
                isEmphasized: false,
                action: onAddIncome
            )

            quickActionButton(
                title: "Registrar gasto",
                subtitle: "Controla tu flujo",
                icon: "arrow.up.right.circle.fill",
                isEmphasized: true,
                action: onAddExpense
            )
        }
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        icon: String,
        isEmphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let backgroundGradient = LinearGradient(
            colors: isEmphasized
                ? [
                    Color(red: 0.74, green: 0.44, blue: 0.99),
                    Color(red: 0.45, green: 0.34, blue: 0.98)
                ]
                : [
                    Color.white.opacity(0.55),
                    Color.white.opacity(0.55)
                ],
            startPoint: .leading,
            endPoint: .trailing
        )

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isEmphasized ? Color.white : AuroraColors.primaryText)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(isEmphasized ? 0.25 : 0.35))
                    )

                Text(title)
                    .font(.headline)
                    .foregroundStyle(isEmphasized ? Color.white : AuroraColors.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isEmphasized ? Color.white.opacity(0.85) : AuroraColors.secondaryText)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(backgroundGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .shadow(
            color: isEmphasized ? Color(red: 0.58, green: 0.43, blue: 0.95).opacity(0.35) : Color.black.opacity(0.05),
            radius: isEmphasized ? 20 : 12,
            y: isEmphasized ? 14 : 8
        )
    }

    private func movementRow(for movement: RecentMovement) -> some View {
        let isPositive = movement.percentageChange >= 0

        return HStack(spacing: 14) {
            // Icono circular
            Circle()
                .fill(movement.iconBackground)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: movement.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                )

            // Nombre y símbolo
            VStack(alignment: .leading, spacing: 3) {
                Text(movement.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AuroraColors.primaryText)
                Text(movement.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AuroraColors.secondaryText.opacity(0.8))
            }

            Spacer()

            // Mini gráfico
            miniChart(isPositive: isPositive)
                .frame(width: 60, height: 30)

            // Precio y porcentaje
            VStack(alignment: .trailing, spacing: 4) {
                Text(movement.amount, format: .currency(code: "CUP"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AuroraColors.primaryText)

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(movement.percentageChange, format: .percent.precision(.fractionLength(2)))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(isPositive ? Color(red: 0.20, green: 0.60, blue: 0.46) : Color(red: 0.86, green: 0.33, blue: 0.33))
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func miniChart(isPositive: Bool) -> some View {
        let color = isPositive ? Color(red: 0.20, green: 0.60, blue: 0.46) : Color(red: 0.86, green: 0.33, blue: 0.33)

        // Generar puntos aleatorios para el mini gráfico
        let points: [Double] = isPositive
            ? [0.3, 0.5, 0.4, 0.6, 0.8, 1.0]
            : [1.0, 0.8, 0.7, 0.5, 0.4, 0.3]

        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(points.count - 1)

                for (index, point) in points.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(point) * height)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    private func chartView(entries: [FinanceEntry]) -> some View {
        let accent = Color(red: 0.49, green: 0.32, blue: 0.94)
        let ordered = entries.sorted { $0.date < $1.date }

        return Chart {
            ForEach(ordered) { entry in
                AreaMark(
                    x: .value("Fecha", entry.date),
                    y: .value("Saldo", entry.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent.opacity(0.35), accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Fecha", entry.date),
                    y: .value("Saldo", entry.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .foregroundStyle(accent)
            }

            if let last = ordered.last {
                PointMark(
                    x: .value("Fecha", last.date),
                    y: .value("Saldo", last.value)
                )
                .symbol {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(accent, lineWidth: 3)
                        )
                }
                .foregroundStyle(accent)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartPlotStyle { plot in
            plot
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var displayedMovements: [RecentMovement] {
        let data: [RecentMovement]
        switch selectedMovementFilter {
        case .all:
            data = recentMovements
        case .incomes:
            data = incomeMovements
        case .expenses:
            data = expenseMovements
        }
        return data.isEmpty ? placeholderMovements(for: selectedMovementFilter) : data
    }

    private var recentMovements: [RecentMovement] {
        guard orderedEntries.count > 1 else { return [] }
        let sorted = orderedEntries
        var results: [RecentMovement] = []
        var incomeIndex = 0
        var expenseIndex = 0

        for (current, previous) in zip(sorted.dropFirst(), sorted) {
            let delta = current.value - previous.value
            guard delta != 0 else { continue }
            let base = abs(previous.value)
            let ratio = base == 0 ? 0 : abs(delta) / base

            if delta > 0 {
                let preset = MovementPreset.incomePresets[incomeIndex % MovementPreset.incomePresets.count]
                results.append(
                    RecentMovement(
                        id: current.id,
                        kind: .income,
                        title: preset.title,
                        subtitle: preset.subtitle,
                        iconName: preset.icon,
                        iconBackground: preset.color,
                        amount: delta,
                        percentageChange: ratio
                    )
                )
                incomeIndex += 1
            } else {
                let preset = MovementPreset.expensePresets[expenseIndex % MovementPreset.expensePresets.count]
                results.append(
                    RecentMovement(
                        id: current.id,
                        kind: .expense,
                        title: preset.title,
                        subtitle: preset.subtitle,
                        iconName: preset.icon,
                        iconBackground: preset.color,
                        amount: abs(delta),
                        percentageChange: -ratio
                    )
                )
                expenseIndex += 1
            }
        }

        return Array(results.suffix(6).reversed())
    }

    private var incomeMovements: [RecentMovement] {
        recentMovements.filter { $0.kind == .income }
    }

    private var expenseMovements: [RecentMovement] {
        recentMovements.filter { $0.kind == .expense }
    }

    private func placeholderMovements(for filter: MovementFilter) -> [RecentMovement] {
        switch filter {
        case .all:
            let incomes = MovementPreset.incomePresets.enumerated().map { index, preset in
                RecentMovement(
                    id: UUID(),
                    kind: .income,
                    title: preset.title,
                    subtitle: preset.subtitle,
                    iconName: preset.icon,
                    iconBackground: preset.color,
                    amount: 420 + Double(index) * 180,
                    percentageChange: 0.012 + Double(index) * 0.006
                )
            }
            let expenses = MovementPreset.expensePresets.enumerated().map { index, preset in
                RecentMovement(
                    id: UUID(),
                    kind: .expense,
                    title: preset.title,
                    subtitle: preset.subtitle,
                    iconName: preset.icon,
                    iconBackground: preset.color,
                    amount: 260 + Double(index) * 90,
                    percentageChange: -(0.008 + Double(index) * 0.004)
                )
            }
            return (incomes + expenses).shuffled()
        case .incomes:
            return MovementPreset.incomePresets.enumerated().map { index, preset in
                RecentMovement(
                    id: UUID(),
                    kind: .income,
                    title: preset.title,
                    subtitle: preset.subtitle,
                    iconName: preset.icon,
                    iconBackground: preset.color,
                    amount: 420 + Double(index) * 180,
                    percentageChange: 0.012 + Double(index) * 0.006
                )
            }
        case .expenses:
            return MovementPreset.expensePresets.enumerated().map { index, preset in
                RecentMovement(
                    id: UUID(),
                    kind: .expense,
                    title: preset.title,
                    subtitle: preset.subtitle,
                    iconName: preset.icon,
                    iconBackground: preset.color,
                    amount: 260 + Double(index) * 90,
                    percentageChange: -(0.008 + Double(index) * 0.004)
                )
            }
        }
    }

    private struct RecentMovement: Identifiable {
        enum Kind {
            case income
            case expense
        }

        let id: UUID
        let kind: Kind
        let title: String
        let subtitle: String
        let iconName: String
        let iconBackground: Color
        let amount: Double
        let percentageChange: Double
    }

    private struct MovementPreset {
        let title: String
        let subtitle: String
        let icon: String
        let color: Color

        static let incomePresets: [MovementPreset] = [
            MovementPreset(
                title: "Salario mensual",
                subtitle: "SAL",
                icon: "creditcard.fill",
                color: Color(red: 0.95, green: 0.61, blue: 0.07)  // Naranja
            ),
            MovementPreset(
                title: "Cobro freelance",
                subtitle: "FRL",
                icon: "laptopcomputer",
                color: Color(red: 0.38, green: 0.42, blue: 0.82)  // Azul índigo
            ),
            MovementPreset(
                title: "Dividendos",
                subtitle: "DIV",
                icon: "chart.line.uptrend.xyaxis",
                color: Color(red: 0.70, green: 0.49, blue: 0.86)  // Púrpura
            )
        ]

        static let expensePresets: [MovementPreset] = [
            MovementPreset(
                title: "Mercado semanal",
                subtitle: "MER",
                icon: "cart.fill",
                color: Color(red: 0.91, green: 0.76, blue: 0.20)  // Amarillo
            ),
            MovementPreset(
                title: "Transporte",
                subtitle: "TRA",
                icon: "car.fill",
                color: Color(red: 0.53, green: 0.62, blue: 0.85)  // Azul grisáceo
            ),
            MovementPreset(
                title: "Entretenimiento",
                subtitle: "ENT",
                icon: "popcorn.fill",
                color: Color(red: 0.26, green: 0.82, blue: 0.76)  // Turquesa
            )
        ]
    }

    private enum MovementFilter: String, CaseIterable, Identifiable {
        case all
        case incomes
        case expenses

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .incomes: return "Ingresos"
            case .expenses: return "Gastos"
            }
        }
    }

    private func balanceDeltaPercentage(for entries: [FinanceEntry]) -> Double {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value, firstValue != 0 else {
            return 0
        }
        return (lastValue - firstValue) / firstValue
    }

    private func balanceDeltaSymbol(for entries: [FinanceEntry]) -> String {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value else {
            return "minus"
        }
        let delta = lastValue - firstValue
        if delta > 0 { return "arrow.up.right" }
        if delta < 0 { return "arrow.down.right" }
        return "minus"
    }

    private func shortDate(for date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func balanceDeltaText(for entries: [FinanceEntry]) -> String {
        guard let firstValue = entries.first?.value, let lastValue = entries.last?.value else {
            return "Sin variación reciente"
        }
        let delta = lastValue - firstValue
        let formatted = delta.magnitude.formatted(.currency(code: "CUP"))
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

    private func usdConversionView() -> some View {
        let usdBalance = currentBalance / usdToCupRate
        return Text("≈ \(usdBalance.formatted(.currency(code: "USD")))")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AuroraColors.secondaryText)
    }
}
