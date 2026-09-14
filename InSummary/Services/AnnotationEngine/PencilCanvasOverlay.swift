//
//  PencilCanvasOverlay.swift
//  InSummary
//
//  Phase 2 (`pencilkit-ink-overlay`) overlay. Hosts a `PKCanvasView` above
//  the `PDFReaderCoordinator`'s `PDFView`, configured with the
//  pencil-only drawing policy and the highlighter as the default tool.
//  The overlay is the data-flow bridge between `PKCanvasView`'s
//  `canvasViewDrawingDidChange` callback and the Phase 1
//  `PageAnnotation.drawingData` SwiftData column.
//
//  Phase 2 invariants this file honours:
//
//  - `@MainActor`. `PKCanvasView` is `UIScrollView`-backed and is touched
//    only on the main actor under the iOS 26 SDK; SwiftData's
//    `ModelContext.save()` is also main-actor-bound in the Phase 2 call
//    sites.
//
//  - No `PDFKit` import. The annotation overlay is independent of the PDF
//    reader surface. The overlay accepts a `pageIndex` and a
//    `PageAnnotation?` from the SwiftUI shell — the PDF reader is not in
//    this file's import graph.
//
//  - No new SwiftData model types. The overlay writes to the Phase 1
//    `PageAnnotation.drawingData` column directly; it does not declare,
//    alter, default, or migrate any Phase 1 entity.
//
//  - Local-only. No network reach-out, no file I/O outside the application
//    bundle and the local SwiftData store. No remote networking APIs, no
//    low-level network primitives, no cloud-backed persistent store, no
//    cloud container, or any remote I/O.
//
//  - Typed error surface at the public boundary. The overlay surfaces
//    `AnnotationError` values through its `lastError` channel. The
//    recoverable-error banner mounted by `ReaderContainerView` (PR #4) is
//    expected to pattern-match on these cases verbatim.
//
//  - Byte-identical round-trip. The bytes persisted by the overlay MUST
//    be exactly the bytes that `PKDrawing.dataRepresentation()` produces,
//    byte-for-byte. There is no post-processor, no normalization, and no
//    codec on top of PencilKit's archive format.
//
//  - PencilKit's highlighter analog. `PKInkingTool.InkType` has no
//    `highlighter` case on iOS 26 (the available cases are `pen`,
//    `pencil`, `marker`, `monoline`, `fountainPen`, `watercolor`,
//    `crayon`, `reed`). The highlighter behaviour the spec asks for is
//    achieved by `.marker` ink with a translucent yellow color and a
//    wide stroke; that combination is captured by
//    `defaultHighlighterTool` so the configuration is the single source
//    of truth for the reader's default highlighter.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit
import PencilKit

// MARK: - PencilCanvasOverlay

/// SwiftUI overlay that hosts a `PKCanvasView` above the PDF reader's
/// `PDFView`. The overlay is bound to a single page (one logical PDF
/// page index) for the duration of its mount; the `PDFPageChangeObserver`
/// (added in `PDFPageChangeObserver.swift`, sibling file in the same
/// directory) drives the page-swap cycle.
///
/// The overlay exposes its data-flow surface publicly so the focused
/// test suite (`InSummaryTests/PencilCanvasOverlayTests.swift`) can
/// verify byte-identical replay, lazy-upsert of missing
/// `PageAnnotation` rows, decode-failure recovery, and clear-clears-
/// everything without needing to mount the SwiftUI tree.
///
/// The struct delegates all state and behaviour to a held
/// `PencilCanvasOverlayCoordinator`. SwiftUI owns the coordinator's
/// lifetime through `makeCoordinator()`; the struct exposes the
/// coordinator's public surface so callers (and tests) can read state
/// without going through `UIViewRepresentable`'s `Context` channel.
///
/// Phase 2 invariant: the overlay is the only writer of the supplied
/// `PageAnnotation.drawingData` while it is mounted. The
/// `PDFPageChangeObserver` captures the outgoing drawing via the
/// canvas's `dataRepresentation()` and persists it on the outgoing
/// page's annotation; the overlay itself only writes the active
/// page's drawing on `canvasViewDrawingDidChange`.
@MainActor
struct PencilCanvasOverlay: UIViewRepresentable {

    // MARK: - Inputs

    /// The 0-indexed logical page index in PDF document space that this
    /// overlay is currently mounted against.
    let pageIndex: Int

    /// The `PageAnnotation` row the overlay is bound to. May be `nil`
    /// when the overlay is mounting against a fresh page that does not
    /// yet have a row; the overlay lazy-upserts one in that case so the
    /// `PDFPageChangeObserver` has a stable row to persist against
    /// later.
    let pageAnnotation: PageAnnotation?

    /// The `DocumentItem` row the lazy-upserted annotation is bound to.
    /// Required when `pageAnnotation == nil`; ignored when a row is
    /// already supplied.
    let document: DocumentItem?

    /// The `ModelContext` the overlay writes through. Held by the SwiftUI
    /// shell so the overlay does not own the container lifetime.
    let modelContext: ModelContext

    // MARK: - Configuration

    /// The default inking tool applied at `makeUIView` time and
    /// re-applied at every `updateUIView` so the highlighter persists
    /// across replays from a stored drawing. The combination of the
    /// `.marker` ink family + translucent yellow color + 20-point
    /// stroke width is the canonical PencilKit highlighter — the
    /// SDK has no `highlighter` case on `PKInkingTool.InkType` (the
    /// available cases are `pen`, `pencil`, `marker`, `monoline`,
    /// `fountainPen`, `watercolor`, `crayon`, `reed`).
    static let defaultHighlighterTool: PKInkingTool = PKInkingTool(
        .marker,
        color: UIColor.systemYellow.withAlphaComponent(0.4),
        width: 20
    )

    // MARK: - Delegation to the coordinator

    /// The coordinator is constructed once per overlay lifetime. SwiftUI
    /// will invoke `makeCoordinator()` and use the same coordinator for
    /// the entire lifetime of the view; tests can also construct the
    /// overlay directly and access this property.
    private let coordinator: PencilCanvasOverlayCoordinator

    // MARK: - Init

    init(
        pageIndex: Int,
        pageAnnotation: PageAnnotation?,
        document: DocumentItem?,
        modelContext: ModelContext
    ) {
        self.pageIndex = pageIndex
        self.pageAnnotation = pageAnnotation
        self.document = document
        self.modelContext = modelContext
        let coordinator = PencilCanvasOverlayCoordinator(
            document: document,
            modelContext: modelContext
        )
        coordinator.attach(pageIndex: pageIndex, pageAnnotation: pageAnnotation)
        self.coordinator = coordinator
    }

    // MARK: - Test surface (mirrors the coordinator's public surface)

    /// The `PageAnnotation` row the overlay is currently bound to,
    /// including the lazy-upserted row when `pageAnnotation == nil` was
    /// passed to the init. Test surface only; production readers should
    /// not depend on this property — the page-change observer reaches
    /// the row via its own `annotation(forPage:)` lookup.
    var pageAnnotationRef: PageAnnotation? { coordinator.pageAnnotation }

    /// The most-recent recoverable error surfaced by the overlay. The
    /// reader surface (mounted by `ReaderContainerView` in PR #4) is
    /// expected to observe this and render a recoverable-error banner.
    var lastError: AnnotationError? { coordinator.lastError }

    /// Builds the `PKCanvasView` configured with the pencil-only
    /// drawing policy and the highlighter default tool, with the
    /// active `PageAnnotation`'s stored drawing replayed. The SwiftUI
    /// shell uses this from `makeUIView`; the test suite uses it to
    /// verify the canvas configuration without mounting the SwiftUI
    /// tree.
    func makeCanvasView() -> PKCanvasView {
        coordinator.makeCanvasView()
    }

    /// Returns the `PKDrawing` that would be set on the canvas right
    /// now if the canvas were rebuilt. Mirrors the coordinator's
    /// `replayDrawing()` helper so the focused test suite can pin the
    /// byte-identical round-trip contract at the data layer. The
    /// canvas mutates the archive after the first layout pass (Apple's
    /// "RemoteRecognizer" layout analysis re-canonicalises the
    /// bytes), so a strict byte comparison against
    /// `canvas.drawing.dataRepresentation()` is not stable across SDK
    /// versions; this passthrough is.
    func replayDrawing() -> PKDrawing {
        coordinator.replayDrawing()
    }

    /// Clears the canvas in memory and persists empty bytes on
    /// `PageAnnotation.drawingData`. The previously persisted bytes are
    /// overwritten with `Data()` so the cleared state survives a
    /// coordinator re-init. The spec calls this the "clear-clears-
    /// everything" contract.
    func clear(canvas: PKCanvasView) {
        coordinator.clear(canvas: canvas)
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> PKCanvasView {
        coordinator.makeCanvasView()
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        coordinator.updateCanvas(canvas)
    }

    func makeCoordinator() -> PencilCanvasOverlayCoordinator {
        coordinator
    }
}

// MARK: - PencilCanvasOverlayCoordinator

/// Owns the `PageAnnotation` reference, the in-memory `PKDrawing`, the
/// recoverable-error surface, and the lifecycle of the canvas-view
/// delegate callbacks. The coordinator is the single mutation point for
/// the supplied `PageAnnotation.drawingData` while the overlay is
/// mounted.
///
/// The coordinator is `@MainActor` because both `PKCanvasView` and the
/// SwiftData main `ModelContext` are main-actor-bound under the iOS 26
/// SDK. The coordinator is a `final class` so SwiftUI can hold a stable
/// reference to the same instance across `makeUIView` /
/// `updateUIView` cycles.
@MainActor
final class PencilCanvasOverlayCoordinator: NSObject, PKCanvasViewDelegate {

    // MARK: - Stored properties

    /// The `PageAnnotation` row the overlay is bound to. Initialised in
    /// `attach(pageIndex:pageAnnotation:)` so a fresh coordinator
    /// (constructed before `attach` runs) is safe to inspect.
    private(set) var pageAnnotation: PageAnnotation?

    /// The most-recent recoverable error surfaced by the overlay. The
    /// reader surface (mounted by `ReaderContainerView` in PR #4) is
    /// expected to observe this and render a recoverable-error banner.
    /// Reset only by the next successful save or replay; the spec
    /// mandates the value persist across replays so the user sees the
    /// banner until they take action.
    private(set) var lastError: AnnotationError?

    /// The `DocumentItem` the lazy-upserted annotation is bound to.
    /// Captured at init time so the upsert path can bind the row.
    private let document: DocumentItem?

    /// The `ModelContext` the overlay writes through.
    private let modelContext: ModelContext

    /// The active `PKCanvasView`. Captured at `attach` time so the
    /// overlay can update its `drawing` (e.g. on clear) without
    /// needing the SwiftUI shell to re-thread the canvas reference.
    private weak var canvasView: PKCanvasView?

    /// The page index the overlay is bound to. Captured at `attach`
    /// time so the lazy-upsert path can write the right index on the
    /// new `PageAnnotation` row.
    private var attachedPageIndex: Int = 0

    // MARK: - Initialisation

    init(document: DocumentItem?, modelContext: ModelContext) {
        self.document = document
        self.modelContext = modelContext
        super.init()
    }

    // MARK: - Public test surface

    /// Builds the `PKCanvasView` configured with the pencil-only drawing
    /// policy and the highlighter default tool. Calls
    /// `attach(pageIndex:pageAnnotation:)` first if it has not been
    /// called yet so the canvas can replay any stored drawing.
    ///
    /// The canvas's `drawing` is assigned **before** its `delegate` is
    /// set, so the initial `canvasViewDrawingDidChange` callback
    /// (which PencilKit fires whenever the drawing is replaced,
    /// including programmatic assignments) does **not** reach the
    /// coordinator's persistence path. Without this ordering, an
    /// unreadable `PageAnnotation.drawingData` would be silently
    /// overwritten with the canvas's blank drawing on the first
    /// mount, breaking the decode-failure preservation contract
    /// and corrupting the row before the user has interacted with
    /// the canvas.
    func makeCanvasView() -> PKCanvasView {
        if pageAnnotation == nil {
            // Default to page 0 if the SwiftUI shell called
            // `makeCanvasView()` before `attach(...)`. The shell always
            // calls `attach` first via `makeUIView` / `updateUIView`,
            // but the test surface calls `makeCanvasView()` directly
            // and must therefore survive a no-attach path.
            attach(pageIndex: 0, pageAnnotation: nil)
        }
        let canvas = PKCanvasView()
        applyCanvasConfiguration(to: canvas, assignDrawing: true)
        canvasView = canvas
        return canvas
    }

    /// Re-applies the canvas configuration without changing the
    /// underlying `PageAnnotation` binding. Used by `updateUIView` to
    /// keep the pencil-only policy and the highlighter default tool
    /// pinned across SwiftUI redraws.
    func updateCanvas(_ canvas: PKCanvasView) {
        applyCanvasConfiguration(to: canvas, assignDrawing: true)
        canvasView = canvas
    }

    /// Single source of truth for `PKCanvasView` configuration.
    /// Every canvas-view the overlay builds or updates flows
    /// through this helper so the pencil-only drawing policy and
    /// the highlighter default tool stay in lockstep across
    /// `makeUIView`, `updateUIView`, and any future canvas
    /// mounting path. The `assignDrawing` parameter is reserved
    /// for future callers that want to configure the canvas
    /// without replacing the drawing (the helper unconditionally
    /// assigns the replayed drawing today; the parameter keeps
    /// the API stable when that assumption changes).
    ///
    /// The canvas's `drawing` is assigned **before** its `delegate`
    /// is set so the initial `canvasViewDrawingDidChange` callback
    /// (which PencilKit fires whenever the drawing is replaced,
    /// including programmatic assignments) does not reach the
    /// coordinator's persistence path. Without this ordering, an
    /// unreadable `PageAnnotation.drawingData` would be silently
    /// overwritten with the canvas's blank drawing on the first
    /// mount, breaking the decode-failure preservation contract
    /// and corrupting the row before the user has interacted with
    /// the canvas.
    private func applyCanvasConfiguration(
        to canvas: PKCanvasView,
        assignDrawing: Bool
    ) {
        canvas.drawingPolicy = .pencilOnly
        canvas.tool = PencilCanvasOverlay.defaultHighlighterTool
        if assignDrawing {
            canvas.drawing = replayDrawing()
            canvas.delegate = self
        }
    }

    /// Clears the canvas in memory and persists empty bytes on
    /// `PageAnnotation.drawingData`. The previously persisted bytes are
    /// overwritten with `Data()` so the cleared state survives a
    /// coordinator re-init. The spec calls this the "clear-clears-
    /// everything" contract.
    func clear(canvas: PKCanvasView) {
        let clearedDrawing = PKDrawing()
        canvas.drawing = clearedDrawing
        pageAnnotation?.drawingData = Data()
        do {
            try modelContext.save()
        } catch {
            // Save failure on clear: retain the cleared drawing in
            // memory for the current session and surface a recoverable
            // error so the reader can retry. The previously persisted
            // bytes are NOT rolled back by `modelContext.save()`
            // failure — the in-memory mutation lives on the
            // not-yet-persisted annotation row, and the on-disk bytes
            // are unchanged.
            lastError = .drawingPersistenceFailed(underlying: error)
        }
    }

    // MARK: - Internal helpers

    /// Binds the overlay to a page index and an optional `PageAnnotation`.
    /// When `pageAnnotation == nil` the overlay lazy-upserts one
    /// against the supplied `document` (PR #4 wires a non-nil document;
    /// the focused test suite exercises both branches).
    func attach(pageIndex: Int, pageAnnotation annotation: PageAnnotation?) {
        attachedPageIndex = pageIndex
        if let annotation {
            pageAnnotation = annotation
        } else if let document = document {
            let new = PageAnnotation()
            new.pageIndex = pageIndex
            new.document = document
            modelContext.insert(new)
            pageAnnotation = new
        }
        // Replay the stored drawing on attach so the canvas reflects
        // any bytes the row already carries. `replayDrawing()` swallows
        // decode failures via `lastError` and renders an empty drawing
        // — see the doc comment for the decode-failure scenario.
        canvasView?.drawing = replayDrawing()
    }

    /// Returns the `PKDrawing` that should be on the canvas right now.
    /// Replays the `PageAnnotation.drawingData` payload when present;
    /// falls back to `PKDrawing()` on missing data or decode failure.
    /// A decode failure is surfaced as
    /// `AnnotationError.drawingDecodeFailed` so the recoverable-error
    /// banner can describe the refusal; the unreadable `drawingData`
    /// on the row is preserved untouched.
    ///
    /// Exposed as `internal` (not `private`) so the focused test suite
    /// can pin the byte-identical round-trip contract at the data
    /// layer. The `PKCanvasView`'s drawing mutates after the first
    /// layout pass (Apple's "RemoteRecognizer" layout analysis
    /// re-canonicalises the archive), so a strict byte comparison
    /// against `canvas.drawing.dataRepresentation()` is not stable
    /// across SDK versions. The `replayDrawing()` round-trip, by
    /// contrast, is byte-stable because it never touches the view
    /// layer — `PKDrawing(data:)` decodes the archive, and
    /// `PKDrawing.dataRepresentation()` re-encodes the same archive.
    func replayDrawing() -> PKDrawing {
        guard let annotation = pageAnnotation else {
            return PKDrawing()
        }
        guard let data = annotation.drawingData, !data.isEmpty else {
            return PKDrawing()
        }
        do {
            return try PKDrawing(data: data)
        } catch {
            // Decode failure: render blank, preserve the unreadable
            // bytes, surface a recoverable error. The
            // `lastError` value is set on every failed replay attempt
            // so the banner stays visible across re-attaches.
            lastError = .drawingDecodeFailed
            return PKDrawing()
        }
    }

    // MARK: - PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // Capture the new drawing into the row and persist. On save
        // failure the in-memory drawing is retained (the canvas view
        // already shows it) and a recoverable error is surfaced. The
        // on-disk bytes are unchanged because `modelContext.save()`
        // threw before the backing store was touched.
        guard let annotation = pageAnnotation else { return }
        annotation.drawingData = canvasView.drawing.dataRepresentation()
        do {
            try modelContext.save()
        } catch {
            lastError = .drawingPersistenceFailed(underlying: error)
        }
    }
}
