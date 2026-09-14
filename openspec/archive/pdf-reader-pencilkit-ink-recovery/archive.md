# Archive — `pdf-reader-pencilkit-ink-recovery`

> Archive record for **Phase 2 of v1 of In-Summary** — the PDF reader and
> the PencilKit ink overlay. The change was approved, all four child PRs
> merged green into the tracker, and the tracker was merged into `main`.
> The OpenSpec change directory
> (`openspec/changes/pdf-reader-pencilkit-ink-recovery/`) is now archived
> here; the live `openspec/changes/` tree no longer carries this change.
> The Spanish mirror was archived to
> `documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/`
> concurrently.

## 1. Verdict

- **Phase 2 verdict**: ✅ **Pass** — all seven Phase 2 acceptance criteria
  from `proposal.md` §"Acceptance" are met.
- **Tracker PR**: PR #19 (`tracker/pdf-reader-pencilkit-ink-recovery`
  → `main`).
- **Final main merge SHA**:
  `973415d508a4d22a788e0408558f7875313ad3c4`.
- **Local tracker integration SHA**: `e2f71fb`.
- **Archive step**: task 5.5, performed by this slice (no production
  code, no test, no PBX, no fixture, no model, no resource touched).

## 2. Final main merge SHA

| Field | Value |
| --- | --- |
| Branch | `main` |
| Merge commit SHA (full) | `973415d508a4d22a788e0408558f7875313ad3c4` |
| Merge commit SHA (short) | `973415d` |
| Tracker PR | #19 (`tracker/pdf-reader-pencilkit-ink-recovery` → `main`) |
| Local tracker integration | `e2f71fb` |
| Child PRs carried | `#1 feat/pdf-fixture`, `#2 feat/pdf-engine`, `#3 feat/pencilkit-ink-overlay`, `#4 feat/pdf-reader-wiring` |
| Linear topology rule | Honored — only the tracker merged to `main` |

The SHA above is the canonical `main` head at the close of Phase 2 and
is the reference target for this archive. Any future re-verification
must check out `973415d508a4d22a788e0408558f7875313ad3c4` on `main` to
reproduce the established Phase 2 evidence.

## 3. Established test evidence

### 3.1 Full XCTest suite — 95/95 green

The full XCTest suite was executed on the iPad Pro 13-inch (M5), iOS
26.5 simulator (the configured M4 iOS 26.0 destination is not installed
on this host; the substitution preserves the iPad Pro 13-inch form
factor and the strict-TDD contract — documented in
`apply-progress.md` across slices 1–4). The captured tail is the exact
log produced by `xcodebuild test` on the tracker branch at the close of
slice 4.

### Exact command

```text
xcodebuild test \
  -project InSummary.xcodeproj \
  -scheme InSummary \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
```

### Observed result — full XCTest suite, 95/95 green

```text
Test Suite 'All tests' started.
Test Suite 'InSummaryTests.xctest' started.
Test Suite 'DocumentItemTests' passed.
        Executed 16 tests, with 0 failures (0 unexpected) in 0.022 (0.026) seconds
Test Suite 'FolderEntityTests' passed.
        Executed 6 tests, with 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Suite 'LibrarySeedServiceTests' passed.
        Executed 6 tests, with 0 failures (0 unexpected) in 0.024 (0.026) seconds
Test Suite 'PDFFixtureGeneratorTests' passed.
        Executed 9 tests, with 0 failures (0 unexpected) in 0.023 (0.025) seconds
Test Suite 'PageAnnotationTests' passed.
        Executed 7 tests, with 0 failures (0 unexpected) in 0.010 (0.011) seconds
Test Suite 'PersistenceControllerTests' passed.
        Executed 4 tests, with 0 failures (0 unexpected) in 0.016 (0.017) seconds
Test Suite 'PencilCanvasOverlayTests' passed.
        Executed 7 tests, with 0 failures (0 unexpected) in 0.053 (0.054) seconds
Test Suite 'PDFPageChangeObserverTests' passed.
        Executed 5 tests, with 0 failures (0 unexpected) in 0.040 (0.041) seconds
Test Suite 'PDFReaderCoordinatorTests' passed.
        Executed 11 tests, with 0 failures (0 unexpected) in 0.090 (0.093) seconds
Test Suite 'ReaderIntegrationTests' passed.
        Executed 2 tests, with 0 failures (0 unexpected) in 0.076 (0.077) seconds
Test Suite 'SampleBundleFixtureTests' passed.
        Executed 5 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds
Test Suite 'StickyNoteEntityTests' passed.
        Executed 9 tests, with 0 failures (0 unexpected) in 0.006 (0.008) seconds
Test Suite 'TextHighlightTests' passed.
        Executed 8 tests, with 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Suite 'InSummaryTests.xctest' passed.
        Executed 95 tests, with 0 failures (0 unexpected) in 0.331 (0.355) seconds
Test Suite 'All tests' passed.
        Executed 95 tests, with 0 failures (0 unexpected) in 0.331 (0.355) seconds

** TEST SUCCEEDED **
```

### 3.2 Per-suite breakdown

| Suite | Tests | Phase |
| --- | ---: | --- |
| `DocumentItemTests` | 16 | Phase 1 (unchanged) |
| `FolderEntityTests` | 6 | Phase 1 (unchanged) |
| `LibrarySeedServiceTests` | 6 | Phase 1 (unchanged) |
| `PDFFixtureGeneratorTests` | 9 | **Slice 1** (`feat/pdf-fixture`) |
| `PageAnnotationTests` | 7 | Phase 1 (unchanged) |
| `PersistenceControllerTests` | 4 | Phase 1 (unchanged) |
| `PencilCanvasOverlayTests` | 7 | **Slice 3** (`feat/pencilkit-ink-overlay`) |
| `PDFPageChangeObserverTests` | 5 | **Slice 3** (`feat/pencilkit-ink-overlay`) |
| `PDFReaderCoordinatorTests` | 11 | **Slice 2** (`feat/pdf-engine`) |
| `ReaderIntegrationTests` | 2 | **Slice 4** (`feat/pdf-reader-wiring`) |
| `SampleBundleFixtureTests` | 5 | **Slice 1** (`feat/pdf-fixture`) |
| `StickyNoteEntityTests` | 9 | Phase 1 (unchanged) |
| `TextHighlightTests` | 8 | Phase 1 (unchanged) |
| **Total** | **95** | **0 failures** |

### 3.3 Test delta (Phase 1 → Phase 2)

| Slice | Suite(s) | Tests added |
| --- | --- | ---: |
| Slice 1 (`feat/pdf-fixture`) | `PDFFixtureGeneratorTests`, `SampleBundleFixtureTests` | 14 |
| Slice 2 (`feat/pdf-engine`) | `PDFReaderCoordinatorTests` | 11 |
| Slice 3 (`feat/pencilkit-ink-overlay`) | `PencilCanvasOverlayTests`, `PDFPageChangeObserverTests` | 12 |
| Slice 4 (`feat/pdf-reader-wiring`) | `ReaderIntegrationTests` | 2 |
| **Total Phase 2 delta** | | **39** |
| Phase 1 baseline (unchanged) | `DocumentItemTests`, `FolderEntityTests`, `LibrarySeedServiceTests`, `PageAnnotationTests`, `PersistenceControllerTests`, `StickyNoteEntityTests`, `TextHighlightTests` | 56 |
| **Grand total** | | **95** |

### 3.4 Other integration gates

- **Grep guard sweep** (`openspec/config.yaml`
  `guards.blocked_substrings_in_product_code` against
  `InSummary/Services/PDFEngine/`, `InSummary/Services/AnnotationEngine/`,
  and `InSummary/Views/Reader/`): zero matches across all 17 blocklist
  patterns. `rg` exit code 1 (no matches). The wider defensive sweep
  across the whole `InSummary/` production tree also returns zero
  matches. Full blocklist command and per-pattern result recorded in
  `verification.md` §5.
- **Diff check**: clean. Canonical fixture path honored
  (`InSummary/Resources/Fixtures/sample-bundle.pdf`, 48 474 bytes,
  SHA-256
  `2d0f772b75d928e469c3bdaa21aba01d1cb23e24773fe2f8851b687588c6d491`).
  Every `PBXBuildFile` resolves from a real
  `PBXSourcesBuildPhase`/`PBXResourcesBuildPhase`. No orphan references.
  Phase 1 invariants preserved (`git diff main..HEAD -- InSummary/Models/`
  reports no change).
- **Airplane-mode acceptance**: passed by construction. No
  remote-capability call site exists in any Phase 2 file; the XCTest
  suite is timing-independent (no `Task.sleep`, no
  `DispatchQueue.main.asyncAfter`, no `Timer`, no `URLProtocol` stub).

## 4. Verification report pointers

The Phase 2 verification report captures each acceptance criterion with
its pin test, the captured XCTest log tail, and the gate-by-gate
verdict. After the archive, the verification report lives next to this
file under the same archive root.

| Artifact | Path (archive-relative) | Notes |
| --- | --- | --- |
| Verification report (English) | `./verification.md` | Phase 2 acceptance criteria pass/fail per criterion with supporting evidence. |
| Verification report (Spanish mirror) | `../../../../documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/verification-es.md` | Faithful neutral-Spanish mirror of `verification.md`. |

Cross-references recorded in `verification.md` §8 (deferred-task note)
and §6.4 (close-out scope) confirm that this archive step is the
authoritative source for Phase 2 close-out; the archive supersedes the
deferred-task note that previous slices carried.

## 5. What was archived

The entire OpenSpec change directory and its Spanish mirror were moved
from `changes/` into `archive/`. The contents below are byte-for-byte
identical to what was previously in `changes/`, with the only edits
being the task 5.5 checkbox flip on `tasks.md` / `tasks-es.md` (now
both `[x]`) and the append of this `archive.md` and `archive-es.md`.

### 5.1 English archive root

```text
openspec/archive/pdf-reader-pencilkit-ink-recovery/
├── README.md
├── archive.md                 (this file, NEW)
├── apply-progress.md
├── design.md
├── proposal.md
├── tasks.md                   (task 5.5 flipped [ ] → [x])
├── verification.md
└── specs/
    ├── pdf-engine/spec.md
    ├── pdf-fixture/spec.md
    ├── pdf-reader-wiring/spec.md
    └── pencilkit-ink-overlay/spec.md
```

### 5.2 Spanish mirror archive root

```text
documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/
├── README-es.md
├── archive-es.md              (NEW, faithful neutral-Spanish mirror)
├── design-es.md
├── proposal-es.md
├── tasks-es.md                (tarea 5.5 marcada [ ] → [x])
├── verification-es.md
└── specs/
    ├── pdf-engine/spec-es.md
    ├── pdf-fixture/spec-es.md
    ├── pdf-reader-wiring/spec-es.md
    └── pencilkit-ink-overlay/spec-es.md
```

## 6. Archive step (task 5.5) — scope and authority

### 6.1 Scope

Task 5.5 is a **documentation unit** owned by the
`<!-- sdd-owner: implementation -->` row. The work performed is:

1. Flipped the `5.5` row from `[ ]` to `[x]` in both `tasks.md` (English)
   and `tasks-es.md` (Spanish), so the persisted task artifact records
   the archive step as complete.
2. Created the empty `openspec/archive/` and
   `documents-es/openspec/archive/` directories and moved the entire
   `pdf-reader-pencilkit-ink-recovery/` change directory from each
   `changes/` tree into the corresponding `archive/` tree, leaving the
   `changes/` trees empty (the empty `changes/` directories were removed
   on this single-change repo).
3. Authored `archive.md` (English) and `archive-es.md` (Spanish) with
   this archive record (final main merge SHA, verification report
   pointers, established test evidence).
4. Appended a final entry to `apply-progress.md` (now living in the
   archive root) documenting the archive step.

### 6.2 Authority

- No production code under `InSummary/` was touched.
- No test, no PBX, no fixture binary, no model, no resource was
  touched.
- No `git commit`, no `git push`, no `git reset`, no PR open, no branch
  switch, no `git mv` was issued. The work is on disk only, awaiting
  the user's commit decision.
- No native SDD `acquire` / `settle` / `reset` was issued. The
  parent-held attempt token (recorded in `verification.md` §6.4 and in
  the `apply-progress.md` slice 5 close-out) is preserved unchanged.
- The edit is limited to the allowed edit surfaces listed in the
  parent prompt.

### 6.3 Deviations

- **None.** Task 5.5 is a documentation-only move; the parent prompt
  authorized `maintainer-authorized documentation archive` as the
  `size:exception` mode for this work unit.

## 7. Phase 2 close-out summary

Phase 2 of v1 ships to `main` (PR #19, commit
`973415d508a4d22a788e0408558f7875313ad3c4`):

- **Four capabilities** introduced through a `feature-branch-chain`
  (linear, four child PRs): `pdf-fixture`, `pdf-engine`,
  `pencilkit-ink-overlay`, `pdf-reader-wiring`. Only the tracker PR
  merged into `main` (linear topology rule honored).
- **39 new tests** added across slices 1–4 (14 + 11 + 12 + 2). Phase 1
  baseline (56 tests) byte-for-byte unchanged. Full suite: 95/95
  green.
- **Zero blocked-substring matches** in any Phase 2 module directory.
  Phase 2 imports exclusively first-party local frameworks
  (`Foundation`, `SwiftData`, `PDFKit`, `PencilKit`, `SwiftUI`,
  `UIKit`, `os`).
- **No Phase 1 entity mutated**. `DocumentItem.paginationModeRaw` and
  `PageAnnotation.drawingData` remain Phase 1 invariants; Phase 2
  reads and writes them as-is.
- **iPad-only, local-only**: no network, no iCloud, no CloudKit, no PDF
  import, no Apple Developer Program capabilities.

The Phase 2 verification closes with all seven acceptance criteria
satisfied. The archive step (task 5.5) is the only remaining
implementation-owned task; this archive record is its completion
evidence.
