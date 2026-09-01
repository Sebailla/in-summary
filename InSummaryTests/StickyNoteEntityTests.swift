//
//  StickyNoteEntityTests.swift
//  InSummaryTests
//
//  Verifies the canonical SwiftData defaults of `StickyNoteEntity` per the
//  approved local-only Phase 1 contract.
//

import XCTest
import SwiftData
@testable import InSummary

@MainActor
final class StickyNoteEntityTests: XCTestCase {

    func test_idIsAssignedOnConstruction() {
        XCTAssertNotNil(StickyNoteEntity().id)
    }

    func test_defaultTextIsEmptyString() {
        XCTAssertEqual(StickyNoteEntity().text, "")
    }

    func test_defaultColorThemeIsYellow() {
        XCTAssertEqual(StickyNoteEntity().colorTheme, "yellow",
                       "StickyNoteEntity.colorTheme must default to \"yellow\" per spec §3.1")
    }

    func test_defaultNormalizedPositionIsCenter() {
        let note = StickyNoteEntity()
        XCTAssertEqual(note.normalizedX, 0.5)
        XCTAssertEqual(note.normalizedY, 0.5)
    }

    func test_defaultSizeIsBaseFrame() {
        let note = StickyNoteEntity()
        XCTAssertEqual(note.width, 180.0)
        XCTAssertEqual(note.height, 140.0)
    }

    func test_defaultRotationAngleIsZero() {
        XCTAssertEqual(StickyNoteEntity().rotationAngle, 0.0)
    }

    func test_createdAtAndUpdatedAtAreSetOnConstruction() {
        let before = Date()
        let note = StickyNoteEntity()
        let after = Date()
        SchemaTestSupport.assertRecent(note.createdAt, before: before, after: after)
        SchemaTestSupport.assertRecent(note.updatedAt, before: before, after: after)
    }

    func test_defaultPageAnnotationRelationshipIsNil() {
        XCTAssertNil(StickyNoteEntity().pageAnnotation)
    }

    func test_stickyNoteIsInsertableAndRoundTripsThroughContainer() throws {
        let context = ModelContext(makeSchemaContainer())
        context.insert(StickyNoteEntity())
        try context.save()

        let notes = try context.fetch(FetchDescriptor<StickyNoteEntity>())
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.colorTheme, "yellow")
        XCTAssertEqual(notes.first?.width, 180.0)
        XCTAssertEqual(notes.first?.height, 140.0)
    }
}