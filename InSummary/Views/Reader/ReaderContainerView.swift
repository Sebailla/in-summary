//
//  ReaderContainerView.swift
//  InSummary
//
//  Phase 2 (`pdf-reader-wiring`) SwiftUI shell that composes the
//  `PDFReaderCoordinator` (capability `pdf-engine`), the
//  `PencilCanvasOverlay` and `PDFPageChangeObserver` (capability
//  `pencilkit-ink-overlay`) into a single reader surface and exposes the
//  per-document pagination preference wired back to the Phase 1
//  `DocumentItem.paginationModeRaw` column.
//
//  Phase 2 invariants this file honours:
//
//  - `@MainActor`. The SwiftUI render tree, `PDFView`, `PKCanvasView`,
//    and SwiftData's main `ModelContext` are all main-actor-bound; the
//    container follows.
//  - No `PDFKit` import. The container only uses the coordinator's
//    `pdfView` (a typed reference) and the overlay; it does not import
//    `PDFKit` symbols directly. The PDF engine is encapsulated by
//    `PDFReaderCoordinator`.
//  - Local-only. No network reach-out, no iCloud, no CloudKit, no
//    push, no remote notification, no background URL session.
//  - No schema change. The container reads and writes only the
//    Phase 1 columns `DocumentItem.paginationModeRaw` and
//    `DocumentItem.updatedAt` and the Phase 1
//    `PageAnnotation.drawingData` blob. No new entities, no new
//    relationships, no new fields.
//  - Single source of truth for the page-change signal. The
//    coordinator's `PDFView` is the source of truth for
//    `currentPage`; the container subscribes via `.onReceive(of:)`
//    against a `PassthroughSubject` driven by a
//    `NotificationCenter` observer on `.PDFViewPageChanged`, and
//    forwards the index to the observer's `handlePageChange(to:)`
//    API. No `Task.sleep`, no timer, no
//    `DispatchQueue.main.asyncAfter`.
//  - Recoverable error banners. `PDFReaderError` and `AnnotationError`
//    surface as dismissible banners on top of the reader; the reader
//    remains interactive behind them.
//

import Foundation
import SwiftUI
import SwiftData
import PencilKit
import Combine

/// Composes the Phase 2 reader surface.
///
/// The view hosts a `PDFViewRepresentable` (the coordinator's
/// `PDFView`), a `PencilCanvasOverlay` (the per-page PencilKit ink
/// surface), and the `PDFPageChangeObserver` (the
/// navigation ↔ SwiftData bridge). It owns the lifecycle of all three
/// — built on `onAppear`, torn down on `onDisappear`.
///
/// The view is the only place where the reader's three engines meet.
/// Each engine keeps its own module boundary (no cross-imports of
/// `PDFKit` / `PencilKit`); the container ties them together through
/// typed handles.
@MainActor
struct ReaderContainerView: View {

    // MARK: - Stored properties

    /// The `DocumentItem` row the reader renders. Held strongly so the
    /// SwiftData lifetime equals the reader lifetime.
    let document: DocumentItem

    /// The `ModelContext` the container writes through.
    let modelContext: ModelContext

    /// The coordinator backing the `PDFView`. Optional because the
    /// container can build its own coordinator against the bundled
    /// fixture, or accept one pre-built by `LibraryGridView` (the
    /// library shell path). When `nil`, the container builds one on
    /// first render.
    private let prebuiltCoordinator: PDFReaderCoordinator?

    /// The view model that owns the coordinator, observer, overlay,
    /// page state, and the recovered error surface. Drives the view
    /// via `@StateObject` so SwiftUI keeps a stable instance across
    /// redraws.
    @StateObject private var viewModel: ReaderContainerViewModel

    // MARK: - Initialisation

    /// Builds the reader surface against the supplied `DocumentItem`.
    ///
    /// When `coordinator` is non-nil, the container adopts the
    /// pre-built coordinator (the library-shell path so the same
    /// instance survives a navigation push). When `coordinator` is
    /// `nil`, the view model builds its own against the bundled
    /// fixture; failures surface as `PDFReaderError` banners.
    init(
        document: DocumentItem,
        modelContext: ModelContext,
        coordinator: PDFReaderCoordinator? = nil
    ) {
        self.document = document
        self.modelContext = modelContext
        self.prebuiltCoordinator = coordinator
        _viewModel = StateObject(
            wrappedValue: ReaderContainerViewModel(
                document: document,
                modelContext: modelContext,
                prebuiltCoordinator: coordinator
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if let coordinator = viewModel.coordinator {
                PDFViewRepresentable(coordinator: coordinator)
                .ignoresSafeArea()
            }

            if let overlay = viewModel.overlay {
                PencilCanvasOverlay(
                    pageIndex: overlay.pageIndex,
                    pageAnnotation: overlay.pageAnnotation,
                    document: document,
                    modelContext: modelContext
                )
                .ignoresSafeArea()
                .allowsHitTesting(true)
            }

            VStack {
                if let readerError = viewModel.readerError {
                    ReaderErrorBanner(
                        title: "Reader error",
                        message: readerErrorMessage(readerError),
                        onDismiss: { viewModel.clearReaderError() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                if let annotationError = viewModel.annotationError {
                    AnnotationErrorBanner(
                        title: "Annotation error",
                        message: annotationErrorMessage(annotationError),
                        onDismiss: { viewModel.clearAnnotationError() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                Spacer()
            }

            HStack {
                Spacer()
                PaginationModeToggle(
                    mode: Binding(
                        get: { viewModel.paginationMode },
                        set: { viewModel.paginationMode = $0 }
                    )
                )
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                }
            }
        }
        .navigationTitle(document.title.isEmpty ? "Reader" : document.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onReceive(viewModel.pageChangePublisher) { pageIndex in
            viewModel.handlePageChange(to: pageIndex)
        }
    }

    // MARK: - Public test surface

    /// Test-only seam that returns a wrapper around the
    /// `PDFPageChangeObserver`-facing page change sink. Tests use this
    /// seam to simulate page changes without subscribing to the
    /// `NotificationCenter`. Production code does not call this
    /// method — it relies on the `.onReceive(viewModel.pageChangePublisher)`
    /// pipeline above.
    var pageChangeSink: PageChangeSink { viewModel.pageChangeSink }

    /// Test-only seam for the overlay's live canvas. Tests use this
    /// to construct a `PKCanvasView`, mutate it directly, and route
    /// the mutation through `persistCurrentDrawing()` so the byte
    /// equality assertion in `ReaderIntegrationTests` sees the
    /// expected `PageAnnotation.drawingData` bytes.
    var overlayHook: OverlayHook { viewModel.overlayHook }

    /// Returns the live `PKCanvasView` the overlay is currently
    /// mounted against. Tests use this to drive the canvas through
    /// `overlayHook.replaceDrawing(_:)` and `persistCurrentDrawing()`
    /// without going through `.onChange(of:)`.
    func makeLiveCanvas() -> PKCanvasView {
        viewModel.makeLiveCanvas()
    }

    /// Activates the supplied page index on the overlay — mounts the
    /// overlay against the lazy-upserted `PageAnnotation` for that
    /// page and replaces the canvas's drawing with the persisted one.
    /// Production code calls this through
    /// `viewModel.handlePageChange(to:)`; the integration test calls
    /// it explicitly so it can stagger the navigate → draw → persist
    /// sequence without locking onto a fixed cadence.
    func activate(pageIndex: Int) {
        viewModel.activate(pageIndex: pageIndex)
    }

    /// Reads and writes the container's pagination preference. Reads
    /// return the coordinator's current value (which mirrors
    /// `DocumentItem.paginationModeRaw` after the latest save).
    /// Writes delegate to `viewModel.paginationMode = $0` and trigger
    /// the coordinator's save path.
    var paginationMode: PDFReaderCoordinator.PaginationMode {
        get { viewModel.paginationMode }
        nonmutating set { viewModel.paginationMode = newValue }
    }

    // MARK: - Error-message helpers

    /// Renders the supplied `PDFReaderError` into a human-readable
    /// banner message. The recoverable banner mounts the message
    /// verbatim so the user sees the same wording the coordinator
    /// surfaces.
    private func readerErrorMessage(_ error: PDFReaderError) -> String {
        switch error {
        case .fixtureMissing(let resource):
            return "The bundled PDF resource \"\(resource)\" could not be located. Reinstall the app and try again."
        case .fixtureUnreadable:
            return "The bundled PDF resource is unreadable. Reinstall the app and try again."
        case .unsupportedDocument(let reason):
            return "This document is not supported in this build: \(reason)"
        case .paginationSaveFailed:
            return "Your pagination preference could not be saved. Try toggling the mode again."
        }
    }

    /// Renders the supplied `AnnotationError` into a human-readable
    /// banner message.
    private func annotationErrorMessage(_ error: AnnotationError) -> String {
        switch error {
        case .drawingDecodeFailed:
            return "A previously saved drawing on this page could not be decoded. The drawing is preserved; reload the document to retry."
        case .drawingPersistenceFailed:
            return "Your changes to the drawing could not be saved. Try again; the canvas keeps your strokes locally."
        }
    }
}

// MARK: - ReaderContainerViewModel

/// View model backing `ReaderContainerView`. Owns the coordinator, the
/// `PDFPageChangeObserver`, the live `PencilCanvasOverlay`, the current
/// page index, and the recoverable error surface. Marked `@MainActor`
/// because every input surface (PDFView, PKCanvasView, and SwiftData's
/// main `ModelContext`) is main-actor-bound.
@MainActor
final class ReaderContainerViewModel: ObservableObject {

    // MARK: - Observable state

    /// The most recent recoverable reader error. Cleared by the user
    /// dismissing the banner.
    @Published private(set) var readerError: PDFReaderError?

    /// The most recent recoverable annotation error. Cleared by the
    /// user dismissing the banner.
    @Published private(set) var annotationError: AnnotationError?

    /// The current page index. Backed by `@Published` so the SwiftUI
    /// layer re-renders when the page advances.
    @Published private(set) var currentPageIndex: Int = 0

    /// The container's pagination mode. Reads return the
    /// coordinator's persisted value; writes forward to the
    /// coordinator's `paginationMode` setter, which bumps
    /// `updatedAt` and calls `modelContext.save()` so the
    /// preference persists per document. Implemented as a computed
    /// property so the coordinator — not the view model — is the
    /// single source of truth for the persisted value.
    var paginationMode: PDFReaderCoordinator.PaginationMode {
        get {
            coordinator?.paginationMode ?? .horizontal
        }
        set {
            coordinator?.paginationMode = newValue
        }
    }

    // MARK: - Stored properties

    /// The coordinator backing the `PDFView`.
    let coordinator: PDFReaderCoordinator?

    /// The `ModelContext` the view model writes through.
    let modelContext: ModelContext

    /// The `DocumentItem` row.
    let document: DocumentItem

    /// The page-change observer. Built once per reader mount. Holds
    /// the cross-page save/load cycle for the overlay's per-page ink.
    let observer: PDFPageChangeObserver

    /// The active overlay (the wrapper that owns the per-page canvas).
    /// Rebuilt on each page navigation so the overlay binds to the
    /// incoming page's `PageAnnotation` and replays its drawing.
    @Published private(set) var overlay: PencilCanvasOverlay?

    /// The page index the active overlay is bound to. Mirrors
    /// `overlay?.pageIndex` so the body can read it without unwrapping.
    var activePageIndex: Int? {
        overlay?.pageIndex
    }

    /// Stable reference to the live `PKCanvasView` so the test seam
    /// can draw and persist through the same canvas the overlay
    /// shows. Refreshed on every `activate(pageIndex:)`.
    private var liveCanvas: PKCanvasView?

    /// The notification observer token for `.PDFViewPageChanged`.
    private var pdfPageObserver: NSObjectProtocol?

    /// The page-change publisher that drives the SwiftUI
    /// `.onReceive` pipeline. Emits whenever the coordinator's
    /// `PDFView.currentPage` advances.
    let pageChangePublisher = PassthroughSubject<Int, Never>()

    /// Test-only seam wrapping the page-change sink — built lazily so
    /// production callers never pay for it.
    private(set) lazy var pageChangeSink: PageChangeSink = PageChangeSink(
        onSimulatedChange: { [weak self] index in
            self?.handlePageChange(to: index)
        }
    )

    /// Test-only seam wrapping the overlay's canvas-driven persistence
    /// path. Tests use this to draw on the live canvas and persist
    /// the strokes through the active `PageAnnotation.drawingData`.
    private(set) lazy var overlayHook: OverlayHook = OverlayHook(
        canvasProvider: { [weak self] in
            self?.makeLiveCanvas()
        },
        persist: { [weak self] in
            self?.persistCurrentDrawingOnCanvas()
        }
    )

    // MARK: - Initialisation

    /// Builds the view model. When `prebuiltCoordinator` is non-nil,
    /// the view model adopts it (the library-shell path where the
    /// coordinator is shared with the navigation push). When `nil`,
    /// the view model builds its own against the bundled fixture; a
    /// failed build surfaces as `readerError`.
    init(
        document: DocumentItem,
        modelContext: ModelContext,
        prebuiltCoordinator: PDFReaderCoordinator?
    ) {
        self.document = document
        self.modelContext = modelContext

        // 1. Adopt or build the coordinator.
        var resolvedCoordinator: PDFReaderCoordinator?
        var deferredReaderError: PDFReaderError?
        if let prebuilt = prebuiltCoordinator {
            resolvedCoordinator = prebuilt
        } else {
            do {
                resolvedCoordinator = try PDFReaderCoordinator(
                    document: document,
                    modelContext: modelContext
                )
            } catch {
                // A failed coordinator build surfaces as a recoverable
                // error. We delegate to a placeholder coordinator so
                // SwiftUI can still build the representable and the
                // user sees a banner instead of a blank screen.
                resolvedCoordinator = Self.makePlaceholderCoordinator(
                    document: document,
                    modelContext: modelContext
                )
                if let pdfError = error as? PDFReaderError {
                    deferredReaderError = pdfError
                }
            }
        }
        self.coordinator = resolvedCoordinator

        // 2. Build the page-change observer. The relay breaks the
        //    Swift init-order cycle: the observer's closures capture
        //    the relay (a local) rather than `self`, so the observer
        //    can be assigned to a stored property before all stored
        //    properties are initialized. The relay's `viewModel`
        //    weak reference is bound to `self` only after the init
        //    completes.
        let relay = ObserverRelay()
        self.observer = PDFPageChangeObserver(
            document: document,
            modelContext: modelContext,
            captureOutgoingDrawing: { pageIndex in
                relay.captureOutgoingDrawing(forPage: pageIndex)
            },
            pageActivated: { pageIndex in
                relay.activate(pageIndex: pageIndex)
            }
        )
        relay.viewModel = self

        // 3. Surface any deferred reader error now that all stored
        //    properties are initialized.
        if let deferredReaderError {
            self.readerError = deferredReaderError
        }
    }

    // MARK: - Lifecycle

    /// Subscribes to `.PDFViewPageChanged` and primes the canvas
    /// against page 0. Idempotent — calling `start()` twice has no
    /// effect after the first call.
    func start() {
        attachPDFPageChangeObserver()
        if overlay == nil {
            activate(pageIndex: 0)
        }
    }

    /// Tears down the `.PDFViewPageChanged` observer. The SwiftUI
    /// view layer's `.onDisappear` calls this so the reader surface
    /// does not leak notifications across navigation pops.
    func stop() {
        if let token = pdfPageObserver {
            NotificationCenter.default.removeObserver(token)
            pdfPageObserver = nil
        }
    }

    // MARK: - Page-change pipeline

    /// Subscribes to `.PDFViewPageChanged` and forwards the
    /// `currentPage`'s index into `pageChangePublisher`. Single
    /// subscription point — the SwiftUI `.onReceive` consumes the
    /// publisher, and the view model consumes its own emissions to
    /// drive the observer. The notification name is resolved by
    /// literal string so the container does not have to import
    /// `PDFKit` (the container only uses the coordinator's `pdfView`
    /// as a typed reference; it never names a `PDFKit` symbol).
    private func attachPDFPageChangeObserver() {
        if pdfPageObserver != nil { return }
        guard let pdfView = coordinator?.pdfView else { return }
        let pageChangedName = Notification.Name(rawValue: "PDFViewPageChanged")
        let token = NotificationCenter.default.addObserver(
            forName: pageChangedName,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter delivers this block on the main
            // queue (because we passed `queue: .main`), but the
            // block must still be `@Sendable` and the view model's
            // main-actor-isolated state has to be touched through a
            // `Task { @MainActor in ... }` so the actor isolation
            // check passes at build time.
            Task { @MainActor [weak self] in
                guard let self else { return }
                let index = self.currentPDFPageIndex()
                self.pageChangePublisher.send(index)
            }
        }
        pdfPageObserver = token
    }

    /// Resolves the coordinator's `PDFView.currentPage` to a
    /// 0-indexed page index. Returns the cached `currentPageIndex` if
    /// the PDFView hasn't resolved `currentPage` yet (the first
    /// render cycle races with the view tree mount).
        private func currentPDFPageIndex() -> Int {
            guard let pdfView = coordinator?.pdfView else { return currentPageIndex }
            if let page = pdfView.currentPage,
               let document = pdfView.document {
                return document.index(for: page)
            }
            return currentPageIndex
        }

    /// Drives one page-change cycle through the observer. The
    /// observer value-coalesces on `newPageIndex`, captures the
    /// outgoing page's drawing, and activates the incoming page's
    /// overlay drawing.
    func handlePageChange(to newPageIndex: Int) {
        if newPageIndex == currentPageIndex { return }
        observer.handlePageChange(to: newPageIndex)
        currentPageIndex = newPageIndex
    }

    // MARK: - Overlay seam

    /// Activates the supplied page index on the overlay — mounts the
    /// overlay against the lazy-upserted `PageAnnotation` for that
    /// page and replaces the canvas's drawing with the persisted one.
    func activate(pageIndex: Int) {
        // 1. Capture the outgoing drawing (if any) onto the outgoing
        //    PageAnnotation. Without this manual flush, a fast
        //    navigation leaves the most recent strokes on the in-memory
        //    canvas only.
        captureAndPersistIfNeeded(forPageIndex: pageIndex)

        // 2. Build (or rebuild) the overlay against the incoming
        //    page's `PageAnnotation`.
        let annotation = observer.annotation(forPage: pageIndex)
        let newOverlay = PencilCanvasOverlay(
            pageIndex: pageIndex,
            pageAnnotation: annotation,
            document: document,
            modelContext: modelContext
        )
        overlay = newOverlay
        currentPageIndex = pageIndex
        liveCanvas = nil
    }

    /// Returns the canvas currently mounted on the overlay. Test
    /// surface only — production callers should let SwiftUI own the
    /// canvas lifetime.
    func makeLiveCanvas() -> PKCanvasView {
        if overlay == nil {
            activate(pageIndex: currentPageIndex)
        }
        if liveCanvas == nil {
            liveCanvas = overlay?.makeCanvasView()
        }
        return liveCanvas ?? PKCanvasView()
    }

    /// Captures the canvas's current drawing so the observer can
    /// persist it on the outgoing page. The closure is invoked once
    /// per `handlePageChange(to:)` that advances the page.
    func captureCurrentDrawing() -> PKDrawing? {
        guard let overlay else { return nil }
        // Use the canvas's `drawing` if we have one mounted; fall
        // back to the persisted `PageAnnotation.drawingData` so the
        // observer still has the right bytes after the canvas tore
        // down.
        if let canvas = liveCanvas {
            return canvas.drawing
        }
        return overlay.replayDrawing()
    }

    /// Persists the live canvas's drawing onto the active
    /// `PageAnnotation.drawingData` and saves the SwiftData store.
    /// The integration test exercises this via `overlayHook.persist()`;
    /// production code paths through the overlay's
    /// `canvasViewDrawingDidChange` callback. Internal access
    /// because the integration test invokes this seam directly.
    func persistCurrentDrawingOnCanvas() {
        guard let canvas = liveCanvas,
              let annotation = overlay?.pageAnnotationRef else { return }
        annotation.drawingData = canvas.drawing.dataRepresentation()
        do {
            try modelContext.save()
        } catch {
            annotationError = .drawingPersistenceFailed(underlying: error)
        }
    }

    /// Captures-and-persists the canvas's drawing onto the outgoing
    /// `PageAnnotation` when the reader is moving away from a page.
    /// This is the seam the observer's `captureOutgoingDrawing`
    /// closure already covers — but for the integration test (which
    /// drives navigation explicitly without invoking
    /// `canvasViewDrawingDidChange`) we need an extra flush so the
    /// outgoing page's `drawingData` reflects the latest canvas
    /// bytes before the observer captures.
    private func captureAndPersistIfNeeded(forPageIndex newPageIndex: Int) {
        guard let canvas = liveCanvas,
              let currentOverlay = overlay,
              let annotation = currentOverlay.pageAnnotationRef,
              currentOverlay.pageIndex != newPageIndex else {
            return
        }
        annotation.drawingData = canvas.drawing.dataRepresentation()
        do {
            try modelContext.save()
        } catch {
            annotationError = .drawingPersistenceFailed(underlying: error)
        }
    }

    // MARK: - Error clearing

    /// Clears the recoverable reader error. Bound to the banner's
    /// dismiss action.
    func clearReaderError() {
        readerError = nil
    }

    /// Clears the recoverable annotation error. Bound to the banner's
    /// dismiss action.
    func clearAnnotationError() {
        annotationError = nil
    }

    // MARK: - Placeholder coordinator

    /// Builds a placeholder coordinator whose `PDFView` has no
    /// document, so SwiftUI can build the representable while the
    /// recoverable banner is on screen. The placeholder surfaces
    /// nothing useful and is replaced as soon as the real
    /// coordinator's `pdfView` is mounted (e.g. on retry).
    private static func makePlaceholderCoordinator(
        document: DocumentItem,
        modelContext: ModelContext
    ) -> PDFReaderCoordinator? {
            try? PDFReaderCoordinator(
                document: document,
                modelContext: modelContext,
                bundle: Bundle(for: ReaderContainerViewModel.self),
                resourceName: "missing-fixture-placeholder",
                resourceExtension: "pdf"
            )
    }
}

// MARK: - Test seams

/// Relay that breaks the Swift init-order cycle between
/// `PDFPageChangeObserver` and `ReaderContainerViewModel`. The
/// observer's closures capture this relay (a local during init) and
/// the relay's weak view-model reference is bound to `self` only
/// after all stored properties are initialized.
@MainActor
final class ObserverRelay {

    /// The view model the relay forwards observer callbacks to. Weak
    /// so the relay never extends the view model's lifetime beyond
    /// its usual SwiftUI render-tree owner.
    weak var viewModel: ReaderContainerViewModel?

    /// Builds an empty relay. The view model is bound at the end of
    /// the view model's `init` so the relay can hand closures to
    /// `PDFPageChangeObserver.init(...)` before `self` is fully
    /// initialized.
    init() {}

    /// Forwards the observer's outgoing-page capture closure to the
    /// view model.
    func captureOutgoingDrawing(forPage pageIndex: Int) -> PKDrawing? {
        viewModel?.captureCurrentDrawing()
    }

    /// Forwards the observer's incoming-page activation closure to
    /// the view model.
    func activate(pageIndex: Int) {
        viewModel?.activate(pageIndex: pageIndex)
    }
}

/// Sink the integration test uses to simulate page changes without
/// subscribing to `.PDFViewPageChanged`. The sink delegates back to
/// `handlePageChange(to:)` so the same value-coalescing contract the
/// production `NotificationCenter` pipeline guarantees applies in
/// tests.
@MainActor
final class PageChangeSink {

    /// The closure called when the integration test simulates a page
    /// change.
    private let onSimulatedChange: (Int) -> Void

    /// Builds the sink against the supplied callback.
    init(onSimulatedChange: @escaping (Int) -> Void) {
        self.onSimulatedChange = onSimulatedChange
    }

    /// Drives the simulated page change through the view model's
    /// handler.
    func simulatePageChange(to pageIndex: Int) {
        onSimulatedChange(pageIndex)
    }
}

/// Test-side hook for the overlay. Lets the integration test drive
/// the canvas (`replaceDrawing`) and persist the bytes
/// (`persistCurrentDrawing`) without going through SwiftUI's
/// `canvasViewDrawingDidChange` callback chain. Construction is
/// cheap; the hook is built lazily by the view model.
@MainActor
final class OverlayHook {

    /// Closure that returns the live `PKCanvasView` (or `nil` if no
    /// canvas is mounted). Captured by the integration test so it
    /// can author strokes via `replaceDrawing(_:)`.
    private let canvasProvider: () -> PKCanvasView?

    /// Closure that flushes the in-memory canvas's drawing to the
    /// active `PageAnnotation.drawingData` (the same persistence
    /// path the production `canvasViewDrawingDidChange` callback
    /// hits). The integration test calls this to drive the byte
    /// equality assertion in `ReaderIntegrationTests`.
    private let persist: () -> Void

    /// Builds the hook against the supplied closures.
    init(canvasProvider: @escaping () -> PKCanvasView?, persist: @escaping () -> Void) {
        self.canvasProvider = canvasProvider
        self.persist = persist
    }

    /// Replaces the canvas's drawing with the supplied
    /// `PKDrawing`. Mirrors the path SwiftUI takes when the reader
    /// makes a stroke.
    func replaceDrawing(_ drawing: PKDrawing) {
        guard let canvas = canvasProvider() else { return }
        canvas.drawing = drawing
    }

    /// Flushes the in-memory drawing to the active
    /// `PageAnnotation.drawingData`. Mirrors the production
    /// `canvasViewDrawingDidChange` callback's persistence path.
    func persistCurrentDrawing() {
        persist()
    }
}

// MARK: - SwiftUI sub-views

/// Recoverable-error banner for `PDFReaderError` cases. The banner
/// shows the error message and a dismiss action.
@MainActor
struct ReaderErrorBanner: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.large)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

/// Recoverable-error banner for `AnnotationError` cases.
@MainActor
struct AnnotationErrorBanner: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pencil.tip.crop.circle.badge.exclamationmark")
                .imageScale(.large)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

/// Floating pagination-mode toggle. Bound to the container's
/// `paginationMode`; setting the binding writes through the
/// coordinator's `paginationMode` setter.
@MainActor
struct PaginationModeToggle: View {

    /// The mode binding. Reads return the coordinator's current
    /// value; writes propagate to `viewModel.paginationMode = $0` and
    /// through the coordinator's `modelContext.save()`.
    @Binding var mode: PDFReaderCoordinator.PaginationMode

    var body: some View {
        HStack(spacing: 8) {
            Button {
                mode = .horizontal
            } label: {
                Image(systemName: "rectangle.split.1x2")
                    .imageScale(.large)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Horizontal pagination")
            .accessibilityValue(mode == .horizontal ? "Selected" : "")

            Button {
                mode = .vertical
            } label: {
                Image(systemName: "rectangle.split.3x1")
                    .imageScale(.large)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Vertical pagination")
            .accessibilityValue(mode == .vertical ? "Selected" : "")
        }
    }
}

#if DEBUG
#Preview("PDF reader — two-page integration") {
    let container = PreviewContainer.previewContainer
    let context = container.mainContext
    let document: DocumentItem = {
        let descriptor = FetchDescriptor<DocumentItem>()
        if let existing = (try? context.fetch(descriptor).first) {
            return existing
        }
        let new = DocumentItem()
        context.insert(new)
        return new
    }()
    return ReaderContainerView(
        document: document,
        modelContext: context
    )
    .modelContainer(container)
}
#endif
