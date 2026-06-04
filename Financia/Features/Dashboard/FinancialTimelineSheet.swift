import SwiftUI

private enum FinancialTimelineKind {
    case currentBalance
    case salary
    case asset
    case subscription
    case liability
    case debt
    case monthClose

    var icon: String {
        switch self {
        case .currentBalance: return "circle.hexagongrid.fill"
        case .salary: return "briefcase.fill"
        case .asset: return "building.columns.fill"
        case .subscription: return "play.rectangle.fill"
        case .liability: return "tray.full.fill"
        case .debt: return "exclamationmark.triangle.fill"
        case .monthClose: return "sparkle.magnifyingglass"
        }
    }
}

private struct FinancialTimelineEvent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let amount: Double
    let date: Date
    let dayOfMonth: Int
    let kind: FinancialTimelineKind
    let tint: Color
    let projectedBalance: Double
}

struct FinancialTimelineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var wealthManager: WealthManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var debtManager: DebtManager
    @EnvironmentObject private var profileManager: ProfileManager

    let currency: Currency

    @State private var hasAnimatedIn = false

    private var accentColor: Color {
        Color(hex: profileManager.profile.accentColorHex ?? "FF5C00")
    }

    private var currentBalance: Double {
        walletManager.wallets
            .filter { $0.currency == currency }
            .reduce(0) { partialResult, wallet in
                partialResult + walletManager.calculateBalance(for: wallet)
            }
    }

    private var incomeTotal: Double {
        wealthManager.forecastedMonthlyIncome(in: currency)
    }

    private var outgoingTotal: Double {
        let subscriptionExpenses = subscriptionManager.subscriptions
            .filter { $0.isActive && $0.currency == currency }
            .reduce(0) { $0 + $1.userExpenseAmount }

        let liabilityExpenses = wealthManager.liabilityEvents(in: currency)
            .reduce(0) { $0 + $1.amount }

        let debtExpenses = debtManager.debts
            .filter { $0.moneda == currency && $0.monto > 0 }
            .reduce(0) { partialResult, debt in
                partialResult + (debt.lastEstimate?.escenarios.first?.pagoMensual ?? 0)
            }

        return subscriptionExpenses + liabilityExpenses + debtExpenses
    }

    private var monthCloseProjection: Double {
        currentBalance + incomeTotal - outgoingTotal
    }

    private var highlightedEvents: [FinancialTimelineEvent] {
        Array(events.prefix(6))
    }

    private var events: [FinancialTimelineEvent] {
        let calendar = Calendar.current
        let now = Date()
        let baseMonth = referenceMonth(for: now, calendar: calendar)
        var rawEvents: [(title: String, subtitle: String, amount: Double, dayOfMonth: Int, kind: FinancialTimelineKind, tint: Color)] = []

        for event in wealthManager.incomeEvents(in: currency) {
            rawEvents.append((
                title: event.sourceName,
                subtitle: event.sourceType == .job ? "Salario programado" : "Rendimiento programado",
                amount: event.amount,
                dayOfMonth: event.dayOfMonth,
                kind: event.sourceType == .job ? .salary : .asset,
                tint: event.sourceType == .job ? Color(hex: "34C759") : Color(hex: "0EA5E9")
            ))
        }

        for subscription in subscriptionManager.subscriptions
            .filter({ $0.isActive && $0.currency == currency })
            .sorted(by: { $0.billingDay < $1.billingDay }) {
            rawEvents.append((
                title: subscription.platformName,
                subtitle: "Suscripción · \(subscription.planName)",
                amount: -subscription.userExpenseAmount,
                dayOfMonth: subscription.billingDay,
                kind: .subscription,
                tint: Color(hex: "7C3AED")
            ))
        }

        for liability in wealthManager.liabilityEvents(in: currency) {
            rawEvents.append((
                title: liability.sourceName,
                subtitle: "Pasivo recurrente",
                amount: -liability.amount,
                dayOfMonth: liability.dayOfMonth,
                kind: .liability,
                tint: Color(hex: "F97316")
            ))
        }

        for debt in debtManager.debts
            .filter({ $0.moneda == currency && $0.monto > 0 }) {
            let monthlyPayment = debt.lastEstimate?.escenarios.first?.pagoMensual ?? 0
            guard monthlyPayment > 0 else { continue }
            rawEvents.append((
                title: debt.nombre,
                subtitle: debt.motivo.isEmpty ? "Pago recomendado de deuda" : debt.motivo,
                amount: -monthlyPayment,
                dayOfMonth: 28,
                kind: .debt,
                tint: DarkFinanceColors.errorRed
            ))
        }

        let sorted = rawEvents
            .map { raw in
                (
                    title: raw.title,
                    subtitle: raw.subtitle,
                    amount: raw.amount,
                    dayOfMonth: min(max(raw.dayOfMonth, 1), 31),
                    date: normalizedDate(dayOfMonth: raw.dayOfMonth, in: baseMonth, calendar: calendar),
                    kind: raw.kind,
                    tint: raw.tint
                )
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.amount > $1.amount
                }
                return $0.date < $1.date
            }

        var runningBalance = currentBalance
        var mapped: [FinancialTimelineEvent] = [
            FinancialTimelineEvent(
                id: UUID(),
                title: "Pulso actual",
                subtitle: "Tu punto de partida en \(currency.rawValue)",
                amount: currentBalance,
                date: now,
                dayOfMonth: calendar.component(.day, from: now),
                kind: .currentBalance,
                tint: accentColor,
                projectedBalance: currentBalance
            )
        ]

        for item in sorted {
            runningBalance += item.amount
            mapped.append(
                FinancialTimelineEvent(
                    id: UUID(),
                    title: item.title,
                    subtitle: item.subtitle,
                    amount: item.amount,
                    date: item.date,
                    dayOfMonth: item.dayOfMonth,
                    kind: item.kind,
                    tint: item.tint,
                    projectedBalance: runningBalance
                )
            )
        }

        let closingDate = closingDate(in: baseMonth, calendar: calendar)
        mapped.append(
            FinancialTimelineEvent(
                id: UUID(),
                title: "Cierre proyectado",
                subtitle: "Balance estimado cuando termine el ciclo",
                amount: monthCloseProjection,
                date: closingDate,
                dayOfMonth: calendar.component(.day, from: closingDate),
                kind: .monthClose,
                tint: .white,
                projectedBalance: runningBalance
            )
        )

        return mapped
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    cover
                    floatingMetrics
                    cinematicCarousel
                    chronologySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 44)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.84)) {
                hasAnimatedIn = true
            }
        }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Future Motion")
                        .font(.custom("Georgia", size: 34))
                        .foregroundColor(.white)
                    Text("Una lectura cinematográfica de tu próximo ciclo en \(currency.rawValue)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.76))
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance proyectado")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(monthCloseProjection, format: .currency(code: currency.rawValue))
                        .font(DarkFinanceTypography.monoAmount(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(events.count - 1) hitos")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.88))
                    Text("desliza el escenario")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.95),
                            Color(hex: "18181B"),
                            Color(hex: "09090B")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 180, height: 180)
                        .blur(radius: 20)
                        .offset(x: 40, y: -50)
                }
                .shadow(color: accentColor.opacity(0.28), radius: 24, x: 0, y: 20)
        )
        .rotation3DEffect(.degrees(hasAnimatedIn ? 0 : -12), axis: (x: 1, y: 0, z: 0), perspective: 0.85)
        .offset(y: hasAnimatedIn ? 0 : 20)
        .opacity(hasAnimatedIn ? 1 : 0)
    }

    private var floatingMetrics: some View {
        HStack(spacing: 12) {
            metricCard(title: "Ingresos", value: incomeTotal, tint: Color(hex: "34C759"))
            metricCard(title: "Salidas", value: outgoingTotal, tint: Color(hex: "FF6B6B"))
            metricCard(title: "Ahora", value: currentBalance, tint: accentColor)
        }
    }

    private func metricCard(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(tint)
                .frame(width: 28, height: 4)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundColor(DarkFinanceColors.secondaryText)
            Text(value, format: .currency(code: currency.rawValue))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(DarkFinanceColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DarkFinanceColors.cardBackground.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                )
        )
    }

    private var cinematicCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timeline 3D")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(Array(highlightedEvents.enumerated()), id: \.element.id) { index, event in
                        GeometryReader { proxy in
                            let frame = proxy.frame(in: .global)
                            let screenMid = UIScreen.main.bounds.width / 2
                            let distance = frame.midX - screenMid
                            let rotation = -distance / 18
                            let scale = max(0.88, 1 - abs(distance) / 900)

                            TimelineCinemaCard(event: event, currency: currency, accentColor: accentColor)
                                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.88)
                                .rotation3DEffect(.degrees(distance / 60), axis: (x: 1, y: 0, z: 0), perspective: 0.88)
                                .scaleEffect(scale)
                                .offset(y: hasAnimatedIn ? 0 : CGFloat(index * 10))
                                .opacity(hasAnimatedIn ? 1 : 0)
                        }
                        .frame(width: 286, height: 320)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
        }
    }

    private var chronologySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Secuencia completa")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    TimelineRow(
                        event: event,
                        currency: currency,
                        accentColor: accentColor,
                        isLast: index == events.count - 1
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DarkFinanceColors.cardBackground.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var background: some View {
        ZStack {
            DarkFinanceBackground()

            LinearGradient(
                colors: [accentColor.opacity(0.10), Color.clear, Color(hex: "0EA5E9").opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(accentColor.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 150, y: -260)

            Circle()
                .fill(Color(hex: "0EA5E9").opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -160, y: 120)
        }
        .ignoresSafeArea()
    }

    private func referenceMonth(for now: Date, calendar: Calendar) -> Date {
        let currentDay = calendar.component(.day, from: now)
        if currentDay > 25 {
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        }
        return now
    }

    private func normalizedDate(dayOfMonth: Int, in monthDate: Date, calendar: Calendar) -> Date {
        let range = calendar.range(of: .day, in: .month, for: monthDate) ?? (1..<32)
        let normalizedDay = min(max(dayOfMonth, 1), range.count)
        return calendar.date(bySetting: .day, value: normalizedDay, of: monthDate) ?? monthDate
    }

    private func closingDate(in monthDate: Date, calendar: Calendar) -> Date {
        let range = calendar.range(of: .day, in: .month, for: monthDate) ?? (1..<32)
        return calendar.date(bySetting: .day, value: range.count, of: monthDate) ?? monthDate
    }
}

private struct TimelineCinemaCard: View {
    let event: FinancialTimelineEvent
    let currency: Currency
    let accentColor: Color

    private var amountColor: Color {
        event.amount >= 0 ? DarkFinanceColors.primaryText : DarkFinanceColors.errorRed
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            event.tint.opacity(0.08),
                            DarkFinanceColors.cardBackground.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(event.tint.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: event.tint.opacity(0.16), radius: 24, x: 0, y: 18)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(event.tint.opacity(0.18))
                            .frame(width: 54, height: 54)
                        Image(systemName: event.kind.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(event.kind == .monthClose ? accentColor : event.tint)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("día \(event.dayOfMonth)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(event.date, format: .dateTime.month(.abbreviated))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Text(event.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text(event.amount, format: .currency(code: currency.rawValue))
                        .font(DarkFinanceTypography.monoAmount(size: 28, weight: .semibold))
                        .foregroundColor(amountColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Balance después")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                        Text(event.projectedBalance, format: .currency(code: currency.rawValue))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(DarkFinanceColors.primaryText)
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct TimelineRow: View {
    let event: FinancialTimelineEvent
    let currency: Currency
    let accentColor: Color
    let isLast: Bool

    private var amountColor: Color {
        event.amount >= 0 ? DarkFinanceColors.primaryText : DarkFinanceColors.errorRed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(event.tint.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: event.kind.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(event.kind == .monthClose ? accentColor : event.tint)
                }

                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [event.tint.opacity(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 52)
                        .padding(.top, 6)
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Text(event.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("día \(event.dayOfMonth)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                        Text(event.date, format: .dateTime.month(.abbreviated))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                }

                HStack {
                    Text(event.amount, format: .currency(code: currency.rawValue))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(amountColor)

                    Spacer()

                    Text("después: \(event.projectedBalance.formatted(.currency(code: currency.rawValue)))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, isLast ? 18 : 0)
    }
}

