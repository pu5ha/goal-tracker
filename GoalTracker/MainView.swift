import SwiftUI

struct MainView: View {
    @ObservedObject private var dataService = DataService.shared
    @ObservedObject private var calendarService = CalendarService.shared
    @ObservedObject private var notificationService = NotificationService.shared
    @State private var selectedWeekStart: Date = WeekService.shared.currentWeekStart
    @State private var showAddGoal = false
    @State private var showAddEvent = false
    @State private var showSettings = false
    @State private var selectedTab: MainTab = .calendar

    enum MainTab: String, CaseIterable {
        case calendar = "CALENDAR"
        case recap = "WEEKLY_RECAP"

        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .recap: return "doc.text.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            // Matrix background
            CyberTheme.background
                .ignoresSafeArea()

            // Subtle grid pattern
            MatrixGridBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                HSplitView {
                    WeeklyGoalsView(weekStart: selectedWeekStart)
                        .frame(minWidth: 280, idealWidth: 300, maxWidth: 340)

                    VStack(spacing: 0) {
                        tabSelector

                        if selectedTab == .calendar {
                            CalendarView(weekStart: selectedWeekStart, calendarService: calendarService)
                        } else {
                            WeeklyRecapView(weekStart: selectedWeekStart)
                        }
                    }
                    .frame(minWidth: 700)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 750)
        .onAppear {
            checkRollover()
            requestCalendarAccess()
            requestNotificationAccess()
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(weekStart: selectedWeekStart)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventSheet(selectedDate: selectedWeekStart, calendarService: calendarService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .id(dataService.refreshTrigger)
    }

    private var headerView: some View {
        HStack(spacing: 20) {
            // Week Navigation
            HStack(spacing: 16) {
                Button(action: goToPreviousWeek) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.matrixGreen)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(CyberTheme.matrixGreen.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                VStack(spacing: 2) {
                    Text("// WEEK_OF")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                    Text(WeekService.shared.formatWeekRange(for: selectedWeekStart).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.matrixGreen)
                }

                Button(action: goToNextWeek) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.matrixGreen)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(CyberTheme.matrixGreen.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                if !WeekService.shared.isCurrentWeek(selectedWeekStart) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedWeekStart = WeekService.shared.currentWeekStart
                        }
                    }) {
                        Text("[TODAY]")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CyberTheme.neonCyan)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            weekStatsView

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { showAddGoal = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text("NEW_GOAL")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(CyberTheme.matrixGreen)
                    .foregroundColor(CyberTheme.background)
                    .cornerRadius(4)
                    .shadow(color: CyberTheme.matrixGreen.opacity(0.5), radius: 8, x: 0, y: 0)
                }
                .buttonStyle(.plain)

                Button(action: { showAddEvent = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Text("NEW_EVENT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(CyberTheme.cardBackground)
                    .foregroundColor(CyberTheme.neonCyan)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(CyberTheme.neonCyan.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.gridLine, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            CyberTheme.cardBackground
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [CyberTheme.matrixGreen.opacity(0.1), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(CyberTheme.matrixGreen.opacity(0.3)),
            alignment: .bottom
        )
    }

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.rawValue) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedTab == tab ? CyberTheme.matrixGreen : Color.clear)
                    )
                    .foregroundColor(selectedTab == tab ? CyberTheme.background : CyberTheme.textSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(selectedTab == tab ? Color.clear : CyberTheme.gridLine, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(10)
        .background(CyberTheme.cardBackground.opacity(0.5))
    }

    private var weekStatsView: some View {
        let stats = dataService.getWeekStats(for: selectedWeekStart)
        let completionRate = stats.total > 0 ? Double(stats.completed) / Double(stats.total) : 0

        return HStack(spacing: 16) {
            // Cyberpunk progress ring
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(CyberTheme.dimGreen, lineWidth: 3)
                    .frame(width: 50, height: 50)

                // Progress arc
                Circle()
                    .trim(from: 0, to: completionRate)
                    .stroke(
                        completionRate == 1.0 ? CyberTheme.neonCyan : CyberTheme.matrixGreen,
                        style: StrokeStyle(lineWidth: 3, lineCap: .butt)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (completionRate == 1.0 ? CyberTheme.neonCyan : CyberTheme.matrixGreen).opacity(0.8), radius: 6, x: 0, y: 0)

                Text("\(stats.completed)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.matrixGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(stats.completed)/\(stats.total)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)
                Text("OBJECTIVES_COMPLETE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(CyberTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CyberTheme.gridLine, lineWidth: 1)
                )
        )
    }

    private func goToPreviousWeek() {
        withAnimation(.spring(response: 0.3)) {
            selectedWeekStart = WeekService.shared.previousWeekStart(from: selectedWeekStart)
        }
    }

    private func goToNextWeek() {
        withAnimation(.spring(response: 0.3)) {
            selectedWeekStart = WeekService.shared.nextWeekStart(from: selectedWeekStart)
        }
    }

    private func checkRollover() {
        let lastLaunchKey = "lastLaunchWeekStart"
        let lastLaunch = UserDefaults.standard.object(forKey: lastLaunchKey) as? Date

        if WeekService.shared.shouldPerformRollover(lastLaunchWeek: lastLaunch) {
            dataService.performRollover()
        }
        UserDefaults.standard.set(WeekService.shared.currentWeekStart, forKey: lastLaunchKey)
    }

    private func requestCalendarAccess() {
        Task {
            await calendarService.requestAccess()
            notificationService.scheduleEventReminders()
        }
    }

    private func requestNotificationAccess() {
        Task {
            let granted = await notificationService.requestAuthorization()
            if granted {
                notificationService.refreshAllNotifications()
            }
        }
    }
}

// MARK: - Matrix Grid Background
struct MatrixGridBackground: View {
    var body: some View {
        Canvas { context, size in
            // Vertical lines
            let spacing: CGFloat = 40
            for x in stride(from: 0, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(CyberTheme.gridLine.opacity(0.3)), lineWidth: 0.5)
            }
            // Horizontal lines
            for y in stride(from: 0, through: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(CyberTheme.gridLine.opacity(0.3)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @ObservedObject private var notificationService = NotificationService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("// SETTINGS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                    Text("Notifications & Preferences")
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
                VStack(alignment: .leading, spacing: 24) {
                    // Notification Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("> NOTIFICATION_STATUS:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)

                        HStack {
                            Image(systemName: notificationService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(notificationService.isAuthorized ? CyberTheme.matrixGreen : CyberTheme.neonMagenta)
                            Text(notificationService.isAuthorized ? "AUTHORIZED" : "NOT_AUTHORIZED")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(CyberTheme.textPrimary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(CyberTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(notificationService.isAuthorized ? CyberTheme.matrixGreen.opacity(0.3) : CyberTheme.neonMagenta.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Daily Reminders Schedule
                    VStack(alignment: .leading, spacing: 12) {
                        Text("> DAILY_REMINDERS:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)

                        VStack(spacing: 8) {
                            reminderRow(icon: "sunrise.fill", title: "Morning Briefing", time: "8:00 AM", color: CyberTheme.neonYellow)
                            reminderRow(icon: "sun.max.fill", title: "Mid-day Check-in", time: "12:00 PM", color: CyberTheme.neonCyan)
                            reminderRow(icon: "moon.fill", title: "End of Day Review", time: "6:00 PM", color: CyberTheme.neonMagenta)
                        }
                    }

                    // Test Notifications
                    VStack(alignment: .leading, spacing: 12) {
                        Text("> TEST_NOTIFICATIONS:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)

                        VStack(spacing: 8) {
                            Button(action: { notificationService.sendMorningBriefingNow() }) {
                                testButton(title: "Send Morning Briefing", icon: "sunrise.fill")
                            }
                            .buttonStyle(.plain)

                            Button(action: { notificationService.sendMiddayCheckinNow() }) {
                                testButton(title: "Send Mid-day Check-in", icon: "sun.max.fill")
                            }
                            .buttonStyle(.plain)

                            Button(action: { notificationService.sendEndOfDayReviewNow() }) {
                                testButton(title: "Send End of Day Review", icon: "moon.fill")
                            }
                            .buttonStyle(.plain)

                            Button(action: { notificationService.sendTestNotification() }) {
                                testButton(title: "Send Test Notification", icon: "bell.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("> INFO:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)

                        Text("Daily reminders include your current goals, focus items, and upcoming calendar events. Event reminders are sent 15 minutes before each scheduled event.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)
                            .padding(12)
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
                Spacer()
                Button(action: { dismiss() }) {
                    Text("[CLOSE]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(CyberTheme.matrixGreen)
                        .foregroundColor(CyberTheme.background)
                        .cornerRadius(4)
                        .shadow(color: CyberTheme.matrixGreen.opacity(0.5), radius: 6, x: 0, y: 0)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(CyberTheme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(CyberTheme.matrixGreen.opacity(0.3)),
                alignment: .top
            )
        }
        .frame(width: 420, height: 520)
        .background(CyberTheme.background)
    }

    private func reminderRow(icon: String, title: String, time: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(CyberTheme.textPrimary)
            Spacer()
            Text(time)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
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
    }

    private func testButton(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundColor(CyberTheme.neonCyan)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(CyberTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CyberTheme.neonCyan.opacity(0.3), lineWidth: 1)
        )
    }
}
