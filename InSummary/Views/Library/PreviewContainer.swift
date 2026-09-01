//
//  PreviewContainer.swift
//  InSummary
//
//  Builds an in-memory SwiftData container pre-populated with the
//  canonical seed folder and document so SwiftUI previews and tests
//  have something meaningful to render.
//

import Foundation
import SwiftData

/// Test/preview-only SwiftData bootstrap.
enum PreviewContainer {

    /// An in-memory container pre-seeded with the canonical entities.
    static var previewContainer: ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        // swiftlint:disable:next force_try
        try! LibrarySeedService.seedIfNeeded(in: context)
        return container
    }
}