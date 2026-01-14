import Foundation
import UserNotifications
import EventKit
import Combine

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()
    private let calendarService = CalendarService.shared
    private let dataService = DataService.shared
    private let weekService = WeekService.shared

    init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            if granted {
                scheduleDailyReminders()
            }
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    // MARK: - Daily Reminders

    func scheduleDailyReminders() {
        scheduleMorningBriefing()
        scheduleMiddayCheckin()
        scheduleEndOfDayReview()
        scheduleDueDateReminders()
    }

    // MARK: - Morning Briefing (8 AM)

    func scheduleMorningBriefing() {
        center.removePendingNotificationRequests(withIdentifiers: ["morning-briefing"])

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "☀️ Morning Briefing"
        content.body = "Tap to see your goals and schedule for today"
        content.sound = .default
        content.categoryIdentifier = "MORNING_BRIEFING"

        let request = UNNotificationRequest(
            identifier: "morning-briefing",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule morning briefing: \(error)")
            }
        }
    }

    // MARK: - Mid-day Check-in (12 PM)

    func scheduleMiddayCheckin() {
        center.removePendingNotificationRequests(withIdentifiers: ["midday-checkin"])

        var dateComponents = DateComponents()
        dateComponents.hour = 12
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "🔄 Mid-day Check-in"
        content.body = "Tap to review your progress and afternoon schedule"
        content.sound = .default
        content.categoryIdentifier = "MIDDAY_CHECKIN"

        let request = UNNotificationRequest(
            identifier: "midday-checkin",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule midday check-in: \(error)")
            }
        }
    }

    // MARK: - End of Day Review (6 PM)

    func scheduleEndOfDayReview() {
        center.removePendingNotificationRequests(withIdentifiers: ["evening-summary", "end-of-day"])

        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "🌙 End of Day Review"
        content.body = "Tap to review today's progress and tomorrow's plan"
        content.sound = .default
        content.categoryIdentifier = "END_OF_DAY"

        let request = UNNotificationRequest(
            identifier: "end-of-day",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule end of day review: \(error)")
            }
        }
    }

    // MARK: - Due Date Reminders

    func scheduleDueDateReminders() {
        scheduleDueTodayMorningReminder()
        scheduleDueTodayAfternoonReminder()
    }

    private func scheduleDueTodayMorningReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["due-today-morning"])

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "⏰ Goals Due Today"
        content.body = "Tap to view goals that need attention today"
        content.sound = .default
        content.categoryIdentifier = "DUE_TODAY"

        let request = UNNotificationRequest(
            identifier: "due-today-morning",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule due today morning reminder: \(error)")
            }
        }
    }

    private func scheduleDueTodayAfternoonReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["due-today-afternoon"])

        var dateComponents = DateComponents()
        dateComponents.hour = 14  // 2 PM
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "⏰ Due Today Check-in"
        content.body = "Don't forget about your goals due today"
        content.sound = .default
        content.categoryIdentifier = "DUE_TODAY"

        let request = UNNotificationRequest(
            identifier: "due-today-afternoon",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule due today afternoon reminder: \(error)")
            }
        }
    }

    // MARK: - Send Immediate Notifications with Content

    func sendMorningBriefingNow() {
        let content = buildMorningContent()
        let request = UNNotificationRequest(
            identifier: "morning-briefing-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendMiddayCheckinNow() {
        let content = buildMiddayContent()
        let request = UNNotificationRequest(
            identifier: "midday-checkin-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendEndOfDayReviewNow() {
        let content = buildEndOfDayContent()
        let request = UNNotificationRequest(
            identifier: "end-of-day-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendDueTodayReminderNow() {
        let content = buildDueTodayContent()
        let request = UNNotificationRequest(
            identifier: "due-today-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    // MARK: - Build Notification Content

    private func buildMorningContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "☀️ Morning Briefing"
        content.sound = .default

        var bodyParts: [String] = []

        // Goals summary
        let weekStart = weekService.currentWeekStart
        let stats = dataService.getWeekStats(for: weekStart)
        bodyParts.append("📋 Goals: \(stats.completed)/\(stats.total) complete")

        // Due today goals
        let dueToday = dataService.getAllGoalsDueToday()
        if !dueToday.isEmpty {
            bodyParts.append("⏰ \(dueToday.count) goal(s) due today")
        }

        // Overdue goals
        let overdue = dataService.getAllOverdueGoals()
        if !overdue.isEmpty {
            bodyParts.append("⚠️ \(overdue.count) overdue goal(s)")
        }

        // Today's focus
        let focusedGoals = dataService.getTodaysFocusedGoals(for: weekStart)
        if !focusedGoals.isEmpty {
            let focusTitles = focusedGoals.prefix(2).compactMap { $0.title }.joined(separator: ", ")
            let suffix = focusedGoals.count > 2 ? " +\(focusedGoals.count - 2) more" : ""
            bodyParts.append("🎯 Focus: \(focusTitles)\(suffix)")
        }

        // Today's events
        let todayEvents = getTodayEvents()
        if !todayEvents.isEmpty {
            let eventCount = todayEvents.count
            if let nextEvent = todayEvents.first {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                let time = nextEvent.isAllDay ? "All day" : formatter.string(from: nextEvent.startDate)
                bodyParts.append("📅 \(eventCount) event(s) • Next: \(time) \(nextEvent.title ?? "Event")")
            }
        } else {
            bodyParts.append("📅 No events today")
        }

        content.body = bodyParts.joined(separator: "\n")
        return content
    }

    private func buildMiddayContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "🔄 Mid-day Check-in"
        content.sound = .default

        var bodyParts: [String] = []

        // Goals progress
        let weekStart = weekService.currentWeekStart
        let stats = dataService.getWeekStats(for: weekStart)
        let progressPercent = stats.total > 0 ? Int((Double(stats.completed) / Double(stats.total)) * 100) : 0
        bodyParts.append("📋 Progress: \(progressPercent)% (\(stats.completed)/\(stats.total))")

        // Due today goals
        let dueToday = dataService.getAllGoalsDueToday()
        if !dueToday.isEmpty {
            bodyParts.append("⏰ \(dueToday.count) goal(s) still due today")
        }

        // Focus items status
        let focusedGoals = dataService.getTodaysFocusedGoals(for: weekStart)
        if !focusedGoals.isEmpty {
            bodyParts.append("🎯 \(focusedGoals.count) focus item(s) remaining")
        }

        // Afternoon events
        let afternoonEvents = getAfternoonEvents()
        if !afternoonEvents.isEmpty {
            let eventList = afternoonEvents.prefix(2).map { event -> String in
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                let time = event.isAllDay ? "All day" : formatter.string(from: event.startDate)
                return "\(time): \(event.title ?? "Event")"
            }.joined(separator: ", ")
            bodyParts.append("📅 Coming up: \(eventList)")
        } else {
            bodyParts.append("📅 No more events today")
        }

        content.body = bodyParts.joined(separator: "\n")
        return content
    }

    private func buildEndOfDayContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "🌙 End of Day Review"
        content.sound = .default

        var bodyParts: [String] = []

        // Today's accomplishments
        let weekStart = weekService.currentWeekStart
        let stats = dataService.getWeekStats(for: weekStart)
        let progressPercent = stats.total > 0 ? Int((Double(stats.completed) / Double(stats.total)) * 100) : 0
        bodyParts.append("📋 Week progress: \(progressPercent)% (\(stats.completed)/\(stats.total))")

        // Due today incomplete warning
        let dueTodayIncomplete = dataService.getAllGoalsDueToday()
        if !dueTodayIncomplete.isEmpty {
            bodyParts.append("⚠️ \(dueTodayIncomplete.count) goal(s) still due today!")
        }

        // Due tomorrow preview
        let weekGoals = dataService.getGoals(for: weekStart)
        let dueTomorrow = weekGoals.filter { $0.isDueTomorrow && !$0.isCompleted }
        if !dueTomorrow.isEmpty {
            bodyParts.append("⏰ \(dueTomorrow.count) goal(s) due tomorrow")
        }

        // Incomplete goals count
        let incompleteCount = stats.total - stats.completed
        if incompleteCount > 0 {
            bodyParts.append("⏳ \(incompleteCount) goal(s) remaining this week")
        } else {
            bodyParts.append("✅ All goals complete!")
        }

        // Tomorrow preview
        let tomorrowEvents = getTomorrowEvents()
        if !tomorrowEvents.isEmpty {
            bodyParts.append("📅 Tomorrow: \(tomorrowEvents.count) event(s)")
        } else {
            bodyParts.append("📅 Tomorrow: No events scheduled")
        }

        content.body = bodyParts.joined(separator: "\n")
        return content
    }

    private func buildDueTodayContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Goals Due Today"
        content.sound = .default

        let dueToday = dataService.getAllGoalsDueToday()
        let overdue = dataService.getAllOverdueGoals()

        var bodyParts: [String] = []

        if !overdue.isEmpty {
            bodyParts.append("⚠️ \(overdue.count) overdue goal(s)")
        }

        if !dueToday.isEmpty {
            let titles = dueToday.prefix(3).compactMap { $0.title }.joined(separator: ", ")
            let suffix = dueToday.count > 3 ? " +\(dueToday.count - 3) more" : ""
            bodyParts.append("📋 Due today: \(titles)\(suffix)")
        } else if overdue.isEmpty {
            bodyParts.append("✅ No goals due today")
        }

        content.body = bodyParts.joined(separator: "\n")
        return content
    }

    // MARK: - Event Helpers

    private func getTodayEvents() -> [EKEvent] {
        guard calendarService.hasAccess else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return calendarService.fetchEvents(from: today, to: tomorrow)
            .sorted { $0.startDate < $1.startDate }
    }

    private func getAfternoonEvents() -> [EKEvent] {
        guard calendarService.hasAccess else { return [] }
        let calendar = Calendar.current
        let now = Date()
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return [] }
        return calendarService.fetchEvents(from: now, to: endOfDay)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    private func getTomorrowEvents() -> [EKEvent] {
        guard calendarService.hasAccess else { return [] }
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let dayAfter = calendar.date(byAdding: .day, value: 1, to: tomorrow) else { return [] }
        let tomorrowStart = calendar.startOfDay(for: tomorrow)
        return calendarService.fetchEvents(from: tomorrowStart, to: dayAfter)
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Event Reminders (15 min before)

    func scheduleEventReminders() {
        guard calendarService.hasAccess else { return }

        // Clear old event reminders
        center.getPendingNotificationRequests { requests in
            let eventIds = requests
                .filter { $0.identifier.hasPrefix("event-") }
                .map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: eventIds)
        }

        // Get events for the next 7 days
        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }

        let events = calendarService.fetchEvents(from: now, to: endDate)

        for event in events {
            scheduleReminderForEvent(event)
        }
    }

    private func scheduleReminderForEvent(_ event: EKEvent) {
        // Skip all-day events for 15-min reminders
        guard !event.isAllDay else { return }

        // Calculate 15 minutes before
        guard let reminderDate = Calendar.current.date(byAdding: .minute, value: -15, to: event.startDate),
              reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "⏰ Starting in 15 minutes"
        content.body = event.title ?? "Event"
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let identifier = "event-\(event.eventIdentifier ?? UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule event reminder: \(error)")
            }
        }
    }

    // MARK: - Refresh All Notifications

    func refreshAllNotifications() {
        guard isAuthorized else { return }
        scheduleDailyReminders()
        scheduleEventReminders()
    }

    // MARK: - Test Notifications

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "GoalTracker notifications are working!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
