import Foundation
import EventKit
import AppKit
import Combine

class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var calendars: [EKCalendar] = []
    @Published var events: [EKEvent] = []

    init() {
        checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess {
            loadCalendars()
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                self.authorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    self.loadCalendars()
                }
            }
            return granted
        } catch {
            print("Failed to request calendar access: \(error)")
            return false
        }
    }

    var hasAccess: Bool {
        authorizationStatus == .fullAccess
    }

    func loadCalendars() {
        calendars = eventStore.calendars(for: .event).sorted { $0.title < $1.title }
    }

    func getDefaultCalendar() -> EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard hasAccess else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let fetchedEvents = eventStore.events(matching: predicate)

        DispatchQueue.main.async {
            self.events = fetchedEvents
        }

        return fetchedEvents
    }

    func fetchEventsForWeek(weekStart: Date) -> [EKEvent] {
        let weekEnd = WeekService.shared.weekEnd(for: weekStart)
        let adjustedEnd = Calendar.current.date(byAdding: .second, value: 1, to: weekEnd) ?? weekEnd
        return fetchEvents(from: weekStart, to: adjustedEnd)
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendar: EKCalendar? = nil,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool = false
    ) throws -> EKEvent {
        guard hasAccess else {
            throw CalendarError.noAccess
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
        return event
    }

    func deleteEvent(_ event: EKEvent) throws {
        guard hasAccess else {
            throw CalendarError.noAccess
        }
        try eventStore.remove(event, span: .thisEvent)
    }

    func updateEvent(_ event: EKEvent) throws {
        guard hasAccess else {
            throw CalendarError.noAccess
        }
        try eventStore.save(event, span: .thisEvent)
    }
}

enum CalendarError: LocalizedError {
    case noAccess
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noAccess: return "Calendar access not granted"
        case .saveFailed: return "Failed to save event"
        }
    }
}

extension EKEvent {
    var calendarColor: NSColor {
        if let cgColor = calendar?.cgColor {
            return NSColor(cgColor: cgColor) ?? .systemBlue
        }
        return .systemBlue
    }

    var formattedStartTime: String {
        if isAllDay { return "All day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }
}
