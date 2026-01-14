import Foundation
import CoreData
import Combine

class DataService: ObservableObject {
    static let shared = DataService()

    @Published var refreshTrigger = UUID()

    private let context: NSManagedObjectContext
    private let weekService = WeekService.shared

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Goal Operations

    func createGoal(title: String, category: GoalCategory, weekStart: Date? = nil, notes: String? = nil, dueDate: Date? = nil) -> Goal {
        let targetWeekStart = weekStart ?? weekService.currentWeekStart

        // Get the next sort order for this category
        let existingGoals = getGoalsByCategory(for: targetWeekStart)[category] ?? []
        let maxSortOrder = existingGoals.map { $0.sortOrder }.max() ?? -1

        let goal = Goal(context: context)
        goal.id = UUID()
        goal.title = title
        goal.category = category.rawValue
        goal.isCompleted = false
        goal.weekStart = targetWeekStart
        goal.createdAt = Date()
        goal.notes = notes
        goal.sortOrder = maxSortOrder + 1
        goal.dueDate = dueDate
        save()
        return goal
    }

    func getGoals(for weekStart: Date) -> [Goal] {
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart == %@", weekStart as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Goal.category, ascending: true),
            NSSortDescriptor(keyPath: \Goal.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Goal.createdAt, ascending: true)
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch goals: \(error)")
            return []
        }
    }

    func getGoalsByCategory(for weekStart: Date) -> [GoalCategory: [Goal]] {
        let goals = getGoals(for: weekStart)
        var grouped: [GoalCategory: [Goal]] = [:]

        for category in GoalCategory.allCases {
            grouped[category] = goals.filter { $0.goalCategory == category }
        }

        return grouped
    }

    func toggleGoalCompletion(_ goal: Goal) {
        goal.isCompleted.toggle()
        goal.completedAt = goal.isCompleted ? Date() : nil
        // Clear focus/active status when completing a goal
        if goal.isCompleted {
            goal.focusDate = nil
        }
        save()
    }

    func deleteGoal(_ goal: Goal) {
        context.delete(goal)
        save()
    }

    func updateGoalTitle(_ goal: Goal, title: String) {
        goal.title = title
        save()
    }

    func updateGoalNotes(_ goal: Goal, notes: String) {
        goal.notes = notes.isEmpty ? nil : notes
        save()
    }

    func reorderGoals(_ goals: [Goal], in category: GoalCategory) {
        for (index, goal) in goals.enumerated() {
            goal.sortOrder = Int16(index)
        }
        save()
    }

    func moveGoal(_ goal: Goal, from sourceIndex: Int, to destinationIndex: Int, in goals: [Goal]) {
        var mutableGoals = goals
        mutableGoals.remove(at: sourceIndex)
        mutableGoals.insert(goal, at: destinationIndex)

        for (index, g) in mutableGoals.enumerated() {
            g.sortOrder = Int16(index)
        }
        save()
    }

    func toggleFocusToday(_ goal: Goal) {
        if goal.isFocusedToday {
            goal.focusDate = nil
        } else {
            goal.focusDate = Date()
        }
        save()
    }

    func getTodaysFocusedGoals(for weekStart: Date) -> [Goal] {
        let goals = getGoals(for: weekStart)
        return goals.filter { $0.isFocusedToday && !$0.isCompleted }
    }

    // MARK: - Due Date Operations

    func updateDueDate(_ goal: Goal, dueDate: Date?) {
        goal.dueDate = dueDate
        save()
    }

    func clearDueDate(_ goal: Goal) {
        goal.dueDate = nil
        save()
    }

    func getGoalsDueToday(for weekStart: Date) -> [Goal] {
        let goals = getGoals(for: weekStart)
        return goals.filter { $0.isDueToday && !$0.isCompleted }
    }

    func getGoalsDueTomorrow(for weekStart: Date) -> [Goal] {
        let goals = getGoals(for: weekStart)
        return goals.filter { $0.isDueTomorrow && !$0.isCompleted }
    }

    func getOverdueGoals(for weekStart: Date) -> [Goal] {
        let goals = getGoals(for: weekStart)
        return goals.filter { $0.isOverdue }
    }

    func getAllGoalsDueToday() -> [Goal] {
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return []
        }

        request.predicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@ AND isCompleted == NO",
            startOfToday as NSDate,
            endOfToday as NSDate
        )

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch due today goals: \(error)")
            return []
        }
    }

    func getAllOverdueGoals() -> [Goal] {
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        let startOfToday = Calendar.current.startOfDay(for: Date())

        request.predicate = NSPredicate(
            format: "dueDate < %@ AND isCompleted == NO",
            startOfToday as NSDate
        )

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch overdue goals: \(error)")
            return []
        }
    }

    // MARK: - Weekly Recap Operations

    func getOrCreateRecap(for weekStart: Date) -> WeeklyRecap {
        let request: NSFetchRequest<WeeklyRecap> = WeeklyRecap.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart == %@", weekStart as NSDate)
        request.fetchLimit = 1

        do {
            if let existing = try context.fetch(request).first {
                return existing
            }
        } catch {
            print("Failed to fetch recap: \(error)")
        }

        let recap = WeeklyRecap(context: context)
        recap.id = UUID()
        recap.weekStart = weekStart
        recap.createdAt = Date()
        recap.updatedAt = Date()
        save()
        return recap
    }

    func updateRecap(_ recap: WeeklyRecap, wins: String?, challenges: String?, lessons: String?, nextWeekFocus: String?) {
        if let wins = wins { recap.wins = wins }
        if let challenges = challenges { recap.challenges = challenges }
        if let lessons = lessons { recap.lessons = lessons }
        if let nextWeekFocus = nextWeekFocus { recap.nextWeekFocus = nextWeekFocus }
        recap.updatedAt = Date()
        save()
    }

    // MARK: - Rollover Operations

    func performRollover() {
        let previousWeekStart = weekService.previousWeekStart(from: Date())
        let currentWeekStart = weekService.currentWeekStart

        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(
            format: "weekStart == %@ AND isCompleted == NO",
            previousWeekStart as NSDate
        )

        do {
            let incompleteGoals = try context.fetch(request)

            for goal in incompleteGoals {
                let newGoal = Goal(context: context)
                newGoal.id = UUID()
                newGoal.title = goal.title
                newGoal.category = goal.category
                newGoal.isCompleted = false
                newGoal.weekStart = currentWeekStart
                newGoal.createdAt = Date()
                newGoal.rolledOverFrom = goal.id
                newGoal.notes = goal.notes
                newGoal.sortOrder = goal.sortOrder
                newGoal.dueDate = goal.dueDate  // Preserve due date on rollover
            }

            save()
        } catch {
            print("Failed to perform rollover: \(error)")
        }
    }

    // MARK: - Statistics

    func getWeekStats(for weekStart: Date) -> (total: Int, completed: Int, byCategory: [GoalCategory: (total: Int, completed: Int)]) {
        let goals = getGoals(for: weekStart)
        let total = goals.count
        let completed = goals.filter { $0.isCompleted }.count

        var byCategory: [GoalCategory: (total: Int, completed: Int)] = [:]
        for category in GoalCategory.allCases {
            let categoryGoals = goals.filter { $0.goalCategory == category }
            byCategory[category] = (categoryGoals.count, categoryGoals.filter { $0.isCompleted }.count)
        }

        return (total, completed, byCategory)
    }

    // MARK: - Archive Operations

    func archiveCompletedGoals(completedBefore date: Date) {
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(
            format: "isCompleted == YES AND completedAt < %@",
            date as NSDate
        )

        do {
            let completedGoals = try context.fetch(request)

            for goal in completedGoals {
                // Create archived copy
                let archived = ArchivedGoal(context: context)
                archived.id = UUID()
                archived.originalGoalId = goal.id
                archived.title = goal.title
                archived.category = goal.category
                archived.notes = goal.notes
                archived.weekStart = goal.weekStart
                archived.createdAt = goal.createdAt
                archived.completedAt = goal.completedAt
                archived.dueDate = goal.dueDate
                archived.archivedAt = Date()

                // Delete original goal
                context.delete(goal)
            }

            if !completedGoals.isEmpty {
                save()
                print("Archived \(completedGoals.count) completed goal(s)")
            }
        } catch {
            print("Failed to archive completed goals: \(error)")
        }
    }

    func archiveGoalsCompletedBeforeToday() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        archiveCompletedGoals(completedBefore: startOfToday)
    }

    func getArchivedGoals() -> [ArchivedGoal] {
        let request: NSFetchRequest<ArchivedGoal> = ArchivedGoal.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ArchivedGoal.completedAt, ascending: false)
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch archived goals: \(error)")
            return []
        }
    }

    func getArchivedGoalsByWeek() -> [Date: [ArchivedGoal]] {
        let archived = getArchivedGoals()
        var grouped: [Date: [ArchivedGoal]] = [:]

        for goal in archived {
            let weekStart = goal.weekStart ?? Date.distantPast
            if grouped[weekStart] == nil {
                grouped[weekStart] = []
            }
            grouped[weekStart]?.append(goal)
        }

        return grouped
    }

    func deleteArchivedGoal(_ goal: ArchivedGoal) {
        context.delete(goal)
        save()
    }

    func clearAllArchivedGoals() {
        let request: NSFetchRequest<ArchivedGoal> = ArchivedGoal.fetchRequest()

        do {
            let archived = try context.fetch(request)
            for goal in archived {
                context.delete(goal)
            }
            save()
        } catch {
            print("Failed to clear archived goals: \(error)")
        }
    }

    // MARK: - Core Data

    func save() {
        if context.hasChanges {
            do {
                try context.save()
                DispatchQueue.main.async {
                    self.refreshTrigger = UUID()
                }
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}
