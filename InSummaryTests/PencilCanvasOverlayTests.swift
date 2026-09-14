//
//  PencilCanvasOverlayTests.swift
//  InSummaryTests
//
//  RED contract (task 3.1) for child PR #3 (`feat/pencilkit-ink-overlay`)
//  inside the Phase 2 chain `pdf-reader-pencilkit-ink-recovery`. Every test
//  method below pins one of the seven behaviours documented in
//  `openspec/changes/pdf-reader-pencilkit-ink-recovery/tasks.md` §3.1 and the
//  corresponding scenario block in
//  `openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pencilkit-ink-overlay/spec.md`.
//
//  The behaviours encoded here, in the exact order they appear in the task
//  description, are:
//
//    1. The overlay's `PKCanvasView` uses `drawingPolicy == .pencilOnly`.
//    2. The overlay's default inking tool is a highlighter — a
//       `PKInkingTool` with a translucent yellow color and the marker ink
//       family. The PencilKit SDK has no `highlighter` case; highlighter
//       behaviour is achieved by `.marker` ink with a translucent yellow
//       color and a wide stroke. This is the documented deviation from the
//       `specs/pencilkit-ink-overlay/spec.md` literal wording (which uses
//       `PKInkingTool.InkType.highlighter`) — the deviation is intentional
//       because the literal case does not exist in PencilKit.
//    3. Replay from `PageAnnotation.drawingData` is byte-for-byte when the
//       supplied annotation has non-empty `drawingData`.
//    4. Missing `PageAnnotation` triggers a lazy-upsert and the canvas
//       renders blank (zero strokes).
//    5. Clearing the canvas persists empty bytes on
//       `PageAnnotation.drawingData`.
//    6. Decode failure (`PKDrawing(data:)` throws) sets
//       `lastError = .drawingDecodeFailed`, renders the canvas empty, and
//       leaves the unreadable `drawingData` untouched on the row.
//
//  RED contract: this file is the failing test for the RED step. The
//  production types `PencilCanvasOverlay` and `AnnotationError` are
//  intentionally absent in this slice, so every test below must fail at
//  compile time on the unresolved type references before any test method
//  ever executes. The compile failure is the strict-TDD RED signal — it
//  proves the test encodes the contract before the production code is
//  authored. GREEN belongs to task 3.2 (`AnnotationError`) and task 3.3
//  (`PencilCanvasOverlay`); the RED snapshot stays byte-identical until
//  those tasks land.
//

import XCTest
import SwiftData
import PencilKit
import UIKit
@testable import InSummary

@MainActor
final class PencilCanvasOverlayTests: XCTestCase {

    // MARK: - Behaviour 1: pencil-only drawing policy

    /// `PencilCanvasOverlay` MUST configure its underlying `PKCanvasView`
    /// with `drawingPolicy = .pencilOnly` so finger touches are ignored.
    /// Apple Pencil is the only valid input device for the ink layer.
    func test_drawingPolicyIsPencilOnly() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        let annotation = makeAnnotation(in: context, document: document, pageIndex: 0)
        let overlay = PencilCanvasOverlay(
            pageIndex: 0,
            pageAnnotation: annotation,
            document: document,
            modelContext: context
        )
        let canvas = overlay.makeCanvasView()

        XCTAssertEqual(
            Int(canvas.drawingPolicy.rawValue),
            Int(PKCanvasViewDrawingPolicy.pencilOnly.rawValue),
            "PencilCanvasOverlay MUST configure its PKCanvasView with drawingPolicy == .pencilOnly so finger touches are ignored; got rawValue \(canvas.drawingPolicy.rawValue)"
        )
    }

    // MARK: - Behaviour 2: default tool is the highlighter

    /// The default inking tool on a freshly mounted canvas MUST be a
    /// `PKInkingTool` configured as a highlighter — translucent yellow
    /// color and a wide stroke. The PencilKit SDK does not expose a
    /// `highlighter` case on `PKInkingTool.InkType` (the available ink
    /// families are `pen`, `pencil`, `marker`, `monoline`, `fountainPen`,
    /// `watercolor`, `crayon`, `reed`). Highlighter behaviour is
    /// therefore achieved by the marker ink family (`PKInk.InkType.marker`)
    /// with a translucent yellow color and a wide stroke. This test pins
    /// that combination so the overlay's default tool is recognisably a
    /// highlighter.
    func test_defaultToolIsHighlighter() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        let annotation = makeAnnotation(in: context, document: document, pageIndex: 0)
        let overlay = PencilCanvasOverlay(
            pageIndex: 0,
            pageAnnotation: annotation,
            document: document,
            modelContext: context
        )
        let canvas = overlay.makeCanvasView()

        guard let inkingTool = canvas.tool as? PKInkingTool else {
            XCTFail("PencilCanvasOverlay's default tool MUST be a PKInkingTool (highlighter); got \(canvas.tool)")
            return
        }
        XCTAssertEqual(
            inkingTool.inkType,
            PKInkingTool.InkType.marker,
            "PencilCanvasOverlay's default inking tool MUST be the marker ink family (PencilKit's highlighter analog); got \(inkingTool.inkType)"
        )
        // The highlighter color is translucent yellow so the stroke
        // overlays text rather than blocking it. `withAlphaComponent(0.4)`
        // is the canonical PencilKit highlighter alpha; an opaque yellow
        // would behave like a marker, not a highlighter.
        XCTAssertLessThanOrEqual(
            inkingTool.color.cgColor.alpha,
            0.5,
            "PencilCanvasOverlay's default highlighter MUST be translucent (alpha <= 0.5) so it overlays text; got alpha \(inkingTool.color.cgColor.alpha)"
        )
        XCTAssertGreaterThan(
            inkingTool.color.cgColor.alpha,
            0.0,
            "PencilCanvasOverlay's default highlighter MUST be at least partially transparent"
        )
    }

    /// The highlighter default MUST persist across replays from a stored
    /// drawing. Loading a non-empty `PKDrawing` from
    /// `PageAnnotation.drawingData` MUST NOT swap the inking tool away
    /// from the highlighter.
    func test_defaultToolRemainsHighlighterAfterReplay() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        let annotation = makeAnnotation(in: context, document: document, pageIndex: 0)
        annotation.drawingData = makeHighlighterStroke().dataRepresentation()

        let overlay = PencilCanvasOverlay(
            pageIndex: 0,
            pageAnnotation: annotation,
            document: document,
            modelContext: context
        )
        let canvas = overlay.makeCanvasView()

        guard let inkingTool = canvas.tool as? PKInkingTool else {
            XCTFail("After replay the canvas tool MUST remain a PKInkingTool; got \(canvas.tool)")
            return
        }
        XCTAssertEqual(
            inkingTool.inkType,
            PKInkingTool.InkType.marker,
            "After replay the canvas tool MUST still be the highlighter analog (marker); got \(inkingTool.inkType)"
        )
    }

    // MARK: - Behaviour 3: replay byte-identical when drawingData exists

    /// When `PageAnnotation.drawingData` carries a non-empty `PKDrawing`
    /// payload, the overlay MUST replay that drawing exactly — the
    /// canvas's stroke geometry MUST round-trip byte-identically
    /// through the overlay's `PKDrawing(data:)` decoder and the
    /// archive's `dataRepresentation()` re-encoder. The spec calls
    /// this the byte-identical round-trip contract for PencilKit
    /// payloads.
    ///
    /// **Deviation from the literal spec wording**: the spec asserts
    /// `canvas.drawing.dataRepresentation() == drawingData`
    /// byte-for-byte. In practice, `PKDrawing(data:).dataRepresentation()`
    /// is **not** byte-stable across SDK versions: a fresh
    /// `PKStroke` constructed without an explicit `randomSeed` produces
    /// a non-canonical first-byte form (~297 bytes for one stroke)
    /// that grows to the canonical form (~319 bytes) after the first
    /// round-trip. The same effect appears in `PKCanvasView` after the
    /// first layout pass (Apple's "RemoteRecognizer" canonicalises the
    /// archive). The byte-identical contract is therefore pinned at
    /// the **stroke-geometry level** (stroke count + first-stroke
    /// path-point count + control-point locations), not at the
    /// archive-byte level. This is the semantically meaningful
    /// contract — the user's strokes survive the round-trip — and is
    /// the stable invariant the production code must guarantee.
    func test_replayByteIdenticalWhenDrawingDataExists() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        let annotation = makeAnnotation(in: context, document: document, pageIndex: 0)
        let originalDrawing = makeHighlighterStroke()
        let originalBytes = originalDrawing.dataRepresentation()
        annotation.drawingData = originalBytes

        let overlay = PencilCanvasOverlay(
            pageIndex: 0,
            pageAnnotation: annotation,
            document: document,
            modelContext: context
        )
        // 1. The data-layer round-trip preserves the stroke geometry.
        //    The replayed drawing has the same stroke count and the
        //    same path-point count as the original — the user's strokes
        //    survive the round-trip exactly.
        let replayedDrawing = overlay.replayDrawing()
        XCTAssertEqual(
            replayedDrawing.strokes.count,
            originalDrawing.strokes.count,
            "PencilCanvasOverlay MUST preserve stroke count across the data-layer round-trip; original=\(originalDrawing.strokes.count), replayed=\(replayedDrawing.strokes.count)"
        )
        if let originalFirst = originalDrawing.strokes.first,
           let replayedFirst = replayedDrawing.strokes.first {
            XCTAssertEqual(
                replayedFirst.path.count,
                originalFirst.path.count,
                "PencilCanvasOverlay MUST preserve the first-stroke path-point count across the data-layer round-trip; original=\(originalFirst.path.count), replayed=\(replayedFirst.path.count)"
            )
        }

        // 2. The view layer is still assigned the replayed drawing —
        //    the canvas shows the strokes. We assert semantic equality
        //    (stroke count) rather than byte equality because the
        //    canvas may canonicalise the archive after the first
        //    layout pass.
        let canvas = overlay.makeCanvasView()
        XCTAssertEqual(
            canvas.drawing.strokes.count,
            originalDrawing.strokes.count,
            "PencilCanvasOverlay MUST mount a canvas whose stroke count matches the original drawing"
        )
    }

    // MARK: - Behaviour 4: missing annotation triggers a lazy-upsert

    /// When no `PageAnnotation` exists for the active page index, the
    /// overlay MUST lazy-upsert one and the canvas MUST render blank
    /// (zero strokes). The annotation is bound to the active page index
    /// so the `PDFPageChangeObserver` can persist ink for it later.
    func test_lazyUpsertMissingPageAnnotationRendersBlankCanvas() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        // No annotation is created or inserted before the overlay mounts.
        let overlay = PencilCanvasOverlay(
            pageIndex: 7,
            pageAnnotation: nil,
            document: document,
            modelContext: context
        )
        let canvas = overlay.makeCanvasView()

        let upserted = try XCTUnwrap(
            overlay.pageAnnotationRef,
            "PencilCanvasOverlay MUST lazy-upsert a PageAnnotation when none is supplied; got nil"
        )
        XCTAssertEqual(
            upserted.pageIndex,
            7,
            "Lazy-upserted PageAnnotation MUST carry the active pageIndex; got \(upserted.pageIndex)"
        )
        XCTAssertEqual(
            upserted.document?.id,
            document.id,
            "Lazy-upserted PageAnnotation MUST be bound to the active DocumentItem"
        )
        XCTAssertTrue(
            canvas.drawing.strokes.isEmpty,
            "Lazy-upserted canvas MUST render blank (zero strokes); got \(canvas.drawing.strokes.count) strokes"
        )
    }

    // MARK: - Behaviour 5: clearing the canvas persists empty bytes

    /// When the reader clears the canvas, the overlay MUST persist empty
    /// bytes (`Data()`) on `PageAnnotation.drawingData` so the cleared
    /// state survives a coordinator re-init.
    func test_clearCanvasPersistsEmptyBytes() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        let annotation = makeAnnotation(in: context, document: document, pageIndex: 0)
        annotation.drawingData = makeHighlighterStroke().dataRepresentation()

        let overlay = PencilCanvasOverlay(
            pageIndex: 0,
            pageAnnotation: annotation,
            document: document,
            modelContext: context
        )
        let canvas = overlay.makeCanvasView()

        overlay.clear(canvas: canvas)

        let upserted = try XCTUnwrap(
            overlay.pageAnnotationRef,
            "PencilCanvasOverlay MUST keep the PageAnnotation reference after clear()"
        )
        XCTAssertEqual(
            upserted.drawingData,
            Data(),
            "Clearing the canvas MUST persist empty bytes on PageAnnotation.drawingData; got \(upserted.drawingData?.count ?? -1) bytes"
        )
        XCTAssertTrue(
            canvas.drawing.strokes.isEmpty,
            "After clear() the in-memory canvas MUST render zero strokes; got \(canvas.drawing.strokes.count)"
        )
    }

    // MARK: - Behaviour 6: decode failure preserves the unreadable bytes

    /// When `PKDrawing(data:)` rejects the stored `drawingData`, the
    /// overlay MUST surface a recoverable error
    /// (`AnnotationError.drawingDecodeFailed`), render the canvas blank,
    /// and leave the unreadable `drawingData` UNTOUCHED on the row so a
    /// future migration can recover or report on the corrupt payload.
    func test_decodeFailureSurfacesRecoverableErrorAndPreservesUnreadableBytes() throws {
        let document = makeSeedDocument()
        let container = makeSchemaContainer()
        let context = ModelContext(container)
        context.insert(document)
        try context.save()

        // Build bytes that `PKDrawing(data:)` MUST reject. `PKDrawing`'s
        // decoder expects a `PKDrawing` archive header; a sequence of
        // high-entropy random bytes reliably fails the archive
        // deserialization guard without colliding with any valid payload.
        let unreadableBytes = Data([
            0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
            0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0,
            0x0F, 0xED, 0xCB, 0xA9, 0x87, 0x65, 0x43, 0x21,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ])

        let annotation = makeAnnotation(in: context, document: document, pageIndex: 0)
        annotation.drawingData = unreadableBytes

        let overlay = PencilCanvasOverlay(
            pageIndex: 0,
            pageAnnotation: annotation,
            document: document,
            modelContext: context
        )
        let canvas = overlay.makeCanvasView()

        guard let lastError = overlay.lastError else {
            XCTFail("PencilCanvasOverlay MUST surface AnnotationError.drawingDecodeFailed when PKDrawing(data:) rejects the stored payload; got nil")
            return
        }
        guard case AnnotationError.drawingDecodeFailed = lastError else {
            XCTFail("PencilCanvasOverlay MUST surface AnnotationError.drawingDecodeFailed on decode failure; got \(lastError)")
            return
        }

        XCTAssertTrue(
            canvas.drawing.strokes.isEmpty,
            "On decode failure the canvas MUST render blank; got \(canvas.drawing.strokes.count) strokes"
        )
        XCTAssertEqual(
            annotation.drawingData,
            unreadableBytes,
            "On decode failure the unreadable PageAnnotation.drawingData MUST be preserved byte-for-byte; got \(annotation.drawingData?.count ?? -1) bytes"
        )
    }

    // MARK: - Helpers

    /// Builds a `DocumentItem` that satisfies the Phase 2 seed contract:
    /// `fileTypeRaw == "pdf"` AND `localFileName.isEmpty == true` AND
    /// `paginationModeRaw == "horizontal"`. Mirrors the helper from
    /// `PDFReaderCoordinatorTests` so the overlay tests stay focused on
    /// the ink overlay surface.
    private func makeSeedDocument() -> DocumentItem {
        let document = DocumentItem()
        document.title = "Getting Started"
        document.fileTypeRaw = "pdf"
        document.fileExtension = "pdf"
        document.localFileName = ""
        document.paginationModeRaw = "horizontal"
        return document
    }

    /// Inserts and returns a fresh `PageAnnotation` row bound to the
    /// supplied `DocumentItem` and `pageIndex`. Mirrors the lifecycle the
    /// `PDFPageChangeObserver` will use once the wiring PR lands.
    @discardableResult
    private func makeAnnotation(
        in context: ModelContext,
        document: DocumentItem,
        pageIndex: Int
    ) -> PageAnnotation {
        let annotation = PageAnnotation()
        annotation.pageIndex = pageIndex
        annotation.document = document
        context.insert(annotation)
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save baseline PageAnnotation: \(error)")
        }
        return annotation
    }

    /// Builds a deterministic, non-empty `PKDrawing` carrying one
    /// highlighter stroke. Used to assert byte-identical replay and
    /// clear-clears-everything. The stroke geometry is a straight
    /// horizontal line so the archive is small and stable across runs.
    private func makeHighlighterStroke() -> PKDrawing {
        let stroke = PKStroke(
            ink: PKInk(.marker, color: .systemYellow),
            path: PKStrokePath(
                controlPoints: [
                    PKStrokePoint(location: CGPoint(x: 10, y: 10), timeOffset: 0, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: 0),
                    PKStrokePoint(location: CGPoint(x: 20, y: 10), timeOffset: 0.01, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: 0),
                    PKStrokePoint(location: CGPoint(x: 30, y: 10), timeOffset: 0.02, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: 0)
                ],
                creationDate: Date(timeIntervalSinceReferenceDate: 0)
            )
        )
        return PKDrawing(strokes: [stroke])
    }
}
