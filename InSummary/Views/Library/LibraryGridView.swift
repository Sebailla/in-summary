//
//  LibraryGridView.swift
//  InSummary
//
//  Minimal accessible library shell for Phase 1. Lists the seed folder
//  and seed document so the on-device experience is end-to-end runnable
//  without an import flow. The full library surface is reintroduced in
//  Phase 5.
//
//  Phase 2 (`pdf-reader-wiring`, child PR #4 — `feat/pdf-reader-wiring`)
//  adds the navigation wiring: the seed `DocumentItem` row becomes a
//  `NavigationLink` to `ReaderContainerView(document:)`; every other row
//  surfaces a recoverable "not supported in this build" alert. The
//  folder row layout, the document section header, and the accessibility
//  labels are preserved byte-for-byte.
//

import SwiftUI
import SwiftData

struct LibraryGridView: View {

    /// Live, observable list of folders rendered in the library shell.
    @Query(sort: \FolderEntity.createdAt, order: .forward)
    private var folders: [FolderEntity]

    /// Live, observable list of documents rendered in the library shell.
    @Query(sort: \DocumentItem.createdAt, order: .forward)
    private var documents: [DocumentItem]

    /// The Phase 1 SwiftData main `ModelContext`. Resolved from the
    /// environment so the `NavigationLink` destination can hand the
    /// context to `ReaderContainerView` without forcing the caller to
    /// thread it through.
    @Environment(\.modelContext) private var modelContext

    /// The document whose row was tapped for the "not supported in this
    /// build" alert. `nil` while no alert is on screen.
    @State private var unsupportedDocumentTitle: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Folders") {
                    ForEach(folders, id: \.id) { folder in
                        LibraryRow(
                            title: folder.name,
                            subtitle: "\(folder.documents?.count ?? 0) document(s)",
                            systemImage: "folder.fill"
                        )
                    }
                }
                Section("Documents") {
                    ForEach(documents, id: \.id) { document in
                        documentRow(for: document)
                    }
                }
            }
            .navigationTitle("In-Summary")
            .alert(
                "Not supported in this build",
                isPresented: Binding(
                    get: { unsupportedDocumentTitle != nil },
                    set: { isPresented in
                        if !isPresented { unsupportedDocumentTitle = nil }
                    }
                ),
                presenting: unsupportedDocumentTitle
            ) { _ in
                Button("OK", role: .cancel) { unsupportedDocumentTitle = nil }
            } message: { title in
                Text("The document \"\(title)\" is not reachable from the reader in this build. Only the bundled PDF seed can be opened.")
            }
        }
    }

    /// Renders a single document row, branching into a
    /// `NavigationLink` to the reader for the seed PDF and a
    /// recoverable alert for every other document. Phase 2 is
    /// reachable only for `DocumentItem` rows whose
    /// `fileTypeRaw == "pdf"` AND `localFileName.isEmpty == true`.
    @ViewBuilder
    private func documentRow(for document: DocumentItem) -> some View {
        let title = document.title.isEmpty ? "Untitled" : document.title
        let subtitle = "\(document.fileTypeRaw.uppercased()) · \(document.totalPages) page(s)"
        if document.fileTypeRaw == "pdf" && document.localFileName.isEmpty {
            NavigationLink {
                ReaderContainerView(document: document, modelContext: modelContext)
            } label: {
                LibraryRow(
                    title: title,
                    subtitle: subtitle,
                    systemImage: "doc.text"
                )
            }
            .accessibilityHint("Opens the reader")
        } else {
            Button {
                unsupportedDocumentTitle = title
            } label: {
                LibraryRow(
                    title: title,
                    subtitle: subtitle,
                    systemImage: "doc.text"
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Not supported in this build")
        }
    }
}

/// A single accessible row in the library list. Uses semantic
/// `accessibilityElement` values so VoiceOver speaks both the title and
/// the subtitle as a single combined label.
private struct LibraryRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

#if DEBUG
#Preview("Library shell") {
    LibraryGridView()
        .modelContainer(PreviewContainer.previewContainer)
}
#endif