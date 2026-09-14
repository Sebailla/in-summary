# Capability spec — `pencilkit-ink-overlay`

## Purpose

Render freeform Apple Pencil ink on top of the PDF reader using
`PencilKit`, persist each page's drawing as a byte-identical
`PKDrawing.dataRepresentation()` payload on the existing Phase 1
`PageAnnotation.drawingData` column, and keep the ink stable across
page changes, app restarts, and `PDFReaderCoordinator` re-inits — all
without introducing sticky notes, semantic highlights, the eraser tool
mode, a parallel file store on disk, or any remote capability.

Byte equality between the stored `drawingData` and the canvas's
`drawing.dataRepresentation()` is asserted only at the persistence
boundary (write side). Because decoding then re-encoding a `PKDrawing`
may canonicalize its archive, the UI replay contract preserves drawing
semantics rather than byte equality: a canvas rebuilt from
`PKDrawing(data: drawingData)` renders the strokes the reader drew, but
its `drawing.dataRepresentation()` MAY differ from the stored bytes.

The overlay is a `UIViewRepresentable` around `PKCanvasView`. The
`PDFPageChangeObserver` is its companion that drives the save/load
cycle. Both live under `InSummary/Services/AnnotationEngine/` and do
not import `PDFKit`.

## ADDED Requirements

### Requirement: Pencil-only drawing policy

The overlay SHALL wrap a `PKCanvasView` whose `drawingPolicy` is
`PKCanvasViewDrawingPolicy.pencilOnly`. The overlay SHALL ignore touch
events whose `UITouch.Type` is not `.pencil`. Finger taps, finger
swipes, and finger drags SHALL NOT add strokes to the canvas.

#### Scenario: Finger touches do not draw

- **WHEN** the reader taps the canvas with a finger
- **THEN** the canvas's stroke count SHALL NOT change
- **AND** the canvas's `PKDrawing.strokes` SHALL remain unchanged.

#### Scenario: Pencil touches draw

- **WHEN** the reader drags the Apple Pencil across the canvas
- **THEN** the canvas's stroke count SHALL increase by exactly one per
  drag gesture
- **AND** `canvasViewDrawingDidChange` SHALL fire.

### Requirement: Default tool is a translucent yellow marker

The overlay SHALL default to `PKInkingTool(.marker, color: <translucent
yellow PKInkingColor with alpha ≤ 0.5>, width: <marker width>)`. This is
the canonical highlighter analog on iOS 26 because
`PKInkingTool.InkType.highlighter` is not exposed on iOS 26. The
default tool SHALL be applied at `makeUIView` time and SHALL persist
across replays from a stored drawing.

#### Scenario: Default tool is a translucent yellow marker on a blank canvas

- **WHEN** the overlay mounts against a `PageAnnotation` whose
  `drawingData == nil` or an empty `PKDrawing`
- **THEN** the underlying `PKCanvasView`'s inking tool SHALL be a
  `PKInkingTool` with `InkType.marker` whose `PKInkingColor` is a
  translucent yellow with alpha ≤ 0.5.

#### Scenario: Tool persists across replays

- **WHEN** the overlay has replayed a non-empty `PKDrawing` from
  `PageAnnotation.drawingData`
- **THEN** the underlying `PKCanvasView`'s inking tool SHALL still be
  a `PKInkingTool` with `InkType.marker` whose `PKInkingColor` is a
  translucent yellow with alpha ≤ 0.5.

### Requirement: Replay stored drawing on page load

The overlay SHALL replay the current page's stored drawing from
`PageAnnotation.drawingData` whenever a page becomes the visible page
in the reader. If no `PageAnnotation` row exists for that page index,
the overlay SHALL lazy-upsert one against the bound `DocumentItem` and
treat the page as blank.

#### Scenario: Non-empty drawing replays with semantics preserved

- **WHEN** a `PageAnnotation` exists for the current page with a
  non-empty `drawingData`
- **THEN** the overlay SHALL replace the underlying `PKCanvasView`'s
  drawing with `PKDrawing(data: drawingData!)`
- **AND** the canvas's `PKDrawing.strokes` SHALL render the strokes
  encoded by the stored `drawingData`
- **AND** the canvas's `drawing.dataRepresentation()` MAY differ from
  the stored `drawingData` because decoding then re-encoding a
  `PKDrawing` may canonicalize its archive; byte equality is asserted
  only at the persistence boundary before replay, not after replay.

#### Scenario: Missing annotation is a blank canvas

- **WHEN** no `PageAnnotation` exists for the current page index
- **THEN** the overlay SHALL lazy-upsert a `PageAnnotation` whose
  `pageIndex` matches the active page index
- **AND** the underlying `PKCanvasView`'s `PKDrawing.strokes` SHALL be
  empty.

### Requirement: Write-on-change persistence on the Phase 1 column

The overlay SHALL persist every change to the canvas by writing
`pageAnnotation.drawingData = canvas.drawing.dataRepresentation()` and
calling `modelContext.save()`. The overlay SHALL NOT introduce a
parallel file store on disk.

#### Scenario: Persisted bytes match the in-memory drawing

- **WHEN** `canvasViewDrawingDidChange` fires after a Pencil stroke
- **THEN** `pageAnnotation.drawingData` SHALL equal
  `canvas.drawing.dataRepresentation()` byte-for-byte
- **AND** `modelContext.save()` SHALL be called.

#### Scenario: Clearing the canvas persists empty bytes

- **WHEN** the reader clears the canvas
- **THEN** `pageAnnotation.drawingData` SHALL equal an empty `Data`
- **AND** the previously persisted bytes SHALL be overwritten on disk.

#### Scenario: Save failure surfaces a recoverable error

- **WHEN** `modelContext.save()` throws
- **THEN** the overlay SHALL set `lastError =
  .drawingPersistenceFailed(underlying:)`
- **AND** the in-memory drawing SHALL be retained for the current
  session
- **AND** the previously persisted bytes SHALL remain untouched on
  disk.

### Requirement: Page round-trip preserves drawing semantics

The overlay's companion `PDFPageChangeObserver` SHALL capture the
outgoing page's bytes from the canvas via an injected closure at the
persistence boundary, persist them on the outgoing `PageAnnotation`,
load the incoming `PageAnnotation` for `(documentID, pageIndex)`, and
ask the overlay to `activate(pageIndex:)`. Byte equality is asserted
only at the persistence boundary; because decoding then re-encoding a
`PKDrawing` may canonicalize its archive, the replay path preserves
drawing semantics rather than byte equality between the canvas's
post-replay `drawing.dataRepresentation()` and the stored `drawingData`.

#### Scenario: Drawing survives a page round-trip

- **WHEN** the reader draws on page 1, navigates to page 2, draws on
  page 2, then returns to page 1
- **THEN** page 1's `PKCanvasView` SHALL render strokes semantically
  equivalent to those the reader originally drew on page 1
- **AND** page 2's `PKCanvasView` SHALL likewise render strokes
  semantically equivalent to those drawn on page 2
- **AND** the canvas's `drawing.dataRepresentation()` after replay MAY
  differ from the stored `drawingData` because decoding then
  re-encoding a `PKDrawing` may canonicalize its archive; byte
  equality is asserted only at the persistence boundary before each
  replay.

#### Scenario: Five navigation cycles are stable

- **WHEN** the reader cycles between pages 1 and 2 five times
- **THEN** both pages' `pageAnnotation.drawingData` rows SHALL remain
  equal to the bytes last persisted at write time
- **AND** both pages' canvases SHALL render strokes semantically
  equivalent to the stored drawings
- **AND** the canvas's `drawing.dataRepresentation()` after replay MAY
  differ from the stored `drawingData` because decoding then
  re-encoding a `PKDrawing` may canonicalize its archive; byte
  equality is asserted only at the persistence boundary before replay.

### Requirement: Value-coalescing on page-change notifications

The `PDFPageChangeObserver` SHALL value-coalesce notifications on
`currentPageIndex` on the main actor. The observer SHALL drop
notifications whose `currentPageIndex` equals the last observed index.
No `Task.sleep`, no `DispatchQueue.main.asyncAfter`, and no timer
SHALL be used.

#### Scenario: Redundant notification is dropped

- **WHEN** the observer receives two notifications with the same
  `currentPageIndex` back-to-back
- **THEN** the second notification SHALL be dropped
- **AND** no extra save or load SHALL occur.

### Requirement: Decode failure preserves the unreadable bytes

When `PKDrawing(data:)` rejects the stored `drawingData`, the canvas
SHALL render empty and the unreadable `drawingData` SHALL remain
untouched on the row.

#### Scenario: Decoder rejection surfaces a recoverable error

- **WHEN** `PKDrawing(data: drawingData)` throws
- **THEN** the overlay SHALL set `lastError = .drawingDecodeFailed`
- **AND** the canvas's `PKDrawing.strokes` SHALL be empty
- **AND** `pageAnnotation.drawingData` SHALL remain equal to the bytes
  read from the row.

### Requirement: No `PDFKit` and no new SwiftData surface

The overlay and the observer SHALL NOT import `PDFKit`. The overlay
and the observer SHALL NOT declare new entities, new relationships, or
new fields on existing entities. Both SHALL use the Phase 1
`PageAnnotation.drawingData` column directly.

#### Scenario: Module boundary holds

- **WHEN** the overlay and observer source files are inspected
- **THEN** neither file SHALL contain `import PDFKit`
- **AND** neither file SHALL declare any `@Model` type
- **AND** neither file SHALL write any file outside the application
  bundle or the SwiftData store.

## MODIFIED Requirements

*None.* This capability introduces the overlay and the observer. It
does not modify any existing Phase 1 entity.

## REMOVED Requirements

*None.*
