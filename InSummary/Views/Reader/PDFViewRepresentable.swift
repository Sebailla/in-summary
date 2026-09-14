//
//  PDFViewRepresentable.swift
//  InSummary
//
//  Phase 2 (`pdf-reader-wiring`) SwiftUI bridge for the
//  `PDFReaderCoordinator`'s `PDFView`. The representable is the
//  single place where the coordinator's UIKit-native `PDFView` is
//  handed to the SwiftUI render tree.
//
//  Phase 2 invariants this file honours:
//
//  - `@MainActor`. `PDFView` is MainActor-isolated under the iOS 26
//    SDK; the representable must be `@MainActor` so SwiftUI can
//    build, update, and tear it down on the main actor alongside the
//    coordinator.
//  - The `PDFView` is the coordinator's. The representable does NOT
//    create its own `PDFView`. The coordinator owns the lifecycle
//    (build → configure → tear down) and configures it for the
//    resolved pagination mode. The representable is a thin host that
//    makes the coordinator's `pdfView` reachable from SwiftUI.
//  - No coordinator ownership transfer. The representable holds a
//    strong reference to the coordinator for the duration of its
//    mount so the underlying `PDFView` is stable across SwiftUI
//    redraws, but it does not move ownership into or out of the
//    coordinator.
//

import SwiftUI
import PDFKit

/// Thin SwiftUI bridge that exposes the `PDFReaderCoordinator`'s
/// `PDFView` to the SwiftUI render tree.
///
/// The representable is intentionally small: it does not own a
/// `PDFView`, does not configure it, and does not respond to
/// coordinator changes. The coordinator — built once per reader
/// mount by `ReaderContainerView` — owns the `PDFView` and configures
/// it for the resolved pagination mode (horizontal paginated or
/// vertical continuous). The representable's only job is to hand the
/// SwiftUI render tree the same `PDFView` instance the coordinator
/// already manages, so both layers can address it.
@MainActor
struct PDFViewRepresentable {

    /// The coordinator whose `pdfView` is exposed to SwiftUI. Held
    /// strongly so the coordinator's `PDFView` reference is stable for
    /// the lifetime of the representable; the coordinator itself is
    /// created and owned by `ReaderContainerView`.
    let coordinator: PDFReaderCoordinator
}

// MARK: - UIViewRepresentable conformance

extension PDFViewRepresentable: UIViewRepresentable {

    /// Returns the coordinator's `PDFView` directly. SwiftUI stores
    /// the view in its render tree; the coordinator continues to own
    /// the view's configuration.
    ///
    /// `makeUIView` is called once per representable instance —
    /// typically once when the SwiftUI container mounts and the
    /// coordinator is built. Subsequent redraws route through
    /// `updateUIView(_:context:)` (a no-op here).
    func makeUIView(context: Context) -> PDFView {
        coordinator.pdfView
    }

    /// No-op. The coordinator owns the `PDFView`'s configuration and
    /// configures it on construction; the representable does not need
    /// to forward SwiftUI state changes because the coordinator is
    /// the single source of truth for `displayMode`,
    /// `displayDirection`, and `usePageViewController`.
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Intentionally empty. The coordinator is the source of truth
        // for the `PDFView`'s configuration.
    }
}
