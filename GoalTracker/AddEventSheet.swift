import SwiftUI
import EventKit

struct AddEventSheet: View {
    let selectedDate: Date
    @ObservedObject var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var selectedCalendar: EKCalendar?
    @State private var notes = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isTitleFocused: Bool

    init(selectedDate: Date, calendarService: CalendarService) {
        self.selectedDate = selectedDate
        self.calendarService = calendarService

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = 9
        components.minute = 0
        let defaultStart = calendar.date(from: components) ?? selectedDate

        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: calendar.date(byAdding: .hour, value: 1, to: defaultStart) ?? defaultStart)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("// NEW_EVENT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                    Text("Add to your calendar")
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
                                    .stroke(isTitleFocused ? CyberTheme.neonCyan : CyberTheme.gridLine, lineWidth: isTitleFocused ? 2 : 1)
                            )
                            .shadow(color: isTitleFocused ? CyberTheme.neonCyan.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 0)
                            .focused($isTitleFocused)
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

                    // Calendar Selection
                    if !calendarService.calendars.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("> CALENDAR:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberTheme.textSecondary)

                            Picker("Calendar", selection: $selectedCalendar) {
                                ForEach(calendarService.calendars, id: \.calendarIdentifier) { calendar in
                                    HStack {
                                        Circle()
                                            .fill(Color(nsColor: NSColor(cgColor: calendar.cgColor) ?? .systemBlue))
                                            .frame(width: 8, height: 8)
                                        Text(calendar.title)
                                            .font(.system(size: 12, design: .monospaced))
                                    }
                                    .tag(calendar as EKCalendar?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("> NOTES (OPTIONAL):")
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

            if showError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CyberTheme.neonMagenta)
                    Text(errorMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(CyberTheme.neonMagenta)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            // Footer
            HStack {
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
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(action: createEvent) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text("CREATE_EVENT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(title.isEmpty ? CyberTheme.dimGreen : CyberTheme.neonCyan)
                    .foregroundColor(title.isEmpty ? CyberTheme.textSecondary : CyberTheme.background)
                    .cornerRadius(4)
                    .shadow(color: title.isEmpty ? Color.clear : CyberTheme.neonCyan.opacity(0.5), radius: 6, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty || !calendarService.hasAccess)
                .keyboardShortcut(.return, modifiers: [])
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
            selectedCalendar = calendarService.getDefaultCalendar()
            isTitleFocused = true
        }
    }

    private func createEvent() {
        guard !title.isEmpty else { return }

        do {
            var eventEnd = endDate
            if isAllDay {
                eventEnd = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            }

            _ = try calendarService.createEvent(
                title: title,
                startDate: startDate,
                endDate: eventEnd,
                calendar: selectedCalendar,
                notes: notes.isEmpty ? nil : notes,
                isAllDay: isAllDay
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
