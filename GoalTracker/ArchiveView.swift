import SwiftUI

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataService = DataService.shared
    @State private var archivedGoals: [ArchivedGoal] = []
    @State private var groupedByWeek: [(weekStart: Date, goals: [ArchivedGoal])] = []
    @State private var hoveredGoalId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("// ARCHIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                    Text("Completed Goals")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textPrimary)
                }

                Spacer()

                Text("[\(archivedGoals.count) TOTAL]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.matrixGreen)

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
                    .foregroundColor(CyberTheme.matrixGreen.opacity(0.3)),
                alignment: .bottom
            )

            if archivedGoals.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "archivebox")
                        .font(.system(size: 40, weight: .light, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary.opacity(0.5))

                    Text("NO_ARCHIVED_GOALS")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)

                    Text("Completed goals will appear here after they're archived")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                // Goals list grouped by week
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedByWeek, id: \.weekStart) { weekGroup in
                            weekSection(weekStart: weekGroup.weekStart, goals: weekGroup.goals)
                        }
                    }
                    .padding(20)
                }
            }

            // Footer
            HStack {
                if !archivedGoals.isEmpty {
                    Button(action: clearAllArchived) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                            Text("CLEAR_ALL")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(CyberTheme.neonMagenta.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.neonMagenta.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text("[CLOSE]")
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
        .frame(width: 500, height: 600)
        .background(CyberTheme.background)
        .onAppear {
            loadArchivedGoals()
        }
    }

    @ViewBuilder
    private func weekSection(weekStart: Date, goals: [ArchivedGoal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Week header
            HStack(spacing: 8) {
                Rectangle()
                    .fill(CyberTheme.matrixGreen)
                    .frame(width: 3, height: 12)
                    .shadow(color: CyberTheme.matrixGreen.opacity(0.8), radius: 4)

                Text("// \(WeekService.shared.formatWeekRange(for: weekStart).uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textSecondary)

                Text("[\(goals.count)]")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberTheme.matrixGreen.opacity(0.7))

                Rectangle()
                    .fill(CyberTheme.gridLine)
                    .frame(height: 1)
            }

            // Goals in this week
            VStack(spacing: 6) {
                ForEach(goals, id: \.id) { goal in
                    archivedGoalRow(goal)
                }
            }
        }
    }

    @ViewBuilder
    private func archivedGoalRow(_ goal: ArchivedGoal) -> some View {
        let isHovered = hoveredGoalId == goal.id
        let color = categoryColor(goal.goalCategory)

        HStack(spacing: 10) {
            // Completed checkmark
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(CyberTheme.background)
                )
                .shadow(color: color.opacity(0.5), radius: 4)

            // Goal info
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.unwrappedTitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)
                    .strikethrough(true, color: CyberTheme.textSecondary.opacity(0.5))

                HStack(spacing: 8) {
                    Text(goal.unwrappedCategory.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(color.opacity(0.7))

                    if let completedAt = goal.completedAt {
                        Text("Completed \(formatDate(completedAt))")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // Delete button (on hover)
            Button(action: { deleteArchivedGoal(goal) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.neonMagenta.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(CyberTheme.neonMagenta.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? CyberTheme.cardBackground : color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? CyberTheme.gridLine : color.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredGoalId = hovering ? goal.id : nil
            }
        }
    }

    private func loadArchivedGoals() {
        archivedGoals = dataService.getArchivedGoals()

        // Group by week
        let grouped = dataService.getArchivedGoalsByWeek()
        groupedByWeek = grouped.keys.sorted(by: >).map { weekStart in
            (weekStart: weekStart, goals: grouped[weekStart] ?? [])
        }
    }

    private func deleteArchivedGoal(_ goal: ArchivedGoal) {
        withAnimation {
            dataService.deleteArchivedGoal(goal)
            loadArchivedGoals()
        }
    }

    private func clearAllArchived() {
        withAnimation {
            dataService.clearAllArchivedGoals()
            loadArchivedGoals()
        }
    }

    private func categoryColor(_ category: GoalCategory) -> Color {
        switch category {
        case .work: return CyberTheme.neonCyan
        case .health: return CyberTheme.matrixGreen
        case .personal: return CyberTheme.neonMagenta
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
