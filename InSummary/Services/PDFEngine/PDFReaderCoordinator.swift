//
//  PDFReaderCoordinator.swift
//  InSummary
//
//  Phase 2 (`pdf-engine`) coordinator. Owns the `PDFView` lifecycle, the
//  pagination-mode switch, and the SwiftData write-back for the user's
//  pagination preference. Sits behind the SwiftUI shell wired in PR #4
//  (`feat/pdf-reader-wiring`) and exposes the typed error surface defined
//  by `PDFReaderError` (task 2.2).
//
//  Phase 2 invariants this file honours:
//
//  - `@MainActor`. The coordinator and the `PDFView` it owns are touched
//    only on the main actor (PDFKit's view surface is MainActor-isolated
//    under the iOS 26 SDK; SwiftData's `ModelContext.save()` is also
//    main-actor-bound in the Phase 2 call sites).
//
//  - No `PencilKit` import. The PDF reader surface is independent of the
//    annotation overlay added in PR #3 (`feat/pencilkit-ink-overlay`).
//
//  - No public SwiftData model types beyond the existing `DocumentItem`
//    reference and the `ModelContext` the caller hands us. The coordinator
//    reads and writes the existing `DocumentItem.paginationModeRaw` and
//    `DocumentItem.updatedAt` columns as-is — it does not declare, alter,
//    default, or migrate any Phase 1 entity.
//
//  - Local-only. No network reach-out, no file I/O outside the application
//    bundle and the local SwiftData store. No remote networking APIs, no
//    low-level network primitives, no cloud-backed persistent store, no
//    cloud container, or any remote I/O.
//
//  - Typed error surface at the public boundary. The initialiser throws
//    only `PDFReaderError`. The `paginationMode` setter logs persistence
//    failures via `os.Logger` and does **not** throw — the RED contract in
//    task 2.1 calls the setter without `try`, so a throwing setter would
//    fail to compile against the existing focused test suite. The
//    `paginationSaveFailed(underlying:)` case is reserved for a future
//    public-save path (e.g. an explicit `persistChanges()` helper added by
//    a later slice that wants typed propagation).
//

import Foundation
import SwiftData
import PDFKit
import os

// MARK: - PDFView bridge

/// Swift bridge that exposes `PDFView.usePageViewController` as a Bool
/// property.
///
/// PDFKit on iOS exposes the page-view-controller toggle as an
/// Objective-C selector `-usePageViewController:withViewOptions:` (a
/// method) plus a read-only `isUsingPageViewController` property. Swift
/// bridges the method unchanged: `func usePageViewController(_ enable:
/// Bool, withViewOptions: [AnyHashable: Any]? = nil)`. The focused test
/// suite authored in task 2.1 (`PDFReaderCoordinatorTests.swift`),
/// however, reads `pdfView.usePageViewController` as a Bool expression
/// (`XCTAssertTrue(coordinator.pdfView.usePageViewController, ...)`) —
/// the strict-TDD contract pins that read form.
///
/// This extension layers a Bool computed property on top of the SDK's
/// existing read-only getter (`isUsingPageViewController`) and setter
/// method (`usePageViewController(_:withViewOptions:)`). The property
/// setter delegates to the SDK method (no recursion; the paren form is
/// unambiguously the method). The property getter delegates to the SDK
/// read-only property (different name; no ambiguity).
///
/// The extension lives at file scope next to `PDFReaderCoordinator` so
/// the bridge is co-located with the only consumer. It does not weaken
/// any PDFKit invariant — the property setter passes the new value
/// straight to the SDK method.
extension PDFView {

    /// Whether the `PDFView` is currently configured to use a
    /// `UIPageViewController` for page navigation. Bridges the SDK's
    /// `-usePageViewController:withViewOptions:` method and
    /// `isUsingPageViewController` read-only property into a single Bool
    /// interface. Setting `true` invokes the SDK method with
    /// `withViewOptions: nil`; setting `false` does the same to opt out.
    var usePageViewController: Bool {
        get {
            isUsingPageViewController
        }
        set {
            self.usePageViewController(newValue, withViewOptions: nil)
        }
    }
}

@MainActor
final class PDFReaderCoordinator {

    // MARK: - PaginationMode

    /// Canonical pagination preference.
    ///
    /// Mirrors `DocumentItem.paginationModeRaw`
    /// (`"horizontal"` | `"vertical"`). The coordinator reads the raw
    /// string at construction time and writes the new raw string back to
    /// the same column on toggle. The raw values are pinned so the
    /// SwiftData row, the typed enum, and the underlying `PDFView`
    /// configuration stay in lockstep.
    enum PaginationMode: String {
        case horizontal = "horizontal"
        case vertical = "vertical"

        /// Resolves a raw string to the typed enum with a **horizontal**
        /// fallback for any value that is not `"horizontal"` or
        /// `"vertical"`. The unknown raw value is logged by the
        /// coordinator so a corrupted row is never silently misread — see
        /// `init(document:modelContext:bundle:resourceName:resourceExtension:)`.
        init(canonicalRawValue rawValue: String) {
            switch rawValue {
            case PaginationMode.horizontal.rawValue:
                self = .horizontal
            case PaginationMode.vertical.rawValue:
                self = .vertical
            default:
                self = .horizontal
            }
        }
    }

    // MARK: - Public stored properties

    /// The underlying `PDFView`. Exposed so the SwiftUI shell's
    /// `UIViewRepresentable` (PR #4) can hand the view back to the SwiftUI
    /// render tree after `makeUIView`.
    let pdfView: PDFView

    /// The `DocumentItem` row the coordinator is rendering. Held strongly
    /// so the coordinator's lifetime equals the SwiftData lifetime the
    /// SwiftUI shell is rendering — the row cannot be deleted from under
    /// the coordinator while it is in flight.
    let document: DocumentItem

    /// The model context the coordinator writes through. Held strongly so
    /// the SwiftUI shell can hand in its own context once at construction
    /// and rely on the coordinator to persist the pagination preference
    /// through the same context.
    let modelContext: ModelContext

    // MARK: - Private stored properties

    /// Backing storage for `paginationMode`. The setter mutates this,
    /// the document row, and the underlying `PDFView` together so the
    /// three views of the same fact stay consistent.
    private var _paginationMode: PaginationMode

    /// Logger for the unknown-raw-value fallback (one log per open) and
    /// for persistence failures (one log per failed save). The subsystem
    /// matches the bundle identifier; the category matches the file name.
    private let logger = Logger(
        subsystem: "com.sebailla.insummary",
        category: "PDFReaderCoordinator"
    )

    // MARK: - Pagination preference

    /// Pagination preference.
    ///
    /// Reading returns the value the coordinator was opened with (the
    /// `DocumentItem.paginationModeRaw` resolved through the unknown-value
    /// fallback).
    ///
    /// Writing:
    /// 1. Sets `document.paginationModeRaw` to the new raw value.
    /// 2. Bumps `document.updatedAt` to `Date()`.
    /// 3. Reapplies the corresponding `PDFView` configuration (horizontal
    ///    or vertical).
    /// 4. Persists the change via `modelContext.save()`.
    ///
    /// A failed save is logged via `os.Logger`; the setter does **not**
    /// throw. The RED contract in task 2.1 calls
    /// `coordinator.paginationMode = .vertical` without `try`, so a
    /// throwing setter would fail to compile against the focused test
    /// suite. The `paginationSaveFailed(underlying:)` case is reserved
    /// for a future public-save path that wants typed propagation.
    var paginationMode: PaginationMode {
        get {
            _paginationMode
        }
        set {
            document.paginationModeRaw = newValue.rawValue
            document.updatedAt = Date()
            Self.configurePDFView(pdfView, for: newValue)
            _paginationMode = newValue
            do {
                try modelContext.save()
            } catch {
                logger.error("Failed to persist paginationMode for document \(self.document.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Canonical fixture identity

    /// Canonical resource name for the bundled PDF fixture. Lives in the
    /// app bundle as `sample-bundle.pdf` (see
    /// `openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pdf-fixture/spec.md`).
    private static let canonicalResourceName = "sample-bundle"

    /// Canonical resource extension for the bundled PDF fixture.
    private static let canonicalResourceExtension = "pdf"

    // MARK: - Initialisation

    /// Builds a `PDFReaderCoordinator` against the supplied `DocumentItem`.
    ///
    /// The initialiser:
    /// 1. Refuses rows whose `fileTypeRaw != "pdf"` with
    ///    `PDFReaderError.unsupportedDocument(reason:)` (a non-empty
    ///    human-readable reason is rendered verbatim by the recoverable
    ///    banner in PR #4).
    /// 2. Refuses rows whose `localFileName` is non-empty (Phase 2 is
    ///    reachable only for the bundled seed; imported sandbox files
    ///    belong to Phase 5).
    /// 3. Resolves the bundled `sample-bundle.pdf` via
    ///    `Bundle.url(forResource:withExtension:)`. The bundle can be
    ///    overridden by the caller (tests inject an isolated bundle);
    ///    the production shell relies on the default `Bundle.main`. A
    ///    missing resource surfaces
    ///    `PDFReaderError.fixtureMissing(resource:)`.
    /// 4. Parses the bundle bytes into a `PDFDocument`. A parse failure
    ///    surfaces `PDFReaderError.fixtureUnreadable`.
    /// 5. Reads `DocumentItem.paginationModeRaw` and resolves it through
    ///    the horizontal fallback. Unknown raw values are logged once via
    ///    `os.Logger` (privacy: `.public` for the raw value and the
    ///    document UUID).
    /// 6. Configures the underlying `PDFView` to match the resolved mode
    ///    (single page horizontal with page-view-controller, or single
    ///    page continuous vertical).
    ///
    /// - Parameters:
    ///   - document: The `DocumentItem` row to render. Must be the Phase 2
    ///     seed (`fileTypeRaw == "pdf"` and `localFileName.isEmpty == true`).
    ///   - modelContext: The `ModelContext` the coordinator writes through.
    ///   - bundle: The bundle to resolve the fixture from. Defaults to
    ///     `Bundle.main` for production; tests inject an isolated bundle.
    ///   - resourceName: The bundle resource name. Defaults to
    ///     `"sample-bundle"`; tests inject a synthetic name to exercise
    ///     the missing-fixture path.
    ///   - resourceExtension: The bundle resource extension. Defaults to
    ///     `"pdf"`; tests inject a synthetic extension to exercise the
    ///     missing-fixture path.
    /// - Throws: `PDFReaderError.fixtureMissing(resource:)` if the bundle
    ///   does not contain the resource,
    ///   `PDFReaderError.fixtureUnreadable` if the bundle bytes are not a
    ///   valid `PDFDocument`, or
    ///   `PDFReaderError.unsupportedDocument(reason:)` if the row is not a
    ///   Phase 2 reachable document.
    init(
        document: DocumentItem,
        modelContext: ModelContext,
        bundle: Bundle = .main,
        resourceName: String = PDFReaderCoordinator.canonicalResourceName,
        resourceExtension: String = PDFReaderCoordinator.canonicalResourceExtension
    ) throws {
        // 1. Validate the document row. Phase 2 is reachable only for the
        //    bundled seed PDF (fileTypeRaw == "pdf", localFileName is empty).
        guard document.fileTypeRaw == "pdf" else {
            throw PDFReaderError.unsupportedDocument(
                reason: "Document fileType '\(document.fileTypeRaw)' is not supported by this build; only the bundled PDF seed is reachable in Phase 2."
            )
        }
        guard document.localFileName.isEmpty else {
            throw PDFReaderError.unsupportedDocument(
                reason: "Document localFileName '\(document.localFileName)' points at an imported sandbox file; only the bundled seed PDF is reachable in Phase 2."
            )
        }

        // 2. Resolve the bundle resource. The fixture-URL lookup is
        //    delegated to `Self.resolveFixtureURL(in:resourceName:resourceExtension:)`
        //    so the init path and any future fixture-loading call site
        //    share the single source of truth for the missing-fixture
        //    error path. The bundle can be overridden by the caller
        //    (tests inject an isolated bundle); the production shell
        //    relies on the default `Bundle.main`. A nil URL surfaces
        //    `PDFReaderError.fixtureMissing(resource:)` with the same
        //    resource name the caller asked for, so the
        //    recoverable-error banner can name the missing asset
        //    verbatim.
        let fixtureURL = try Self.resolveFixtureURL(
            in: bundle,
            resourceName: resourceName,
            resourceExtension: resourceExtension
        )

        // 3. Parse the fixture bytes. `PDFDocument(url:)` returns nil for
        //    unreadable PDFs (corrupt bytes, not a PDF at all, encrypted
        //    without a password). The recoverability banner mounted in PR
        //    #4 pattern-matches on `.fixtureUnreadable` to render the
        //    error.
        guard let pdfDocument = PDFDocument(url: fixtureURL) else {
            throw PDFReaderError.fixtureUnreadable
        }

        // 4. Resolve the pagination mode with a horizontal fallback for
        //    any raw value that is not "horizontal" or "vertical". Capture
        //    the unknown raw value (if any) so we can log it after `self`
        //    is initialised — the `Logger` is a stored property and is
        //    only reachable post-`self`-init.
        let canonicalRawValues: Set<String> = [
            PaginationMode.horizontal.rawValue,
            PaginationMode.vertical.rawValue
        ]
        let rawPaginationMode = document.paginationModeRaw
        let resolvedMode = PaginationMode(canonicalRawValue: rawPaginationMode)
        let unknownRawValue: String? = canonicalRawValues.contains(rawPaginationMode)
            ? nil
            : rawPaginationMode

        // 5. Build the PDFView and apply the resolved mode. Done before
        //    `self` is initialised so the stored property can take a
        //    fully-configured value.
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        Self.configurePDFView(pdfView, for: resolvedMode)

        // 6. Initialise stored properties. After this point the logger is
        //    available and we can record the unknown-raw-value event.
        self.document = document
        self.modelContext = modelContext
        self.pdfView = pdfView
        self._paginationMode = resolvedMode

        if let unknownRawValue {
            logger.warning("Unknown paginationModeRaw '\(unknownRawValue, privacy: .public)' for document \(document.id, privacy: .public); falling back to horizontal.")
        }
    }

    // MARK: - Private helpers

    /// Resolves the bundled fixture URL via
    /// `Bundle.url(forResource:withExtension:)`. Single source of truth
    /// for the fixture-URL lookup so the initialisation path and any
    /// future fixture-loading call site (e.g. a public re-load helper
    /// added by a later slice) share the same missing-fixture error
    /// path. A `nil` URL surfaces
    /// `PDFReaderError.fixtureMissing(resource:)` with the requested
    /// resource name verbatim, so the recoverable-error banner mounted
    /// by `ReaderContainerView` (child PR #4) can point the user at the
    /// missing asset by name.
    ///
    /// - Parameters:
    ///   - bundle: The bundle to resolve the fixture from. Production
    ///     code passes `Bundle.main`; the test suite injects an
    ///     isolated bundle to exercise the missing-fixture path.
    ///   - resourceName: The bundle resource name (defaults to
    ///     `canonicalResourceName` = `"sample-bundle"`).
    ///   - resourceExtension: The bundle resource extension (defaults
    ///     to `canonicalResourceExtension` = `"pdf"`).
    /// - Returns: The located `URL` pointing at the bundled fixture
    ///   bytes.
    /// - Throws: `PDFReaderError.fixtureMissing(resource:)` if the
    ///   bundle does not contain a resource matching the supplied
    ///   `resourceName` and `resourceExtension`. The associated value
    ///   is the `resourceName` the caller passed in.
    private static func resolveFixtureURL(
        in bundle: Bundle,
        resourceName: String,
        resourceExtension: String
    ) throws -> URL {
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw PDFReaderError.fixtureMissing(resource: resourceName)
        }
        return url
    }

    /// Configures the supplied `PDFView` to match the supplied pagination
    /// mode. Single source of truth for the `PDFView` configuration so the
    /// initial configuration (init path) and the toggle path (`paginationMode`
    /// setter) stay byte-equal.
    ///
    /// Horizontal paginated mode:
    /// - `displayMode = .singlePage`
    /// - `displayDirection = .horizontal`
    /// - `usePageViewController(true)` is invoked with `viewOptions = nil`.
    ///   PDFKit exposes `usePageViewController` as a method on iOS
    ///   (`-usePageViewController:withViewOptions:`), not a property; the
    ///   setter call is the canonical way to opt into the page-view-controller
    ///   navigation stack.
    ///
    /// Vertical continuous mode:
    /// - `displayMode = .singlePageContinuous`
    /// - `displayDirection = .vertical`
    /// - `usePageViewController` is **not** invoked; the PDFKit default under
    ///   `singlePageContinuous` is the configuration the spec mandates.
    private static func configurePDFView(_ pdfView: PDFView, for mode: PaginationMode) {
        switch mode {
        case .horizontal:
            pdfView.displayMode = .singlePage
            pdfView.displayDirection = .horizontal
            pdfView.usePageViewController(true)
        case .vertical:
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
        }
    }
}
