//
//  FolderEntityTests.swift
//  InSummaryTests
//
//  Verifies the canonical SwiftData defaults and structural invariants of
//  `FolderEntity` per the approved local-only Phase 1 contract.
//

import XCTest
import SwiftData
@testable import InSummary

@MainActor
final class FolderEntityTests: XCTestCase {

    func test_idIsAssignedOnConstruction() {
        XCTAssertNotNil(FolderEntity().id)
    }

    func test_defaultNameIsNewFolder() {
        XCTAssertEqual(FolderEntity().name, "New Folder",
                       "FolderEntity.name must default to \"New Folder\" per spec §3.1")
    }

    func test_defaultColorHexMatchesTheSystemBlueAccent() {
        XCTAssertEqual(FolderEntity().colorHex, "#5AC8FA",
                       "FolderEntity.colorHex must default to \"#5AC8FA\" per spec §3.1")
    }

    func test_defaultCreatedAtIsRecent() {
        let before = Date()
        let folder = FolderEntity()
        let after = Date()
        SchemaTestSupport.assertRecent(folder.createdAt, before: before, after: after)
    }

    func test_documentsDefaultsToEmptyArrayNotNil() {
        let folder = FolderEntity()
        XCTAssertNotNil(folder.documents,
                        "FolderEntity.documents must default to an empty array (not nil) so the relationship is CloudKit-compatible")
        XCTAssertEqual(folder.documents?.count, 0)
    }

    func test_folderIsInsertableAndRoundTripsThroughContainer() throws {
        let context = ModelContext(makeSchemaContainer())
        context.insert(FolderEntity())
        try context.save()

        let folders = try context.fetch(FetchDescriptor<FolderEntity>())
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "New Folder")
        XCTAssertEqual(folders.first?.documents?.count, 0)
    }
}