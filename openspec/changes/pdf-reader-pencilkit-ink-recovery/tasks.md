# Tasks — pdf-reader-pencilkit-ink-recovery

> Strict-TDD task list. Tasks are grouped by child PR. Every task that
> introduces a public symbol also adds the XCTest that pins the
> behaviour. Out-of-scope tasks are listed at the bottom and **must
> not** be picked up inside any Phase 2 PR.
>
> Status legend: `[ ]` open · `[~]` in progress · `[x]` closed.

## Review workload forecast

| Field | Value |
| --- | --- |
| Estimated changed lines | ~990 total across four child PRs (no binary); largest PR ≈ 320 lines (PR #3) |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes |
| Chain topology | **Linear** (`tracker ← #1 ← #2 ← #3 ← #4`) |
| Delivery strategy | feature-branch-chain (linear) |
| Tracker merge target | `main` (only the tracker merges to main) |

Decision needed before apply: **No** — the chain is locked by
`openspec/config.yaml` and the orchestrator's preflight.

## 0. Tracker PR (this change)

- [x] 0.1 Write `openspec/config.yaml` (with explicit linear topology
      and the canonical fixture path) and `openspec/project-context.md`.
- [x] 0.2 Write `proposal.md`, `design.md`, `tasks.md`, and the four
      capability specs under
      `openspec/changes/pdf-reader-pencilkit-ink-recovery/`.
- [x] 0.3 Write the Spanish mirrors under
      `documents-es/openspec/changes/pdf-reader-pencilkit-ink-recovery/`.
- [ ] 0.4 Open the tracker PR as **draft / no-merge** with the chain
      dependency diagram.
- [ ] 0.5 Keep the tracker draft until every child PR (#1–#4) merges
      green.
      <!-- sdd-owner: parent -->

## 1. Child PR #1 — `feat/pdf-fixture` (target: tracker)

The fixture is a hard dependency of every test in Phase 2 and is
isolated into its own PR so every later PR can review reader behaviour
without fixture churn.

- [ ] 1.1 RED — add `InSummaryTests/Support/PDFFixtureGeneratorTests.swift`
      (alongside the generator) covering: two consecutive calls to
      `generateFixture() -> Data` produce byte-for-byte identical bytes;
      `PDFDocument(data:).pageCount == 20`; each page renders to a
      non-empty `UIImage` at 72 DPI; the canonical
      `fixtureContentHash` constant equals the SHA-256 of the output.
      Run against the baseline and confirm the suite is red.
      <!-- sdd-owner: implementation -->
- [ ] 1.2 GREEN — add `InSummaryTests/Support/PDFFixtureGenerator.swift`
      exposing `generateFixture() -> Data`, `fixtureContentHash: String`,
      and `fixturePageCount: Int`. The generator uses `PDFKit`
      (`UIGraphicsPDFRenderer` is acceptable; the chosen API must be
      deterministic) to draw 20 letter-sized pages, each carrying the
      page index in the bottom-right corner, a deterministic geometric
      pattern, and one block of CC0 text from a frozen constant.
      <!-- sdd-owner: implementation -->
- [ ] 1.3 GREEN — add `InSummary/Resources/Fixtures/sample-bundle.pdf`
      (binary) by running the generator locally. The exact path is
      canonical and must not vary.
      <!-- sdd-owner: implementation -->
- [ ] 1.4 GREEN — add
      `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` with the
      CC0 1.0 Universal dedication, the generator SHA-256, the page
      count, and a one-line "project-authored" assertion.
      <!-- sdd-owner: implementation -->
- [ ] 1.5 GREEN — wire `InSummary/Resources/Fixtures/sample-bundle.pdf`
      into `InSummary.xcodeproj` *Copy Bundle Resources* phase on the
      `InSummary` target. Confirm the file appears in the build output
      bundle under the same relative path.
      <!-- sdd-owner: implementation -->
- [ ] 1.6 GREEN — add
      `InSummaryTests/Fixtures/SampleBundleFixtureTests.swift` asserting:
      `Bundle.main.url(forResource: "sample-bundle", withExtension:
      "pdf")` resolves and is non-nil; the file is non-empty; the file
      is ≤ 1 MB; the bundled bytes' SHA-256 equals the in-process
      generator output's SHA-256; `PDFDocument(url:).pageCount == 20`.
      Run the suite and confirm green.
      <!-- sdd-owner: implementation -->
- [ ] 1.7 REFACTOR — collapse duplicated generator configuration into a
      single private helper; keep the page-by-page draw in one place;
      confirm two consecutive runs of the generator still produce
      byte-identical bytes.
      <!-- sdd-owner: implementation -->
- [ ] 1.8 VERIFY — run the grep guards across the PR diff and confirm
      zero matches for the blocked-substring list (especially
      `NSPersistentCloudKitContainer`, `URLSession`, `.fileImporter`,
      `https?://`). Run
      `xcodebuild test -scheme InSummary -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=26.0'`
      and confirm green. Rollback: revert the binary, the license file,
      the generator, the tests, and the PBX `Copy Bundle Resources`
      entry — no other slice touches these files.
      <!-- sdd-owner: implementation -->

## 2. Child PR #2 — `feat/pdf-engine` (target: PR #1's branch)

`PDFReaderCoordinator` is independent of PencilKit and benefits from
review in isolation. It targets PR #1 because the fixture must exist
before the coordinator can run its red-first tests.

- [ ] 2.1 RED — add
      `InSummaryTests/PDFReaderCoordinatorTests.swift` covering: the
      coordinator loads the bundled fixture; horizontal mode sets
      `displayMode = .singlePage` + `displayDirection = .horizontal`
      + `usePageViewController(true)`; vertical mode sets
      `displayMode = .singlePageContinuous` + `displayDirection =
      .vertical`; unknown `paginationModeRaw` falls back to horizontal;
      `paginationModeRaw` round-trip preserves the value across a
      coordinator re-init; the coordinator persists only
      `paginationModeRaw` + `updatedAt` to the SwiftData row; missing
      fixture surfaces `PDFReaderError.fixtureMissing(resource:)`;
      unreadable fixture surfaces `.fixtureUnreadable`; non-PDF
      document surfaces `.unsupportedDocument(reason:)`; document with
      non-empty `localFileName` surfaces
      `.unsupportedDocument(reason:)`. Run against the baseline and
      confirm red.
      <!-- sdd-owner: implementation -->
- [ ] 2.2 GREEN — add
      `InSummary/Services/PDFEngine/PDFReaderError.swift` with typed
      errors: `fixtureMissing(resource:)`, `fixtureUnreadable`,
      `unsupportedDocument(reason:)`, `paginationSaveFailed(underlying:)`.
      <!-- sdd-owner: implementation -->
- [ ] 2.3 GREEN — add
      `InSummary/Services/PDFEngine/PDFReaderCoordinator.swift`
      (`@MainActor`, no `PencilKit` import, no public `SwiftData` model
      types beyond the existing `DocumentItem` reference) to turn the
      new tests green.
      <!-- sdd-owner: implementation -->
- [ ] 2.4 GREEN — wire the two new files into `InSummary.xcodeproj`
      *Sources* phase on the `InSummary` target.
      <!-- sdd-owner: implementation -->
- [ ] 2.5 TRIANGULATE — add a test asserting that `setPaginationMode`
      calls `modelContext.save()` and that the persisted row's
      `updatedAt` advances while every other field stays equal.
      <!-- sdd-owner: implementation -->
- [ ] 2.6 REFACTOR — keep the coordinator free of `PencilKit` and any
      `SwiftData` model imports beyond `DocumentItem`; collapse
      duplicated fixture-URL lookup into a single private helper.
      <!-- sdd-owner: implementation -->
- [ ] 2.7 VERIFY — run
      `xcodebuild test -scheme InSummary -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=26.0' -only-testing:InSummaryTests/PDFReaderCoordinatorTests`
      and confirm green. Run the grep guards scoped to
      `InSummary/Services/PDFEngine/`:
      ```bash
      rg -n --type swift \
         -e 'NSPersistentCloudKitContainer' \
         -e 'CKContainer' \
         -e 'CKDatabase' \
         -e 'CKAsset' \
         -e 'cloudKitDatabase' \
         -e 'CloudSyncMonitor' \
         -e 'RemoteNotification' \
         -e '.fileImporter' \
         -e 'UIDocumentPickerViewController' \
         -e 'PHPickerViewController' \
         -e 'URLSession.shared' \
         -e 'NWConnection' \
         -e 'NWPath' \
         -e 'https?://' \
         InSummary/Services/PDFEngine
      ```
      A single match fails verification. Rollback: delete the two
      source files, the test, and the PBX *Sources* entries — no
      later slice imports them.
      <!-- sdd-owner: implementation -->

## 3. Child PR #3 — `feat/pencilkit-ink-overlay` (target: PR #2's branch)

The overlay and observer depend on the coordinator's page-change signal
(PR #2) and on the bundled fixture (PR #1). They target PR #2 so the
chain stays linear.

- [ ] 3.1 RED — add
      `InSummaryTests/PencilCanvasOverlayTests.swift` covering:
      `drawingPolicy == .pencilOnly`; default tool is the highlighter
      (`PKInkingTool.InkType.highlighter`); replay byte-identical when
      the supplied `PageAnnotation` has non-empty `drawingData`;
      missing `PageAnnotation` triggers a lazy-upsert and the canvas
      renders blank; clearing the canvas persists empty bytes; a
      decode failure sets `lastError = .drawingDecodeFailed`, renders
      the canvas empty, and leaves the unreadable `drawingData`
      untouched on the row. Run against the baseline and confirm red.
      <!-- sdd-owner: implementation -->
- [ ] 3.2 GREEN — add
      `InSummary/Services/AnnotationEngine/AnnotationError.swift` with
      typed errors: `drawingDecodeFailed`,
      `drawingPersistenceFailed(underlying:)`.
      <!-- sdd-owner: implementation -->
- [ ] 3.3 GREEN — add
      `InSummary/Services/AnnotationEngine/PencilCanvasOverlay.swift`
      (`UIViewRepresentable` wrapping `PKCanvasView`, `@MainActor`, no
      `PDFKit` import, no public `SwiftData` model imports beyond the
      existing `PageAnnotation` reference) to turn the new tests green.
      <!-- sdd-owner: implementation -->
- [ ] 3.4 RED — add
      `InSummaryTests/PDFPageChangeObserverTests.swift` covering:
      round-trip preserves byte-identical `PKDrawing` payloads across
      pages 1 → 2 → 1; five navigation cycles are stable; the observer
      drops notifications whose `currentPageIndex` equals the last
      observed index (value-coalescing); a coordinator re-init keeps
      stored drawings; a save failure surfaces
      `AnnotationError.drawingPersistenceFailed(underlying:)` and
      `lastObservedPageIndex` is **not** mutated on failure. Run
      against the baseline and confirm red.
      <!-- sdd-owner: implementation -->
- [ ] 3.5 GREEN — add
      `InSummary/Services/AnnotationEngine/PDFPageChangeObserver.swift`
      (`@MainActor final class`, no `PDFKit` import, no public
      `SwiftData` model imports beyond `DocumentItem.id` and the
      supplied `PageAnnotation`) to turn the new tests green.
      <!-- sdd-owner: implementation -->
- [ ] 3.6 GREEN — wire the three new files into `InSummary.xcodeproj`
      *Sources* phase on the `InSummary` target.
      <!-- sdd-owner: implementation -->
- [ ] 3.7 REFACTOR — collapse duplicated canvas configuration into a
      single private helper; keep `PKCanvasView` setup in one place;
      pull the `NotificationCenter` subscription into the view layer
      (added in PR #4) so the observer remains testable in isolation.
      <!-- sdd-owner: implementation -->
- [ ] 3.8 VERIFY — run
      `xcodebuild test -scheme InSummary -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=26.0' -only-testing:InSummaryTests/PencilCanvasOverlayTests -only-testing:InSummaryTests/PDFPageChangeObserverTests`
      and confirm green. Rollback: delete the source files, the error
      file, the tests, and the PBX *Sources* entries — the overlay and
      observer are not yet referenced anywhere outside their own test
      target.
      <!-- sdd-owner: implementation -->

## 4. Child PR #4 — `feat/pdf-reader-wiring` (target: PR #3's branch)

This slice wires everything into the existing library shell. It depends
on PR #1 (fixture), PR #2 (coordinator), and PR #3 (overlay + observer).
It targets PR #3 because the chain must remain linear — it is the
terminal child PR before the tracker close-out.

- [ ] 4.1 Add `InSummary/Views/Reader/PDFViewRepresentable.swift`
      (`UIViewRepresentable` around `PDFView`; hands the `pdfView`
      reference to the coordinator after `makeUIView`).
      <!-- sdd-owner: implementation -->
- [ ] 4.2 Add `InSummary/Views/Reader/ReaderContainerView.swift` (v1):
      SwiftUI shell hosting `PDFViewRepresentable(coordinator:)` plus
      a recoverable `PDFReaderError` banner. **Do not** reference
      `PencilCanvasOverlay` or `PDFPageChangeObserver` in v1; they are
      wired in step 4.4.
      <!-- sdd-owner: implementation -->
- [ ] 4.3 Modify `InSummary/Views/Library/LibraryGridView.swift`: the
      seed `DocumentItem` row becomes a `NavigationLink` to
      `ReaderContainerView(document:)`; every other row surfaces the
      recoverable "not supported in this build" alert. Keep the change
      to the library file under ~30 lines.
      <!-- sdd-owner: implementation -->
- [ ] 4.4 Extend `ReaderContainerView` (v2): add
      `PencilCanvasOverlay(pageIndex:, pageAnnotation:, modelContext:)`
      to the body, add an `AnnotationError` banner, construct
      `PDFPageChangeObserver` against the live `PDFView`, and subscribe
      to the coordinator's page-change publisher via `.onReceive` so
      each event routes to `observer.handlePageChange(to:)`.
      <!-- sdd-owner: implementation -->
- [ ] 4.5 Add a `#Preview` to `ReaderContainerView.swift` that mounts
      against `PreviewContainer.previewContainer` and renders two pages
      with distinct ink so the reviewer can verify the round-trip
      visually.
      <!-- sdd-owner: implementation -->
- [ ] 4.6 RED — add `InSummaryTests/ReaderIntegrationTests.swift`
      covering: open the bundled fixture, navigate across pages, draw
      on page 1 and page 2, return to page 1, assert
      `PKDrawing.dataRepresentation()` is byte-for-byte preserved on
      both pages; preference round-trip across reopening the document.
      Run against the baseline and confirm red.
      <!-- sdd-owner: implementation -->
- [ ] 4.7 GREEN — wire the two new files into `InSummary.xcodeproj`
      *Sources* phase on the `InSummary` target.
      <!-- sdd-owner: implementation -->
- [ ] 4.8 REFACTOR — confirm `ReaderContainerView.swift` (v2) compiles
      with no `PDFKit` import (it only uses the coordinator and the
      overlay); isolate the banner into a small sub-view.
      <!-- sdd-owner: implementation -->
- [ ] 4.9 VERIFY — run the **full** XCTest suite
      (`SampleBundleFixtureTests` + `PDFFixtureGeneratorTests` +
      `PDFReaderCoordinatorTests` + `PencilCanvasOverlayTests` +
      `PDFPageChangeObserverTests` + `ReaderIntegrationTests`) on the
      iPadOS simulator destination and confirm green. The `#Preview`
      renders two pages with distinct ink. Run the grep guards scoped
      to `InSummary/Services/PDFEngine/`,
      `InSummary/Services/AnnotationEngine/`, and
      `InSummary/Views/Reader/`; zero matches required. Rollback:
      revert `ReaderContainerView.swift` to its v1 state, delete the
      PDF view representable, delete the integration tests, drop the
      PBX *Sources* entries — Slice 4 is the integration point and is
      fully removable.
      <!-- sdd-owner: implementation -->

## 5. Tracker close-out (after all four child PRs merge green)

- [ ] 5.1 Rebase (or fast-forward) `tracker/pdf-reader-pencilkit-ink-recovery`
      onto the head of PR #4's branch so the tracker carries every
      merged child.
      <!-- sdd-owner: parent -->
- [ ] 5.2 Run the integration gates on the tracker branch (full XCTest
      suite, grep guards across the whole `InSummary/` tree, airplane-mode
      acceptance) and confirm green before promoting the tracker PR out
      of draft.
      <!-- sdd-owner: parent -->
- [ ] 5.3 Promote the tracker PR from **draft** → **ready** and merge
      `tracker/pdf-reader-pencilkit-ink-recovery` into `main`. **Only the
      tracker ever merges into `main`; no child PR targets `main`
      directly.**
      <!-- sdd-owner: parent -->
- [ ] 5.4 Author `openspec/changes/pdf-reader-pencilkit-ink-recovery/verification.md`
      with pass/fail checkboxes for each Phase 2 acceptance criterion
      from `proposal.md`, the captured log tail, the grep results, and
      the airplane-mode result.
      <!-- sdd-owner: implementation -->
- [ ] 5.5 Archive the change: move
      `openspec/changes/pdf-reader-pencilkit-ink-recovery/` to
      `openspec/archive/pdf-reader-pencilkit-ink-recovery/` and append
      `openspec/archive/pdf-reader-pencilkit-ink-recovery/archive.md`
      with the final SHA, the green-test log tail, and the verification
      report pointer. Mirror the archive under
      `documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/`.
      <!-- sdd-owner: implementation -->

## Constraints carried by every task

- iPad-only. iPhone / Mac Catalyst targets stay disabled.
- Local-only. No network, no iCloud, no CloudKit, no Apple Developer
  Program capabilities.
- Strict TDD: red-first; tests ship with code in the same work unit
  (slice); the only exception is the SwiftUI shell skeleton in step
  4.2, which compiles against the existing PR #2 coordinator and is
  verified by the full XCTest suite in step 4.8.
- No schema changes. `DocumentItem.paginationModeRaw` and
  `PageAnnotation.drawingData` are Phase 1 invariants. Phase 2 reads
  and writes them as-is.
- Fixture path is **exactly** `InSummary/Resources/Fixtures/sample-bundle.pdf`
  (plural `Fixtures`, hyphenated name). The forbidden paths
  (`Fixture/sample.pdf`, `Fixtures/sample.pdf`, or any other variant)
  are listed in `openspec/config.yaml` and must fail review if they
  appear.
- Linear topology. Every child PR after #1 targets its immediate
  predecessor's branch. Only PR #1 targets the tracker. Only the
  tracker merges into `main`. No branching, no fan-out.
- Review budget is **400 lines** per PR. The `chained-pr` skill's
  `feature-branch-chain` strategy applies with **four** child PRs:
  `#1` → `#2` → `#3` → `#4`. A long-lived
  `tracker/pdf-reader-pencilkit-ink-recovery` branch carries a
  draft/no-merge PR targeting `main`. Do not bundle implementation +
  verification in the same PR if the diff exceeds the budget, and do
  not request `size:exception` — the four-PR split keeps every PR well
  under 400 changed lines.

## Out of scope (do not start inside any Phase 2 PR)

- Semantic highlights (Phase 4).
- Sticky notes (Phase 4).
- EPUB engine, Markdown engine (Phase 3).
- Import, export, folders, library shell additions (Phase 5).
- Multi-window, theming, accessibility polish (Phase 6).
- iCloud / CloudKit / `CKAsset` / sync monitor / push notifications
  (deferred to a future phase; forbidden by the Phase 2 guards in
  `openspec/config.yaml`).
- Network calls of any kind.
- Snapshot tests (deferred to Phase 6 per the spec).
- Adding, altering, defaulting, or migrating any Phase 1 entity
  (`DocumentItem`, `FolderEntity`, `PageAnnotation`, `TextHighlight`,
  `StickyNoteEntity`).
- A separate ink file store on disk. `PageAnnotation.drawingData` is
  reused directly.
