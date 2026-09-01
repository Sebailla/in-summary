//
//  TextHighlight.swift
//  InSummary
//
//  Canonical SwiftData entity that records a semantic text highlight on a
//  page. Phase 1 contract: no `@Attribute(.unique)`, optional to-one
//  relationship to `PageAnnotation`.
//

import Foundation
import SwiftData

/// A semantic highlight on a document page.
///
/// `anchorPayload` carries the format-specific stable locator
/// (PDF: normalized rects; MD: NSRange + blockPath; EPUB: CFI) serialized
/// as JSON inside `Data`. `anchorFormatRaw` is the discriminator.
@Model
final class TextHighlight {

    var id: UUID = UUID()

    /// Canonical default per spec §3.1: `"#FFEB3B"`.
    var colorHex: String = "#FFEB3B"

    /// The highlighted text snippet, captured for context and search.
    var selectedText: String = ""

    /// Format-specific locator encoded as JSON. Empty until capture.
    var anchorPayload: Data = Data()

    /// Format discriminator: `"pdf"` | `"markdown"` | `"epub"`.
    /// Canonical default per spec §3.1: `"pdf"`.
    var anchorFormatRaw: String = "pdf"

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var pageAnnotation: PageAnnotation?

    init() {}
}