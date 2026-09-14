//
//  AnnotationError.swift
//  InSummary
//
//  Typed error surface for the Phase 2 PencilKit annotation engine (child
//  PR #3 — `feat/pencilkit-ink-overlay`). The cases enumerated here are the
//  only errors the `PencilCanvasOverlay` and `PDFPageChangeObserver` are
//  permitted to surface to the reader surface; the recoverable-error banner
//  mounted by `ReaderContainerView` (child PR #4) is expected to
//  pattern-match on these cases verbatim.
//
//  Phase 2 invariants this file honours:
//
//  - Local-only. The cases describe *local* persistence / decoding refusal
//    reasons — a SwiftData save failure or a PencilKit archive decode
//    failure. No HTTP, no `URLError`, no cloud-backed SwiftData store
//    error, no `CKError`.
//  - No `PDFKit` import. The annotation engine surface is independent of
//    the PDF reader surface; the observer does not introduce a `PDFView`,
//    `PDFDocument`, or `PDFKit` symbol.
//  - No new SwiftData model. `drawingPersistenceFailed(underlying:)`
//    wraps the underlying error verbatim so the crash-log path can capture
//    the original cause; it does not expose a typed `ModelContext` failure
//    or a new entity.
//

import Foundation

/// Errors surfaced by the Phase 2 PencilKit annotation engine at its
/// public boundary.
///
/// The cases encode the exact refusal reasons documented in
/// `openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pencilkit-ink-overlay/spec.md`:
/// a `PKDrawing(data:)` archive rejection and a SwiftData save failure
/// when persisting the per-page ink. Every case carries the minimum
/// context the recoverable-error banner needs to describe the refusal to
/// the user.
enum AnnotationError: Error {

    /// `PKDrawing(data:)` rejected the bytes stored on
    /// `PageAnnotation.drawingData`. The canvas renders blank and the
    /// unreadable `drawingData` is preserved untouched on the row so a
    /// future migration can recover or report on the corrupt payload.
    ///
    /// Spec reference: "Decoder rejection surfaces a recoverable error"
    /// — the overlay SHALL set `lastError = .drawingDecodeFailed`, render
    /// the canvas empty, and leave the unreadable `drawingData`
    /// untouched.
    case drawingDecodeFailed

    /// Persisting the per-page ink via `ModelContext.save()` failed. The
    /// associated value is the underlying error so the crash-log path can
    /// capture the original cause. The overlay retains the in-memory
    /// drawing for the current session and the previously persisted bytes
    /// remain untouched on disk.
    ///
    /// Spec reference: "Save failure surfaces a recoverable error" — the
    /// overlay SHALL set `lastError = .drawingPersistenceFailed(underlying:)`
    /// on `modelContext.save()` failure; the in-memory drawing is retained
    /// for the current session; the previously persisted bytes are left
    /// untouched on disk.
    case drawingPersistenceFailed(underlying: any Error)
}
