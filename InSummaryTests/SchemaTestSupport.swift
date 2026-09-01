//
//  SchemaTestSupport.swift
//  InSummaryTests
//
//  Shared helpers for the canonical SwiftData schema test suite. Each entity
//  test case uses the same in-memory `ModelContainer` factory and the same
//  "timestamp is recent on construction" assertion, so consolidating them
//  here keeps the per-entity test files focused on defaults, relationships,
//  and round-trip persistence.
//

import Foundation
import SwiftData
import XCTest
@testable import InSummary

/// Reusable, in-memory `ModelContainer` factory shared by every entity test
/// case. The container registers the full canonical schema so cross-entity
/// relationship assertions stay realistic without spinning up disk I/O.
enum SchemaTestSupport {

    /// Builds a transient in-memory container that owns the canonical schema.
    /// Every test calls this fresh so state never leaks between cases.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            FolderEntity.self,
            DocumentItem.self,
            PageAnnotation.self,
            TextHighlight.self,
            StickyNoteEntity.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_unwrapping
        return try! ModelContainer(for: schema, configurations: configuration)
    }

    /// Asserts `date` falls inside the `[before, after]` window. Captures
    /// `before` and `after` around the entity creation so the test stays a
    /// single expression.
    static func assertRecent(_ date: Date,
                             before: Date,
                             after: Date,
                             file: StaticString = #file,
                             line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(date, before, file: file, line: line)
        XCTAssertLessThanOrEqual(date, after, file: file, line: line)
    }
}

/// Shorthand for the `SchemaTestSupport.makeContainer()` factory so each
/// test site stays a single line.
func makeSchemaContainer() -> ModelContainer {
    SchemaTestSupport.makeContainer()
}