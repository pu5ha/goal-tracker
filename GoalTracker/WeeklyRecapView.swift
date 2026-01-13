import SwiftUI
import AppKit

struct WeeklyRecapView: View {
    let weekStart: Date
    @ObservedObject private var dataService = DataService.shared
    @State private var recap: WeeklyRecap?
    @State private var showingSaveConfirmation = false

    @State private var overviewText = ""
    @State private var winsText = ""
    @State private var challengesText = ""
    @State private var gratefulForText = ""
    @State private var songOfWeekText = ""
    @State private var lessonsText = ""
    @State private var nextWeekText = ""

    private let weekService = WeekService.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Card
                    headerCard

                    // Sections
                    recapSection(
                        title: "OVERVIEW",
                        icon: "doc.text",
                        color: CyberTheme.neonCyan,
                        placeholder: "// What did you accomplish this week? Give a brief summary...",
                        text: $overviewText
                    )

                    HStack(alignment: .top, spacing: 12) {
                        recapSection(
                            title: "WINS",
                            icon: "star",
                            color: CyberTheme.neonYellow,
                            placeholder: "// What went well? What are you proud of?",
                            text: $winsText
                        )

                        recapSection(
                            title: "CHALLENGES",
                            icon: "exclamationmark.triangle",
                            color: CyberTheme.neonMagenta,
                            placeholder: "// What obstacles did you face?",
                            text: $challengesText
                        )
                    }

                    HStack(alignment: .top, spacing: 12) {
                        recapSection(
                            title: "GRATEFUL_FOR",
                            icon: "heart",
                            color: CyberTheme.neonMagenta,
                            placeholder: "// What are you thankful for?",
                            text: $gratefulForText
                        )

                        recapSection(
                            title: "SONG_OF_WEEK",
                            icon: "music.note",
                            color: CyberTheme.neonCyan,
                            placeholder: "// What song defined your week?",
                            text: $songOfWeekText,
                            minHeight: 60
                        )
                    }

                    recapSection(
                        title: "LESSONS_LEARNED",
                        icon: "lightbulb",
                        color: CyberTheme.neonYellow,
                        placeholder: "// What did you learn? Any insights or realizations?",
                        text: $lessonsText
                    )

                    nextWeekSection

                    Spacer(minLength: 20)
                }
                .padding(20)
            }

            // Footer
            footerView
        }
        .background(CyberTheme.background)
        .onAppear(perform: loadRecap)
        .onChange(of: weekStart) { _ in
            saveRecap()
            loadRecap()
        }
    }

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("// WEEKLY_RECAP")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textSecondary)

                Text(weekService.formatWeekRange(for: weekStart).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.matrixGreen)
            }

            Spacer()

            if recap?.hasContent == true {
                HStack(spacing: 6) {
                    Circle()
                        .fill(CyberTheme.matrixGreen)
                        .frame(width: 8, height: 8)
                        .shadow(color: CyberTheme.matrixGreen.opacity(0.8), radius: 4, x: 0, y: 0)
                    Text("IN_PROGRESS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberTheme.matrixGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(CyberTheme.matrixGreen.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(CyberTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CyberTheme.matrixGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Button(action: saveRecap) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("SAVE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(CyberTheme.matrixGreen)
                .foregroundColor(CyberTheme.background)
                .cornerRadius(4)
                .shadow(color: CyberTheme.matrixGreen.opacity(0.5), radius: 6, x: 0, y: 0)
            }
            .buttonStyle(.plain)

            Button(action: exportRecap) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Text("EXPORT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(CyberTheme.cardBackground)
                .foregroundColor(CyberTheme.neonCyan)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(CyberTheme.neonCyan.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            if showingSaveConfirmation {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Text("SAVED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(CyberTheme.matrixGreen)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(CyberTheme.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(CyberTheme.matrixGreen.opacity(0.3)),
            alignment: .top
        )
    }

    private var nextWeekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(CyberTheme.matrixGreen)
                    .frame(width: 3, height: 12)
                    .shadow(color: CyberTheme.matrixGreen.opacity(0.8), radius: 4, x: 0, y: 0)

                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.matrixGreen)

                Text("NEXT_WEEK_FOCUS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)

                Spacer()

                if !nextWeekText.isEmpty {
                    Button {
                        convertToGoals()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                            Text("ADD_AS_GOALS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(CyberTheme.matrixGreen)
                        .foregroundColor(CyberTheme.background)
                        .cornerRadius(3)
                        .shadow(color: CyberTheme.matrixGreen.opacity(0.5), radius: 4, x: 0, y: 0)
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $nextWeekText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundColor(CyberTheme.textPrimary)
                    .padding(12)
                    .frame(minHeight: 100)

                if nextWeekText.isEmpty {
                    Text("// List your priorities for next week (one per line)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(CyberTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(CyberTheme.matrixGreen.opacity(0.3), lineWidth: 1)
            )

            Text("> TIP: Write each goal on a new line, then click 'ADD_AS_GOALS'")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(CyberTheme.textSecondary.opacity(0.6))
        }
    }

    private func convertToGoals() {
        let nextWeekStart = weekService.nextWeekStart(from: weekStart)
        let lines = nextWeekText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            _ = dataService.createGoal(title: line, category: .personal, weekStart: nextWeekStart)
        }

        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "GOALS_CREATED"
        alert.informativeText = "\(lines.count) objective(s) added to next week."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @ViewBuilder
    private func recapSection(
        title: String,
        icon: String,
        color: Color,
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 80
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 12)
                    .shadow(color: color.opacity(0.8), radius: 4, x: 0, y: 0)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundColor(CyberTheme.textPrimary)
                    .padding(12)
                    .frame(minHeight: minHeight)

                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CyberTheme.textSecondary.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(CyberTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func loadRecap() {
        recap = dataService.getOrCreateRecap(for: weekStart)
        overviewText = recap?.unwrappedOverview ?? ""
        winsText = recap?.unwrappedWins ?? ""
        challengesText = recap?.unwrappedChallenges ?? ""
        gratefulForText = recap?.unwrappedGratefulFor ?? ""
        songOfWeekText = recap?.unwrappedSongOfWeek ?? ""
        lessonsText = recap?.unwrappedLessons ?? ""
        nextWeekText = recap?.unwrappedNextWeekFocus ?? ""
    }

    private func saveRecap() {
        guard let recap = recap else { return }

        recap.overview = overviewText
        recap.wins = winsText
        recap.challenges = challengesText
        recap.gratefulFor = gratefulForText
        recap.songOfWeek = songOfWeekText
        recap.lessons = lessonsText
        recap.nextWeekFocus = nextWeekText
        recap.updatedAt = Date()

        let context = recap.managedObjectContext
        if context?.hasChanges == true {
            try? context?.save()

            withAnimation(.spring(response: 0.3)) {
                showingSaveConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSaveConfirmation = false
                }
            }
        }
    }

    private func exportRecap() {
        saveRecap()

        guard let recap = recap else { return }

        let weekRange = weekService.formatWeekRange(for: weekStart)
        let exportText = recap.formattedForExport(weekRange: weekRange)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(exportText, forType: .string)

        let alert = NSAlert()
        alert.messageText = "RECAP_EXPORTED"
        alert.informativeText = "Weekly recap copied to clipboard. Ready to share."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "OPEN_MESSAGES")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "imessage://") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
