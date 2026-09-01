//
//  PersistenceController.swift
//  InSummary
//
//  Local-only SwiftData container bootstrap. Phase 1 persists data only on
//  the device and has no remote-storage configuration.
//

import Foundation
import SwiftData

/// Owns the canonical `ModelContainer` for the application.
///
/// v1 is local-first: all persistence happens in the device sandbox.
enum PersistenceController {

    /// Canonical schema shared by every container built in v1.
    static let schema = Schema([
        FolderEntity.self,
        DocumentItem.self,
        PageAnnotation.self,
        TextHighlight.self,
        StickyNoteEntity.self
    ])

    /// Builds an in-memory container for tests and previews.
    ///
    /// - Throws: rethrows `ModelContainer` initialization failures.
    /// - Returns: a local container with the canonical schema.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Builds the main on-disk container for the application.
    ///
    /// Phase 1 persists the canonical schema on the local device.
    static func makeMainContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration()
        return try ModelContainer(for: schema, configurations: configuration)
    }
}