import Foundation
import CoreData

@objc(Goal)
public class Goal: NSManagedObject {

}

extension Goal {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Goal> {
        return NSFetchRequest<Goal>(entityName: "Goal")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var category: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var weekStart: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var rolledOverFrom: UUID?
    @NSManaged public var focusDate: Date?
}

// MARK: - Convenience Properties
extension Goal {
    var unwrappedTitle: String {
        title ?? ""
    }

    var unwrappedCategory: String {
        category ?? "Personal"
    }

    var goalCategory: GoalCategory {
        GoalCategory(rawValue: category ?? "Personal") ?? .personal
    }

    var isFocusedToday: Bool {
        guard let focusDate = focusDate else { return false }
        return Calendar.current.isDateInToday(focusDate)
    }
}

// MARK: - Goal Category
enum GoalCategory: String, CaseIterable, Identifiable {
    case work = "Work"
    case health = "Health"
    case personal = "Personal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .health: return "heart.fill"
        case .personal: return "person.fill"
        }
    }

    var color: String {
        switch self {
        case .work: return "blue"
        case .health: return "green"
        case .personal: return "purple"
        }
    }
}
