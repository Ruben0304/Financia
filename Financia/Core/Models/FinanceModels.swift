import Foundation

enum DateRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "7 D"
        case .month: return "30 D"
        case .quarter: return "90 D"
        }
    }

    var lengthInDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

struct FinanceEntry: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

extension FinanceEntry {
    static let sampleHistory: [FinanceEntry] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<60).map { offset -> FinanceEntry in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let harmonic = sin(Double(offset) / 6.0) * 600
            let trend = Double((offset % 10) * 20)
            let value = 12400 + harmonic + trend
            return FinanceEntry(date: date, value: value)
        }
        .sorted { $0.date < $1.date }
    }()
}
