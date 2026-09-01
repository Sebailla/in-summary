//
//  PageAnnotationTests.swift
//  InSummaryTests
//
//  Verifies the canonical SwiftData defaults of `PageAnnotation` per the
//  approved local-only Phase 1 contract.
//

import XCTest
import SwiftData
@testable import InSummary

@MainActor
final class PageAnnotationTests: XCTestCase {

    func test_idIsAssignedOnConstruction() {
        XCTAssertNotNil(PageAnnotation().id)
    }

    func test_defaultPageIndexIsZero() {
        XCTAssertEqual(PageAnnotation().pageIndex, 0)
    }

    func test_defaultDrawingDataIsNil() {
        XCTAssertNil(PageAnnotation().drawingData,
                     "PageAnnotation.drawingData must default to nil (no PencilKit ink persisted yet)")
    }

    func test_defaultHighlightsArrayIsEmpty() {
        let annotation = PageAnnotation()
        XCTAssertNotNil(annotation.highlights)
        XCTAssertEqual(annotation.highlights?.count, 0)
    }

    func test_defaultStickyNotesArrayIsEmpty() {
        let annotation = PageAnnotation()
        XCTAssertNotNil(annotation.stickyNotes)
        XCTAssertEqual(annotation.stickyNotes?.count, 0)
    }

    func test_defaultDocumentRelationshipIsNil() {
        XCTAssertNil(PageAnnotation().document)
    }

    func test_pageAnnotationIsInsertableAndRoundTripsThroughContainer() throws {
        let context = ModelContext(makeSchemaContainer())
        context.insert(PageAnnotation())
        try context.save()

        let annotations = try context.fetch(FetchDescriptor<PageAnnotation>())
        XCTAssertEqual(annotations.count, 1)
        XCTAssertEqual(annotations.first?.pageIndex, 0)
        XCTAssertNil(annotations.first?.drawingData)
    }
}