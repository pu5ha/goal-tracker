//
//  GoalTrackerApp.swift
//  GoalTracker
//
//  Created by Jason Chaskin on 1/13/26.
//

import SwiftUI
import CoreData

@main
struct GoalTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
