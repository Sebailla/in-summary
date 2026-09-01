//
//  InSummaryApp.swift
//  InSummary
//
//  Application entry point. Phase 1 wires the local ModelContainer into the
//  SwiftUI environment and presents the minimal accessible library shell.
//

import SwiftUI
import SwiftData

@main
struct InSummaryApp: App {

    /// Local-only SwiftData container for the canonical schema.
    private let container: ModelContainer

    init() {
        do {
            self.container = try PersistenceController.makeMainContainer()
        } catch {
            // Phase 1 contract: a failed local bootstrap is a fatal
            // configuration error; we surface it immediately rather
            // than degrade to an empty shell that hides the bug.
            fatalError("Failed to initialize local SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryGridView()
                .task {
                    // Seed the local library exactly once, at first launch.
                    try? LibrarySeedService.seedIfNeeded(in: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}