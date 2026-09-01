//
//  LibraryGridView.swift
//  InSummary
//
//  Minimal accessible library shell for Phase 1. Lists the seed folder
//  and seed document so the on-device experience is end-to-end runnable
//  without an import flow. The full library surface is reintroduced in
//  Phase 5.
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
                        LibraryRow(
                            title: document.title.isEmpty ? "Untitled" : document.title,
                            subtitle: "\(document.fileTypeRaw.uppercased()) · \(document.totalPages) page(s)",
                            systemImage: "doc.text"
                        )
                    }
                }
            }
            .navigationTitle("In-Summary")
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