import SwiftUI

struct AddGoalSheet: View {
    let weekStart: Date
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataService = DataService.shared

    @State private var title = ""
    @State private var selectedCategory: GoalCategory = .personal
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("// NEW_OBJECTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                    Text("Add a goal for this week")
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
                    .foregroundColor(CyberTheme.matrixGreen.opacity(0.3)),
                alignment: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Goal Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("> ENTER_OBJECTIVE:")
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
                                .stroke(isTitleFocused ? CyberTheme.matrixGreen : CyberTheme.gridLine, lineWidth: isTitleFocused ? 2 : 1)
                        )
                        .shadow(color: isTitleFocused ? CyberTheme.matrixGreen.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 0)
                        .focused($isTitleFocused)
                }

                // Category Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("> SELECT_CATEGORY:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)

                    HStack(spacing: 10) {
                        ForEach(GoalCategory.allCases) { category in
                            categoryButton(category)
                        }
                    }
                }

                // Week Info
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                    Text("WEEK: \(WeekService.shared.formatWeekRange(for: weekStart).uppercased())")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary)
                }
                .padding(.top, 8)
            }
            .padding(20)

            Spacer()

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

                Button(action: addGoal) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text("ADD_OBJECTIVE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(title.isEmpty ? CyberTheme.dimGreen : CyberTheme.matrixGreen)
                    .foregroundColor(title.isEmpty ? CyberTheme.textSecondary : CyberTheme.background)
                    .cornerRadius(4)
                    .shadow(color: title.isEmpty ? Color.clear : CyberTheme.matrixGreen.opacity(0.5), radius: 6, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
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
        .frame(width: 450, height: 400)
        .background(CyberTheme.background)
        .onAppear {
            isTitleFocused = true
        }
    }

    @ViewBuilder
    private func categoryButton(_ category: GoalCategory) -> some View {
        let isSelected = selectedCategory == category
        let color = categoryColor(category)

        Button(action: { selectedCategory = category }) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(category.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? color : Color.clear)
            )
            .foregroundColor(isSelected ? CyberTheme.background : CyberTheme.textSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.clear : CyberTheme.gridLine, lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    private func categoryColor(_ category: GoalCategory) -> Color {
        switch category {
        case .work: return CyberTheme.neonCyan
        case .health: return CyberTheme.matrixGreen
        case .personal: return CyberTheme.neonMagenta
        }
    }

    private func addGoal() {
        guard !title.isEmpty else { return }
        _ = dataService.createGoal(title: title, category: selectedCategory, weekStart: weekStart)
        dismiss()
    }
}
