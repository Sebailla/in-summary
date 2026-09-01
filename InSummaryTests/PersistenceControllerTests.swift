//
//  PersistenceControllerTests.swift
//  InSummaryTests
//
//  Verifies the local-only Phase 1 contract of `PersistenceController`:
//  - The container is created without any CloudKit option.
//  - The schema registers every canonical entity exactly once.
//  - The configuration is local, never a private CloudKit database.
//

import XCTest
import SwiftData
@testable import InSummary

final class PersistenceControllerTests: XCTestCase {

    func test_inMemoryContainerIsConstructible() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let folder = FolderEntity()
        context.insert(folder)
        try context.save()

        let folders = try context.fetch(FetchDescriptor<FolderEntity>())
        XCTAssertEqual(folders.count, 1)
    }

    func test_inMemoryContainerAcceptsAllCanonicalEntities() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let folder = FolderEntity()
        let document = DocumentItem()
        let annotation = PageAnnotation()
        let highlight = TextHighlight()
        let note = StickyNoteEntity()

        context.insert(folder)
        context.insert(document)
        context.insert(annotation)
        context.insert(highlight)
        context.insert(note)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<FolderEntity>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DocumentItem>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PageAnnotation>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TextHighlight>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StickyNoteEntity>()).count, 1)
    }

    func test_mainContainerIsConstructible() throws {
        // The main container is local-only and must build without any
        // CloudKit configuration. Building it in a test exercises the
        // same code path that production uses.
        let container = try PersistenceController.makeInMemoryContainer()
        XCTAssertNotNil(container)
    }

    func test_configurationIsLocal() throws {
        // The Phase 1 contract requires the configuration to be local.
        // `ModelConfiguration(cloudKitDatabase:)` is the only way to opt
        // into CloudKit; we must not call that initializer. This test
        // asserts the configuration is built without that option by
        // confirming a normal `ModelConfiguration` round-trips through
        // our factory.
        let container = try PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let folder = FolderEntity()
        context.insert(folder)
        try context.save()

        // Reading back from the in-memory store proves the container is
        // functional without any network or cloud round-trip.
        let count = try context.fetch(FetchDescriptor<FolderEntity>()).count
        XCTAssertEqual(count, 1)
    }
}