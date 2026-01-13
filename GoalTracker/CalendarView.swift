import SwiftUI
import EventKit

// Wrapper to make EKEvent work with sheet(item:)
struct IdentifiableEvent: Identifiable {
    let id: String
    let event: EKEvent

    init(_ event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.event = event
    }
}

struct CalendarView: View {
    let weekStart: Date
    @ObservedObject var calendarService: CalendarService
    @State private var events: [EKEvent] = []
    @State private var hoveredEventId: String?
    @State private var eventToEdit: IdentifiableEvent?
    @State private var showAddEvent = false
    @State private var addEventDate: Date = Date()

    private let weekService = WeekService.shared

    // Only show today and future days for current/future weeks
    // For past weeks, show all days
    private var visibleDays: [Date] {
        let allDays = weekService.daysOfWeek(for: weekStart)

        // If viewing a past week, show all days
        if weekService.isPastWeek(weekStart) {
            return allDays
        }

        // For current week, filter to today and future only
        return allDays.filter { day in
            weekService.isToday(day) || day > Date()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if calendarService.hasAccess {
                calendarGrid
            } else {
                noAccessView
            }
        }
        .background(CyberTheme.background)
        .onAppear(perform: loadEvents)
        .onChange(of: weekStart) { _ in loadEvents() }
        .sheet(item: $eventToEdit) { identifiableEvent in
            EditEventSheet(event: identifiableEvent.event, calendarService: calendarService) {
                loadEvents()
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventSheet(selectedDate: addEventDate, calendarService: calendarService)
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
                    ForEach(dayEvents, id: \.eventIdentifier) { event in
                        eventCard(event)
                            .onTapGesture {
                                eventToEdit = IdentifiableEvent(event)
                            }
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
                .padding(6)
            }

            // Add event button at bottom of each day
            Button(action: {
                addEventDate = date
                showAddEvent = true
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

    private func eventCard(_ event: EKEvent) -> some View {
        let isHovered = hoveredEventId == event.eventIdentifier
        let eventColor = Color(nsColor: event.calendarColor)

        return VStack(alignment: .leading, spacing: 3) {
            Text(event.formattedStartTime.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(eventColor)

            Text(event.title ?? "UNTITLED")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(CyberTheme.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(CyberTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? eventColor : eventColor.opacity(0.3), lineWidth: 1)
        )
        .overlay(
            Rectangle()
                .fill(eventColor)
                .frame(width: 3)
                .shadow(color: eventColor.opacity(0.6), radius: 3, x: 0, y: 0),
            alignment: .leading
        )
        .shadow(color: isHovered ? eventColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredEventId = hovering ? event.eventIdentifier : nil
            }
        }
        .contentShape(Rectangle())
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
        events = calendarService.fetchEventsForWeek(weekStart: weekStart)
    }

    private func eventsForDay(_ date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        return events.filter { event in
            event.startDate < endOfDay && event.endDate > startOfDay
        }.sorted { $0.startDate < $1.startDate }
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
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.gridLine, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
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

                    // Date/Time
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("> START:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberTheme.textSecondary)

                            DatePicker("", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                                .datePickerStyle(.field)
                                .labelsHidden()
                                .colorScheme(.dark)
                        }

                        if !isAllDay {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("> END:")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(CyberTheme.textSecondary)

                                DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.field)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                        }
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
        .frame(width: 450, height: 480)
        .background(CyberTheme.background)
        .onAppear {
            title = event.title ?? ""
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
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
