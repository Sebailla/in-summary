# Design — pdf-reader-pencilkit-ink-recovery

> Technical decisions for Phase 2. Decisions are stated first, justified
> second. Cross-references to `specification.md` and to the Phase 1
> canonical schema are explicit so reviewers can confirm intent without
> re-reading either source.

## 1. Reader composition

The PDF reader is composed of two SwiftUI layers and two `@MainActor`
engines:

```
LibraryGridView (Phase 1, ship-ready, modified in PR #4)
        └─► ReaderContainerView (PR #4 NEW, wraps PDFReaderCoordinator)
                ├─► PDFReaderCoordinator (PR #2 NEW, UIViewRepresentable)
                │       └─► PDFView (PDFKit, native gesture stack)
                └─► PencilCanvasOverlay (PR #3 NEW, UIViewRepresentable)
                        └─► PKCanvasView (PencilKit)
```

- `PDFReaderCoordinator` owns the `PDFView` and the pagination-mode
  switch (horizontal `PDFDisplayMode.singlePage` + horizontal direction
  vs. vertical `PDFDisplayMode.singlePageContinuous`).
- `PencilCanvasOverlay` is a sibling `UIViewRepresentable` placed **above**
  the `PDFView`; it hosts one `PKCanvasView` per logical page.
- `PDFPageChangeObserver` (introduced in PR #3 alongside the overlay) is
  the coordinator/overlay bridge: it watches the page-change signal,
  captures the outgoing page's `PKDrawing`, persists it on
  `PageAnnotation.drawingData`, and asks the overlay to load the incoming
  page's drawing.
- `ReaderContainerView` owns the lifecycle of all three: it loads the
  document, wires the page-change signal, reads/writes the per-document
  pagination preference, and tears down both subviews on disappear.

**Why two `UIViewRepresentable`s, not one**: the `PDFView` and the
`PKCanvasView` have different gesture stacks and different SwiftUI update
cycles. Merging them into a single coordinator makes the page-change swap
awkward and forces one update cycle to drag the other. Keeping them
separate lets each view observe its own publisher.

**Why the overlay sits above, not inside, the `PDFView`**: PDFKit renders
the page content as a `CALayer`. Drawing on top of that layer with a
sibling view keeps PencilKit's coordinate space independent of PDFKit's
and keeps the page-swap simple — the overlay just replaces the active
`PKCanvasView` on page change.

## 2. Pagination preference (Phase 1 invariant)

`DocumentItem.paginationModeRaw: String` already exists in
`InSummary/Models/DocumentItem.swift` as a Phase 1 invariant, defaulted
to `"horizontal"`. Phase 2 **does not** add, alter, default, or migrate
the field; it reads it once on coordinator init and writes it back when
the reader toggles mode.

- `PDFReaderCoordinator` exposes a `paginationMode: PaginationMode`
  computed from the document's `paginationModeRaw` at construction time.
- The toggle is exposed to the SwiftUI layer as a binding; the
  coordinator writes the new raw value back to the same
  `DocumentItem` row on `modelContext.save()` and bumps `updatedAt`.
- The preference is **per document**, not per app session.
- The wrapper enum (`PaginationMode.horizontal | .vertical`) is
  constructed at the read site and decoded at the write site; both sites
  live in the reader module so the type boundary is obvious.
- An unknown raw value (e.g. `"foo"`) falls back to `horizontal` and
  is logged once via `os.Logger` so a corrupted row is never silently
  broken.

**Why `String` and not an enum on the entity**: the entity already
persists `paginationModeRaw: String` as a Phase 1 invariant. Phase 2
does not migrate the storage type. Migration is deferred until the
future sync phase formalises annotation storage.

## 3. Ink persistence — `PageAnnotation.drawingData` (Phase 1 invariant)

`PageAnnotation.drawingData: Data?` already exists in
`InSummary/Models/PageAnnotation.swift` (declared with
`@Attribute(.externalStorage)` per `specification.md` §3.1). Phase 2
**reuses** this column directly. No parallel file store, no
`InkDrawingStore` actor, no new entity, no new relationship.

- `PencilCanvasOverlay` is given a `pageAnnotation: PageAnnotation`
  reference (or `nil` for first-mount lazy-upsert) and a
  `modelContext: ModelContext`.
- On `canvasViewDrawingDidChange` the overlay writes
  `pageAnnotation.drawingData = canvas.drawing.dataRepresentation()` and
  calls `modelContext.save()`. Failures surface as
  `AnnotationError.drawingPersistenceFailed(underlying:)` via the
  `@Observable` `lastError` channel.
- `PDFPageChangeObserver` is the bridge: it captures the outgoing
  page's bytes from the overlay (via an injected closure), persists them
  on the outgoing `PageAnnotation`, loads the incoming
  `PageAnnotation` by `(document.id, pageIndex)`, lazy-upserts one if
  missing, and asks the overlay to `activate(pageIndex:)`.
- Byte-identical round-trip is a hard requirement: the bytes persisted
  by the overlay MUST be exactly the bytes that
  `PKDrawing.dataRepresentation()` produces, byte-for-byte.

**Why no separate file store**: the prior attempt invented a JSON file
store under `Application Support/Ink/<documentID>.ink.json` to "avoid
a schema change". That schema change was already shipped by Phase 1.
Reusing `PageAnnotation.drawingData` keeps Phase 2 small, keeps the
data model canonical, and keeps the CloudKit-compatibility invariant
(`@Attribute(.externalStorage)` works with future sync) intact.

## 4. Page-change persistence and value-coalescing

`PDFView.publish(for: \.currentPage)` and
`NotificationCenter.default.publisher(for: .PDFViewPageChanged)` both
fire on background renders, layout passes, and user swipes. Without
coalescing, the overlay would write the same bytes back to disk on
every render tick.

- `PDFPageChangeObserver` is `@MainActor` and **value-coalesces** on
  the resolved `currentPageIndex`. The observer drops notifications
  whose `currentPageIndex` equals the last observed index.
- The observer does **not** use `Task.sleep`,
  `DispatchQueue.main.asyncAfter`, or any timer. No time-based tests.
- The SwiftUI subscription is a `.onReceive` of the publisher exposed
  by `PDFReaderCoordinator`, not a free `NotificationCenter.addObserver`
  inside the view.

## 5. Fixture — project-authored deterministic CC0 20-page PDF

The acceptance criteria for Phase 2 require a 20-page PDF that can be
opened, navigated, and annotated. The fixture is **project-authored,
deterministic, CC0, and bundled at build time** at exactly
`InSummary/Resources/Fixtures/sample-bundle.pdf` (plural `Fixtures`,
hyphenated name).

- `Tools/generate-sample-bundle-pdf.swift` is a project-authored
  deterministic Swift script that uses `PDFKit` to draw 20 letter-sized
  pages. Each page carries: the page index in the bottom-right corner,
  a deterministic geometric pattern that changes only with the page
  index, and one block of CC0 dummy text drawn from a frozen string
  constant.
- The generator exposes `generateFixture() -> Data` and a
  `fixtureContentHash` computed over the page-by-page output. Tests
  assert the hash against a known-good constant, so any drift trips the
  suite.
- The generator runs at test time (in-process) and at the build phase
  (writes the bytes to `InSummary/Resources/Fixtures/sample-bundle.pdf`
  whenever the generator source changes). Tests never read the bundle
  resource directly — they call the generator in-process and compare the
  bundle-loaded bytes against the in-process generator output.
- `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` records the
  CC0 dedication, the generator SHA-256, and the page count.
- The fixture is **CC0** because every drawing primitive comes from
  first-party code; no third-party content is embedded.

**Why generate, not ship a binary**: shipping a binary PDF means the test
suite can drift from the artifact the app actually loads, and the
binary becomes a black box that nobody can review. A deterministic
generator keeps the artifact under source review, makes regeneration
trivial, and keeps git diffs reviewable.

**Why CC0**: the Phase 2 guardrails in `openspec/config.yaml` pin the
fixture license to `CC0`. CC0 makes the fixture safe to bundle in the
app binary and to redistribute in test logs.

**Why the canonical path matters**: the prior failed init used
`InSummary/Resources/Fixture/sample.pdf` (singular `Fixture`, no
hyphen). That path is wrong because (a) `Assets.xcassets` and the rest
of the bundle use plural-noun resource directories, (b) the bundle's
project file glob is `InSummary/Resources/Fixtures/*.pdf`, and (c) every
spec, test, build phase, and PR description must reference one and only
one path.

## 6. Concurrency & threading

- `PDFView`, `PKCanvasView`, and the SwiftData main `ModelContext` are
  touched only on the main actor; `PDFReaderCoordinator`,
  `PencilCanvasOverlay`, and `PDFPageChangeObserver` are all
  `@MainActor`.
- The page-swap closure is delivered to the overlay synchronously on the
  main actor.
- Persistence failures are surfaced as recoverable errors via
  `AnnotationError`; the canvas keeps the in-memory drawing for the
  current session and the previously persisted bytes stay untouched on
  disk.

**Why no async/await for the page-swap**: the swap path is main-actor
and tightly bounded by the gesture's frame budget. Adding structured
concurrency there buys nothing and risks a SwiftUI cancellation signal
during a fast swipe.

## 7. Test strategy

Strict TDD per `openspec/config.yaml`. Every requirement ships with
XCTest coverage that fails before the change and passes after. Tests
land in the same PR as the code they cover.

| Layer | Coverage |
| --- | --- |
| `Tools/generate-sample-bundle-pdf.swift` (called from test support) | Determinism: hashing the generator output twice yields the same bytes; the canonical content hash matches the constant; the output is a 20-page `PDFDocument`; each page renders to a non-empty `UIImage`. |
| `SampleBundleFixtureTests` (target: `InSummaryTests`) | The bundled fixture resolves from `Bundle.main`; the file is non-empty and ≤ 1 MB; the in-process generator output and the bundled bytes hash identically. |
| `PDFReaderCoordinator` | Loads the bundled fixture; sets `displayMode` + `displayDirection` from `DocumentItem.paginationModeRaw`; updates the preference binding when the reader toggles mode; preserves the preference when the view is torn down and rebuilt; surfaces `PDFReaderError` for missing fixture, unreadable fixture, non-PDF document, and non-seed document. |
| `PencilCanvasOverlay` | Ignores touch events that do not originate from `UITouch.Type.pencil`; persists a non-empty drawing on page leave; loads the same drawing byte-for-byte on page return; renders the default tool as `.highlighter`; lazy-upserts a `PageAnnotation` when none exists for the active page index. |
| `PDFPageChangeObserver` | Round-trip preserves byte-identical `PKDrawing` payloads across pages 1 → 2 → 1; five navigation cycles are stable; the observer drops notifications whose `currentPageIndex` equals the last observed index; a save failure surfaces `AnnotationError.drawingPersistenceFailed(underlying:)` and does **not** mutate `lastObservedPageIndex`. |
| `ReaderIntegrationTests` | End-to-end: open the bundled fixture, navigate across pages, draw on page 1 and page 2, return, assert strokes are byte-for-byte preserved; offline (airplane mode) acceptance check. |

UI tests and snapshot tests are deferred to Phase 6. Phase 2 ships unit
tests and the offline end-to-end XCTest described above.

## 8. Slice boundary rationale (for the linear feature-branch-chain)

| Slice | Why it is its own PR | Target branch |
| --- | --- | --- |
| `pdf-fixture` (PR #1) | The fixture is a hard dependency of every test in Phase 2 and a one-shot generator. Isolating it keeps every later PR focused on reader behaviour. | `tracker/pdf-reader-pencilkit-ink-recovery` |
| `pdf-engine` (PR #2) | The `PDFView` lifecycle and pagination-mode switch are independent of PencilKit and benefit from review in isolation. | PR #1's branch (`feat/pdf-fixture`) |
| `pencilkit-ink-overlay` (PR #3) | Depends on the coordinator's page-change publisher (PR #2) and on the bundled fixture (PR #1). The overlay and observer are small enough to land in one PR with their tests. | PR #2's branch (`feat/pdf-engine`) |
| `pdf-reader-wiring` (PR #4) | Depends on PRs #1, #2, and #3. Wires everything into the existing library shell and adds the integration tests. | PR #3's branch (`feat/pencilkit-ink-overlay`) |

**Linear topology rule (strict):** every child PR after #1 targets the
branch of its immediate predecessor. The chain is a single line, not a
tree:

```
tracker ← PR #1 ← PR #2 ← PR #3 ← PR #4
```

The only PR that targets the tracker branch is PR #1. The only PR that
ever merges into `main` is the tracker. No fan-out, no parallel chains,
no merge-to-main by any child PR.

## 9. Decision table

| # | Decision | Rationale |
| - | --- | --- |
| D1 | Reuse `DocumentItem.paginationModeRaw` as-is; do not add, alter, default, or migrate the field. | Phase 1 invariant. The gate failure on the prior attempt came from inventing this field. |
| D2 | Reuse `PageAnnotation.drawingData` as the per-page ink store; do not invent a parallel file store. | Phase 1 invariant (`@Attribute(.externalStorage)`). Avoids the prior attempt's invented `InkDrawingStore`. |
| D3 | Use exactly `InSummary/Resources/Fixtures/sample-bundle.pdf` as the fixture path everywhere (specs, tasks, build phase, tests, PR description). | The prior attempt used the wrong path (`Fixture/sample.pdf`). The canonical path is plural `Fixtures`, hyphenated `sample-bundle.pdf`. |
| D4 | The library document row navigates to `ReaderContainerView` for `DocumentItem` where `fileTypeRaw == "pdf"` AND `localFileName.isEmpty == true`; everything else surfaces a recoverable "not supported in this build" error. | Spec §pdf-reader "Seeded Document Is Navigable Without Import" mandates that the reader is reachable for the seed PDF without introducing import. No other document type qualifies in Phase 2. |
| D5 | Only `Bundle.main.url(forResource: "sample-bundle", withExtension: "pdf")` is a resolvable source for the reader. Missing or unreadable fixtures raise typed `PDFReaderError.fixtureMissing(resource:)` / `.fixtureUnreadable` and surface a recoverable error. | Spec §pdf-reader "Bundled Fixture Source" forbids any other PDF source for Phase 2. |
| D6 | `PDFPageChangeObserver` value-coalesces by `currentPageIndex` on `MainActor`. No `Task.sleep`, no `DispatchQueue.main.asyncAfter`, no timer. | Spec §pencil-canvas-overlay "Page-Change Save/Load Cycle" requires the observer to coalesce redundant notifications; value-coalescing is deterministic and reproducible. |
| D7 | `PencilCanvasOverlay` owns write-on-change (via `canvasViewDrawingDidChange`) AND lazy-upsert of `PageAnnotation` on first mount per page index. `PDFPageChangeObserver` owns the cross-page save/load cycle. | Spec §pencil-canvas-overlay splits the responsibility cleanly. Keeps `ModelContext` imports inside the reader surface, not inside PencilKit code. |
| D8 | Save failures inside the canvas surface a recoverable error via `@Observable lastError: AnnotationError?`; in-memory drawing is retained for the current session and previously persisted bytes are left untouched on disk. Decode failures surface `AnnotationError.drawingDecodeFailed`; the canvas renders empty and the unreadable `drawingData` is preserved. | Spec §pencil-canvas-overlay "Failure handling" requires recoverable errors and on-disk preservation. |
| D9 | The fixture is **project-authored and deterministic**: a small Swift script (`Tools/generate-sample-bundle-pdf.swift`) generates a 20-page PDF using `PDFKit`, with fixed seeds for page content, font, and layout. The generated bytes are written to `InSummary/Resources/Fixtures/sample-bundle.pdf` by the build phase. A dedicated `SAMPLE-BUNDLE-LICENSE.md` records the CC0 dedication, the generator SHA-256, and the page count. | User request: project-authored, deterministic, 20-page, CC0, generated locally. Avoids licensing risk and the local-only invariant. |
| D10 | All UI and persistence calls run on `MainActor`. `PDFView`, `PKCanvasView`, and SwiftData's main `ModelContext` are MainActor-bound in this codebase; tests share the same thread. No background queue, no `Task.detached`. | Spec §pencil-canvas-overlay "no time-based tests" and the codebase's existing MainActor isolation in `LibraryGridView` and `PreviewContainer`. |
| D11 | `PDFReaderCoordinator` does not import `PencilKit`. `PencilCanvasOverlay` and `PDFPageChangeObserver` do not import `PDFKit` publicly; they accept already-loaded values and a page index. | Keeps the engines independently testable. Mirrors the spec §4 separation between the PDF engine and the annotation engine. |
| D12 | Delivery uses the `feature-branch-chain` strategy with **four** child PRs in a **strictly linear** topology. A long-lived `tracker/pdf-reader-pencilkit-ink-recovery` branch carries a draft/no-merge PR targeting `main`; PR #1 targets the tracker; PR #N (N > 1) targets the branch of PR #(N-1); only the tracker ever merges to `main`. | `chained-pr` skill: each child PR ≤ 400 lines (largest ≈ 320 lines for PR #3), single deliverable unit, tests-with-code, no cross-slice bundle, draft tracker PR is the only path to `main`. The prior attempt's branching topology violated this rule. |
| D13 | The reader shell binds the seed `DocumentItem`'s `id` to the reader view through SwiftUI navigation, not through a global singleton. The shell opens, the coordinator initializes against the bound document, and the observer wires to the live `PDFView`. Re-entering the shell re-initializes against the same document. | Spec §pdf-reader "Preference Round-Trip": the persisted `paginationModeRaw` must survive a coordinator re-init. |
