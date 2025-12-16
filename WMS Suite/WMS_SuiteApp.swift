//
//  WMS_SuiteApp.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/6/25.
//

import SwiftUI
import CoreData  // This import should be present

@main
struct WMS_SuiteApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
