# Change `pdf-reader-pencilkit-ink-recovery`

Phase 2 of **In-Summary** — the PDF reader and the PencilKit ink overlay —
delivered through a `feature-branch-chain` with this tracker PR as the
single merge point into `main`.

## Quick path for reviewers

1. Read `proposal.md` (~2 minutes) to confirm scope and out-of-scope.
2. Read `design.md` §1–§4 (~5 minutes) for the technical shape.
3. Skim `specs/` to confirm every requirement is testable.
4. Validate `tasks.md` against the **linear** child PR chain.
5. Verify the Spanish mirrors under
   `documents-es/openspec/changes/pdf-reader-pencilkit-ink-recovery/`.

## Decision in one screen

| Question | Answer |
| --- | --- |
| What ships in this change? | A 20-page deterministic CC0 PDF fixture at `InSummary/Resources/Fixtures/sample-bundle.pdf`, a `PDFReaderCoordinator` with horizontal/vertical pagination, a `PencilCanvasOverlay` with `.pencilOnly` and `.highlighter`, a `PDFPageChangeObserver` that swaps and persists `PKDrawing` bytes across page changes, and a `ReaderContainerView` reachable from the Phase 1 library shell. |
| What does this change reuse from Phase 1? | `DocumentItem.paginationModeRaw` (default `"horizontal"`) for the per-document preference and `PageAnnotation.drawingData` for ink persistence. **No schema changes.** |
| What is the fixture path? | Exactly `InSummary/Resources/Fixtures/sample-bundle.pdf` (plural `Fixtures`, hyphenated name). |
| What is the PR chain shape? | Strictly linear: `tracker ← PR #1 ← PR #2 ← PR #3 ← PR #4`. Only PR #1 targets the tracker. Only the tracker merges into `main`. |
| What is out of scope? | Import, export, library shell additions, sticky notes, semantic highlights, EPUB/Markdown engines, theming, multi-window, iCloud, CloudKit, `CKAsset`, push notifications, network of any kind. |

## What's in this change

| File | Purpose |
| --- | --- |
| `proposal.md` | Why, what, scope, and delivery plan |
| `design.md` | Technical decisions, phase-1 invariants, and slice boundaries |
| `tasks.md` | Strict-TDD checklist per child PR |
| `specs/pdf-fixture/spec.md` | Capability: project-authored deterministic CC0 20-page PDF bundled at build time |
| `specs/pdf-engine/spec.md` | Capability: `PDFReaderCoordinator` with horizontal/vertical pagination |
| `specs/pencilkit-ink-overlay/spec.md` | Capability: Pencil-only ink overlay + page-change persistence on `PageAnnotation.drawingData` |
| `specs/pdf-reader-wiring/spec.md` | Capability: `ReaderContainerView` composition + library navigation |

## What is intentionally absent

- No product code under `InSummary/` (this is the tracker PR — code lands
  in child PRs #1–#4).
- No fixture PDF binary anywhere in the repo (the fixture generator and
  its build phase land in PR #1).
- No iCloud, CloudKit, `CKAsset`, network, import, or export.
- No modification to `InSummary/Models/DocumentItem.swift` or
  `InSummary/Models/PageAnnotation.swift`. Both are Phase 1 invariants.
- No reference to the prior blocked attempt's partial code or planning
  artifacts.

## Child PR chain (strictly linear)

```
tracker/pdf-reader-pencilkit-ink-recovery   ← 🧭 tracker (this PR, draft / no-merge)
        ↑
        │ PR #1 targets the tracker
        │
feat/pdf-fixture                             ← PR #1 (Slice 1 — fixture + build phase)
        ↑
        │ PR #2 targets PR #1's branch
        │
feat/pdf-engine                              ← PR #2 (Slice 2 — PDF reader core)
        ↑
        │ PR #3 targets PR #2's branch
        │
feat/pencilkit-ink-overlay                   ← PR #3 (Slice 3 — overlay + observer)
        ↑
        │ PR #4 targets PR #3's branch
        │
feat/pdf-reader-wiring                       ← PR #4 (Slice 4 — shell + library nav)
```

**Topology rule:** every child PR after #1 targets the **immediate
predecessor's branch**. No fan-out. No child PR targets the tracker
except PR #1. Only the tracker merges into `main`.

Each child PR body carries:
- A dependency diagram marking itself with 📍 and the tracker with 🧭.
- The chain context block (start, end, prior dependency, follow-up work,
  out-of-scope items).
- A `size:exception` rationale **only** if the PR exceeds 400 changed
  lines (none of the four child PRs is forecast to do so).

## Next step

Open the **tracker PR** as **draft / no-merge**. Hand off to the parent
orchestrator to spawn child PR #1 (`feat/pdf-fixture`) once the tracker
PR is open.
