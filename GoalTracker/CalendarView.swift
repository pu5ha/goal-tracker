import SwiftUI
import EventKit
import Combine

// Wrapper to make EKEvent work with sheet(item:)
struct IdentifiableEvent: Identifiable {
    let id: String
    let event: EKEvent

    init(_ event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.event = event
    }
}

// Wrapper to pass date to sheet(item:)
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct CalendarView: View {
    let weekStart: Date
    @ObservedObject var calendarService: CalendarService
    @State private var events: [EKEvent] = []
    @State private var hoveredEventId: String?
    @State private var eventToEdit: IdentifiableEvent?
    @State private var addEventDate: IdentifiableDate?
    @State private var currentTime = Date()
    @State private var isRefreshing = false

    private let weekService = WeekService.shared
    private let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Always show 7 days - starting from today for current week, or from weekStart for other weeks
    private var visibleDays: [Date] {
        let calendar = Calendar.current

        // For current week, show 7 days starting from today
        if weekService.isCurrentWeek(weekStart) {
            let today = calendar.startOfDay(for: Date())
            return (0..<7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: dayOffset, to: today)
            }
        }

        // For past/future weeks, show 7 days from weekStart
        return weekService.daysOfWeek(for: weekStart)
    }

    // Next upcoming event
    private var nextEvent: EKEvent? {
        let now = Date()
        return events
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    var body: some View {
        VStack(spacing: 0) {
            if calendarService.hasAccess {
                // Refresh button bar
                HStack {
                    Spacer()
                    Button(action: { refreshEvents() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            Text(isRefreshing ? "LOADING..." : "REFRESH")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(CyberTheme.matrixGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isRefreshing ? CyberTheme.matrixGreen.opacity(0.1) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.matrixGreen.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CyberTheme.cardBackground)

                // Next meeting banner
                if let next = nextEvent {
                    nextMeetingBanner(next)
                }
                calendarGrid
            } else {
                noAccessView
            }
        }
        .background(CyberTheme.background)
        .onAppear(perform: loadEvents)
        .onChange(of: weekStart) { _ in loadEvents() }
        .onReceive(timeUpdateTimer) { _ in
            currentTime = Date()
        }
        .sheet(item: $eventToEdit) { identifiableEvent in
            EditEventSheet(event: identifiableEvent.event, calendarService: calendarService) {
                loadEvents()
            }
        }
        .overlay {
            if let dateWrapper = addEventDate {
                ZStack {
                    // Dimmed background - tap to dismiss
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            addEventDate = nil
                        }

                    // Modal content
                    AddEventSheet(selectedDate: dateWrapper.date, calendarService: calendarService, onDismiss: {
                        addEventDate = nil
                    })
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.2), value: addEventDate != nil)
            }
        }
    }

    private func nextMeetingBanner(_ event: EKEvent) -> some View {
        let eventColor = Color(nsColor: event.calendarColor)
        let timeUntil = timeUntilEvent(event)

        return HStack(spacing: 12) {
            // Pulsing indicator
            Circle()
                .fill(eventColor)
                .frame(width: 8, height: 8)
                .shadow(color: eventColor.opacity(0.8), radius: 4, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("// NEXT_EVENT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textSecondary)

                Text(event.title ?? "UNTITLED")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.formattedStartTime.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(eventColor)

                Text(timeUntil)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberTheme.textSecondary)
            }

            // Quick action to view
            Button(action: { eventToEdit = IdentifiableEvent(event) }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(eventColor)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(eventColor.opacity(0.1))
        )
        .overlay(
            Rectangle()
                .fill(eventColor)
                .frame(width: 3),
            alignment: .leading
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(eventColor.opacity(0.3)),
            alignment: .bottom
        )
    }

    private func timeUntilEvent(_ event: EKEvent) -> String {
        let now = Date()
        let interval = event.startDate.timeIntervalSince(now)

        if interval < 60 {
            return "STARTING NOW"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "IN \(minutes) MIN"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes > 0 {
                return "IN \(hours)H \(minutes)M"
            }
            return "IN \(hours) HOUR\(hours > 1 ? "S" : "")"
        } else {
            let days = Int(interval / 86400)
            return "IN \(days) DAY\(days > 1 ? "S" : "")"
        }
    }

    private var calendarGrid: some View {
        let days = visibleDays

        return GeometryReader { geometry in
            VStack(spacing: 0) {
                // Day Headers
                HStack(spacing: 1) {
                    ForEach(days, id: \.self) { day in
                        dayHeader(day)
                    }
                }
                .frame(height: 55)
                .background(CyberTheme.cardBackground)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(CyberTheme.matrixGreen.opacity(0.3)),
                    alignment: .bottom
                )

                // Day Columns
                HStack(alignment: .top, spacing: 1) {
                    ForEach(days, id: \.self) { day in
                        dayColumn(day)
                    }
                }
            }
        }
    }

    private func dayHeader(_ date: Date) -> some View {
        let formatted = weekService.formatDay(date)
        let isToday = weekService.isToday(date)

        return VStack(spacing: 4) {
            Text(formatted.weekday.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isToday ? CyberTheme.matrixGreen : CyberTheme.textSecondary)

            Text(formatted.day)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(isToday ? CyberTheme.matrixGreen : CyberTheme.textPrimary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? CyberTheme.matrixGreen.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isToday ? CyberTheme.matrixGreen : Color.clear, lineWidth: 1)
                )
                .shadow(color: isToday ? CyberTheme.matrixGreen.opacity(0.6) : Color.clear, radius: 6, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func dayColumn(_ date: Date) -> some View {
        let dayEvents = eventsForDay(date)
        let isToday = weekService.isToday(date)

        return VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if isToday {
                        // Split events into past and future, insert time indicator between
                        let (pastEvents, futureEvents) = splitEventsByCurrentTime(dayEvents)

                        ForEach(pastEvents, id: \.eventIdentifier) { event in
                            Button(action: { eventToEdit = IdentifiableEvent(event) }) {
                                eventCard(event, isPast: true)
                            }
                            .buttonStyle(.plain)
                        }

                        // Current time indicator in the middle
                        currentTimeIndicator

                        ForEach(futureEvents, id: \.eventIdentifier) { event in
                            Button(action: { eventToEdit = IdentifiableEvent(event) }) {
                                eventCard(event, isPast: false)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ForEach(dayEvents, id: \.eventIdentifier) { event in
                            Button(action: { eventToEdit = IdentifiableEvent(event) }) {
                                eventCard(event, isPast: false)
                            }
                            .buttonStyle(.plain)
                        }

                        if dayEvents.isEmpty {
                            VStack(spacing: 4) {
                                Text("--")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(CyberTheme.dimGreen)
                                Text("NO_EVENTS")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(CyberTheme.textSecondary.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                        }
                    }
                }
                .padding(6)
            }

            // Add event button at bottom of each day
            Button(action: {
                addEventDate = IdentifiableDate(date: date)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    Text("ADD")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundColor(CyberTheme.matrixGreen)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(CyberTheme.cardBackground)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(CyberTheme.gridLine),
                    alignment: .top
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isToday ? CyberTheme.matrixGreen.opacity(0.03) : Color.clear)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(CyberTheme.gridLine),
            alignment: .trailing
        )
    }

    private func splitEventsByCurrentTime(_ events: [EKEvent]) -> ([EKEvent], [EKEvent]) {
        let now = currentTime
        let pastEvents = events.filter { $0.endDate <= now }
        let futureEvents = events.filter { $0.endDate > now }
        return (pastEvents, futureEvents)
    }

    private var currentTimeIndicator: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: currentTime)

        return HStack(spacing: 0) {
            Circle()
                .fill(CyberTheme.neonMagenta)
                .frame(width: 8, height: 8)
                .shadow(color: CyberTheme.neonMagenta.opacity(0.8), radius: 4, x: 0, y: 0)

            Rectangle()
                .fill(CyberTheme.neonMagenta)
                .frame(height: 2)
                .shadow(color: CyberTheme.neonMagenta.opacity(0.6), radius: 2, x: 0, y: 0)
        }
        .overlay(
            Text(timeString.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(CyberTheme.neonMagenta)
                .padding(.horizontal, 4)
                .background(CyberTheme.background)
                .offset(y: -10),
            alignment: .leading
        )
        .padding(.vertical, 8)
    }

    private func eventCard(_ event: EKEvent, isPast: Bool = false) -> some View {
        let isHovered = hoveredEventId == event.eventIdentifier
        let eventColor = Color(nsColor: event.calendarColor)
        let opacity: Double = isPast ? 0.5 : 1.0

        return VStack(alignment: .leading, spacing: 5) {
            Text(event.formattedStartTime.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(eventColor.opacity(opacity))

            Text(event.title ?? "UNTITLED")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isPast ? CyberTheme.textSecondary : CyberTheme.textPrimary)
                .strikethrough(isPast, color: CyberTheme.textSecondary.opacity(0.5))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // Show location if available
            if let location = event.location, !location.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text(cleanLocation(location))
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(CyberTheme.textSecondary.opacity(opacity * 0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(CyberTheme.cardBackground.opacity(isPast ? 0.5 : 1.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? eventColor : eventColor.opacity(0.3 * opacity), lineWidth: 1)
        )
        .overlay(
            Rectangle()
                .fill(eventColor.opacity(opacity))
                .frame(width: 3)
                .shadow(color: isPast ? Color.clear : eventColor.opacity(0.6), radius: 3, x: 0, y: 0),
            alignment: .leading
        )
        .shadow(color: isHovered && !isPast ? eventColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 0)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredEventId = hovering ? event.eventIdentifier : nil
            }
            // Set cursor to pointing hand on hover
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var noAccessView: some View {
        VStack(spacing: 20) {
            ZStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 50, design: .monospaced))
                    .foregroundColor(CyberTheme.neonMagenta.opacity(0.3))
                    .offset(x: 2, y: 2)

                Image(systemName: "lock.shield")
                    .font(.system(size: 50, design: .monospaced))
                    .foregroundColor(CyberTheme.neonCyan.opacity(0.3))
                    .offset(x: -2, y: -2)

                Image(systemName: "lock.shield")
                    .font(.system(size: 50, design: .monospaced))
                    .foregroundColor(CyberTheme.neonMagenta)
            }
            .shadow(color: CyberTheme.neonMagenta.opacity(0.5), radius: 10, x: 0, y: 0)

            VStack(spacing: 8) {
                Text("// ACCESS_DENIED")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)

                Text("CALENDAR_PERMISSION_REQUIRED")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CyberTheme.textSecondary)
            }

            HStack(spacing: 16) {
                Button(action: {
                    Task { await calendarService.requestAccess() }
                }) {
                    Text("[GRANT_ACCESS]")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(CyberTheme.matrixGreen)
                        .foregroundColor(CyberTheme.background)
                        .cornerRadius(4)
                        .shadow(color: CyberTheme.matrixGreen.opacity(0.5), radius: 8, x: 0, y: 0)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("[SYS_SETTINGS]")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.gridLine, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CyberTheme.background)
    }

    private func loadEvents() {
        let calendar = Calendar.current
        var fetchedEvents: [EKEvent]

        // For current week, fetch 7 days starting from today
        if weekService.isCurrentWeek(weekStart) {
            let today = calendar.startOfDay(for: Date())
            let endDate = calendar.date(byAdding: .day, value: 7, to: today) ?? today
            fetchedEvents = calendarService.fetchEvents(from: today, to: endDate)
        } else {
            // For past/future weeks, fetch the standard week
            fetchedEvents = calendarService.fetchEventsForWeek(weekStart: weekStart)
        }

        // Deduplicate events with same title and start time (e.g., holidays on multiple calendars)
        var seen = Set<String>()
        events = fetchedEvents.filter { event in
            let key = "\(event.title ?? "")_\(event.startDate.timeIntervalSince1970)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private func refreshEvents() {
        isRefreshing = true
        let oldCount = events.count
        NSLog("🔄 Refresh started - current events count: %d", oldCount)

        // Trigger refresh from external sources, then reload events
        calendarService.refreshFromExternalSources { [self] in
            loadEvents()
            NSLog("🔄 Refresh complete - old count: %d, new count: %d", oldCount, events.count)
            isRefreshing = false
        }
    }

    private func eventsForDay(_ date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        return events.filter { event in
            event.startDate < endOfDay && event.endDate > startOfDay
        }.sorted { $0.startDate < $1.startDate }
    }

    private func cleanLocation(_ location: String) -> String {
        var cleaned = location

        // Remove country names
        let countries = [", United States", ", USA", ", US", ", Canada", ", UK", ", United Kingdom"]
        for country in countries {
            cleaned = cleaned.replacingOccurrences(of: country, with: "", options: .caseInsensitive)
        }

        // Remove zip codes (5 digits, optionally with -4 extension)
        cleaned = cleaned.replacingOccurrences(
            of: #",?\s*\d{5}(-\d{4})?"#,
            with: "",
            options: .regularExpression
        )

        // Clean up any trailing commas or extra spaces
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        if cleaned.hasSuffix(",") {
            cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return cleaned
    }
}

// MARK: - Edit Event Sheet
struct EditEventSheet: View {
    let event: EKEvent
    @ObservedObject var calendarService: CalendarService
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isAllDay: Bool = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("// EDIT_EVENT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                    Text("Modify calendar event")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberTheme.textPrimary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.gridLine, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(20)
            .background(CyberTheme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(CyberTheme.neonCyan.opacity(0.3)),
                alignment: .bottom
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("> EVENT_TITLE:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)

                        TextField("", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(CyberTheme.textPrimary)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(CyberTheme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(CyberTheme.neonCyan.opacity(0.5), lineWidth: 1)
                            )
                    }

                    // All Day Toggle
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.neonYellow)
                        Text("ALL_DAY_EVENT")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(CyberTheme.textPrimary)
                        Spacer()
                        Toggle("", isOn: $isAllDay)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(CyberTheme.matrixGreen)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(CyberTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CyberTheme.gridLine, lineWidth: 1)
                    )

                    // Date/Time - Improved UI
                    VStack(alignment: .leading, spacing: 12) {
                        // Start Date & Time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("> START:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberTheme.textSecondary)

                            HStack(spacing: 12) {
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .accentColor(CyberTheme.neonCyan)

                                if !isAllDay {
                                    DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .accentColor(CyberTheme.neonCyan)
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(CyberTheme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(CyberTheme.neonCyan.opacity(0.3), lineWidth: 1)
                            )
                        }

                        if !isAllDay {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("> END:")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(CyberTheme.textSecondary)

                                HStack(spacing: 12) {
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .accentColor(CyberTheme.matrixGreen)

                                    DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .accentColor(CyberTheme.matrixGreen)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(CyberTheme.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(CyberTheme.matrixGreen.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .onChange(of: startDate) { newStart in
                        if endDate <= newStart {
                            endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("> LOCATION:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)

                        LocationSearchField(location: $location)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("> NOTES:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)

                        TextEditor(text: $notes)
                            .font(.system(size: 12, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .foregroundColor(CyberTheme.textPrimary)
                            .padding(12)
                            .frame(minHeight: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(CyberTheme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(CyberTheme.gridLine, lineWidth: 1)
                            )
                    }
                }
                .padding(20)
            }

            // Footer
            HStack {
                Button(action: { showDeleteConfirm = true }) {
                    Text("[DELETE]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.neonMagenta)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.neonMagenta.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text("[CANCEL]")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.gridLine, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                Button(action: saveEvent) {
                    Text("[SAVE]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(CyberTheme.neonCyan)
                        .foregroundColor(CyberTheme.background)
                        .cornerRadius(4)
                        .shadow(color: CyberTheme.neonCyan.opacity(0.5), radius: 6, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(20)
            .background(CyberTheme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(CyberTheme.neonCyan.opacity(0.3)),
                alignment: .top
            )
        }
        .frame(width: 450, height: 540)
        .background(CyberTheme.background)
        .onAppear {
            title = event.title ?? ""
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
            location = event.location ?? ""
            notes = event.notes ?? ""
        }
        .alert("DELETE_EVENT?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func saveEvent() {
        event.title = title
        event.startDate = startDate
        event.endDate = isAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate : endDate
        event.isAllDay = isAllDay
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes

        do {
            try calendarService.updateEvent(event)
            onSave()
            dismiss()
        } catch {
            print("Failed to save event: \(error)")
        }
    }

    private func deleteEvent() {
        do {
            try calendarService.deleteEvent(event)
            onSave()
            dismiss()
        } catch {
            print("Failed to delete event: \(error)")
        }
    }
}
