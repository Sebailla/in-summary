//
//  PageAnnotation.swift
//  InSummary
//
//  Canonical SwiftData entity that anchors a single document page's
//  freeform ink drawing, semantic highlights, and sticky notes.
//  Phase 1 contract: optional relationships, no `@Attribute(.unique)`,
//  default-empty arrays on to-many sides. `drawingData` uses
//  `@Attribute(.externalStorage)` so PencilKit's binary payload is
//  stored out-of-row for predictable schema size.
//

import Foundation
import SwiftData

/// Anchors one page's annotations in the local library.
///
/// `drawingData` stores the PencilKit `PKDrawing.dataRepresentation()`
/// payload. Highlights and sticky notes are linked through their own
/// `pageAnnotation` to-one relationship so a single page change can
/// load all of its marks in one fetch.
@Model
final class PageAnnotation {

    var id: UUID = UUID()

    /// Display hint: the page index in PDF document space, or 0 for
    /// reflowable formats.
    var pageIndex: Int = 0

    /// PencilKit binary payload, stored out-of-row.
    @Attribute(.externalStorage)
    var drawingData: Data? = nil

    // MARK: - Relationships

    var document: DocumentItem?

    @Relationship(deleteRule: .cascade, inverse: \TextHighlight.pageAnnotation)
    var highlights: [TextHighlight]? = []

    @Relationship(deleteRule: .cascade, inverse: \StickyNoteEntity.pageAnnotation)
    var stickyNotes: [StickyNoteEntity]? = []

    init() {}
}