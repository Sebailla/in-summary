//
//  PDFPageChangeObserver.swift
//  InSummary
//
//  Phase 2 (`pencilkit-ink-overlay`) page-change bridge. Watches the
//  PDF reader's page-change signal and drives the cross-page
//  save/load cycle for `PencilCanvasOverlay`'s per-page
//  `PKDrawing` payloads. The observer is the only place where
//  navigation order and SwiftData persistence meet for the ink
//  overlay surface.
//
//  Phase 2 invariants this file honours:
//
//  - `@MainActor`. `PDFView`'s page-change notifications fire on
//    the main thread (the SwiftUI shell routes them through `.onReceive`),
//    and SwiftData's main `ModelContext.save()` is main-actor-bound.
//    Value-coalescing is therefore main-actor-safe by construction.
//
//  - No `PDFKit` import. The observer is driven by an injected
//    `currentPageIndex` — the SwiftUI shell supplies it from
//    `PDFReaderCoordinator`'s page-change publisher. The observer does
//    not need `PDFKit` types to persist a `PKDrawing`.
//
//  - No public SwiftData model types beyond `DocumentItem.id` and the
//    supplied `PageAnnotation`. The observer reads `DocumentItem.id`
//    to scope its `(document, pageIndex)` lookups; it does not declare
//    or alter any model type.
//
//  - Local-only. No network reach-out, no file I/O outside the
//    SwiftData store. The observer does not import any networking
//    primitive.
//
//  - Typed error surface at the public boundary. Persistence failures
//    surface as `AnnotationError.drawingPersistenceFailed(underlying:)`
//    via the `lastError` channel — the recoverable-error banner
//    mounted by `ReaderContainerView` (PR #4) pattern-matches on
//    this case verbatim.
//
//  - Value-coalescing on `currentPageIndex`. The observer drops
//    notifications whose index equals the last observed index, so
//    background renders, layout passes, and `PDFView`'s internal
//    notification storm do not author extra save/load cycles.
//
//  - Fail-fast on persistence failures. A failed save MUST surface
//    `AnnotationError.drawingPersistenceFailed(underlying:)` AND MUST
//    NOT mutate `lastObservedPageIndex` — the navigation cycle stops
//    at the failed page so the overlay stays bound to the last
//    successful page and the user sees a recoverable error.
//

import Foundation
import SwiftData
import PencilKit

/// Owns the cross-page save/load cycle for the PencilKit ink overlay.
///
/// The observer is the only place where `PencilCanvasOverlay`'s
/// in-memory `PKDrawing` (the reader's strokes on the visible page)
/// meets the SwiftData `PageAnnotation` rows that persist them. It is
/// driven by an injected `currentPageIndex` (the SwiftUI shell
/// supplies it from `PDFReaderCoordinator`'s page-change publisher in
/// PR #4) and reaches the canvas's drawing through two closures:
///
/// - `captureOutgoingDrawing(pageIndex)` — called once per
///   `handlePageChange(to:)` that advances the page. Returns the
///   canvas's current `PKDrawing` for the *outgoing* page so the
///   observer can persist it.
/// - `pageActivated(pageIndex)` — called once per successful
///   navigation. The overlay uses this signal to load the incoming
///   page's drawing into the canvas.
///
/// The observer is `@MainActor` because the `ModelContext` and the
/// injected closures are MainActor-bound in the Phase 2 call sites.
/// The observer is a `final class` so the SwiftUI shell can hold a
/// stable reference to the same instance across view updates.
@MainActor
final class PDFPageChangeObserver {

    // MARK: - Stored properties

    /// The `DocumentItem` row the observer is bound to. Held strongly
    /// so the observer's lifetime equals the SwiftUI shell's reader
    /// lifetime — the row cannot be deleted from under the observer
    /// while it is in flight.
    let document: DocumentItem

    /// The `ModelContext` the observer writes through. Held strongly
    /// so the SwiftUI shell can hand in its own context once at
    /// construction and rely on the observer to persist the per-page
    /// ink through the same context.
    let modelContext: ModelContext

    /// The most recent recoverable error surfaced by the observer. A
    /// failed save sets this to
    /// `AnnotationError.drawingPersistenceFailed(underlying:)`. The
    /// recoverable-error banner mounted by `ReaderContainerView`
    /// (PR #4) pattern-matches on this case verbatim.
    private(set) var lastError: AnnotationError?

    /// The page index that the observer most-recently activated. `nil`
    /// at construction; advanced to the incoming page index on every
    /// successful navigation. On a failed save the value MUST NOT be
    /// mutated — the fail-fast contract keeps the overlay bound to
    /// the last successful page.
    private(set) var lastObservedPageIndex: Int?

    /// Closure the observer invokes to capture the outgoing page's
    /// `PKDrawing` from the canvas. The closure returns `nil` when
    /// the outgoing page has no drawing to persist (e.g. the canvas
    /// was never mounted against that page index, or the user never
    /// picked up the Pencil). In that case the observer writes empty
    /// bytes to the outgoing page's `PageAnnotation` so the row stays
    /// in lockstep with the canvas.
    private let captureOutgoingDrawing: (Int) -> PKDrawing?

    /// Closure the observer invokes to notify the overlay that a new
    /// page has been activated. The overlay uses this signal to load
    /// the incoming page's `PKDrawing` into the canvas (via
    /// `replayDrawing()`). The closure is the only path the observer
    /// uses to talk back to the overlay — the observer does not own
    /// a reference to the canvas.
    private let pageActivated: (Int) -> Void

    /// Closure the observer invokes to persist a `PageAnnotation`
    /// mutation. Defaults to `{ try modelContext.save() }` so
    /// production code writes through the SwiftData store. Tests
    /// inject a throwing closure to exercise the fail-fast path
    /// deterministically.
    private let saveFn: () throws -> Void

    // MARK: - Initialisation

    /// Builds a `PDFPageChangeObserver` bound to the supplied
    /// `DocumentItem` and `ModelContext`.
    ///
    /// - Parameters:
    ///   - document: The `DocumentItem` row whose
    ///     `(document.id, pageIndex)` pairs scope the observer's
    ///     `PageAnnotation` lookups.
    ///   - modelContext: The `ModelContext` the observer writes
    ///     through. Held strongly; the SwiftUI shell owns the
    ///     container lifetime.
    ///   - captureOutgoingDrawing: Closure that returns the canvas's
    ///     live `PKDrawing` for a given page index. Return `nil` when
    ///     the outgoing page carries no ink to persist.
    ///   - pageActivated: Closure the observer invokes once per
    ///     successful navigation to notify the overlay that a new
    ///     page is active.
    ///   - saveFn: Closure the observer invokes to persist a mutated
    ///     `PageAnnotation`. Defaults to `{ try modelContext.save() }`.
    ///     The test suite injects a throwing closure to pin the
    ///     fail-fast contract.
    init(
        document: DocumentItem,
        modelContext: ModelContext,
        captureOutgoingDrawing: @escaping (Int) -> PKDrawing?,
        pageActivated: @escaping (Int) -> Void,
        saveFn: (() throws -> Void)? = nil
    ) {
        self.document = document
        self.modelContext = modelContext
        self.captureOutgoingDrawing = captureOutgoingDrawing
        self.pageActivated = pageActivated
        self.saveFn = saveFn ?? { try modelContext.save() }
    }

    // MARK: - Public surface

    /// Drives one page-change cycle. The observer:
    ///
    /// 1. Drops the notification if `newPageIndex` equals
    ///    `lastObservedPageIndex` (value-coalescing).
    /// 2. Captures the outgoing page's drawing via
    ///    `captureOutgoingDrawing(outgoingPage)`, persists it on the
    ///    outgoing `PageAnnotation` (lazy-upserted if missing), and
    ///    saves the row through `saveFn()`. A save failure sets
    ///    `lastError` and returns without mutating
    ///    `lastObservedPageIndex` (fail-fast contract).
    /// 3. Invokes `pageActivated(newPageIndex)` so the overlay can
    ///    load the incoming page's drawing into the canvas.
    /// 4. Advances `lastObservedPageIndex` to `newPageIndex`.
    func handlePageChange(to newPageIndex: Int) {
        // Step 1 — value-coalescing.
        if newPageIndex == lastObservedPageIndex {
            return
        }

        // Step 2 — capture, persist, save.
        if let outgoingPage = lastObservedPageIndex {
            let outgoingDrawing = captureOutgoingDrawing(outgoingPage)
            let saveSucceeded = persistOutgoingDrawing(
                forPage: outgoingPage,
                drawing: outgoingDrawing
            )
            if !saveSucceeded {
                // Fail-fast: a failed save stops the navigation
                // cycle. `lastObservedPageIndex` stays at the
                // outgoing page, `pageActivated(newPageIndex)` is
                // NOT called, and the recoverable-error banner
                // surfaces the failure.
                return
            }
        }

        // Step 3 — notify the overlay that a new page is active.
        pageActivated(newPageIndex)

        // Step 4 — advance the page index.
        lastObservedPageIndex = newPageIndex
    }

    /// Returns the `PageAnnotation` row for `(document.id, pageIndex)`,
    /// lazy-upserting one against the bound `DocumentItem` when no row
    /// exists. The lookup is scoped by `document.id` so the observer
    /// works correctly when the SwiftData container holds
    /// `PageAnnotation` rows for other documents.
    ///
    /// Public so the focused test suite can read the persisted rows
    /// without going through `modelContext.fetch(...)` and asserting
    /// against the spec's byte-identical contract directly.
    func annotation(forPage pageIndex: Int) -> PageAnnotation {
        let documentID = document.id
        let descriptor = FetchDescriptor<PageAnnotation>(
            predicate: #Predicate { annotation in
                annotation.pageIndex == pageIndex
                    && annotation.document?.id == documentID
            }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let new = PageAnnotation()
        new.pageIndex = pageIndex
        new.document = document
        modelContext.insert(new)
        return new
    }

    // MARK: - Private helpers

    /// Persists the outgoing page's `PKDrawing` (or empty bytes if the
    /// canvas returned `nil`) on the matching `PageAnnotation` row.
    /// Returns `false` on a save failure — the caller uses the boolean
    /// to enforce the fail-fast contract.
    private func persistOutgoingDrawing(
        forPage pageIndex: Int,
        drawing: PKDrawing?
    ) -> Bool {
        let annotation = self.annotation(forPage: pageIndex)
        let data: Data = drawing?.dataRepresentation() ?? Data()
        annotation.drawingData = data
        do {
            try saveFn()
            return true
        } catch {
            // The SwiftData row's in-memory mutation survives (it
            // lives on the unsaved annotation object), but the
            // persistent store is unchanged because `saveFn()` threw
            // before the backing store was touched. The recoverable-
            // error banner surfaces the underlying error verbatim so
            // the crash-log path can capture it.
            lastError = .drawingPersistenceFailed(underlying: error)
            return false
        }
    }
}
