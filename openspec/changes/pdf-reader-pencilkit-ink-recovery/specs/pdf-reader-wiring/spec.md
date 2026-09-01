# Capability spec — `pdf-reader-wiring`

## Purpose

Compose the `PDFReaderCoordinator` (capability `pdf-engine`) and the
`PencilCanvasOverlay` + `PDFPageChangeObserver`
(capability `pencilkit-ink-overlay`) into a single SwiftUI
`ReaderContainerView`, and wire the Phase 1 library shell so the seed
PDF document is reachable from the library row without introducing
import, export, folders, or any other Phase 5 surface.

This capability defines the contract that the integration tests and
the offline acceptance check depend on. It does not introduce a new
SwiftData field; the per-document pagination preference is the Phase 1
invariant `DocumentItem.paginationModeRaw`.

## ADDED Requirements

### Requirement: Reader container composition

The system SHALL expose a SwiftUI `ReaderContainerView` that composes
the `PDFReaderCoordinator` and the `PencilCanvasOverlay` and owns
their lifecycle. The container SHALL:

1. Accept the seed `DocumentItem` (Phase 1 `fileTypeRaw == "pdf"`,
   `localFileName.isEmpty == true`) via SwiftUI navigation, not via a
   global singleton.
2. Build the coordinator against the bound document; the coordinator
   reads the existing `paginationModeRaw` column.
3. Subscribe `PDFPageChangeObserver` to the coordinator's page-change
   publisher via `.onReceive`.
4. Mount `PencilCanvasOverlay` above the coordinator's `PDFView` and
   pass the current `PageAnnotation` (lazy-upserted if missing) plus
   the `ModelContext`.
5. Surface recoverable error banners from `PDFReaderError` and
   `AnnotationError`.
6. Tear down both subviews on disappear; no retained `PKCanvasView`
   SHALL outlive the container.

#### Scenario: Reader opens the bundled fixture

- **WHEN** the container receives a seed `DocumentItem`
- **THEN** the coordinator SHALL load the bundled
  `sample-bundle.pdf`
- **AND** the overlay SHALL mount on top of the coordinator.

#### Scenario: Reader tears down cleanly

- **WHEN** the container disappears
- **THEN** both UIKit subviews SHALL be removed from the view hierarchy
- **AND** no retained `PKCanvasView` SHALL outlive the container.

### Requirement: Library shell navigation

The Phase 1 `LibraryGridView` SHALL be modified so the seed
`DocumentItem` row becomes a `NavigationLink` to
`ReaderContainerView(document:)`. Rows for any other `DocumentItem`
SHALL surface a recoverable "not supported in this build" alert.

#### Scenario: Seed document opens the reader

- **GIVEN** the local SwiftData store contains the seed
  `DocumentItem` produced by `LibrarySeedService`
- **WHEN** the reader taps that row in the library shell
- **THEN** the library SHALL navigate to
  `ReaderContainerView(document:)`
- **AND** no file importer, folder browser, or document picker SHALL
  be presented to the user.

#### Scenario: Non-PDF or non-seed row is refused

- **WHEN** the reader taps a row whose `fileTypeRaw != "pdf"` or
  whose `localFileName.isEmpty == false`
- **THEN** the library SHALL surface a recoverable alert stating
  "not supported in this build"
- **AND** the library SHALL NOT navigate to `ReaderContainerView`.

### Requirement: Mode-toggle UI binding

The container SHALL expose a SwiftUI binding so a parent view can
toggle pagination mode declaratively. The container SHALL write the
new mode back to `DocumentItem.paginationModeRaw` (the Phase 1
column) so the preference survives the next open.

#### Scenario: Toggle writes the preference

- **WHEN** the parent view flips the mode binding to `"vertical"`
- **THEN** `DocumentItem.paginationModeRaw` SHALL equal `"vertical"`
  after the next runloop tick
- **AND** `DocumentItem.updatedAt` SHALL advance.

### Requirement: End-to-end byte-identical round-trip

When the reader opens the bundled fixture, draws on page 1, navigates
to page 2, draws on page 2, returns to page 1, and closes the document,
both pages' `PKDrawing.dataRepresentation()` payloads SHALL be
byte-for-byte equal to the values the reader originally drew, both
persisted on `PageAnnotation.drawingData`.

#### Scenario: Reader integration round-trip

- **WHEN** the integration test opens the bundled fixture, draws on
  page 1 and page 2, returns to page 1, and exits
- **THEN** both pages' `PKDrawing.dataRepresentation()` payloads SHALL
  match the expected bytes byte-for-byte
- **AND** `PageAnnotation.drawingData` for both pages SHALL equal the
  in-memory `PKDrawing.dataRepresentation()` bytes byte-for-byte.

### Requirement: Offline acceptance

When the device is in airplane mode (no network, no iCloud session),
the reader SHALL open the bundled fixture, render both pagination
modes, accept Pencil drawing on both pages, and round-trip the strokes
across navigation.

#### Scenario: Airplane-mode round-trip

- **GIVEN** the device is in airplane mode
- **WHEN** the test opens the fixture, draws on page 1, draws on
  page 2, navigates back to page 1, and exits
- **THEN** both pages' drawings SHALL be byte-for-byte preserved
- **AND** `DocumentItem.paginationModeRaw` SHALL survive the
  document reopen.

### Requirement: No new entitlements

The container SHALL NOT require any new entry in `Info.plist`. The
application bundle SHALL NOT gain iCloud, CloudKit, push
notification, or background mode entitlements as a result of this
change.

#### Scenario: Entitlement delta is empty

- **WHEN** the diff of `InSummary/Info.plist` and the entitlement
  files is computed across this change
- **THEN** the diff SHALL be empty.

### Requirement: No new SwiftData surface

The container SHALL NOT declare new entities, new relationships, or
new fields on existing entities. The container SHALL read and write
only the Phase 1 columns `DocumentItem.paginationModeRaw`,
`DocumentItem.updatedAt`, and `PageAnnotation.drawingData`.

#### Scenario: Module boundary holds

- **WHEN** the container source file is inspected
- **THEN** the file SHALL NOT contain `@Model`
- **AND** the file SHALL NOT add any property to a `@Model` type
- **AND** the file SHALL NOT introduce a new file store on disk.

## MODIFIED Requirements

### MODIFIED: `LibraryGridView.swift` (Phase 1)

The Phase 1 `LibraryGridView.swift` SHALL be modified so the seed
`DocumentItem` row becomes a `NavigationLink` to
`ReaderContainerView(document:)` and every other row surfaces a
recoverable "not supported in this build" alert. The library row
layout (folder section + document section, accessibility labels,
preview) SHALL be preserved.

#### Scenario: Section layout is preserved

- **WHEN** the library shell is rendered after the change
- **THEN** the Folders section SHALL still render `FolderEntity` rows
- **AND** the Documents section SHALL still render `DocumentItem` rows
- **AND** accessibility labels SHALL still combine title and subtitle.

## REMOVED Requirements

*None.*
