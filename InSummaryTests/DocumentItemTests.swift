//
//  DocumentItemTests.swift
//  InSummaryTests
//
//  Verifies the canonical SwiftData defaults of `DocumentItem` per the
//  approved local-only Phase 1 contract, including the absence of any
//  `contentCKAsset` field and the canonical `paginationModeRaw` default.
//

import XCTest
import SwiftData
@testable import InSummary

@MainActor
final class DocumentItemTests: XCTestCase {

    func test_idIsAssignedOnConstruction() {
        XCTAssertNotNil(DocumentItem().id)
    }

    func test_defaultTitleIsEmptyString() {
        XCTAssertEqual(DocumentItem().title, "")
    }

    func test_defaultFileTypeRawIsPDF() {
        XCTAssertEqual(DocumentItem().fileTypeRaw, "pdf",
                       "DocumentItem.fileTypeRaw must default to \"pdf\" per spec §3.1")
    }

    func test_defaultFileExtensionIsPDF() {
        XCTAssertEqual(DocumentItem().fileExtension, "pdf",
                       "DocumentItem.fileExtension must default to \"pdf\" (lowercase, no dot)")
    }

    func test_defaultLocalFileNameIsEmptyString() {
        XCTAssertEqual(DocumentItem().localFileName, "",
                       "DocumentItem.localFileName must default to an empty string and be populated at import time")
    }

    func test_defaultFileSizeIsZero() {
        XCTAssertEqual(DocumentItem().fileSize, 0)
    }

    func test_defaultContentHashIsEmptyString() {
        XCTAssertEqual(DocumentItem().contentHash, "")
    }

    func test_defaultLastReadLocatorIsEmptyData() {
        XCTAssertEqual(DocumentItem().lastReadLocator, Data())
    }

    func test_defaultLastReadPageIndexIsZero() {
        XCTAssertEqual(DocumentItem().lastReadPageIndex, 0)
    }

    func test_defaultTotalPagesIsOne() {
        XCTAssertEqual(DocumentItem().totalPages, 1,
                       "DocumentItem.totalPages must default to 1 (display hint for reflowable)")
    }

    func test_paginationModeRawDefaultsToHorizontal() {
        XCTAssertEqual(DocumentItem().paginationModeRaw, "horizontal",
                       "DocumentItem.paginationModeRaw must default to \"horizontal\" per the approved Phase 1 contract")
    }

    func test_createdAtAndUpdatedAtAreSetOnConstruction() {
        let before = Date()
        let document = DocumentItem()
        let after = Date()
        SchemaTestSupport.assertRecent(document.createdAt, before: before, after: after)
        SchemaTestSupport.assertRecent(document.updatedAt, before: before, after: after)
    }

    func test_folderRelationshipDefaultsToNil() {
        XCTAssertNil(DocumentItem().folder,
                     "DocumentItem.folder must default to nil so the relationship is optional and CloudKit-compatible")
    }

    func test_annotationsRelationshipDefaultsToEmptyArray() {
        let document = DocumentItem()
        XCTAssertNotNil(document.annotations)
        XCTAssertEqual(document.annotations?.count, 0)
    }

    func test_documentIsInsertableAndRoundTripsThroughContainer() throws {
        let context = ModelContext(makeSchemaContainer())
        context.insert(DocumentItem())
        try context.save()

        let documents = try context.fetch(FetchDescriptor<DocumentItem>())
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents.first?.fileTypeRaw, "pdf")
        XCTAssertEqual(documents.first?.paginationModeRaw, "horizontal")
        XCTAssertEqual(documents.first?.totalPages, 1)
        XCTAssertEqual(documents.first?.annotations?.count, 0)
    }

    func test_noContentCKAssetFieldIsExposedInV1Schema() throws {
        // The local-only Phase 1 contract excludes `contentCKAsset`. Mirror this
        // expectation at the persistence boundary by ensuring no field matching
        // that name is reachable through SwiftData reflection.
        let context = ModelContext(makeSchemaContainer())
        let document = DocumentItem()
        context.insert(document)
        try context.save()

        let mirror = Mirror(reflecting: document)
        let childLabels = mirror.children.compactMap { $0.label }
        XCTAssertFalse(childLabels.contains("contentCKAsset"),
                       "DocumentItem must NOT expose a contentCKAsset field in v1 (deferred to a future sync phase)")
    }
}