# Proposal — pdf-reader-pencilkit-ink-recovery

## Why

Phase 2 of v1 introduces the first real reader surface in **In-Summary**:
the PDF engine with horizontal/vertical pagination, the PencilKit ink
overlay that records the reader's handwriting per logical page, and the
page-change persistence that keeps every page's
`PKDrawing.dataRepresentation()` intact across navigation.

This change is a **recovery** of the same scope whose first init gate
failed on three counts:

1. It invented a `paginationModeRaw` schema field that Phase 1 already
   ships as `var paginationModeRaw: String = "horizontal"` in
   `InSummary/Models/DocumentItem.swift`.
2. It used the wrong fixture path
   (`InSummary/Resources/Fixture/sample.pdf`) instead of the canonical
   `InSummary/Resources/Fixtures/sample-bundle.pdf`.
3. It produced a branching PR topology (two child PRs targeting the
   tracker branch) instead of the strict linear chain the
   `chained-pr` skill requires for `feature-branch-chain`.

This successor **does not** reuse or reference any partial code from the
prior attempt. It carries forward only the confirmed product decisions:

- iPad-only and local-only — Phase 2 ships no iCloud, CloudKit, network,
  import, export, or sync code path.
- The fixture used to exercise the reader is a **project-authored,
  deterministic, CC0, 20-page PDF** located at exactly
  `InSummary/Resources/Fixtures/sample-bundle.pdf`.
- Delivery follows a `feature-branch-chain` with a draft/no-merge tracker
  PR; each child PR is ≤ 400 changed lines and reviews in ≤ 60 minutes.
- The PR chain is **strictly linear**: every child PR after #1 targets the
  immediate predecessor's branch; only PR #1 targets the tracker.

## What changes

A new reader path opens a 20-page local PDF and lets the reader:

1. Choose horizontal paginated mode or vertical continuous mode; the choice
   is read from `DocumentItem.paginationModeRaw` (a Phase 1 invariant) and
   written back on toggle, so it persists per document across reopening.
2. Navigate with the native `PDFView` gesture stack (swipe in horizontal,
   scroll in vertical).
3. Draw with Apple Pencil on any page; finger touches are ignored.
4. Leave the page and return — the strokes drawn on each page survive the
   navigation byte-for-byte, persisted on the Phase 1
   `PageAnnotation.drawingData` column (already declared with
   `@Attribute(.externalStorage)`).

Four capabilities are introduced through this change:

- `pdf-fixture` — the project-authored deterministic CC0 20-page PDF
  shipped at exactly `InSummary/Resources/Fixtures/sample-bundle.pdf`.
- `pdf-engine` — `PDFReaderCoordinator` with horizontal and vertical
  modes; reads `paginationModeRaw` (does not add or alter the field).
- `pencilkit-ink-overlay` — `PencilCanvasOverlay` (`.pencilOnly`,
  `.highlighter`) plus `PDFPageChangeObserver` that persists
  `PKDrawing.dataRepresentation()` on `PageAnnotation.drawingData`.
- `pdf-reader-wiring` — `ReaderContainerView` composition and the
  navigation wiring from the Phase 1 library shell so the seed PDF is
  reachable without introducing import.

## Phase 1 invariants this change reuses (do not modify)

| Invariant | Where it lives | What Phase 2 does |
| --- | --- | --- |
| `DocumentItem.paginationModeRaw: String` default `"horizontal"` | `InSummary/Models/DocumentItem.swift` | Read once when the coordinator opens; write back when the reader toggles mode. **No schema change.** |
| `PageAnnotation.drawingData: Data?` with `@Attribute(.externalStorage)` | `InSummary/Models/PageAnnotation.swift` (declared in `specification.md` §3.1) | Use as the per-page ink store. `PencilCanvasOverlay` reads/writes this column directly. No parallel file store is introduced. |
| No `@Attribute(.unique)` anywhere on the local SwiftData schema | Phase 1 + `specification.md` §3.5 | Untouched. No new entities. No new relationships. |
| CloudKit-compatible by design | Phase 1 + `specification.md` §3.1 | Untouched. Phase 2 does not introduce fields or relationships that would break future sync. |

## Non-goals (explicit)

| Non-goal | Why it is excluded |
| --- | --- |
| Add, alter, default, or migrate `DocumentItem.paginationModeRaw` | Phase 1 already ships it. Phase 2 reads and writes the field as-is. |
| Add, alter, default, or migrate `PageAnnotation.drawingData` | Phase 1 already ships it with `@Attribute(.externalStorage)`. Phase 2 reuses it. |
| PDF import via `.fileImporter`, `UIDocumentPickerViewController`, or `PHPickerViewController` | Phase 5 — out of `phases.in_scope`. The reader is exercised only by the bundled fixture. |
| Library, folders, drag-and-drop organization | Phase 5 — out of scope. |
| Burned-in PDF export | Phase 5 — out of scope. |
| Sticky notes | Phase 4 — out of scope. |
| Semantic highlights (PDF text selection) | Phase 4 — out of scope. |
| Markdown or EPUB engines | Phase 3 — out of scope. |
| iCloud / CloudKit sync, "Make available on my other devices", `CKAsset`, push notifications | Future phase — must not enter v1. The blocked-substring list in `openspec/config.yaml` enforces this in product code. |
| Apple Developer Program capabilities (push, CloudKit container, App Group across devices) | Personal/development signing is sufficient for v1. |
| Network requests of any kind (`URLSession`, `NWConnection`, raw sockets, analytics, telemetry) | Local-only invariant. |
| A separate ink file store on disk | `PageAnnotation.drawingData` already exists in Phase 1. Phase 2 does not invent a parallel store. |

## Product boundary (this change)

- **iPad only.** No iPhone target, no Mac Catalyst target, no visionOS.
- **Local only.** All file reads come from the app bundle or the local
  SwiftData store. Zero outbound network requests.
- **No remote capabilities.** No iCloud, CloudKit, push, remote
  notification, or background URL session.
- **No Apple Developer Program.** Personal / development signing is
  sufficient.
- **Only local, first-party frameworks.** `PDFKit`, `PencilKit`,
  `SwiftData`, `SwiftUI`, `UIKit`. No third-party SDKs.

## What ships in code

| Path | Layer | Notes |
| --- | --- | --- |
| `InSummary/Services/PDFEngine/PDFReaderCoordinator.swift` | Domain | `@MainActor` `UIViewRepresentable` that owns a `PDFView`. Reads `paginationModeRaw` once and writes back on toggle. No `PencilKit` import. |
| `InSummary/Services/PDFEngine/PDFReaderError.swift` | Domain | Typed errors: `fixtureMissing(resource:)`, `fixtureUnreadable`, `unsupportedDocument(reason:)`, `paginationSaveFailed(underlying:)`. |
| `InSummary/Services/AnnotationEngine/PencilCanvasOverlay.swift` | Domain | `UIViewRepresentable` wrapping `PKCanvasView` with `drawingPolicy = .pencilOnly` and the highlighter as the default tool. Reads/writes `PageAnnotation.drawingData`. No `PDFKit` import. |
| `InSummary/Services/AnnotationEngine/PDFPageChangeObserver.swift` | Domain | `@MainActor final class` that observes the page-change signal and swaps `PKDrawing` between pages. No `PDFKit` import; accepts an injected page index. |
| `InSummary/Services/AnnotationEngine/AnnotationError.swift` | Domain | Typed errors: `drawingDecodeFailed`, `drawingPersistenceFailed(underlying:)`. |
| `InSummary/Views/Reader/ReaderContainerView.swift` | Presentation | SwiftUI shell. Composes the coordinator and the overlay; subscribes the observer to the coordinator's page-change publisher; surfaces recoverable error banners. |
| `InSummary/Views/Reader/PDFViewRepresentable.swift` | Presentation | Thin `UIViewRepresentable` wrapper around `PDFView` so the coordinator can read the live reference. |
| `InSummary/Views/Library/LibraryGridView.swift` (modified) | Presentation | Seed PDF row becomes a `NavigationLink` to `ReaderContainerView(document:)`; non-PDF or non-seed rows surface a recoverable "not supported in this build" alert. |
| `Tools/generate-sample-bundle-pdf.swift` | Tools | Project-authored deterministic generator that emits 20 pages of CC0 text into `InSummary/Resources/Fixtures/sample-bundle.pdf`. Runs locally and at build time. |

## What ships in resources

| Path | Purpose |
| --- | --- |
| `InSummary/Resources/Fixtures/sample-bundle.pdf` | The fixture PDF. Project-authored, deterministic, CC0, 20 pages. Added by the build phase in PR #1. The exact path is canonical and must not vary. |
| `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` | CC0 dedication, generator SHA-256, page count. Added by PR #1. |

## What ships in tests

| Path | Covers |
| --- | --- |
| `InSummaryTests/Fixtures/PDFFixtureGeneratorTests.swift` | The generator's determinism (two runs hash identically), page count = 20, paper size, per-page render. |
| `InSummaryTests/Fixtures/SampleBundleFixtureTests.swift` | The bundled fixture resolves from `Bundle.main`, is non-empty, ≤ 1 MB, and loads as a 20-page `PDFDocument`. |
| `InSummaryTests/PDFReaderCoordinatorTests.swift` | Opens the bundled fixture; horizontal mode sets `displayMode = .singlePage` + `displayDirection = .horizontal`; vertical mode sets `displayMode = .singlePageContinuous` + `displayDirection = .vertical`; unknown mode falls back to horizontal; `paginationModeRaw` round-trip persists the value; missing fixture surfaces `PDFReaderError.fixtureMissing`; unreadable fixture surfaces `.fixtureUnreadable`; non-PDF or non-seed document surfaces `.unsupportedDocument`. |
| `InSummaryTests/PencilCanvasOverlayTests.swift` | `drawingPolicy == .pencilOnly`; default tool is the highlighter; replay from `PageAnnotation.drawingData` is byte-for-byte; missing `PageAnnotation` lazy-upserts a row; clearing the canvas persists empty bytes. |
| `InSummaryTests/PDFPageChangeObserverTests.swift` | Round-trip preserves byte-identical `PKDrawing` payloads across pages 1 → 2 → 1; five navigation cycles are stable; the observer drops notifications whose `currentPageIndex` equals the last observed index (value-coalescing). |
| `InSummaryTests/ReaderIntegrationTests.swift` | End-to-end: open the bundled fixture, navigate across pages, draw on page 1 and page 2, return, assert strokes are byte-for-byte preserved; offline (airplane mode) acceptance check. |

## Untouched

- `InSummary/Models/*` — no schema changes; Phase 1 entities are reused.
- `InSummary/Services/Persistence/*` — schema unchanged; this change
  reuses the Phase 1 `ModelContainer` and `LibrarySeedService`.
- `InSummary/Info.plist` — no new usage descriptions; PDF access is
  bundle-only in v1.

## Acceptance (mirrors `specification.md` §6 Phase 2)

1. Opening the bundled fixture in horizontal mode allows swiping between
   pages with `PDFView`'s native transition.
2. Opening the bundled fixture in vertical mode allows continuous scrolling
   through every page.
3. Drawing on page 1, navigating to page 2 (blank canvas), drawing on
   page 2, and returning to page 1 yields byte-identical `PKDrawing`
   payloads on both pages, both persisted on `PageAnnotation.drawingData`.
4. The horizontal / vertical preference (read from
   `DocumentItem.paginationModeRaw`) is preserved across closing and
   reopening the document.
5. `PencilCanvasOverlay` ignores finger touches; only Pencil draws
   (`drawingPolicy == .pencilOnly`).
6. The full XCTest suite runs green on an iPadOS simulator with the
   device in airplane mode (offline acceptance).
7. A code search for the blocked substrings listed in
   `openspec/config.yaml` returns zero matches in
   `InSummary/Services/PDFEngine/`,
   `InSummary/Services/AnnotationEngine/`, and
   `InSummary/Views/Reader/`.

## Risks

| Risk | Mitigation |
| --- | --- |
| Drift between the bundled `sample-bundle.pdf` and the in-process generator output | A dedicated XCTest loads both, hashes them, and fails the suite on any drift. The build phase regenerates the file when the generator source changes. |
| `PDFView` page-change notifications fire on background renders | `PDFPageChangeObserver` value-coalesces on `currentPageIndex`; tests assert the save/load contract, not timing. No `Task.sleep`, no `DispatchQueue.main.asyncAfter`, no timer. |
| Decoder rejection of stored `PKDrawing` bytes | `AnnotationError.drawingDecodeFailed` surfaces a recoverable error; the unreadable `drawingData` is preserved untouched and the canvas renders empty. |
| Reader size on real iPad | Out of scope for v1; the iPad-only invariant keeps the matrix small. The 20-page fixture is the bound. |
| The prior failed init's artifacts leak into this recovery | The recovery tracker branch was created at the Phase 1 merge (`94b0f0c`). The prior attempt's untracked planning files have been removed from this worktree. No code or fixture from the prior attempt is referenced. |

## Delivery

This is the **tracker PR**. It contains only planning artifacts — no
production code, no fixture binary. The implementation lands through four
child PRs, each ≤ 400 changed lines, each pushed on a `feat/<slice-id>`
branch off the immediate predecessor's branch (or, for PR #1 only, off
the tracker branch):

| # | Branch | Slice | Target branch | Lines forecast |
| - | --- | --- | --- | --- |
| 1 | `feat/pdf-fixture` | Project-authored deterministic CC0 20-page PDF + build phase + license file + fixture tests | `tracker/pdf-reader-pencilkit-ink-recovery` | ~ 150 |
| 2 | `feat/pdf-engine` | `PDFReaderCoordinator` + `PDFReaderError` + coordinator tests, no UI shell | PR #1's branch | ~ 280 |
| 3 | `feat/pencilkit-ink-overlay` | `PencilCanvasOverlay` + `PDFPageChangeObserver` + `AnnotationError` + overlay/observer tests | PR #2's branch | ~ 320 |
| 4 | `feat/pdf-reader-wiring` | `ReaderContainerView` + `PDFViewRepresentable` + `LibraryGridView` navigation wiring + integration tests | PR #3's branch | ~ 240 |

**Topology rule (strict):** every child PR after #1 targets its immediate
predecessor's branch. Only PR #1 targets the tracker. Only the tracker
merges into `main`. No branching, no fan-out, no child PR targeting the
tracker except PR #1.

The tracker PR stays **draft / no-merge** until every child PR merges
green. Only then is the tracker rebased onto `main` and merged.

## Confirmation

- [x] Proposal framed against `specification.md` §6 Phase 2.
- [x] No code from the prior blocked attempt is referenced or reused.
- [x] `DocumentItem.paginationModeRaw` is treated as a Phase 1 invariant
      — not added, not altered, not migrated, not defaulted.
- [x] `PageAnnotation.drawingData` is reused as the per-page ink store —
      no parallel file store is introduced.
- [x] The fixture path is exactly
      `InSummary/Resources/Fixtures/sample-bundle.pdf` in every artifact,
      test, build phase, and PR description.
- [x] The PR chain is strictly linear
      (`tracker ← #1 ← #2 ← #3 ← #4`).
- [x] No iCloud, CloudKit, `CKAsset`, `NSPersistentCloudKitContainer`,
      `URLSession`, `NWConnection`, `.fileImporter`,
      `UIDocumentPickerViewController`, or `PHPickerViewController` is
      proposed in product code.
- [x] The bundle is local-only; only `PDFKit`, `PencilKit`, `SwiftData`,
      `SwiftUI`, and `UIKit` are imported by the new code.
