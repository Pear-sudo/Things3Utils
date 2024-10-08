//
//  Things3UtilsApp.swift
//  Things3Utils
//
//  Created by A on 03/09/2024.
//

import SwiftUI
import SwiftData

@main
struct Things3UtilsApp: App {
    
    private var viewModel: ViewModel = .init()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(viewModel)
        
        Window("Submission", id: WindowID.submission.rawValue) {
            SubmissionView()
        }
        .environment(viewModel)
    }
}

enum WindowID: String, RawRepresentable {
    case submission
}
