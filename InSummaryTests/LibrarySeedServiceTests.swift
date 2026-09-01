//
//  LibrarySeedServiceTests.swift
//  InSummaryTests
//
//  Verifies that `LibrarySeedService` is idempotent and produces a single
//  seed folder with a single seed document, regardless of how many times
//  it is invoked against the same container.
//

import XCTest
import SwiftData
@testable import InSummary

@MainActor
final class LibrarySeedServiceTests: XCTestCase {

    private func makeContainer() -> ModelContainer {
        let schema = Schema([
            FolderEntity.self,
            DocumentItem.self,
            PageAnnotation.self,
            TextHighlight.self,
            StickyNoteEntity.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_unwrapping
        return try! ModelContainer(for: schema, configurations: configuration)
    }

    func test_seedOnEmptyContainerCreatesExactlyOneFolder() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        try LibrarySeedService.seedIfNeeded(in: context)

        let folders = try context.fetch(FetchDescriptor<FolderEntity>())
        XCTAssertEqual(folders.count, 1,
                       "First seed against an empty library must create exactly one seed folder")
    }

    func test_seedOnEmptyContainerCreatesExactlyOneDocument() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        try LibrarySeedService.seedIfNeeded(in: context)

        let documents = try context.fetch(FetchDescriptor<DocumentItem>())
        XCTAssertEqual(documents.count, 1,
                       "First seed against an empty library must create exactly one seed document")
    }

    func test_seedDocumentBelongsToSeedFolder() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        try LibrarySeedService.seedIfNeeded(in: context)

        let folder = try XCTUnwrap(
            try context.fetch(FetchDescriptor<FolderEntity>()).first
        )
        let document = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DocumentItem>()).first
        )
        XCTAssertNotNil(document.folder)
        XCTAssertEqual(document.folder?.id, folder.id,
                       "The seed document must belong to the seed folder via the folder relationship")
    }

    func test_seedIsIdempotentAcrossRepeatedInvocations() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        try LibrarySeedService.seedIfNeeded(in: context)
        try LibrarySeedService.seedIfNeeded(in: context)
        try LibrarySeedService.seedIfNeeded(in: context)

        let folders = try context.fetch(FetchDescriptor<FolderEntity>())
        let documents = try context.fetch(FetchDescriptor<DocumentItem>())
        XCTAssertEqual(folders.count, 1,
                       "Repeated seeding must remain idempotent (one folder)")
        XCTAssertEqual(documents.count, 1,
                       "Repeated seeding must remain idempotent (one document)")
    }

    func test_seedDoesNotInsertWhenAnyDocumentAlreadyExists() throws {
        let container = makeContainer()
        let context = ModelContext(container)

        // Pre-seed an unrelated document so the library is "non-empty".
        let existing = DocumentItem()
        existing.title = "Pre-existing"
        existing.fileTypeRaw = "pdf"
        existing.fileExtension = "pdf"
        context.insert(existing)
        try context.save()

        try LibrarySeedService.seedIfNeeded(in: context)

        let documents = try context.fetch(FetchDescriptor<DocumentItem>())
        XCTAssertEqual(documents.count, 1,
                       "Seeding must not insert anything when the library already has a document")
        XCTAssertEqual(documents.first?.title, "Pre-existing",
                       "The pre-existing document must be the one that remains")
    }

    func test_seedIsIdempotentAcrossSeparateModelContexts() throws {
        let container = makeContainer()

        try LibrarySeedService.seedIfNeeded(in: ModelContext(container))
        try LibrarySeedService.seedIfNeeded(in: ModelContext(container))

        let documents = try container.mainContext.fetch(FetchDescriptor<DocumentItem>())
        XCTAssertEqual(documents.count, 1)
    }
}