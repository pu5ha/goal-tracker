import SwiftUI

struct WeeklyGoalsView: View {
    let weekStart: Date
    @ObservedObject private var dataService = DataService.shared
    @State private var editingGoal: Goal?
    @State private var editText = ""
    @State private var hoveredGoalId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.matrixGreen)
                    Text("OBJECTIVES")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textPrimary)
                }
                Spacer()

                let stats = dataService.getWeekStats(for: weekStart)
                if stats.total > 0 {
                    Text("[\(stats.completed)/\(stats.total)]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.matrixGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(CyberTheme.matrixGreen.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(CyberTheme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(CyberTheme.matrixGreen.opacity(0.3)),
                alignment: .bottom
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(GoalCategory.allCases) { category in
                        categorySection(category)
                    }
                }
                .padding(16)
            }
            .background(CyberTheme.background)
        }
        .background(CyberTheme.background)
        .id(dataService.refreshTrigger)
    }

    @ViewBuilder
    private func categorySection(_ category: GoalCategory) -> some View {
        let goals = dataService.getGoalsByCategory(for: weekStart)[category] ?? []

        VStack(alignment: .leading, spacing: 10) {
            // Category Header
            HStack(spacing: 8) {
                Rectangle()
                    .fill(categoryColor(category))
                    .frame(width: 3, height: 12)
                    .shadow(color: categoryColor(category).opacity(0.8), radius: 4, x: 0, y: 0)

                Text("// \(category.rawValue.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textSecondary)

                if !goals.isEmpty {
                    Text("[\(goals.filter { $0.isCompleted }.count)/\(goals.count)]")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(categoryColor(category).opacity(0.7))
                }

                Rectangle()
                    .fill(CyberTheme.gridLine)
                    .frame(height: 1)
            }

            if goals.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(CyberTheme.dimGreen)
                        Text("NO_OBJECTIVES")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(goals, id: \.id) { goal in
                        goalRow(goal, category: category)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal, category: GoalCategory) -> some View {
        let isHovered = hoveredGoalId == goal.id

        HStack(spacing: 10) {
            // Cyberpunk checkbox
            Button {
                toggleGoal(goal)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(goal.isCompleted ? Color.clear : categoryColor(category).opacity(0.5), lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if goal.isCompleted {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(categoryColor(category))
                            .frame(width: 20, height: 20)
                            .shadow(color: categoryColor(category).opacity(0.6), radius: 4, x: 0, y: 0)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(CyberTheme.background)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())

            // Goal text
            if editingGoal?.id == goal.id {
                TextField("", text: $editText, onCommit: saveEdit)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)
                    .onAppear { editText = goal.unwrappedTitle }
            } else {
                Text(goal.unwrappedTitle)
                    .font(.system(size: 12, weight: goal.isCompleted ? .regular : .medium, design: .monospaced))
                    .foregroundColor(goal.isCompleted ? CyberTheme.textSecondary : CyberTheme.textPrimary)
                    .strikethrough(goal.isCompleted, color: CyberTheme.textSecondary)
                    .onTapGesture(count: 2) { startEditing(goal) }
            }

            Spacer()

            // Rolled over indicator
            if goal.rolledOverFrom != nil {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.neonYellow.opacity(0.7))
                    .help("ROLLED_OVER")
            }

            // Today focus button
            Button(action: { toggleFocusToday(goal) }) {
                HStack(spacing: 3) {
                    Image(systemName: goal.isFocusedToday ? "bolt.fill" : "bolt")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    if goal.isFocusedToday {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.horizontal, goal.isFocusedToday ? 8 : 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(goal.isFocusedToday ? CyberTheme.neonYellow : Color.clear)
                )
                .foregroundColor(goal.isFocusedToday ? CyberTheme.background : CyberTheme.textSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(goal.isFocusedToday ? Color.clear : CyberTheme.gridLine, lineWidth: 1)
                )
                .shadow(color: goal.isFocusedToday ? CyberTheme.neonYellow.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .help(goal.isFocusedToday ? "DEACTIVATE" : "ACTIVATE_TODAY")

            // Delete button (only on hover)
            if isHovered {
                Button(action: { deleteGoal(goal) }) {
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
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(goal.isCompleted ? categoryColor(category).opacity(0.1) : (isHovered ? CyberTheme.cardBackground : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    goal.isCompleted ? categoryColor(category).opacity(0.2) :
                    (goal.isFocusedToday ? CyberTheme.neonYellow.opacity(0.3) :
                    (isHovered ? CyberTheme.gridLine : Color.clear)),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredGoalId = hovering ? goal.id : nil
            }
        }
    }

    private func toggleGoal(_ goal: Goal) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dataService.toggleGoalCompletion(goal)
        }
    }

    private func toggleFocusToday(_ goal: Goal) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dataService.toggleFocusToday(goal)
        }
    }

    private func startEditing(_ goal: Goal) {
        editingGoal = goal
        editText = goal.unwrappedTitle
    }

    private func saveEdit() {
        if let goal = editingGoal, !editText.isEmpty {
            dataService.updateGoalTitle(goal, title: editText)
        }
        editingGoal = nil
    }

    private func deleteGoal(_ goal: Goal) {
        withAnimation(.easeOut(duration: 0.2)) {
            dataService.deleteGoal(goal)
        }
    }

    private func categoryColor(_ category: GoalCategory) -> Color {
        switch category {
        case .work: return CyberTheme.neonCyan
        case .health: return CyberTheme.matrixGreen
        case .personal: return CyberTheme.neonMagenta
        }
    }
}
