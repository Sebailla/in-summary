# In-Summary — OpenSpec project context

> Maintained by the SDD init phase. Read this before bootstrapping any new
> change; it captures the canonical project context, the SDD configuration,
> and the active guardrails that every subsequent phase must respect.

## Project snapshot

- **Project**: In-Summary (universal reader & annotator for iPad).
- **Platform**: iPadOS 26.0+ only. No iPhone, no Mac Catalyst, no visionOS.
- **Language / toolchain**: Swift 5.10+ on Xcode 26 (Swift 6 toolchain
  available); SwiftUI shell, PDFKit, PencilKit, SwiftData persistence.
- **v1 product posture**: local-first, single-user, fully offline, no Apple
  Developer Program membership required.
- **v1 explicitly defers**: iCloud/CloudKit sync, `CKAsset` upload,
  cross-device availability, import, export, EPUB engine, Markdown engine,
  sticky notes, semantic highlights, theming, multi-window, and any network
  or third-party SDK.

## Active SDD change

- **Change ID**: `pdf-reader-pencilkit-ink-recovery`.
- **Tracker branch**: `tracker/pdf-reader-pencilkit-ink-recovery` (the
  branch currently checked out in this worktree).
- **Scope**: Phase 2 of v1 — the PDF engine with horizontal/vertical
  pagination, the PencilKit ink overlay with `.pencilOnly` policy and
  `.highlighter` default tool, and byte-identical page-change persistence
  of every page's `PKDrawing` on the existing `PageAnnotation.drawingData`
  column.
- **Delivery**: `feature-branch-chain` with a **linear** topology. A draft
  tracker PR is the single path into `main`. Each child PR is capped at
  **400 changed lines** and reviews in ≤ 60 minutes.
- **Why a recovery change**: the prior attempt at this scope failed the
  first init gate because it (a) proposed adding a schema field that
  Phase 1 already ships, (b) referenced an incorrect fixture path, and
  (c) produced a branching PR topology. This successor reuses only the
  confirmed product decisions, references the canonical Phase 1 schema,
  uses the canonical fixture path, and enforces a strict linear chain.

## Prior init gate failures (do not repeat)

| Gate | Failure | Correct posture |
| --- | --- | --- |
| 1 | The prior proposal/design/tasks invented a `paginationModeRaw` field on `DocumentItem`. Phase 1 already ships it as `var paginationModeRaw: String = "horizontal"` in `InSummary/Models/DocumentItem.swift`. | Reference `paginationModeRaw` as **immutable Phase 1 input**. Do not propose to add, alter, default, or migrate it. |
| 2 | The prior fixture spec used the wrong path: `InSummary/Resources/Fixture/sample.pdf`. The canonical path is `InSummary/Resources/Fixtures/sample-bundle.pdf`. | Use exactly `InSummary/Resources/Fixtures/sample-bundle.pdf` in every artifact, build phase, test, and PR description. |
| 3 | The prior delivery plan proposed child PR #2 and child PR #4 both targeting the tracker branch, producing a branching topology. | Enforce **linear chain**: `tracker ← PR #1 ← PR #2 ← PR #3 ← PR #4`. Only child PR #1 targets the tracker. Only the tracker ever merges into `main`. |

## Authoritative references

- **Canonical specification**: `specification.md` (English) and
  `documents-es/specification-es.md` (Spanish mirror).
- **Phase 2 acceptance criteria**: `specification.md` §6 Phase 2.
- **Phase 1 schema (immutable in Phase 2)**:
  - `InSummary/Models/DocumentItem.swift` — `paginationModeRaw` (default
    `"horizontal"`).
  - `InSummary/Models/PageAnnotation.swift` — `drawingData` (`Data?`,
    `@Attribute(.externalStorage)`) — already used by Phase 2 for ink.
- **SDD configuration**: `openspec/config.yaml` — read it before any change.
- **Active change artifacts**: `openspec/changes/pdf-reader-pencilkit-ink-recovery/`.
- **Spanish mirrors**: `documents-es/openspec/changes/pdf-reader-pencilkit-ink-recovery/`.

## Guardrails (enforced by `openspec/config.yaml`)

| Area | Rule |
| --- | --- |
| Sync / CloudKit | Forbidden in Phase 2 and in every Phase 2 child PR. The blocked-substring list is enforced on the whole `InSummary/` source tree. |
| Network | Forbidden in Phase 2. No HTTP clients, no `URLSession`, no `NWConnection`, no remote telemetry. |
| Import | Forbidden in Phase 2. The reader is reached through the existing Phase 1 library shell with a seed document only. |
| External services | Forbidden. No third-party SDKs, no analytics, no payment SDKs. |
| Schema | Phase 2 does **not** add, alter, default, or migrate any Phase 1 entity. `DocumentItem.paginationModeRaw` and `PageAnnotation.drawingData` are read and written as-is. |
| Fixture | The 20-page PDF used to exercise the reader must be **project-authored**, **deterministic**, **CC0**, and located at exactly `InSummary/Resources/Fixtures/sample-bundle.pdf`. No hand-shipped binary PDF is allowed in git history. |
| Bundle | Phase 2 ships only local resources. No iCloud entitlements, no `aps-environment`, no background modes, no new `Info.plist` usage descriptions. |
| TDD | Strict. Every requirement in a child PR ships with XCTest coverage that fails before the change and passes after. Tests land in the same PR as the code they cover. |
| Delivery | `feature-branch-chain` with **linear** topology. Only child PR #1 targets the tracker. Only the tracker merges into `main`. |
| Tools | Only local, first-party tools. `Tools/generate-sample-bundle-pdf.swift` is a project-authored deterministic Swift script that produces `InSummary/Resources/Fixtures/sample-bundle.pdf` byte-for-byte. No third-party tools. |

## Conventions carried into every child PR

- **Branch naming**: `feat/<slice-id>` (per `branch-pr` skill).
- **Conventional commits**: enforced by the `work-unit-commits` skill.
- **PR body**: follows the `chained-pr` template; states start, end, prior
  dependency, follow-up work, and out-of-scope items.
- **Dependency diagram**: each child PR includes a linear chain diagram
  marking itself with 📍, its immediate predecessor (if any) with the
  preceding step's marker, and the tracker with 🧭.
- **Spanish mirror**: every change artifact under
  `openspec/changes/...` has a faithful mirror under
  `documents-es/openspec/changes/...`.

## Out of scope for Phase 2 (must not creep in)

- Semantic highlights (Phase 4).
- Sticky notes (Phase 4).
- EPUB engine, Markdown engine (Phase 3).
- Import, export, folders, library shell additions (Phase 5).
- Theming, multi-window, accessibility polish (Phase 6).
- iCloud / CloudKit / `CKAsset` / sync monitor / push notifications
  (forbidden by the Phase 2 guards; deferred to a future phase).
- Snapshot tests (deferred to Phase 6 per the spec).
- Any modification to `InSummary/Models/DocumentItem.swift` or
  `InSummary/Models/PageAnnotation.swift`.
