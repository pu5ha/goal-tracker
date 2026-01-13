import Foundation

class WeekService {
    static let shared = WeekService()

    private let calendar: Calendar

    init() {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2
        self.calendar = cal
    }

    // MARK: - Week Calculations

    func weekStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    var currentWeekStart: Date {
        weekStart(for: Date())
    }

    func previousWeekStart(from date: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart(for: date)) ?? date
    }

    func nextWeekStart(from date: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart(for: date)) ?? date
    }

    func weekEnd(for date: Date) -> Date {
        let start = weekStart(for: date)
        var endComponents = DateComponents()
        endComponents.day = 6
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59
        return calendar.date(byAdding: endComponents, to: start) ?? date
    }

    func daysOfWeek(for weekStart: Date) -> [Date] {
        (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }

    func isCurrentWeek(_ date: Date) -> Bool {
        weekStart(for: date) == currentWeekStart
    }

    func isPastWeek(_ date: Date) -> Bool {
        weekStart(for: date) < currentWeekStart
    }

    // MARK: - Formatting

    func formatWeekRange(for date: Date) -> String {
        let start = weekStart(for: date)
        let end = weekEnd(for: date)

        let startFormatter = DateFormatter()
        let endFormatter = DateFormatter()

        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        if startYear != endYear {
            startFormatter.dateFormat = "MMM d, yyyy"
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
        } else if startMonth != endMonth {
            startFormatter.dateFormat = "MMM d"
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
        } else {
            startFormatter.dateFormat = "MMM d"
            endFormatter.dateFormat = "d, yyyy"
            return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
        }
    }

    func formatDay(_ date: Date) -> (weekday: String, day: String) {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEE"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        return (weekdayFormatter.string(from: date), dayFormatter.string(from: date))
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    // MARK: - Rollover Logic

    func shouldPerformRollover(lastLaunchWeek: Date?) -> Bool {
        guard let lastWeek = lastLaunchWeek else { return false }
        return weekStart(for: lastWeek) < currentWeekStart
    }
}
