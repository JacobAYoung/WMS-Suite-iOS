//
//  WMS_SuiteApp.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/6/25.
//

import SwiftUI

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
