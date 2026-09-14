//
//  PDFReaderError.swift
//  InSummary
//
//  Typed error surface for the Phase 2 PDF reader (child PR #2 —
//  `feat/pdf-engine`). The cases enumerated here are the only errors the
//  `PDFReaderCoordinator` is permitted to throw at its public boundary;
//  the recoverable-error banner mounted by `ReaderContainerView`
//  (child PR #4) is expected to pattern-match on these cases verbatim.
//
//  Phase 2 invariants this file honours:
//
//  - Local-only access. The cases below describe *local* refusal reasons
//    (a missing or unreadable bundled resource, a `DocumentItem` row
//    that the bundled seed cannot satisfy, a SwiftData save failure when
//    persisting the pagination preference). No HTTP, no `URLError`, no
//    cloud-backed SwiftData store error, no `CKError`.
//  - No `PencilKit` import. The PDF reader surface is independent of the
//    annotation overlay; the coordinator does not introduce a
//    `PKDrawing` or `PKCanvasView` symbol.
//  - No public `SwiftData` model import. `paginationSaveFailed(underlying:)`
//    wraps the underlying `Error` verbatim so the crash-log path can
//    capture the original cause; it does not expose a typed
//    `ModelContext` failure.
//

import Foundation

/// Errors thrown by the Phase 2 PDF reader at its public boundary.
///
/// The cases encode the exact refusal reasons documented in
/// `openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pdf-engine/spec.md`:
/// a missing bundle resource, an unreadable bundle byte stream, a
/// `DocumentItem` row the reader cannot open, and a SwiftData save
/// failure when persisting the pagination preference. Every case
/// carries the minimum context the recoverable-error banner needs to
/// describe the refusal to the user.
enum PDFReaderError: Error {

    /// The requested bundle resource could not be located. The associated
    /// value is the resource name the caller asked for, so the
    /// recoverable-error banner can name the missing asset verbatim.
    ///
    /// Spec reference: "Missing bundled fixture" — the coordinator SHALL
    /// throw `PDFReaderError.fixtureMissing(resource: "sample-bundle")`
    /// when the app bundle does not contain the requested resource.
    case fixtureMissing(resource: String)

    /// The bundle contained the requested resource but its bytes do not
    /// parse into a `PDFDocument`. The reader surface must show a
    /// recoverable error rather than presenting an empty `PDFView`.
    ///
    /// Spec reference: "Unreadable bundled fixture" — the coordinator
    /// SHALL throw `PDFReaderError.fixtureUnreadable` when the bundle
    /// bytes fail to parse through `PDFKit`.
    case fixtureUnreadable

    /// The `DocumentItem` row is not a PDF the Phase 2 reader can open.
    /// Typical reasons: `fileTypeRaw != "pdf"`, or `localFileName` is
    /// non-empty (i.e. the row points at a sandbox file rather than the
    /// bundled seed). The associated value is a non-empty human-readable
    /// reason the banner can render verbatim.
    ///
    /// Spec reference: "Unsupported document row" — the coordinator
    /// SHALL throw `PDFReaderError.unsupportedDocument(reason:)` when
    /// the row's `fileTypeRaw` is not `"pdf"` or its `localFileName` is
    /// non-empty.
    case unsupportedDocument(reason: String)

    /// Persisting the pagination preference via `ModelContext.save()`
    /// failed. The associated value is the underlying error so the
    /// crash-log path can capture the original cause.
    ///
    /// This case is not exercised by the RED contract in task 2.1 — it
    /// is part of the GREEN surface because the coordinator's
    /// `paginationMode` setter is required to call
    /// `modelContext.save()` and surface any failure through this case
    /// rather than swallowing it.
    case paginationSaveFailed(underlying: any Error)
}