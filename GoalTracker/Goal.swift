import Foundation
import CoreData
import SwiftUI

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
    @NSManaged public var notes: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var dueDate: Date?
}

// MARK: - Convenience Properties
extension Goal {
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

    var isFocusedToday: Bool {
        guard let focusDate = focusDate else { return false }
        return Calendar.current.isDateInToday(focusDate)
    }

    // MARK: - Due Date Properties
    var hasDueDate: Bool {
        dueDate != nil
    }

    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueTomorrow: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day
    }

    var dueDateStatus: DueDateStatus {
        guard hasDueDate else { return .noDueDate }
        if isCompleted { return .completed }
        if isOverdue { return .overdue }
        if isDueToday { return .dueToday }
        if isDueTomorrow { return .dueTomorrow }
        if let days = daysUntilDue, days <= 3 { return .dueSoon }
        return .upcoming
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

// MARK: - Due Date Status
enum DueDateStatus {
    case noDueDate
    case completed
    case overdue
    case dueToday
    case dueTomorrow
    case dueSoon      // Within 3 days
    case upcoming

    var badgeColor: Color {
        switch self {
        case .noDueDate, .completed, .upcoming: return .clear
        case .overdue: return CyberTheme.neonMagenta
        case .dueToday: return CyberTheme.neonYellow
        case .dueTomorrow: return CyberTheme.neonCyan
        case .dueSoon: return CyberTheme.matrixGreen
        }
    }

    var icon: String? {
        switch self {
        case .overdue: return "exclamationmark.triangle.fill"
        case .dueToday: return "clock.fill"
        case .dueTomorrow: return "clock"
        case .dueSoon: return "calendar.badge.clock"
        default: return nil
        }
    }
}
