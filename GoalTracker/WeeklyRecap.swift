import Foundation
import CoreData

@objc(WeeklyRecap)
public class WeeklyRecap: NSManagedObject {

}

extension WeeklyRecap {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeeklyRecap> {
        return NSFetchRequest<WeeklyRecap>(entityName: "WeeklyRecap")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var weekStart: Date?
    @NSManaged public var overview: String?
    @NSManaged public var wins: String?
    @NSManaged public var challenges: String?
    @NSManaged public var gratefulFor: String?
    @NSManaged public var songOfWeek: String?
    @NSManaged public var lessons: String?
    @NSManaged public var nextWeekFocus: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

// MARK: - Convenience Properties
extension WeeklyRecap {
    var unwrappedOverview: String { overview ?? "" }
    var unwrappedWins: String { wins ?? "" }
    var unwrappedChallenges: String { challenges ?? "" }
    var unwrappedGratefulFor: String { gratefulFor ?? "" }
    var unwrappedSongOfWeek: String { songOfWeek ?? "" }
    var unwrappedLessons: String { lessons ?? "" }
    var unwrappedNextWeekFocus: String { nextWeekFocus ?? "" }

    var hasContent: Bool {
        !unwrappedOverview.isEmpty ||
        !unwrappedWins.isEmpty ||
        !unwrappedChallenges.isEmpty ||
        !unwrappedGratefulFor.isEmpty ||
        !unwrappedSongOfWeek.isEmpty ||
        !unwrappedLessons.isEmpty ||
        !unwrappedNextWeekFocus.isEmpty
    }

    func formattedForExport(weekRange: String) -> String {
        var output = "Weekly Recap - \(weekRange)\n"
        output += String(repeating: "=", count: 40) + "\n\n"

        if !unwrappedOverview.isEmpty {
            output += "OVERVIEW\n"
            output += unwrappedOverview + "\n\n"
        }

        if !unwrappedWins.isEmpty {
            output += "WINS\n"
            output += unwrappedWins + "\n\n"
        }

        if !unwrappedChallenges.isEmpty {
            output += "CHALLENGES\n"
            output += unwrappedChallenges + "\n\n"
        }

        if !unwrappedGratefulFor.isEmpty {
            output += "GRATEFUL FOR\n"
            output += unwrappedGratefulFor + "\n\n"
        }

        if !unwrappedSongOfWeek.isEmpty {
            output += "SONG OF THE WEEK\n"
            output += unwrappedSongOfWeek + "\n\n"
        }

        if !unwrappedLessons.isEmpty {
            output += "LESSONS LEARNED\n"
            output += unwrappedLessons + "\n\n"
        }

        if !unwrappedNextWeekFocus.isEmpty {
            output += "NEXT WEEK FOCUS\n"
            output += unwrappedNextWeekFocus + "\n\n"
        }

        return output
    }
}
