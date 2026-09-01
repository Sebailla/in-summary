# Capability spec — `pdf-engine`

## Purpose

Provide a `@MainActor` SwiftUI-friendly `PDFReaderCoordinator` that
wraps `PDFKit.PDFView` and renders the bundled PDF fixture in
horizontal paginated mode or vertical continuous mode according to the
**Phase 1 invariant** `DocumentItem.paginationModeRaw` (default
`"horizontal"`). The coordinator does not introduce a SwiftData field,
does not add an entity, and does not migrate any Phase 1 entity. It
reads and writes the existing `paginationModeRaw` and `updatedAt`
columns as-is.

This capability defines the contract the PencilKit ink overlay and the
reader shell depend on. The bundled fixture source is the canonical
`sample-bundle.pdf` (see `specs/pdf-fixture/spec.md`); no other PDF
source is reachable in Phase 2.

## ADDED Requirements

### Requirement: PDF reader coordinator

The system SHALL expose a `PDFReaderCoordinator` that wraps
`PDFKit.PDFView` and renders the bundled fixture. The coordinator SHALL
be `@MainActor`. The coordinator SHALL expose the current page index and
the current pagination mode as observable bindings so the SwiftUI parent
can react to either change.

#### Scenario: Loading the bundled fixture

- **WHEN** the coordinator receives a reference to the seed
  `DocumentItem` (Phase 1 `fileTypeRaw == "pdf"`,
  `localFileName.isEmpty == true`)
- **THEN** the underlying `PDFView` SHALL open the bundled
  `sample-bundle.pdf`
- **AND** the page-index binding SHALL publish `0` as the initial
  value.

#### Scenario: Stable view identity across SwiftUI rebuilds

- **WHEN** the parent SwiftUI view is rebuilt with the same
  `DocumentItem`
- **THEN** `makeUIView` SHALL NOT recreate the underlying `PDFView`
  unnecessarily
- **AND** the page-index binding SHALL NOT reset to `0` mid-reading.

### Requirement: Horizontal paginated mode

The coordinator SHALL support a **horizontal paginated** mode. In this
mode the underlying `PDFView` SHALL use `PDFDisplayMode.singlePage` and
`PDFDisplayDirection.horizontal` with `usePageViewController(true)`.
The document SHALL advance one page at a time using PDFKit's native
horizontal swipe gesture.

#### Scenario: Swipe advances one page

- **WHEN** the reader is in horizontal mode and swipes left on the page
- **THEN** the underlying `PDFView` SHALL advance exactly one page
- **AND** the page-index binding SHALL publish the new page index
  through the page-change publisher.

### Requirement: Vertical continuous mode

The coordinator SHALL support a **vertical continuous** mode. In this
mode the underlying `PDFView` SHALL use
`PDFDisplayMode.singlePageContinuous` and
`PDFDisplayDirection.vertical`. The document SHALL scroll vertically
through the pages.

#### Scenario: Continuous scroll

- **WHEN** the reader is in vertical mode and scrolls downward
- **THEN** the underlying `PDFView` SHALL traverse pages without a hard
  cut
- **AND** the page-index binding SHALL publish the page that occupies
  the centre of the visible area.

### Requirement: Pagination-mode switch from a Phase 1 invariant

The coordinator SHALL derive the initial pagination mode from the
existing `DocumentItem.paginationModeRaw` column. The coordinator SHALL
NOT introduce a new SwiftData field, a new entity, or a new
relationship to model the preference. The coordinator SHALL write the
new raw value back to the same column on toggle and bump
`DocumentItem.updatedAt`.

#### Scenario: Default preference is read from Phase 1

- **WHEN** the coordinator opens a `DocumentItem` whose
  `paginationModeRaw == "horizontal"`
- **THEN** the coordinator SHALL apply horizontal paginated mode
- **AND** the underlying `PDFView` SHALL match the horizontal settings.

#### Scenario: Vertical preference is read from Phase 1

- **WHEN** the coordinator opens a `DocumentItem` whose
  `paginationModeRaw == "vertical"`
- **THEN** the coordinator SHALL apply vertical continuous mode
- **AND** the underlying `PDFView` SHALL match the vertical settings.

#### Scenario: Unknown raw value falls back to horizontal

- **WHEN** the coordinator opens a `DocumentItem` whose
  `paginationModeRaw` is any value other than `"horizontal"` or
  `"vertical"`
- **THEN** the coordinator SHALL fall back to horizontal paginated mode
- **AND** the coordinator SHALL log the unknown value via `os.Logger`
  exactly once per open.

#### Scenario: Toggle writes back to the existing column

- **WHEN** the parent view flips the mode binding to `"vertical"`
- **THEN** `DocumentItem.paginationModeRaw` SHALL equal `"vertical"`
  after the next runloop tick
- **AND** `DocumentItem.updatedAt` SHALL advance
- **AND** every other field on the row SHALL remain unchanged.

#### Scenario: Round-trip across coordinator re-init

- **WHEN** the reader toggles a document to `"vertical"` and the
  document is closed and reopened
- **THEN** the coordinator SHALL open in vertical mode.

### Requirement: Bundled fixture source

The coordinator SHALL resolve its PDF source from the app bundle only,
never from a user-imported file picker, a sandbox document directory,
or the network. The fixture is the `sample-bundle.pdf` shipped via
*Copy Bundle Resources* (see `specs/pdf-fixture/spec.md`).

#### Scenario: Missing fixture is a typed failure

- **WHEN** the app bundle does NOT contain `sample-bundle.pdf`
- **THEN** the coordinator SHALL throw
  `PDFReaderError.fixtureMissing(resource: "sample-bundle")`
- **AND** the reader surface SHALL surface a recoverable error to the
  caller instead of silently substituting a fallback.

#### Scenario: Unreadable fixture is a typed failure

- **WHEN** the bundled `sample-bundle.pdf` exists but cannot be parsed
  into a `PDFDocument`
- **THEN** the coordinator SHALL throw `PDFReaderError.fixtureUnreadable`
- **AND** the reader surface SHALL surface a recoverable error to the
  caller instead of presenting an empty `PDFView`.

### Requirement: Seeded document is navigable without import

The coordinator SHALL be reachable for the Phase 1 seed PDF document
(`title: "Getting Started"`, `fileTypeRaw: "pdf"`,
`localFileName.isEmpty == true`) from the existing library shell. The
coordinator SHALL NOT require a folder navigation gesture, a file
importer, a document picker, or a drag-and-drop target to do so.

#### Scenario: Non-PDF or non-seed document is refused

- **WHEN** the reader surface is requested for a `DocumentItem` whose
  `fileTypeRaw != "pdf"` or whose `localFileName.isEmpty == false`
- **THEN** the coordinator SHALL throw
  `PDFReaderError.unsupportedDocument(reason:)`
- **AND** the reader surface SHALL surface a recoverable "not
  supported in this build" error to the caller.

### Requirement: No network and no remote I/O

The coordinator SHALL NOT perform any network request and SHALL NOT
read or write any file outside the application bundle or the local
SwiftData store.

#### Scenario: No network reach-out

- **WHEN** the coordinator opens or pages through the document
- **THEN** no URL session, no socket, and no remote URL SHALL be opened
- **AND** a code search for `URLSession`, `NWConnection`, and
  `NSURLConnection` inside `InSummary/Services/PDFEngine/` SHALL return
  zero matches.

### Requirement: No `PencilKit` and no new SwiftData surface

The coordinator SHALL NOT import `PencilKit`. The coordinator SHALL
NOT declare new entities, new relationships, or new fields on existing
entities. The coordinator SHALL NOT introduce an additional file
store on disk.

#### Scenario: Module boundary holds

- **WHEN** the coordinator source is inspected
- **THEN** the file SHALL NOT contain `import PencilKit`
- **AND** the file SHALL NOT declare any `@Model` type
- **AND** the file SHALL NOT write any file outside the application
  bundle or the SwiftData store.

## MODIFIED Requirements

*None.* This capability introduces the coordinator. It does not modify
any existing Phase 1 entity.

## REMOVED Requirements

*None.*
