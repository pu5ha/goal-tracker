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

    func createGoal(title: String, category: GoalCategory, weekStart: Date? = nil) -> Goal {
        let goal = Goal(context: context)
        goal.id = UUID()
        goal.title = title
        goal.category = category.rawValue
        goal.isCompleted = false
        goal.weekStart = weekStart ?? weekService.currentWeekStart
        goal.createdAt = Date()
        save()
        return goal
    }

    func getGoals(for weekStart: Date) -> [Goal] {
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart == %@", weekStart as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Goal.category, ascending: true),
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
