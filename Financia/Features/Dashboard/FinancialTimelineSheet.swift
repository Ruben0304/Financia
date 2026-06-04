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
    let currency: Currency
    let date: Date
    let dayOfMonth: Int
    let kind: FinancialTimelineKind
    let tint: Color
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
    @State private var selectedEventID: UUID?

    private var accentColor: Color {
        Color(hex: profileManager.profile.accentColorHex ?? "FF5C00")
    }

    private var timelineSubtitle: String {
        let currencies = Set(events.map(\.currency.rawValue)).sorted()
        return currencies.isEmpty ? "Sin hitos con fecha" : currencies.joined(separator: " · ")
    }

    private var events: [FinancialTimelineEvent] {
        let calendar = Calendar.current
        let now = Date()
        let baseMonth = referenceMonth(for: now, calendar: calendar)
        var mapped: [FinancialTimelineEvent] = []

        for event in wealthManager.allIncomeEvents() {
            mapped.append(
                FinancialTimelineEvent(
                    id: UUID(),
                    title: event.sourceName,
                    subtitle: event.sourceType == .job ? "Salario programado" : "Rendimiento programado",
                    amount: event.amount,
                    currency: event.currency,
                    date: normalizedDate(dayOfMonth: event.dayOfMonth, in: baseMonth, calendar: calendar),
                    dayOfMonth: event.dayOfMonth,
                    kind: event.sourceType == .job ? .salary : .asset,
                    tint: event.sourceType == .job ? Color(hex: "34C759") : Color(hex: "0EA5E9")
                )
            )
        }

        for subscription in subscriptionManager.subscriptions
            .filter({ $0.isActive })
            .sorted(by: { lhs, rhs in
                if lhs.billingDay == rhs.billingDay {
                    return lhs.userExpenseAmount > rhs.userExpenseAmount
                }
                return lhs.billingDay < rhs.billingDay
            }) {
            mapped.append(
                FinancialTimelineEvent(
                    id: UUID(),
                    title: subscription.platformName,
                    subtitle: "Suscripción · \(subscription.planName)",
                    amount: -subscription.userExpenseAmount,
                    currency: subscription.currency,
                    date: normalizedDate(dayOfMonth: subscription.billingDay, in: baseMonth, calendar: calendar),
                    dayOfMonth: subscription.billingDay,
                    kind: .subscription,
                    tint: Color(hex: "7C3AED")
                )
            )
        }

        for liability in wealthManager.allLiabilityEvents() {
            mapped.append(
                FinancialTimelineEvent(
                    id: UUID(),
                    title: liability.sourceName,
                    subtitle: "Pasivo recurrente",
                    amount: -liability.amount,
                    currency: liability.currency,
                    date: normalizedDate(dayOfMonth: liability.dayOfMonth, in: baseMonth, calendar: calendar),
                    dayOfMonth: liability.dayOfMonth,
                    kind: .liability,
                    tint: Color(hex: "F97316")
                )
            )
        }

        for debt in debtManager.debts.filter({ $0.monto > 0 }) {
            let monthlyPayment = debt.lastEstimate?.escenarios.first?.pagoMensual ?? 0
            guard monthlyPayment > 0 else { continue }
            mapped.append(
                FinancialTimelineEvent(
                    id: UUID(),
                    title: debt.nombre,
                    subtitle: debt.motivo.isEmpty ? "Pago recomendado de deuda" : debt.motivo,
                    amount: -monthlyPayment,
                    currency: debt.moneda,
                    date: normalizedDate(dayOfMonth: 28, in: baseMonth, calendar: calendar),
                    dayOfMonth: 28,
                    kind: .debt,
                    tint: DarkFinanceColors.errorRed
                )
            )
        }

        mapped.append(
            FinancialTimelineEvent(
                id: UUID(),
                title: "Hoy",
                subtitle: "Punto de partida para leer la secuencia",
                amount: 0,
                currency: currency,
                date: now,
                dayOfMonth: calendar.component(.day, from: now),
                kind: .currentBalance,
                tint: accentColor
            )
        )

        return mapped.sorted {
            if $0.date == $1.date {
                return $0.amount > $1.amount
            }
            return $0.date < $1.date
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            TimelineTrackRow(
                                event: event,
                                currency: currency,
                                accentColor: accentColor,
                                isSelected: selectedEventID == event.id,
                                isFirst: index == 0,
                                isLast: index == events.count - 1
                            ) {
                                selectedEventID = event.id
                                softHaptic()
                            }
                            .padding(.bottom, index == events.count - 1 ? 0 : 6)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Timeline")
                        .darkFinanceToolbarTitle(size: 22)
                        .foregroundColor(DarkFinanceColors.primaryText)
                }

                ToolbarItem(placement: .subtitle) {
                    Text(timelineSubtitle)
                        .darkFinanceToolbarSubtitle(size: 12, weight: .medium)
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(DarkFinanceColors.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.84)) {
                hasAnimatedIn = true
                selectedEventID = events.first?.id
            }
            mediumHaptic()
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

}

private struct TimelineTrackRow: View {
    let event: FinancialTimelineEvent
    let currency: Currency
    let accentColor: Color
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    if !isFirst {
                        Capsule()
                            .fill(lineGradient.opacity(0.8))
                            .frame(width: 2, height: 24)
                    } else {
                        Spacer()
                            .frame(width: 2, height: 24)
                    }

                    ZStack {
                        Circle()
                            .fill(event.tint.opacity(isSelected ? 0.26 : 0.14))
                            .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
                            .overlay(
                                Circle()
                                    .stroke(event.tint.opacity(isSelected ? 0.9 : 0.35), lineWidth: isSelected ? 5 : 1)
                            )

                        if isSelected {
                            Circle()
                                .fill(event.tint)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .shadow(color: event.tint.opacity(isSelected ? 0.35 : 0.0), radius: 12, x: 0, y: 0)

                    if !isLast {
                        Capsule()
                            .fill(lineGradient)
                            .frame(width: 2, height: 86)
                    }
                }
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(event.title)
                            .font(.system(size: isSelected ? 17 : 15, weight: .semibold))
                            .foregroundColor(DarkFinanceColors.primaryText)

                        Spacer(minLength: 8)

                        Text(event.date, format: .dateTime.day().month(.abbreviated))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isSelected ? event.tint : DarkFinanceColors.tertiaryText)
                    }

                    Text(event.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                        .lineLimit(isSelected ? 3 : 2)

                    HStack(alignment: .lastTextBaseline) {
                        Text(event.amount, format: .currency(code: event.currency.rawValue))
                            .font(.system(size: isSelected ? 20 : 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(amountColor)

                        Spacer()

                        Text(event.currency.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DarkFinanceColors.cardBackground.opacity(isSelected ? 0.98 : 0.92),
                                    event.tint.opacity(isSelected ? 0.08 : 0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(isSelected ? event.tint.opacity(0.35) : DarkFinanceColors.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: isSelected ? event.tint.opacity(0.12) : Color.black.opacity(0.04), radius: isSelected ? 18 : 8, x: 0, y: isSelected ? 12 : 4)
                )
                .rotation3DEffect(.degrees(isSelected ? 0 : 3), axis: (x: 1, y: 0, z: 0), perspective: 0.95)
                .scaleEffect(isSelected ? 1 : 0.985)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: isSelected)
        .opacity(hasContentOpacity)
        .offset(y: hasContentOffset)
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [event.tint.opacity(0.36), event.tint.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var amountColor: Color {
        if event.kind == .currentBalance {
            return accentColor
        }
        return event.amount >= 0 ? DarkFinanceColors.primaryText : DarkFinanceColors.errorRed
    }

    private var hasContentOpacity: Double {
        isSelected ? 1 : 0.92
    }

    private var hasContentOffset: CGFloat {
        isSelected ? 0 : 2
    }
}

private func softHaptic() {
    let generator = UIImpactFeedbackGenerator(style: .soft)
    generator.prepare()
    generator.impactOccurred(intensity: 0.8)
}

private func mediumHaptic() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.prepare()
    generator.impactOccurred(intensity: 0.9)
}
