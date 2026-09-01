//
//  FolderEntity.swift
//  InSummary
//
//  Canonical SwiftData entity representing a user-created folder that groups
//  documents in the local library. Phase 1 contract: no `@Attribute(.unique)`,
//  optional relationships only, default-empty array on the to-many side.
//

import Foundation
import SwiftData

/// A folder in the local library that groups `DocumentItem` records.
///
/// Phase 1 invariant: no `@Attribute(.unique)` is used; uniqueness of
/// `id` is provided by SwiftData's UUID generation at construction time.
@Model
final class FolderEntity {

    // MARK: - Identity & display

    /// Stable identifier; UUID is assigned at construction so cross-device
    /// identification is preserved for a future sync phase.
    var id: UUID = UUID()

    /// Display name shown in the library sidebar.
    /// Canonical default per spec §3.1: `"New Folder"`.
    var name: String = "New Folder"

    /// Hex color used to tint the folder in the library.
    /// Canonical default per spec §3.1: `"#5AC8FA"`.
    var colorHex: String = "#5AC8FA"

    /// Creation timestamp.
    var createdAt: Date = Date()

    // MARK: - Relationships

    /// Documents contained in this folder. Cascade-deleted when the folder
    /// is removed. The optional, empty-by-default relationship keeps the
    /// local data model simple to evolve.
    @Relationship(deleteRule: .cascade, inverse: \DocumentItem.folder)
    var documents: [DocumentItem]? = []

    // MARK: - Initialization

    init() {}
}