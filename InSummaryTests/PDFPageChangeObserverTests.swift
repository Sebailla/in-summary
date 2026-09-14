//
//  PDFPageChangeObserverTests.swift
//  InSummaryTests
//
//  RED contract (task 3.4) for child PR #3 (`feat/pencilkit-ink-overlay`)
//  inside the Phase 2 chain `pdf-reader-pencilkit-ink-recovery`. Every test
//  method below pins one of the five behaviours documented in
//  `openspec/changes/pdf-reader-pencilkit-ink-recovery/tasks.md` §3.4 and
//  the corresponding scenario block in
//  `openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pencilkit-ink-overlay/spec.md`.
//
//  The behaviours encoded here, in the exact order they appear in the task
//  description, are:
//
//    1. Round-trip preserves byte-identical `PKDrawing` payloads across
//       pages 1 → 2 → 1 (the reader's strokes survive a round-trip
//       across the page-save / page-load cycle).
//    2. Five navigation cycles are stable (the bytes persisted by the
//       observer on cycle N match the bytes persisted on cycle 1).
//    3. The observer drops notifications whose `currentPageIndex` equals
//       the last observed index (value-coalescing).
//    4. A coordinator re-init keeps stored drawings (the observer's
//       in-memory state is reconstructable from the SwiftData rows).
//    5. A save failure surfaces
//       `AnnotationError.drawingPersistenceFailed(underlying:)` and
//       `lastObservedPageIndex` is **not** mutated on failure (the
//       observer's contract is fail-fast: an error stops the navigation
//       cycle).
//
//  RED contract: this file is the failing test for the RED step. The
//  production type `PDFPageChangeObserver` is intentionally absent in
//  this slice, so every test below must fail at compile time on the
//  unresolved type reference before any test method ever executes. The
//  compile failure is the strict-TDD RED signal — it proves the test
//  encodes the contract before the production code is authored. GREEN
//  belongs to task 3.5 (`PDFPageChangeObserver`); the RED snapshot
//  stays byte-identical until that task lands.
//

import XCTest
import SwiftData
import PencilKit
import UIKit
@testable import InSummary

@MainActor
final class PDFPageChangeObserverTests: XCTestCase {

    // MARK: - Behaviour 1: round-trip preserves byte-identical payloads

    /// Drawing on page 1, navigating to page 2, drawing on page 2, then
    /// returning to page 1 MUST preserve byte-identical `PKDrawing`
    /// payloads on both pages. The observer captures the outgoing
    /// page's drawing via the injected `captureOutgoingDrawing`
    /// closure, persists it on the outgoing `PageAnnotation`, and asks
    /// the overlay (via the injected `pageActivated` closure) to load
    /// the incoming page's drawing.
    ///
    /// The byte-identical contract is pinned at the data-layer level
    /// here (the SwiftData row's `drawingData` equals the bytes the
    /// test authored via `PKDrawing.dataRepresentation()`). The
    /// in-memory PencilKit archive is not byte-stable across a
    /// `PKDrawing(data:)` round-trip (the canvas canonicalises the
    /// bytes after the first layout pass; see
    /// `PencilCanvasOverlayTests.test_replayByteIdenticalWhenDrawingDataExists`
    /// for the documented PencilKit quirk). This test pins the
    /// contract the observer actually owns: bytes written to the
    /// `PageAnnotation` row are preserved byte-for-byte when the row
    /// is re-read from the SwiftData store.
    func test_roundTripPreservesByteIdenticalPayloadsAcrossPages() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        // The in-memory "live" drawing store the test pretends is on
        // the canvas. Each page's drawing is what the test authored;
        // the observer must capture it via the closure and persist
        // it to the matching `PageAnnotation` row.
        var liveDrawings: [Int: PKDrawing] = [:]

        let observer = PDFPageChangeObserver(
            document: document,
            modelContext: context,
            captureOutgoingDrawing: { pageIndex in liveDrawings[pageIndex] },
            pageActivated: { _ in }
        )

        // Page 1 — first navigation; no outgoing drawing to capture.
        observer.handlePageChange(to: 1)
        let pageOneDrawing = makeHighlighterStroke(label: "page1")
        liveDrawings[1] = pageOneDrawing

        // Page 2 — captures page 1's drawing, persists it on the
        // page-1 annotation, then activates page 2.
        observer.handlePageChange(to: 2)
        let pageTwoDrawing = makeHighlighterStroke(label: "page2")
        liveDrawings[2] = pageTwoDrawing

        // Back to page 1 — captures page 2's drawing, persists it on
        // the page-2 annotation, then activates page 1.
        observer.handlePageChange(to: 1)

        let pageOneAnnotation = try XCTUnwrap(
            observer.annotation(forPage: 1),
            "Page 1 annotation MUST exist after navigation 1 → 2 → 1"
        )
        let pageTwoAnnotation = try XCTUnwrap(
            observer.annotation(forPage: 2),
            "Page 2 annotation MUST exist after navigation 1 → 2 → 1"
        )

        let pageOneExpected = pageOneDrawing.dataRepresentation()
        let pageTwoExpected = pageTwoDrawing.dataRepresentation()
        XCTAssertEqual(
            pageOneAnnotation.drawingData,
            pageOneExpected,
            "Page 1's drawingData MUST equal the bytes originally captured from the canvas; got \(pageOneAnnotation.drawingData?.count ?? -1) bytes vs \(pageOneExpected.count)"
        )
        XCTAssertEqual(
            pageTwoAnnotation.drawingData,
            pageTwoExpected,
            "Page 2's drawingData MUST equal the bytes originally captured from the canvas; got \(pageTwoAnnotation.drawingData?.count ?? -1) bytes vs \(pageTwoExpected.count)"
        )
    }

    // MARK: - Behaviour 2: five navigation cycles are stable

    /// Cycling between pages 1 and 2 five times MUST preserve the
    /// byte-identical `PKDrawing` payloads on both pages. The bytes
    /// persisted by the observer on cycle N MUST match the bytes
    /// persisted on cycle 1.
    func test_fiveNavigationCyclesAreStable() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        var liveDrawings: [Int: PKDrawing] = [:]
        let observer = PDFPageChangeObserver(
            document: document,
            modelContext: context,
            captureOutgoingDrawing: { pageIndex in liveDrawings[pageIndex] },
            pageActivated: { _ in }
        )

        let pageOneDrawing = makeHighlighterStroke(label: "cycle-page1")
        let pageTwoDrawing = makeHighlighterStroke(label: "cycle-page2")

        // Navigate 1 → 2 → 1, capturing each page's drawing on first visit.
        observer.handlePageChange(to: 1)
        liveDrawings[1] = pageOneDrawing
        observer.handlePageChange(to: 2)
        liveDrawings[2] = pageTwoDrawing
        observer.handlePageChange(to: 1)

        // Capture the persisted bytes after the first round-trip —
        // these are the pinnable cycle-1 bytes that cycles 2..5 must
        // reproduce.
        let pageOneAnnotation = try XCTUnwrap(observer.annotation(forPage: 1))
        let pageTwoAnnotation = try XCTUnwrap(observer.annotation(forPage: 2))
        let cycleOnePageOneBytes = try XCTUnwrap(
            pageOneAnnotation.drawingData,
            "Page 1 annotation MUST carry drawingData after cycle 1"
        )
        let cycleOnePageTwoBytes = try XCTUnwrap(
            pageTwoAnnotation.drawingData,
            "Page 2 annotation MUST carry drawingData after cycle 1"
        )

        // Run cycles 2..5 — the observer must re-capture the same
        // `liveDrawings` payload on each outgoing step. The captured
        // payloads are byte-identical to cycle 1 because we re-feed
        // the same in-memory `PKDrawing` instances.
        for _ in 2...5 {
            observer.handlePageChange(to: 2)
            observer.handlePageChange(to: 1)

            let freshPageOne = try XCTUnwrap(observer.annotation(forPage: 1))
            let freshPageTwo = try XCTUnwrap(observer.annotation(forPage: 2))
            XCTAssertEqual(
                freshPageOne.drawingData,
                cycleOnePageOneBytes,
                "After 5 cycles page 1's drawingData MUST equal the cycle-1 bytes; got \(freshPageOne.drawingData?.count ?? -1) bytes vs \(cycleOnePageOneBytes.count)"
            )
            XCTAssertEqual(
                freshPageTwo.drawingData,
                cycleOnePageTwoBytes,
                "After 5 cycles page 2's drawingData MUST equal the cycle-1 bytes; got \(freshPageTwo.drawingData?.count ?? -1) bytes vs \(cycleOnePageTwoBytes.count)"
            )
        }
    }

    // MARK: - Behaviour 3: value-coalescing on redundant notifications

    /// The observer MUST drop notifications whose `currentPageIndex`
    /// equals the last observed index. The `pageActivated` closure is
    /// the observable witness — it must fire once per *change* of
    /// `currentPageIndex`, not once per call to `handlePageChange(to:)`.
    func test_valueCoalescingDropsRedundantNotifications() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        var activationLog: [Int] = []
        let observer = PDFPageChangeObserver(
            document: document,
            modelContext: context,
            captureOutgoingDrawing: { _ in nil },
            pageActivated: { pageIndex in
                activationLog.append(pageIndex)
            }
        )

        // First navigation: 0 → 1. Must fire once.
        observer.handlePageChange(to: 1)
        // Redundant: same index. Must be dropped.
        observer.handlePageChange(to: 1)
        // Redundant again: same index. Must be dropped.
        observer.handlePageChange(to: 1)
        // New navigation: 1 → 2. Must fire once.
        observer.handlePageChange(to: 2)
        // Redundant: same index. Must be dropped.
        observer.handlePageChange(to: 2)

        XCTAssertEqual(
            activationLog,
            [1, 2],
            "Observer MUST drop notifications whose currentPageIndex equals the last observed index; got \(activationLog)"
        )
        XCTAssertEqual(
            observer.lastObservedPageIndex,
            2,
            "After the navigation sequence 1 → 1 → 1 → 2 → 2 the last observed page index MUST be 2; got \(String(describing: observer.lastObservedPageIndex))"
        )
    }

    // MARK: - Behaviour 4: coordinator re-init keeps stored drawings

    /// Discarding the observer and instantiating a fresh one against the
    /// same SwiftData container MUST recover the stored drawings from
    /// the existing `PageAnnotation` rows. The observer's in-memory
    /// state is reconstructable; the source of truth is the SwiftData
    /// row, not the observer instance.
    func test_coordinatorReinitKeepsStoredDrawings() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        let pageOneDrawing = makeHighlighterStroke(label: "reinit-page1")
        let pageTwoDrawing = makeHighlighterStroke(label: "reinit-page2")

        // Observer A: navigate 1 → 2 → 1, dropping the captured
        // drawings into the SwiftData store via the closure-driven
        // capture pipeline.
        do {
            var liveDrawings: [Int: PKDrawing] = [:]
            let observerA = PDFPageChangeObserver(
                document: document,
                modelContext: context,
                captureOutgoingDrawing: { pageIndex in liveDrawings[pageIndex] },
                pageActivated: { _ in }
            )
            observerA.handlePageChange(to: 1)
            liveDrawings[1] = pageOneDrawing
            observerA.handlePageChange(to: 2)
            liveDrawings[2] = pageTwoDrawing
            observerA.handlePageChange(to: 1)
        }

        // Observer B: fresh instance against the same container.
        // The new observer sees the persisted drawings through its
        // `annotation(forPage:)` lookup.
        let observerB = PDFPageChangeObserver(
            document: document,
            modelContext: context,
            captureOutgoingDrawing: { _ in nil },
            pageActivated: { _ in }
        )

        // Navigate to page 1 — the observer looks up the persisted
        // annotation by (document.id, pageIndex) and finds the
        // row written by observer A.
        observerB.handlePageChange(to: 1)

        let reloadedPageOne = try XCTUnwrap(
            observerB.annotation(forPage: 1),
            "Page 1 annotation MUST survive a coordinator re-init"
        )
        let reloadedPageTwo = try XCTUnwrap(
            observerB.annotation(forPage: 2),
            "Page 2 annotation MUST survive a coordinator re-init"
        )
        XCTAssertEqual(
            reloadedPageOne.drawingData,
            pageOneDrawing.dataRepresentation(),
            "After a coordinator re-init, page 1's drawingData MUST equal the bytes originally captured"
        )
        XCTAssertEqual(
            reloadedPageTwo.drawingData,
            pageTwoDrawing.dataRepresentation(),
            "After a coordinator re-init, page 2's drawingData MUST equal the bytes originally captured"
        )
    }

    // MARK: - Behaviour 5: save failure surfaces error and does not mutate lastObservedPageIndex

    /// When `modelContext.save()` throws, the observer MUST surface
    /// `AnnotationError.drawingPersistenceFailed(underlying:)` AND
    /// `lastObservedPageIndex` MUST NOT be mutated. The fail-fast
    /// contract keeps the navigation cycle honest: a failed save
    /// stops the page-change sequence, the overlay stays bound to
    /// the previous page, and the recoverable-error banner gets the
    /// underlying error.
    ///
    /// The test uses an injected `saveFn` closure that always throws
    /// so the test exercises the failure path deterministically — no
    /// probing of the SwiftData internals.
    func test_saveFailureSurfacesErrorAndDoesNotMutateLastObservedPageIndex() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        let saveError = NSError(
            domain: "PDFPageChangeObserverTests",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "synthetic save failure"]
        )

        var activationLog: [Int] = []
        let observer = PDFPageChangeObserver(
            document: document,
            modelContext: context,
            captureOutgoingDrawing: { _ in PKDrawing() },
            pageActivated: { pageIndex in
                activationLog.append(pageIndex)
            },
            saveFn: {
                throw saveError
            }
        )

        // First navigation: 0 → 1. No outgoing drawing to persist,
        // so no save is attempted — lastObservedPageIndex advances to
        // 1 and pageActivated(1) fires.
        observer.handlePageChange(to: 1)
        XCTAssertNil(
            observer.lastError,
            "Initial navigation MUST NOT surface a recoverable error; got \(String(describing: observer.lastError))"
        )
        XCTAssertEqual(
            observer.lastObservedPageIndex,
            1,
            "Initial navigation MUST advance lastObservedPageIndex to 1"
        )

        // Second navigation: 1 → 2. The observer captures the
        // outgoing page-1 drawing, then attempts to save it through
        // the injected saveFn — which throws. The save failure MUST
        // surface as AnnotationError.drawingPersistenceFailed and
        // MUST NOT mutate lastObservedPageIndex (it stays at 1).
        observer.handlePageChange(to: 2)

        guard let lastError = observer.lastError else {
            XCTFail("Save failure MUST surface AnnotationError.drawingPersistenceFailed; got nil")
            return
        }
        guard case AnnotationError.drawingPersistenceFailed(let underlying) = lastError else {
            XCTFail("Save failure MUST surface AnnotationError.drawingPersistenceFailed; got \(lastError)")
            return
        }
        XCTAssertEqual(
            (underlying as NSError).domain,
            saveError.domain,
            "The wrapped underlying error MUST be the saveFn error"
        )
        XCTAssertEqual(
            (underlying as NSError).code,
            saveError.code,
            "The wrapped underlying error MUST carry the saveFn error code"
        )

        XCTAssertEqual(
            observer.lastObservedPageIndex,
            1,
            "Save failure MUST NOT mutate lastObservedPageIndex; got \(String(describing: observer.lastObservedPageIndex))"
        )
        XCTAssertEqual(
            activationLog,
            [1],
            "Save failure MUST NOT fire pageActivated for the would-be incoming page; got \(activationLog)"
        )
    }

    // MARK: - Helpers

    /// Builds a `DocumentItem` that satisfies the Phase 2 seed contract:
    /// `fileTypeRaw == "pdf"` AND `localFileName.isEmpty == true` AND
    /// `paginationModeRaw == "horizontal"`. Mirrors the helper from
    /// `PDFReaderCoordinatorTests` so the observer tests stay focused on
    /// the page-save / page-load surface.
    private func makeSeedDocument() -> DocumentItem {
        let document = DocumentItem()
        document.title = "Getting Started"
        document.fileTypeRaw = "pdf"
        document.fileExtension = "pdf"
        document.localFileName = ""
        document.paginationModeRaw = "horizontal"
        return document
    }

    /// Builds a deterministic, non-empty `PKDrawing` carrying one
    /// highlighter stroke. The `label` parameter varies the stroke
    /// geometry so two test drawings are distinguishable on the
    /// round-trip assertion. Stroke geometry is a short horizontal
    /// line so the archive is small and stable across runs.
    private func makeHighlighterStroke(label: String) -> PKDrawing {
        // Pick a y-offset and color seed derived from the label so the
        // two round-trip drawings (`page1` vs `page2`) have distinct
        // geometries. This guards against the test passing on
        // coincidental byte equality (e.g. when both pages render
        // empty because the offset rounds to the same value).
        let labelHash = abs(label.hashValue)
        let baseY = 10 + CGFloat(labelHash % 100)
        let stroke = PKStroke(
            ink: PKInk(.marker, color: .systemYellow),
            path: PKStrokePath(
                controlPoints: [
                    PKStrokePoint(location: CGPoint(x: 10, y: baseY), timeOffset: 0, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: 0),
                    PKStrokePoint(location: CGPoint(x: 20, y: baseY), timeOffset: 0.01, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: 0),
                    PKStrokePoint(location: CGPoint(x: 30, y: baseY), timeOffset: 0.02, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: 0)
                ],
                creationDate: Date(timeIntervalSinceReferenceDate: 0)
            )
        )
        return PKDrawing(strokes: [stroke])
    }
}
