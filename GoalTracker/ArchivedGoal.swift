import Foundation
import CoreData

@objc(ArchivedGoal)
public class ArchivedGoal: NSManagedObject {

}

extension ArchivedGoal {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ArchivedGoal> {
        return NSFetchRequest<ArchivedGoal>(entityName: "ArchivedGoal")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var originalGoalId: UUID?
    @NSManaged public var title: String?
    @NSManaged public var category: String?
    @NSManaged public var notes: String?
    @NSManaged public var weekStart: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var archivedAt: Date?
}

// MARK: - Convenience Properties
extension ArchivedGoal {
    var unwrappedTitle: String {
        title ?? ""
    }

    var unwrappedCategory: String {
        category ?? "Personal"
    }

    var unwrappedNotes: String {
        notes ?? ""
    }

    var hasNotes: Bool {
        !(notes ?? "").isEmpty
    }

    var goalCategory: GoalCategory {
        GoalCategory(rawValue: category ?? "Personal") ?? .personal
    }

    var formattedCompletedDate: String {
        guard let completedAt = completedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: completedAt)
    }

    var formattedWeek: String {
        guard let weekStart = weekStart else { return "" }
        return WeekService.shared.formatWeekRange(for: weekStart)
    }
}
