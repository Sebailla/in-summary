//
//  TextHighlightTests.swift
//  InSummaryTests
//
//  Verifies the canonical SwiftData defaults of `TextHighlight` per the
//  approved local-only Phase 1 contract.
//

import XCTest
import SwiftData
@testable import InSummary

@MainActor
final class TextHighlightTests: XCTestCase {

    func test_idIsAssignedOnConstruction() {
        XCTAssertNotNil(TextHighlight().id)
    }

    func test_defaultColorHexMatchesTheCanonicalYellow() {
        XCTAssertEqual(TextHighlight().colorHex, "#FFEB3B",
                       "TextHighlight.colorHex must default to \"#FFEB3B\" per spec §3.1")
    }

    func test_defaultSelectedTextIsEmptyString() {
        XCTAssertEqual(TextHighlight().selectedText, "")
    }

    func test_defaultAnchorPayloadIsEmptyData() {
        XCTAssertEqual(TextHighlight().anchorPayload, Data())
    }

    func test_defaultAnchorFormatRawIsPDF() {
        XCTAssertEqual(TextHighlight().anchorFormatRaw, "pdf",
                       "TextHighlight.anchorFormatRaw must default to \"pdf\" per spec §3.1")
    }

    func test_createdAtAndUpdatedAtAreSetOnConstruction() {
        let before = Date()
        let highlight = TextHighlight()
        let after = Date()
        SchemaTestSupport.assertRecent(highlight.createdAt, before: before, after: after)
        SchemaTestSupport.assertRecent(highlight.updatedAt, before: before, after: after)
    }

    func test_defaultPageAnnotationRelationshipIsNil() {
        XCTAssertNil(TextHighlight().pageAnnotation)
    }

    func test_textHighlightIsInsertableAndRoundTripsThroughContainer() throws {
        let context = ModelContext(makeSchemaContainer())
        context.insert(TextHighlight())
        try context.save()

        let highlights = try context.fetch(FetchDescriptor<TextHighlight>())
        XCTAssertEqual(highlights.count, 1)
        XCTAssertEqual(highlights.first?.colorHex, "#FFEB3B")
        XCTAssertEqual(highlights.first?.anchorFormatRaw, "pdf")
    }
}