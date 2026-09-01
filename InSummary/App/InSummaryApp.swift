//
//  InSummaryApp.swift
//  InSummary
//
//  Application entry point placeholder for PR1 of the approved Phase 1
//  Feature Branch Chain. This scaffold intentionally contains no domain
//  logic, persistence wiring, or library UI; downstream PRs introduce those
//  concerns in the agreed order so each slice compiles independently.
//

import SwiftUI

@main
struct InSummaryApp: App {

    var body: some Scene {
        WindowGroup {
            PlaceholderRootView()
        }
    }
}

/// Minimal placeholder surface used only to verify the build and runtime
/// bootstrap succeed. Replaced by the real library shell in PR2.
private struct PlaceholderRootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("In-Summary")
                .font(.largeTitle)
                .accessibilityAddTraits(.isHeader)
            Text("PR1 · Project scaffold")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
