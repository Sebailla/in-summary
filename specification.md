# Technical Specification — Universal Reader & Annotator for iPad

**Project:** In-Summary (Universal Reader & Annotator for iPad)
**Platform:** iPadOS 26.0+
**Language / Tooling:** Swift 5.10 / Swift 6, Xcode 15 / 16
**Document Status:** Canonical specification — supersedes `especifications.md` and `especifications-2.md`
**Audience:** Reviewers, future contributors, and the implementing engineer
**Product decision (v1):** local-first; no Apple Developer Program membership required. Cross-device sync via iCloud/CloudKit and binary upload (`CKAsset`) are explicitly deferred to a future phase.

---

## Decision Summary

In-Summary is a personal, library-based reading and study environment for iPad. It imports documents in **PDF**, **EPUB**, and **Markdown**, paginates them horizontally or vertically according to the reader's choice, supports two annotation modes (semantic text highlights and freeform Apple Pencil ink), and overlays persistent floating sticky notes. The interface adopts the iOS 26 Liquid Glass visual language, adapted for iPadOS. Original files and metadata live exclusively in the sandbox of the device that imported them; v1 makes no network calls of any kind. Cross-device sync and remote book availability are deferred to a future phase.

| Area | Decision |
| --- | --- |
| Reader surface | SwiftUI shell hosting one format engine per document via `UIViewRepresentable` |
| Pagination | Horizontal or vertical, chosen by the reader and persisted per document |
| Visual design | iOS 26 Liquid Glass, adapted for iPadOS and respecting accessibility and contrast |
| Annotation layers | Four z-ordered layers (semantic highlights → PencilKit ink → sticky notes → UI overlays) |
| Persistence | **Local** SwiftData `ModelContainer`; no active iCloud/CloudKit capabilities in v1. Sync is deferred to a future phase |
| SwiftData schema | CloudKit-compatible by design (no unique attributes, all relationships optional or defaulted), to reduce the cost of the future sync phase |
| Uniqueness | No `@Attribute(.unique)`; uniqueness enforced at the application layer on import |
| EPUB security | Sandboxed unzip with path-traversal guard, allowlisted content types, `WKWebView` isolated per document |
| Performance | No absolute FPS, latency, or RAM targets; manual smoothness verification on real hardware |

**What is in scope (v1):** reading, paginating, annotating, sticky-noting, organizing in folders, exporting PDF with burned-in marks and a Markdown notes summary — all 100% local and server-less.

**What is out of scope (v1):** collaborative editing, sharing books or notes with other users, cross-device sync (iCloud/CloudKit), uploading or downloading binaries as `CKAsset`, "Make available on my other devices", any backend, third-party analytics, payment SDKs, server-side rendering, AI features, audio/video playback, format conversion (e.g., EPUB → PDF), DRM-protected content, non-iPad form factors.

**Deferred to a future phase (not v1):** syncing annotations and metadata across the user's own devices through a private CloudKit database; opt-in upload of the book binary as a `CKAsset`; cross-device download; cloud revocation. The design is preserved here for forward compatibility, but **none** of these behaviors ship in v1.

**Resolved contradictions (this section replaces earlier drafts):**

1. **Cross-device availability is deferred.** In v1, binaries and metadata are exclusively local. When the future sync phase lands, CloudKit will sync SwiftData records only; original documents will remain in the importing device's sandbox. Until then, the library shows no remote or "not downloaded" states. This avoids silently broken libraries and keeps v1's surface minimal.
2. **Reflowable content cannot use `pageIndex` as a stable locator.** Markdown and EPUB re-flow with the viewport and font size, which makes page numbers unstable. Stable locators are:
   - **PDF** → `(pageIndex, normalizedQuads: [CGRect])` in PDF document space.
   - **Markdown** → `NSRange(location, length)` plus a `contentHash` for invalidation when the source changes.
   - **EPUB** → an EPUB 3 **CFI** (Canonical Fragment Identifier) string, falling back to DOM Range serialization if CFI generation fails.
   `pageIndex` is retained only as a **display hint** and as a navigation pointer; the canonical anchor for highlights is format-specific.
3. **Annotation coordinate spaces are explicit and per-layer.** See §3.4.
4. **SwiftData uniqueness is enforced at the application layer**, not via `@Attribute(.unique)`. Beyond producing clearer error messages, this keeps the schema CloudKit-compatible by design so the future sync phase does not require entity rewrites. See §3.5.
5. **Cross-device conflict resolution is deferred.** v1 has no sync, so there are no cross-device conflict scenarios. SwiftData's local semantics (write order on the same device) apply as-is. When sync is reactivated, the planned rule is **last-writer-wins per record** with `updatedAt` tiebreaker; byte-level PencilKit merges remain explicitly out of scope.
6. **No absolute performance guarantees.** Earlier drafts claimed 120 FPS, sub-9 ms latency, and memory ceilings. These are removed and replaced with qualitative verification steps on real hardware with Instruments.

---

## Quick Path for Reviewers

1. Read §1 (Scope) and §2 (Architecture) for orientation — 5 minutes.
2. Skim the tables in §3 (Data Model) and §4 (Format Engines) — 10 minutes.
3. Validate §6 (Phased Delivery) acceptance criteria against the test strategy in §7.
4. Verify nothing in §9 (Non-Goals) is silently being implemented, and everything labelled "deferred" stays labelled that way and is absent from v1 product code.

---

## 1. Scope, Users, and Constraints

### 1.1 Product description

A library-based iPad application that lets a single user:

- Import `.pdf`, `.epub`, and `.md` files into a private on-device library.
- Read each document with **horizontal or vertical pagination**, according to the reader's persisted preference.
- Highlight text semantically (per-character) and/or paint freeform ink with Apple Pencil.
- Place floating sticky notes on any page, edit them with keyboard or Scribble, and reposition them with drag gestures.
- Organize documents into user-created folders.
- Resume reading at the last locator per document.
- Export a PDF with burned-in ink and highlights, plus a Markdown summary of all annotations for the document.

**No server, no Apple Developer account, and no network dependency.** All content and all metadata live in the local sandbox of the device that imported the files.

### 1.2 Constraints

- **Platform:** iPadOS 26.0+ only. No iPhone, no Mac Catalyst, no visionOS.
- **Interface:** use the iOS 26 Liquid Glass visual system, adapted for iPadOS; translucent effects must not reduce legibility, contrast, or VoiceOver compatibility.
- **Connectivity:** v1 is designed to work **fully offline** and **without active iCloud/CloudKit capabilities**. No network calls are made to Apple or to any third party.
- **Apple Developer Program membership:** not required for v1; iCloud, CloudKit, push notifications, and distribution-signing capabilities are disabled.
- **No third-party services:** no custom servers, no analytics SDKs, no payment SDKs.
- **No DRM circumvention:** the app does not bypass store or publisher DRM.

### 1.3 Non-goals (v1)

| Non-goal | Why it is excluded |
| --- | --- |
| Sharing books with other users | v1 is single-user and local; sharing requires a different storage model |
| Collaborative annotations | Same as above; out of scope until sharing is introduced |
| Format conversion (EPUB→PDF, etc.) | Adds significant complexity and ownership/licensing risk |
| Audio / video playback | Reader engines are text-first |
| AI summarization / OCR | Not in v1; hooks can be added later without schema breakage |
| Cross-device sync (iCloud/CloudKit) | Deferred to a future phase; v1 is local-first and requires no Apple Developer Program membership |
| Uploading or downloading binaries as `CKAsset` | Deferred with sync; depends on CloudKit |
| Cross-device book availability ("Make available on my other devices") | Deferred with sync |
| Custom backend, manual restore, or remote backup | Not claimed; v1 implements no remote backup path |
| Windows/macOS targets | Reduces PencilKit and multi-window testing surface to a known target |

---

## 2. Architecture

### 2.1 Layers

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          PRESENTATION LAYER                                 │
│  ┌────────────────┐  ┌─────────────────────────┐  ┌────────────────────┐  │
│  │ LibraryGrid    │  │ ReaderContainerView     │  │ StickyNote / Tools │  │
│  └────────────────┘  └────────────┬────────────┘  └────────────────────┘  │
│                                   │                                        │
│                                   ▼                                        │
│                          Reader ViewModels                                 │
└─────────────────────────────────┬──────────────────────────────────────────┘
                                          │
┌─────────────────────────────────▼──────────────────────────────────────────┐
│                            DOMAIN LAYER                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ PDF Engine  │  │ MD Engine   │  │ EPUB Engine  │  │ Annotation Eng.  │  │
│  └─────────────┘  └─────────────┘  └──────────────┘  └──────────────────┘  │
│            ┌─────────────────────────────────────────────────────┐        │
│            │ EPUB Security + Availability (deferred)             │        │
│            └─────────────────────────────────────────────────────┘        │
└─────────────────────────────────┬──────────────────────────────────────────┘
                                          │
┌─────────────────────────────────▼──────────────────────────────────────────┐
│                       DATA & PERSISTENCE LAYER                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │            SwiftData ModelContainer LOCAL (no CloudKit)             │  │
│  │  FolderEntity ─< DocumentItem ─< PageAnnotation ─< {TextHighlight,  │  │
│  │                                                       StickyNote}   │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│           │                                                                │
│           ▼                                                                │
│   Application Support/Documents/<UUID>.<ext>                               │
│   (original binaries, exclusively local)                                    │
└────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Module map

| Module | Responsibility | Key types |
| --- | --- | --- |
| `App/` | App entry point, DI, capabilities wiring (no iCloud/CloudKit in v1) | `UniversalReaderApp`, `DependencyContainer` |
| `Models/` | SwiftData entities (local schema in v1; CloudKit-compatible by design) | `FolderEntity`, `DocumentItem`, `PageAnnotation`, `TextHighlight`, `StickyNoteEntity` |
| `Services/Storage/` | Sandbox file I/O and thumbnail cache; no active sync monitor in v1 | `FileStorageService`, `ThumbnailCache` |
| `Services/PDFEngine/` | PDFKit wrapper, coordinate conversion | `PDFReaderCoordinator`, `PDFCoordinateConverter` |
| `Services/MarkdownEngine/` | Markdown parse + paginate | `MarkdownParser`, `MarkdownPaginator` |
| `Services/EPUBEngine/` | EPUB unzip, OPF parse, JS bridge | `EPUBUnarchiver`, `EPUBManifestParser`, `EPUBBridgeScript.js` |
| `Services/AnnotationEngine/` | PencilKit lifecycle, post-it physics | `PencilManager`, `PostItLayoutEngine` |
| `Services/Security/` | EPUB safe-unzip, content-type allowlist | `EPUBSandboxValidator` |
| `Views/Library/` | Library grid + folders | `LibraryGridView`, `FolderSidebarView` |
| `Views/Reader/` | Reader shell + per-format views | `ReaderContainerView`, `PDFViewRepresentable`, `MarkdownPageView`, `EPUBWebViewRepresentable` |
| `Views/Reader/Overlays/` | Annotation overlays | `StickyNoteView`, `PencilCanvasOverlay`, `HighlightRendererView` |
| `Views/Components/` | Reusable UI | `CustomToolBar`, `ColorPalettePicker` |
| `Resources/` | Embedded fonts, assets | `Caveat-Regular.ttf`, `Assets.xcassets` |

> **Deferred (future phase):** `Services/Storage/CloudSyncMonitor` will be introduced when sync is reactivated. In v1 it does not exist, is not initialized, and its absence must not be modeled as a pending "no network" state.

### 2.3 Sandbox layout

| Path | Purpose | Synced? |
| --- | --- | --- |
| `Application Support/Documents/<UUID>.<ext>` | Imported original binaries | No (device-local) |
| `Application Support/Thumbnails/<UUID>.png` | Library cover thumbnails | No |
| `Caches/<UUID>/` | EPUB-extracted HTML/CSS/images | No (regenerable) |
| SwiftData store (system location) | All entities below | **No** (local in v1; sync deferred) |

---

## 3. Data Model

### 3.1 Canonical entities (authoritative SwiftData schema)

These names and field names are the source of truth. The schema avoids unique attributes and keeps relationships optional or defaulted. **No entity is connected to a CloudKit database in v1**; reactivating future sync requires an explicit migration.

```swift
@Model final class FolderEntity {
    var id: UUID = UUID()
    var name: String = "New Folder"
    var colorHex: String = "#5AC8FA"
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DocumentItem.folder)
    var documents: [DocumentItem]? = []
}

@Model final class DocumentItem {
    var id: UUID = UUID()
    var title: String = ""
    var fileTypeRaw: String = "pdf"          // "pdf" | "epub" | "md"
    var fileExtension: String = "pdf"        // lowercase, no dot
    var localFileName: String = ""           // "UUID.<ext>" in sandbox
    var fileSize: Int64 = 0
    var contentHash: String = ""             // SHA-256 of original bytes (hex)
    var lastReadLocator: Data = Data()       // JSON-encoded stable locator
    var lastReadPageIndex: Int = 0           // DISPLAY HINT only — see §3.4
    var totalPages: Int = 1                  // DISPLAY HINT only for reflowable
    var paginationModeRaw: String = "horizontal" // "horizontal" | "vertical"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var folder: FolderEntity?

    @Relationship(deleteRule: .cascade, inverse: \PageAnnotation.document)
    var annotations: [PageAnnotation]? = []
}

@Model final class PageAnnotation {
    var id: UUID = UUID()
    var pageIndex: Int = 0                   // DISPLAY HINT for PDFs; 0 for reflowable

    @Attribute(.externalStorage)
    var drawingData: Data? = nil             // PKDrawing.dataRepresentation()

    var document: DocumentItem?

    @Relationship(deleteRule: .cascade, inverse: \TextHighlight.pageAnnotation)
    var highlights: [TextHighlight]? = []

    @Relationship(deleteRule: .cascade, inverse: \StickyNoteEntity.pageAnnotation)
    var stickyNotes: [StickyNoteEntity]? = []
}

@Model final class TextHighlight {
    var id: UUID = UUID()
    var colorHex: String = "#FFEB3B"
    var selectedText: String = ""
    var anchorPayload: Data = Data()         // format-specific locator, JSON
    var anchorFormatRaw: String = "pdf"      // "pdf" | "markdown" | "epub"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var pageAnnotation: PageAnnotation?
}

@Model final class StickyNoteEntity {
    var id: UUID = UUID()
    var text: String = ""
    var colorTheme: String = "yellow"        // "yellow" | "pink" | "blue" | "green"
    var normalizedX: Double = 0.5            // 0..1 in page viewport space
    var normalizedY: Double = 0.5
    var width: Double = 180.0                // base size; runtime resizable in future
    var height: Double = 140.0
    var rotationAngle: Double = 0.0          // degrees, ±3.0 aesthetic
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var pageAnnotation: PageAnnotation?
}
```

### 3.2 Naming reconciliation

| Earlier draft name | Canonical name | Reason |
| --- | --- | --- |
| `rotationDegrees` | `rotationAngle` | Consistency with code in `especifications-2.md` |
| `fileTypeRaw` only | `fileTypeRaw` + `fileExtension` | `fileExtension` makes export logic simpler |
| `lastReadPageIndex` only | `lastReadLocator: Data` + `lastReadPageIndex` (display hint) | Stable locators cannot be reduced to a page index |
| absent `contentHash` | `contentHash` on `DocumentItem` | Detect local content drift between devices (foundation when sync reactivates) |
| absent `updatedAt` on highlight/note | `updatedAt` on `TextHighlight` and `StickyNoteEntity` | Required for LWW conflict resolution when sync reactivates |
| `colorThemeRaw` | `colorTheme` | Consistency |
| `anchorData` | `anchorPayload` + `anchorFormatRaw` | Format discriminator must be explicit |

### 3.3 Format-specific locator payloads (`anchorPayload`)

All payloads are JSON-encoded into `Data`. The discriminator is `anchorFormatRaw`.

| Format | JSON shape | Stability |
| --- | --- | --- |
| `pdf` | `{"page":Int,"rects":[[x,y,w,h],…],"quads":[[x,y,…],…]}` where x/y/w/h are normalized 0..1 to the PDF page's `MediaBox` | Stable; PDF is fixed-layout |
| `markdown` | `{"contentHash":String,"range":{"location":Int,"length":Int},"blockPath":[Int,…]}` | Stable across viewport changes; invalidated when `contentHash` differs |
| `epub` | `{"cfi":String,"fallbackRange":String?}` | Stable across viewport; falls back to serialized Range when CFI fails |

Validation rules on load:

- **PDF:** rects must be within `[0,1]`. If out of range or the page count changed, the highlight is hidden and surfaced in a "review" list.
- **Markdown:** if `contentHash` does not match the current document, the highlight is hidden and flagged.
- **EPUB:** if the CFI does not resolve, fall back to the serialized Range; if neither resolves, hide and flag.

### 3.4 Coordinate spaces

| Layer | Storage coordinate space | Rendering coordinate space | Notes |
| --- | --- | --- | --- |
| PDF text highlight | **PDF document space**, normalized 0..1 to the page's `MediaBox` | Convert to view space via `PDFView.convert(_:to:)` | PDFKit origin is bottom-left |
| PencilKit ink (`drawingData`) | **PencilKit canvas space** (origin bottom-left, points), anchored to the page viewport | Replayed inside a `PKCanvasView` sized to the viewport | Switching pages loads a new `PKDrawing` |
| Sticky note | **Page viewport rect**, normalized 0..1 of the rendered content area | `(normalizedX * viewportWidth, normalizedY * viewportHeight)` | Survives rotation and Split View |
| Markdown highlight | `NSRange` in source text + `blockPath` | Re-found by walking the AST and re-laying out | Inherently reflowable |

**Rule:** never mix coordinate spaces. Conversion lives in `*CoordinateConverter` types per engine. Any value crossing a layer boundary is converted explicitly and the source space is recorded next to it.

### 3.5 Uniqueness invariants

| Invariant | Where enforced | Reason |
| --- | --- | --- |
| `DocumentItem.localFileName` is unique in the app's sandbox | `FileStorageService.importDocument(_:)` generates `<UUID>.<ext>` and rejects collisions | UUID-based naming gives uniqueness by construction |
| `DocumentItem.id` is unique per app (UUID set at insert) | Generated by SwiftData on insert | Stable identification; preserves the path to future cross-device sync |
| `DocumentItem.contentHash` matches the on-disk file bytes | Recomputed at import time | Local drift detection |
| `(documentId, anchorFormatRaw, anchorPayloadHash)` is unique per app | Insertion guard in the model context | Prevents duplicates from LWW replays |

**No `@Attribute(.unique)` is used.** This rule stays for two reasons: (a) application-layer enforcement yields clearer error messages, and (b) the schema is ready for a future sync phase without rewrites.

### 3.6 Conflict behavior (deferred)

> **This section describes behavior planned for a future phase. v1 has no sync, so there are no cross-device conflict scenarios.** It is preserved here as a design reference so the future implementation starts from an explicit baseline.

When the cross-device sync phase (private CloudKit) is reactivated, the following rules will apply. Until then, SwiftData's natural write ordering on the same device applies.

| Conflict type | Planned behavior |
| --- | --- |
| Metadata change on either side (title, folder, lastReadLocator) | LWW by `updatedAt`; tiebreaker: deterministic comparison of record id |
| Two distinct `TextHighlight` rows inserted concurrently with identical anchor hash on the same page | Keep both; dedupe in the UI by `(colorHex, selectedText, anchorHash)`; the user decides to merge or delete |
| Two edits to the same `TextHighlight` while offline | LWW by `updatedAt`; on next open, surface a "review changes" badge linked to the prior version stored as `previousAnchorPayload: Data?` (field to be introduced with the sync phase) |
| Two distinct ink drawings on the same page on two devices | LWW by the `updatedAt` associated with `drawingData`; the losing device shows a one-time banner: "your freeform ink on this page was replaced by a newer version from another device" |
| Binaries (CKAsset) | LWW by upload `updatedAt`; older binaries are pruned after 30 days from CloudKit |

---

## 4. Format Engines

### 4.1 Engine comparison

| Aspect | PDF Engine | Markdown Engine | EPUB Engine |
| --- | --- | --- | --- |
| Underlying tech | `PDFKit` (`PDFView`, `PDFDocument`) | `swift-markdown` AST + TextKit 2 (`NSTextLayoutManager`) | `WKWebView` + CSS Multi-Column + JS bridge |
| Pagination | Per-document preference: horizontal with `displayMode = .singlePage`, `displayDirection = .horizontal`, `usePageViewController(true)`; or vertical with continuous scrolling | Per-document preference: horizontal paginated `TabView` or vertical `ScrollView` over the computed pages | Per-document preference: CSS columns at 100vw with JS-controlled horizontal scrolling, or vertical flow with scroll enabled |
| Page-change gesture | Native `UIPageViewController` swipe | SwiftUI `TabView(selection:)` with `.page(indexDisplayMode: .never)` | `window.scrollTo(left = pageIndex * innerWidth)` in JS triggered from Swift |
| Stable locator for highlights | `(pageIndex, [normalized CGRect])` | `(contentHash, NSRange, blockPath)` | CFI string with DOM Range fallback |
| Surface for ink | `PKCanvasView` overlay per page | `PKCanvasView` overlay per `NSRange`-derived ordinal "page" (Phase 1) | `PKCanvasView` overlay per CFI-resolved viewport segment |

### 4.2 PDF engine

- `PDFView` is wrapped in `UIViewRepresentable`. Pencil gestures are routed to the overlay canvas (see §5) instead of the PDFView.
- Coordinate conversion: screen → PDF point → normalized rect in `MediaBox`.
- In horizontal mode, `usePageViewController(true)` provides native swipe with inertia; in vertical mode, the reader uses continuous scrolling.
- `autoScales = true` with pinch zoom is supported; zoom does not invalidate highlight rects because they are normalized.

### 4.3 Markdown engine

1. Read the `.md` from the sandbox.
2. Parse with `swift-markdown` into an AST.
3. Render to `NSAttributedString` with consistent typography (font, kerning, paragraph spacing).
4. Compute viewport size from the reader's safe-area insets minus margins.
5. In a loop, allocate `NSTextContainer(size: viewport)` and ask `NSTextLayoutManager` for the range that fills it without splitting paragraphs across containers when avoidable.
6. Persist `[(NSRange, containerIndex)]` per document; expose the ordinal `pageIndex` for display only.
7. Display containers in `TabView(selection:)` for horizontal mode or in `ScrollView` for vertical mode, according to the document's persisted preference.
8. Highlight lookup is by `NSRange` within `contentHash`-matched content; if the file changed, the highlight is hidden and listed for review.
9. Ink is persisted per ordinal "page" in Phase 1 with the caveat that re-pagination (font size change) shifts drawings; the spec accepts this and records a "reflow safe" path as a Phase 2+ improvement.

### 4.4 EPUB engine

1. **Safe unzip** (§5) into `Caches/<UUID>/`.
2. Read `META-INF/container.xml` to locate the OPF.
3. Parse the OPF to enumerate spine items (reading order).
4. Inject CSS according to the reading preference: horizontal columns at 100vw or vertical flow with scroll enabled.
5. Bridge via `WKScriptMessageHandler` to expose: current page index, page count, request to jump to page index, text selection capture (range → CFI).
6. **Security:** `WKWebView` is configured with `allowFileAccessFromFileURLs = false`, `allowUniversalAccessFromFileURLs = false`. The reader's HTML is loaded from a per-document isolated directory. Cross-document navigation is disabled.

### 4.5 Annotation pipeline (engine-neutral)

For each page-change event:

1. Persist the outgoing page's `drawingData` (PencilKit) and any pending sticky-note edits to SwiftData.
2. Load the incoming page's `PageAnnotation` (lazy).
3. Replay the `PKDrawing` into the canvas overlay.
4. Re-apply sticky notes at `(normalizedX * viewportWidth, normalizedY * viewportHeight)`.
5. Re-apply semantic highlights by re-resolving their locator in the engine's space.

---

## 5. Security & File Availability

### 5.1 EPUB safe-unzip (`EPUBSandboxValidator`)

| Check | Action on failure |
| --- | --- |
| ZIP entry name contains `..`, absolute path, or NUL | Reject the entire EPUB |
| Entry name escapes the destination directory after normalization | Reject |
| Entry `Content-Type` outside the allowlist `text/html`, `text/css`, `image/png`, `image/jpeg`, `image/gif`, `image/svg+xml`, `application/xhtml+xml`, `application/xml` | Skip entry; record in warnings |
| `<script>` tag found in any HTML/XHTML after extraction | Strip the tag and inline event handlers; record warning |
| Inline `on*` handlers in HTML | Strip; record warning |
| `javascript:` URLs in `href`/`src` | Strip; record warning |

The unzipped tree lives in `Caches/<UUID>/` and is regenerated if missing.

### 5.2 WebView isolation

| Setting | Value |
| --- | --- |
| `WKWebView.allowFileAccessFromFileURLs` | `false` |
| `WKWebView.allowUniversalAccessFromFileURLs` | `false` |
| `WKPreferences.javaScriptCanOpenWindowsAutomatically` | `false` |
| Cross-document navigation | Disabled via `WKNavigationDelegate` |
| `WKScriptMessageHandler` channels | Whitelisted names only: `pageChange`, `selectionCapture`, `jumpToPage` |

### 5.3 File availability across devices (deferred)

> **This section describes behavior planned for a future phase. v1 has no cross-device sync and no cloud upload of binaries.** The design is preserved so the future phase has an explicit baseline; no menu, button, or code path activates it in v1.

- **Default (planned for the future sync phase):** binaries will be device-local. The library will show each document on the device that imported it. Other devices will see metadata only and display "Not downloaded on this device".
- **Opt-in upload (planned):** the user taps "Make available on my other devices" in the document's context menu. The app:
  1. Computes `contentHash` if not already present.
  2. Applies the sync-phase migration and uploads the binary as a `CKAsset` through the new availability entity.
  3. Records `contentAssetUploadedAt: Date` on that entity.
- **Download (planned):** on another device, the library detects a migrated availability asset for a document missing locally and offers "Download" with size and progress.
- **Revocation (planned):** "Remove from iCloud" deletes the `CKAsset` but keeps the metadata.

In v1 **none** of these four paths exist: no default cross-device state, no opt-in upload, no download, no revocation. The document context menu does not show these options. v1 **does not implement** any remote backup path, manual restore, or export to a custom server.

---

## 6. Phased Delivery

Each phase ends with measurable, executable acceptance criteria. Phases are sequential; later phases may overlap once a phase is signed off. Numbering reflects the real delivery order: the sync phase (CloudKit, `CKAsset`, sync monitor) is **not** part of v1 and is reserved for a future phase with its own rubric.

### Phase 1 — Project setup, local data model, library shell

| Task | Concrete deliverable |
| --- | --- |
| Initialize Xcode project | iPadOS 26+ target; iPad orientations only; **no** iCloud capability, **no** CloudKit capability, **no** Background Modes (Remote Notifications); Liquid Glass interface |
| Define entities | All five `@Model` files compile without warnings; they use no unique attributes, every relationship is optional or defaulted, and `DocumentItem.paginationModeRaw` starts as `"horizontal"` |
| Container | **Local** SwiftData `ModelContainer`; the `ModelConfiguration` does not declare any remote-sync option |
| Sync monitor | **Does not exist in v1.** No `CloudSyncMonitor` (or equivalent) is initialized; no code looks it up or publishes it |
| Library shell | `LibraryGridView` shows a seed folder and seed document |

**Acceptance criteria:**

1. `xcodebuild -scheme InSummary -destination 'generic/platform=iOS Simulator' build` succeeds without data-schema warnings, and the resulting binary **does not** include iCloud, CloudKit, or `aps-environment` (push notifications) entitlements.
2. On a real iPad, creating a folder + document persists across app restarts **without** a network and **without** an active iCloud session.
3. The library shell creates and displays a seed folder and document, and both persist locally with the device in airplane mode. Import, reading, annotation, and export are validated in their later phases.
4. A code search for `cloudKit`, `CKContainer`, `CKDatabase`, `CKAsset`, `NSPersistentCloudKitContainer`, `cloudKitDatabase`, `CloudSyncMonitor`, `RemoteNotification` returns **zero** matches in product code. (Mentions inside this specification document do not count.)
5. The app installs and signs with a personal / development provisioning profile that does not require Apple Developer Program membership.

### Phase 2 — PDF engine + PencilKit ink

| Task | Concrete deliverable |
| --- | --- |
| PDF reader | `PDFReaderCoordinator` opens PDFs in horizontal paginated mode or vertical continuous mode according to the reader's preference |
| Ink overlay | `PencilCanvasOverlay` with `drawingPolicy = .pencilOnly`, `.highlighter` default tool |
| Page-change persistence | On `PDFViewPageChangedNotification`, save prior page's `PKDrawing`, load next page's `drawingData` |

**Acceptance criteria:**

1. Open a 20-page PDF; in horizontal mode, swipe changes pages with `PDFView`'s native transition; in vertical mode, continuous scrolling traverses the document.
2. Draw on page 1, navigate to page 2 (blank), draw on page 2, return to page 1 — the original strokes are preserved byte-for-byte.
3. The horizontal or vertical pagination preference is preserved across closing and reopening the document.
4. `PencilCanvasOverlay` ignores finger touches; only Pencil draws.

### Phase 3 — Markdown and EPUB engines

| Task | Concrete deliverable |
| --- | --- |
| Markdown parser + paginator | `MarkdownParser` + `MarkdownPaginator` produce `[(NSRange, Int)]` pages; rendered in horizontal `TabView(selection:)` or vertical `ScrollView` according to the reader's preference |
| EPUB safe-unzip | `EPUBSandboxValidator` passes the test corpus (table-driven tests) |
| EPUB CSS injection | 100vw columns for horizontal mode or vertical flow for vertical mode; JS bridge for page index and text selection |
| Reading progress | `lastReadLocator` (encoded `NSRange` for MD, encoded CFI for EPUB) persists per document |

**Acceptance criteria:**

1. A 5 KB Markdown file paginates into ≥ 1 page at the default font size and ≥ 1 page (possibly a different count) at +20% font size; no paragraph is split mid-line in either case.
2. The same Markdown document can be read in horizontal `TabView` and in vertical `ScrollView`; the chosen preference is preserved when reopened.
3. An EPUB from the test corpus loads spine chapters in order; horizontal page-to-page navigation and continuous vertical scrolling both work according to the chosen preference.
4. Resuming a document restores the reader to the exact `NSRange` (MD) or CFI (EPUB).
5. `EPUBSandboxValidator` rejects the malicious EPUB corpus (path traversal, `<script>` injection, disallowed content types).

### Phase 4 — Sticky notes + semantic highlights

| Task | Concrete deliverable |
| --- | --- |
| Sticky note overlay | `StickyNoteView` with pastel colors, drag gesture updating `normalizedX/Y`, Scribble-enabled `TextEditor` |
| Semantic highlights | PDF: capture `PDFSelection.bounds` → normalized rects; MD: capture `NSRange`; EPUB: capture CFI |
| Tool modes | `Navigation` / `Pencil` / `Highlight` / `Eraser` toggle |

**Acceptance criteria:**

1. A new sticky note appears at the tap point, persists across page changes, and survives rotation and Split View resizes (manual verification at two window sizes).
2. Selecting text in any engine and choosing a color creates a `TextHighlight` that re-appears when the document is reopened.
3. Switching tools disables Pencil input in Navigation mode and disables text selection in Pencil mode.

### Phase 5 — Library, import, export

| Task | Concrete deliverable |
| --- | --- |
| Import | `.fileImporter` accepts `.pdf`, `.epub`, `.md`; copies to `Application Support/Documents/<UUID>.<ext>`; rejects duplicates by `contentHash` |
| Thumbnails | PDF: `PDFPage.thumbnail(of:size:)`; EPUB: OPF cover; MD: text-snippet render |
| Folders | Create / rename / delete folders; drag documents between folders |
| Export | Burned-in PDF (PDF engine rasterizer + composite); `.md` summary of highlights + sticky notes |

**Acceptance criteria:**

1. Importing the same file twice produces one library entry with one `contentHash`; the second import is rejected with a clear message.
2. Exporting a PDF with ink + highlights + sticky notes produces a valid PDF where the marks are visible in standard readers.
3. Exporting a `.md` summary produces a readable file listing highlights and sticky notes with stable locators.
4. After local import and export, the relevant bytes round-trip back to the original (`contentHash` preserved) and no network request was made.

### Phase 6 — Polish, accessibility, and stability

| Task | Concrete deliverable |
| --- | --- |
| Reading themes | Light, Sepia, Dark themes per document |
| Immersive mode | Tap center to hide chrome |
| Multi-window | Two windows open two different documents simultaneously |
| Accessibility | VoiceOver labels for all interactive elements; dynamic type up to AX5 |
| Stability | Long-session reading (60 min) without crashes on real hardware |

**Acceptance criteria:**

1. VoiceOver can navigate the library, open a document, place a sticky note, and read it back.
2. Opening two windows with different documents and annotating each persists annotations independently per document.
3. A 60-minute reading session on a real iPad does not crash and does not show the iPadOS "using too much memory" warning.
4. Switching themes does not invalidate any stored locator or coordinate.

### Future phase (not v1) — iCloud/CloudKit sync + opt-in binary upload

> **This phase is not part of v1.** It is documented so the team knows the intended shape, but **none** of the criteria below are v1 acceptance criteria.

- The `ModelContainer` is connected to a private CloudKit database (`cloudKitDatabase: .private("iCloud.<team-bundle-id>")`).
- `CloudSyncMonitor` is introduced with `idle`, `syncing`, `noNetwork`, `error` states.
- The "Make available on my other devices" menu, download flow, revocation flow, and conflict banners described in §3.6 and §5.3 are reactivated.
- This phase will require an active Apple Developer Program membership to issue valid iCloud entitlements.

---

## 7. Test Strategy

| Test type | Scope | Tooling |
| --- | --- | --- |
| Unit tests | `MarkdownParser`, `MarkdownPaginator`, `PDFCoordinateConverter`, `EPUBSandboxValidator`, `EPUBManifestParser`, anchor validation per format | XCTest, table-driven cases |
| Snapshot tests | Markdown and EPUB page rendering | `swift-snapshot-testing` (Phase 6 decision) |
| UI tests | Import flow, library navigation, sticky-note create/move/delete, theme switching | XCUITest |
| Security corpus | 8–12 hostile EPUBs (path traversal, scripts, disallowed types, oversized entries) | XCTest fixture bundle |
| Offline test | Full read + annotate + export session with the device in airplane mode | Manual + checklist on real hardware |
| Performance manual test | PencilKit ink latency, memory under Instruments during a 30-minute reading session | Instruments, manual notes |
| Accessibility | VoiceOver walkthrough, dynamic type sweep | Manual + Xcode Accessibility Inspector |

**Rule for "manual" tests:** they are recorded as a checklist with pass/fail on real hardware before the phase is signed off. They are not claimed as guarantees in user-facing copy.

> **Deferred (future phase):** the "manual sync test between two devices" that appeared in earlier drafts. It does not run in v1 because there is no sync. When the sync phase is introduced, it returns to this table.

---

## 8. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| The SwiftData schema becomes incompatible with CloudKit if `@Attribute(.unique)` or a defaulted-less relationship is later added | Medium | High (would force migration when sync reactivates) | CloudKit compatibility is an invariant of the reviewer checklist (§B); any required change ships as a new entity version |
| EPUB parser is hostile-input brittle | High | Medium | `EPUBSandboxValidator` blocks path traversal, scripts, and disallowed content types before any rendering |
| Markdown re-pagination shifts ink drawings when font size changes | High | Low | Document the limitation; ship a "reflow safe" overlay in a later phase |
| Local concurrent edits to the same ink drawing (rare multi-window case) on the same device | Low | Low | SwiftData serializes write order; no silent loss. Byte-level merges remain out of scope |
| PDFKit cannot resolve normalized rects after a re-flow (rare; PDFs are fixed-layout) | Low | Low | Validator marks "needs review" when rects are out of `[0,1]` |
| WKWebView JS bridge misuse grants unintended capabilities | Low | High | Whitelisted message names; no `evaluateJavaScript` accepts arbitrary caller-provided code; CSP-style restrictions on extracted HTML |
| Deferred risk (future sync phase): offline edits on two devices to the same ink drawing silently overwrite | Medium | Medium | When sync reactivates: LWW with explicit "your drawing was replaced" banner; preserve prior version on the device for one sync cycle |
| Deferred risk (future sync phase): CloudKit asset storage costs grow with library size | Medium | Medium | When sync reactivates: opt-in only; UI shows estimated asset size before upload; deletion prunes assets after 30 days |

---

## 9. Non-Goals (consolidated)

- Multi-user sharing, comments, presence.
- Cross-device sync (iCloud/CloudKit) — **deferred to a future phase**.
- Uploading or downloading binaries as `CKAsset`, "Make available on my other devices", cross-device book availability — **deferred with sync**.
- Custom backend, manual restore, or remote backup. v1 implements and claims no remote backup path.
- Server-side rendering or any sync beyond the local sandbox.
- DRM circumvention or content decryption beyond what EPUB/PDF allow natively.
- Audio, video, or interactive widgets inside documents.
- AI features (summarization, OCR, Q&A).
- Format conversion (EPUB ↔ PDF, MD → PDF).
- iPhone, Mac Catalyst, or visionOS targets.
- Public App Store distribution with privacy-sensitive analytics.
- On-device collaboration.

---

## 10. Open Questions

These are intentionally deferred; they do not block v1 but are recorded so future contributors know they exist.

1. Should `lastReadLocator` be migrated to a `Codable` Swift type once SwiftData gains native enum support (currently `Data` + JSON)?
2. **Deferred to the future sync phase:** which migration will add the availability entity and its opt-in binary asset when synchronization is reactivated? v1 includes no such field and makes no decision.
3. Should ink drawings be stored per logical page or per viewport snapshot? Current decision: per logical page for PDF, per ordinal "page" for MD with the documented limitation, per CFI segment for EPUB.
4. Should the reader support custom font loading beyond the embedded `Caveat-Regular.ttf`? Deferred — security implications for untrusted font files.
5. **(New)** What is the exact rubric (entitlements, container identifier, deployment scheme) for reactivating the sync phase when it is decided to resume? Deferred until Apple Developer Program membership is obtained.

---

## Appendix A — Info.plist requirements

```xml
<key>UIAppFonts</key>
<array>
    <string>Caveat-Regular.ttf</string>
</array>

<key>UISupportsDocumentBrowser</key>
<false/>

<key>UIFileSharingEnabled</key>
<true/>

<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

> **v1 does not require iCloud, CloudKit, or APS (push notifications) entitlements.** The target's `.entitlements` file is empty or contains only non-iCloud entitlements. Any future addition is justified in the PR that reactivates the sync phase.

`UIPreferredFrameRateRangeMinimum` is intentionally not set in this spec; the app relies on standard ProMotion behavior without promising a frame rate.

## Appendix B — Reviewer checklist

- [ ] §1.3 non-goals are respected by every phase's tasks.
- [ ] §3.5 invariants are enforced in `FileStorageService` and at insertion sites.
- [ ] §4.4 EPUB engine never loads a `WKWebView` without `EPUBSandboxValidator` having passed.
- [ ] **No active CloudKit/iCloud code in v1.** A search for `cloudKit`, `CKContainer`, `CKAsset`, `NSPersistentCloudKitContainer`, `cloudKitDatabase`, `CloudSyncMonitor`, `RemoteNotification` returns zero matches in product code.
- [ ] The target's entitlements file does not include iCloud, CloudKit, or `aps-environment`.
- [ ] The `ModelContainer` is built without `cloudKitDatabase:` and without `NSPersistentCloudKitContainer`.
- [ ] Every mention of CloudKit/iCloud in this document is labelled "deferred" or "future phase".
- [ ] §6 acceptance criteria for each phase are exercised before sign-off.
- [ ] §7 offline test (airplane mode) passes on real hardware for the full v1 flow.
- [ ] §8 risks have concrete mitigations in code, not just in this document.

---
