import Foundation

struct WalletBreathingInsight: Equatable {
    let wallet: Wallet
    let currentBalance: Double
    let learnedDailySpend: Double
    let survivalDays: Int?
    let safeDailySpendUntilNextIncome: Double?
    let nextIncomeDate: Date?
    let nextIncomeAmount: Double
    let reservedExpensesUntilNextIncome: Double
    let observedDays: Int
    let expenseDays: Int
    let confidence: Double

    var hasEnoughHistory: Bool {
        observedDays >= 14 && expenseDays >= 5 && learnedDailySpend > 0
    }
}

final class FinancialBreathingManager {
    static let shared = FinancialBreathingManager()

    private let calendar = Calendar.current

    private init() {}

    func insight(
        for wallet: Wallet,
        currentBalance: Double,
        transactions: [Transaction],
        wealthManager: WealthManager,
        referenceDate: Date = Date()
    ) -> WalletBreathingInsight {
        let walletExpenses = transactions
            .filter { $0.walletId == wallet.id && $0.type == .expense && $0.date <= referenceDate }
            .sorted { $0.date < $1.date }

        let dailySeries = buildDailySeries(from: walletExpenses, referenceDate: referenceDate)
        let learnedDailySpend = adaptiveDailySpend(from: dailySeries)
        let weekdaySpend = weekdaySpendMap(from: dailySeries, fallback: learnedDailySpend)
        let survivalDays = projectedSurvivalDays(
            balance: currentBalance,
            weekdaySpend: weekdaySpend,
            fallbackSpend: learnedDailySpend,
            referenceDate: referenceDate
        )

        let nextIncome = nextIncomeEvent(in: wallet.currency, wealthManager: wealthManager, referenceDate: referenceDate)
        let reservedExpenses = reservedLiabilities(
            in: wallet.currency,
            wealthManager: wealthManager,
            until: nextIncome?.date,
            referenceDate: referenceDate
        )
        let safeDailySpend = safeDailySpend(
            balance: currentBalance,
            reservedExpenses: reservedExpenses,
            nextIncomeDate: nextIncome?.date,
            referenceDate: referenceDate
        )

        let observedDays = dailySeries.count
        let expenseDays = dailySeries.filter { $0.total > 0 }.count
        let confidence = confidenceScore(observedDays: observedDays, expenseDays: expenseDays)

        return WalletBreathingInsight(
            wallet: wallet,
            currentBalance: currentBalance,
            learnedDailySpend: learnedDailySpend,
            survivalDays: survivalDays,
            safeDailySpendUntilNextIncome: safeDailySpend,
            nextIncomeDate: nextIncome?.date,
            nextIncomeAmount: nextIncome?.amount ?? 0,
            reservedExpensesUntilNextIncome: reservedExpenses,
            observedDays: observedDays,
            expenseDays: expenseDays,
            confidence: confidence
        )
    }

    private func buildDailySeries(from expenses: [Transaction], referenceDate: Date) -> [DailyExpense] {
        guard let firstExpense = expenses.first?.date else { return [] }

        let windowStart = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        let startDate = max(calendar.startOfDay(for: firstExpense), windowStart)
        let endDate = calendar.startOfDay(for: referenceDate)
        let totalsByDay = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
            .mapValues { dayExpenses in
                dayExpenses.reduce(0) { $0 + $1.amount }
            }

        var cursor = startDate
        var series: [DailyExpense] = []

        while cursor <= endDate {
            series.append(
                DailyExpense(
                    date: cursor,
                    total: totalsByDay[cursor] ?? 0
                )
            )
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDate.addingTimeInterval(86_400)
        }

        return winsorizedSeries(series)
    }

    private func winsorizedSeries(_ series: [DailyExpense]) -> [DailyExpense] {
        let positives = series.map(\.total).filter { $0 > 0 }.sorted()
        guard positives.count >= 4 else { return series }

        let median = percentile(0.5, in: positives)
        let p90 = percentile(0.9, in: positives)
        let cap = max(p90, median * 1.8)

        return series.map { day in
            DailyExpense(date: day.date, total: min(day.total, cap))
        }
    }

    private func adaptiveDailySpend(from series: [DailyExpense]) -> Double {
        guard !series.isEmpty else { return 0 }

        let weighted = series.enumerated().reduce((sum: 0.0, weight: 0.0)) { partial, element in
            let progress = Double(element.offset + 1) / Double(series.count)
            let weight = 0.55 + pow(progress, 2.0) * 1.45
            return (
                sum: partial.sum + (element.element.total * weight),
                weight: partial.weight + weight
            )
        }

        guard weighted.weight > 0 else { return 0 }
        return weighted.sum / weighted.weight
    }

    private func weekdaySpendMap(from series: [DailyExpense], fallback: Double) -> [Int: Double] {
        guard !series.isEmpty else {
            return Dictionary(uniqueKeysWithValues: (1...7).map { ($0, fallback) })
        }

        let grouped = Dictionary(grouping: series) { calendar.component(.weekday, from: $0.date) }
        var result: [Int: Double] = [:]

        for weekday in 1...7 {
            let days = grouped[weekday] ?? []
            let localAverage = days.isEmpty ? fallback : days.reduce(0) { $0 + $1.total } / Double(days.count)
            let shrinkFactor = min(Double(days.count) / 6.0, 1.0)
            result[weekday] = (localAverage * shrinkFactor) + (fallback * (1 - shrinkFactor))
        }

        return result
    }

    private func projectedSurvivalDays(
        balance: Double,
        weekdaySpend: [Int: Double],
        fallbackSpend: Double,
        referenceDate: Date
    ) -> Int? {
        guard balance > 0, fallbackSpend > 0 else { return nil }

        var remaining = balance
        var cursor = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        var survivedDays = 0

        for _ in 0..<3650 {
            let weekday = calendar.component(.weekday, from: cursor)
            let spend = max(weekdaySpend[weekday] ?? fallbackSpend, fallbackSpend * 0.35)
            if remaining < spend {
                return survivedDays
            }

            remaining -= spend
            survivedDays += 1
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }

        return survivedDays
    }

    private func nextIncomeEvent(
        in currency: Currency,
        wealthManager: WealthManager,
        referenceDate: Date
    ) -> (date: Date, amount: Double)? {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let events = wealthManager.incomeEvents(in: currency)
            .compactMap { event -> (date: Date, amount: Double)? in
                guard let date = nextDate(forDayOfMonth: event.dayOfMonth, referenceDate: referenceDate) else {
                    return nil
                }
                return (date: date, amount: event.amount)
            }

        guard let nextDate = events.map(\.date).min() else { return nil }
        guard nextDate >= startOfToday else { return nil }

        let totalAmount = events
            .filter { calendar.isDate($0.date, inSameDayAs: nextDate) }
            .reduce(0) { $0 + $1.amount }

        return (date: nextDate, amount: totalAmount)
    }

    private func reservedLiabilities(
        in currency: Currency,
        wealthManager: WealthManager,
        until nextIncomeDate: Date?,
        referenceDate: Date
    ) -> Double {
        guard let nextIncomeDate else { return 0 }

        return wealthManager.liabilityEvents(in: currency).reduce(0) { total, event in
            guard let eventDate = nextDate(forDayOfMonth: event.dayOfMonth, referenceDate: referenceDate) else {
                return total
            }

            if eventDate < nextIncomeDate {
                return total + event.amount
            }

            return total
        }
    }

    private func safeDailySpend(
        balance: Double,
        reservedExpenses: Double,
        nextIncomeDate: Date?,
        referenceDate: Date
    ) -> Double? {
        guard let nextIncomeDate else { return nil }

        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfNextIncome = calendar.startOfDay(for: nextIncomeDate)
        let daysUntilIncome = max(calendar.dateComponents([.day], from: startOfToday, to: startOfNextIncome).day ?? 0, 1)
        let available = max(balance - reservedExpenses, 0)

        return available / Double(daysUntilIncome)
    }

    private func nextDate(forDayOfMonth dayOfMonth: Int, referenceDate: Date) -> Date? {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let currentMonthDate = normalizedDate(dayOfMonth: dayOfMonth, in: startOfToday)

        if currentMonthDate >= startOfToday {
            return currentMonthDate
        }

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfToday) else {
            return nil
        }

        return normalizedDate(dayOfMonth: dayOfMonth, in: nextMonth)
    }

    private func normalizedDate(dayOfMonth: Int, in baseDate: Date) -> Date {
        let range = calendar.range(of: .day, in: .month, for: baseDate) ?? (1..<32)
        let clampedDay = min(max(dayOfMonth, 1), range.count)
        return calendar.date(bySetting: .day, value: clampedDay, of: baseDate) ?? baseDate
    }

    private func percentile(_ percentile: Double, in sortedValues: [Double]) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        guard sortedValues.count > 1 else { return sortedValues[0] }

        let position = percentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }

        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex] + ((sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction)
    }

    private func confidenceScore(observedDays: Int, expenseDays: Int) -> Double {
        let observedFactor = min(Double(observedDays) / 60.0, 1.0)
        let activityFactor = min(Double(expenseDays) / 20.0, 1.0)
        return (observedFactor * 0.6) + (activityFactor * 0.4)
    }
}

private struct DailyExpense {
    let date: Date
    let total: Double
}
