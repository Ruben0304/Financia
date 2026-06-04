import Foundation
@preconcurrency import UserNotifications

@MainActor
final class SubscriptionNotificationManager {
    static let shared = SubscriptionNotificationManager()

    private let weeklySummaryIdentifier = "subscriptions.weekly.summary"
    private let reminderPrefix = "subscriptions.daybefore"

    private init() {}

    func scheduleNotifications(for subscriptions: [Subscription]) {
        requestAuthorizationIfNeeded { [weak self] granted in
            guard let self, granted else { return }

            let active = subscriptions.filter(\.isActive)
            self.clearSubscriptionNotifications {
                self.scheduleWeeklySummary(for: active)
                self.scheduleDayBeforeReminders(for: active)
            }
        }
    }

    private func requestAuthorizationIfNeeded(completion: @escaping @MainActor (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                Task { @MainActor in
                    completion(true)
                }
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error {
                    print("Error requesting notification authorization: \(error)")
                }
                Task { @MainActor in
                    completion(granted)
                }
            }
        }
    }

    private func clearSubscriptionNotifications(completion: @escaping @MainActor () -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                Task { @MainActor in
                    completion()
                }
                return
            }

            let identifiers = requests
                .map(\.identifier)
                .filter { $0 == self.weeklySummaryIdentifier || $0.hasPrefix(self.reminderPrefix) }

            if !identifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            Task { @MainActor in
                completion()
            }
        }
    }

    private func scheduleWeeklySummary(for subscriptions: [Subscription]) {
        let content = UNMutableNotificationContent()
        content.title = "Suscripciones de esta semana"
        content.body = weeklySummaryBody(for: subscriptions)
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1 // Domingo
        components.hour = 15
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklySummaryIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Error scheduling weekly summary notification: \(error)")
            }
        }
    }

    private func scheduleDayBeforeReminders(for subscriptions: [Subscription]) {
        let calendar = Calendar.current
        let now = Date()

        for subscription in subscriptions {
            let upcomingBillingDates = nextBillingDates(for: subscription, count: 12, from: now, calendar: calendar)
            for billingDate in upcomingBillingDates {
                guard let reminderDate = calendar.date(byAdding: .day, value: -1, to: billingDate) else { continue }

                let components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
                guard components.year != nil, components.month != nil, components.day != nil else { continue }

                var reminderComponents = components
                reminderComponents.hour = 10
                reminderComponents.minute = 0

                let content = UNMutableNotificationContent()
                content.title = "Recordatorio de suscripción"
                content.body = "Mañana toca pagar \(subscription.platformName) (\(subscription.planName))."
                content.sound = .default

                let identifier = "\(reminderPrefix).\(subscription.id.uuidString).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
                let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request) { error in
                    if let error {
                        print("Error scheduling day-before reminder: \(error)")
                    }
                }
            }
        }
    }

    private func weeklySummaryBody(for subscriptions: [Subscription]) -> String {
        let calendar = Calendar.current
        let now = Date()

        guard
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
            let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart),
            let nextWeekEnd = calendar.date(byAdding: .day, value: 7, to: nextWeekStart)
        else {
            return subscriptions.isEmpty
                ? "No tienes pagos de suscripciones próximos."
                : "Revisa tus suscripciones activas para esta semana."
        }

        let upcoming = subscriptions.filter { subscription in
            guard let date = nextBillingDate(for: subscription, from: now, calendar: calendar) else { return false }
            return date >= nextWeekStart && date < nextWeekEnd
        }

        guard !upcoming.isEmpty else {
            return "No tienes pagos de suscripciones en la semana entrante."
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"

        let lines = upcoming
            .sorted { $0.billingDay < $1.billingDay }
            .prefix(5)
            .map { subscription in
                let dateText = nextBillingDate(for: subscription, from: now, calendar: calendar).map { formatter.string(from: $0) } ?? "--"
                return "\(subscription.platformName) (\(subscription.planName)) - \(dateText)"
            }

        return lines.joined(separator: ", ")
    }

    private func nextBillingDates(for subscription: Subscription, count: Int, from date: Date, calendar: Calendar) -> [Date] {
        guard count > 0 else { return [] }

        var results: [Date] = []
        var baseDate = date

        for _ in 0..<count {
            guard let next = nextBillingDate(for: subscription, from: baseDate, calendar: calendar) else { break }
            results.append(next)
            guard let after = calendar.date(byAdding: .day, value: 1, to: next) else { break }
            baseDate = after
        }

        return results
    }

    private func nextBillingDate(for subscription: Subscription, from date: Date, calendar: Calendar) -> Date? {
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return nil
        }

        if let currentMonthBilling = billingDate(inMonthOf: currentMonthStart, day: subscription.billingDay, calendar: calendar),
           currentMonthBilling >= calendar.startOfDay(for: date) {
            return currentMonthBilling
        }

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else { return nil }
        return billingDate(inMonthOf: nextMonth, day: subscription.billingDay, calendar: calendar)
    }

    private func billingDate(inMonthOf date: Date, day: Int, calendar: Calendar) -> Date? {
        let range = calendar.range(of: .day, in: .month, for: date)
        let clampedDay = min(max(1, day), range?.count ?? 28)
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = clampedDay
        return calendar.date(from: components)
    }
}
