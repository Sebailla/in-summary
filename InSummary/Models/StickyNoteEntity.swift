//
//  StickyNoteEntity.swift
//  InSummary
//
//  Canonical SwiftData entity representing a floating sticky note placed on a
//  document page. Phase 1 contract: no `@Attribute(.unique)`, optional
//  to-one relationship to `PageAnnotation`.
//

import Foundation
import SwiftData

/// A floating sticky note anchored to a document page.
///
/// The position is stored normalized to the page viewport (`0..1`) so the
/// note survives rotation, Split View, and font-size changes.
@Model
final class StickyNoteEntity {

    var id: UUID = UUID()

    /// User-entered text content. Empty until first edit.
    var text: String = ""

    /// Color theme discriminator. Canonical set per spec §3.1:
    /// `"yellow"` | `"pink"` | `"blue"` | `"green"`.
    /// Canonical default: `"yellow"`.
    var colorTheme: String = "yellow"

    /// Normalized 0..1 X in page viewport space. Canonical default: 0.5.
    var normalizedX: Double = 0.5

    /// Normalized 0..1 Y in page viewport space. Canonical default: 0.5.
    var normalizedY: Double = 0.5

    /// Base width in points. Canonical default: 180.0.
    var width: Double = 180.0

    /// Base height in points. Canonical default: 140.0.
    var height: Double = 140.0

    /// Aesthetic rotation in degrees, ±3.0. Canonical default: 0.0.
    var rotationAngle: Double = 0.0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var pageAnnotation: PageAnnotation?

    init() {}
}