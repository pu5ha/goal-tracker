import SwiftUI
import UniformTypeIdentifiers

struct WeeklyGoalsView: View {
    let weekStart: Date
    @ObservedObject private var dataService = DataService.shared
    @State private var editingGoal: Goal?
    @State private var editText = ""
    @State private var hoveredGoalId: UUID?
    @State private var showAddGoal = false
    @State private var addGoalCategory: GoalCategory = .personal
    @State private var expandedGoalIds: Set<UUID> = []
    @State private var editingNotesGoal: Goal?
    @State private var notesText = ""
    @State private var draggedGoal: Goal?

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
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(weekStart: weekStart, initialCategory: addGoalCategory)
        }
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

                // Add button for this category
                Button(action: {
                    addGoalCategory = category
                    showAddGoal = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(categoryColor(category))
                        .frame(width: 20, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(categoryColor(category).opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }

            if goals.isEmpty {
                Button(action: {
                    addGoalCategory = category
                    showAddGoal = true
                }) {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "plus.viewfinder")
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundColor(CyberTheme.dimGreen)
                            Text("ADD_OBJECTIVE")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(CyberTheme.textSecondary)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(goals, id: \.id) { goal in
                        goalRow(goal, category: category, allGoals: goals)
                            .onDrag {
                                self.draggedGoal = goal
                                return NSItemProvider(object: goal.id?.uuidString as NSString? ?? "" as NSString)
                            }
                            .onDrop(of: [.text], delegate: GoalDropDelegate(
                                goal: goal,
                                goals: goals,
                                draggedGoal: $draggedGoal,
                                dataService: dataService
                            ))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal, category: GoalCategory, allGoals: [Goal]) -> some View {
        let isHovered = hoveredGoalId == goal.id
        let isExpanded = expandedGoalIds.contains(goal.id ?? UUID())

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isHovered ? CyberTheme.textSecondary : CyberTheme.dimGreen)
                    .frame(width: 16)
                    .onHover { hovering in
                        if hovering { NSCursor.openHand.push() } else { NSCursor.pop() }
                    }

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
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                // Goal text
                VStack(alignment: .leading, spacing: 2) {
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
                }

                Spacer()

                // Notes indicator/button
                Button(action: { toggleExpanded(goal) }) {
                    Image(systemName: goal.hasNotes ? "note.text" : "note.text.badge.plus")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(goal.hasNotes ? CyberTheme.neonCyan : CyberTheme.textSecondary.opacity(0.5))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(goal.hasNotes ? "VIEW_NOTES" : "ADD_NOTES")
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

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
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

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
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            // Expandable notes section
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(CyberTheme.gridLine)
                        .frame(height: 1)
                        .padding(.horizontal, 10)

                    if editingNotesGoal?.id == goal.id {
                        // Editing notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("> NOTES:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberTheme.textSecondary)

                            TextEditor(text: $notesText)
                                .font(.system(size: 11, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .foregroundColor(CyberTheme.textPrimary)
                                .frame(minHeight: 60, maxHeight: 120)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(CyberTheme.background)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(CyberTheme.neonCyan.opacity(0.5), lineWidth: 1)
                                )

                            HStack {
                                Spacer()
                                Button(action: { cancelNotesEdit() }) {
                                    Text("[CANCEL]")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundColor(CyberTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }

                                Button(action: { saveNotes(goal) }) {
                                    Text("[SAVE]")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(CyberTheme.neonCyan)
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    } else if goal.hasNotes {
                        // Display notes
                        HStack(alignment: .top) {
                            Text(goal.unwrappedNotes)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(CyberTheme.textSecondary)
                                .lineLimit(nil)

                            Spacer()

                            Button(action: { startEditingNotes(goal) }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(CyberTheme.neonCyan.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    } else {
                        // No notes yet, show add prompt
                        Button(action: { startEditingNotes(goal) }) {
                            HStack {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                Text("ADD_NOTE")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(CyberTheme.textSecondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(goal.isCompleted ? categoryColor(category).opacity(0.1) : (isHovered || isExpanded ? CyberTheme.cardBackground : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    goal.isCompleted ? categoryColor(category).opacity(0.2) :
                    (goal.isFocusedToday ? CyberTheme.neonYellow.opacity(0.3) :
                    (isHovered || isExpanded ? CyberTheme.gridLine : Color.clear)),
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

    private func toggleExpanded(_ goal: Goal) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let id = goal.id {
                if expandedGoalIds.contains(id) {
                    expandedGoalIds.remove(id)
                    if editingNotesGoal?.id == id {
                        editingNotesGoal = nil
                    }
                } else {
                    expandedGoalIds.insert(id)
                }
            }
        }
    }

    private func startEditingNotes(_ goal: Goal) {
        editingNotesGoal = goal
        notesText = goal.unwrappedNotes
    }

    private func cancelNotesEdit() {
        editingNotesGoal = nil
        notesText = ""
    }

    private func saveNotes(_ goal: Goal) {
        dataService.updateGoalNotes(goal, notes: notesText)
        editingNotesGoal = nil
        notesText = ""
    }

    private func categoryColor(_ category: GoalCategory) -> Color {
        switch category {
        case .work: return CyberTheme.neonCyan
        case .health: return CyberTheme.matrixGreen
        case .personal: return CyberTheme.neonMagenta
        }
    }
}

// MARK: - Drag & Drop Delegate
struct GoalDropDelegate: DropDelegate {
    let goal: Goal
    let goals: [Goal]
    @Binding var draggedGoal: Goal?
    let dataService: DataService

    func performDrop(info: DropInfo) -> Bool {
        draggedGoal = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedGoal = draggedGoal,
              draggedGoal.id != goal.id,
              let fromIndex = goals.firstIndex(where: { $0.id == draggedGoal.id }),
              let toIndex = goals.firstIndex(where: { $0.id == goal.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            dataService.moveGoal(draggedGoal, from: fromIndex, to: toIndex, in: goals)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
