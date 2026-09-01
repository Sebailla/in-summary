//
//  DocumentItem.swift
//  InSummary
//
//  Canonical SwiftData entity representing a single imported document in the
//  local library. Phase 1 contract: no `@Attribute(.unique)`, optional
//  relationships only, a default-empty array on the to-many side, and the
//  canonical `paginationModeRaw` field defaulted to "horizontal". Future
//  synchronization storage ships through its own explicit migration.
//

import Foundation
import SwiftData

/// A document in the local library.
///
/// Phase 1 invariants:
/// - No `@Attribute(.unique)` is used; uniqueness is enforced at the
///   application layer on insert.
/// - `paginationModeRaw` is the canonical field that records the reader's
///   persisted pagination preference ("horizontal" | "vertical").
@Model
final class DocumentItem {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Display & file metadata

    /// Reader-facing title. Empty until import logic populates it.
    var title: String = ""

    /// Format discriminator: "pdf" | "epub" | "md".
    /// Canonical default per spec §3.1: `"pdf"`.
    var fileTypeRaw: String = "pdf"

    /// Lowercase extension without a leading dot.
    /// Canonical default per spec §3.1: `"pdf"`.
    var fileExtension: String = "pdf"

    /// Sandbox-relative file name in the form `<UUID>.<ext>`.
    /// Populated at import time; empty at construction.
    var localFileName: String = ""

    /// Original file size in bytes.
    var fileSize: Int64 = 0

    /// SHA-256 hex of the original file bytes. Reserved for content-drift
    /// detection when sync is reintroduced. Empty until import.
    var contentHash: String = ""

    // MARK: - Reading progress

    /// Stable, format-specific locator serialized as JSON.
    var lastReadLocator: Data = Data()

    /// Display hint only — see spec §3.4. Stable locators cannot be
    /// reduced to a single integer for reflowable formats.
    var lastReadPageIndex: Int = 0

    /// Display hint for reflowable formats.
    var totalPages: Int = 1

    /// Pagination preference persisted per document. Canonical values:
    /// `"horizontal"` | `"vertical"`. Canonical default: `"horizontal"`.
    var paginationModeRaw: String = "horizontal"

    // MARK: - Bookkeeping

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships

    /// Optional parent folder.
    var folder: FolderEntity?

    /// Page annotations belonging to this document. Cascade-deleted when
    /// the document is removed.
    @Relationship(deleteRule: .cascade, inverse: \PageAnnotation.document)
    var annotations: [PageAnnotation]? = []

    // MARK: - Initialization

    init() {}
}