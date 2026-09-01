//
//  LibrarySeedService.swift
//  InSummary
//
//  Idempotent seed for the local library. Inserts exactly one seed
//  folder and one seed document against an empty library, and is a
//  no-op on every subsequent invocation.
//

import Foundation
import SwiftData

/// Seeds the local library with a single folder + document the first
/// time the app launches against an empty store.
///
/// The service is idempotent: every subsequent call observes the
/// existing seed and skips the insert.
enum LibrarySeedService {

    /// Seed content displayed in the local library shell.
    enum SeedContent {
        static let folderName = "Welcome"
        static let folderColorHex = "#5AC8FA"
        static let documentTitle = "Getting Started"
        static let documentFileTypeRaw = "pdf"
        static let documentFileExtension = "pdf"
    }

    /// Inserts the seed folder + seed document when the library is empty.
    ///
    /// - Parameter context: the model context in which the seed lives.
    /// - Throws: rethrows `ModelContext.save` failures.
    static func seedIfNeeded(in context: ModelContext) throws {
        // Idempotency guard: only seed when the library is empty.
        // Fetching documents is the cheapest invariant check; the spec
        // explicitly states "must not insert anything when the library
        // already has a document".
        var descriptor = FetchDescriptor<DocumentItem>()
        descriptor.fetchLimit = 1
        let existingDocuments = try context.fetch(descriptor)
        guard existingDocuments.isEmpty else {
            return
        }

        let folder = FolderEntity()
        folder.name = SeedContent.folderName
        folder.colorHex = SeedContent.folderColorHex

        let document = DocumentItem()
        document.title = SeedContent.documentTitle
        document.fileTypeRaw = SeedContent.documentFileTypeRaw
        document.fileExtension = SeedContent.documentFileExtension
        document.folder = folder

        context.insert(folder)
        context.insert(document)
        try context.save()
    }
}