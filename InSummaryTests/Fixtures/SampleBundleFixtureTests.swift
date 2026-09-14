//
//  SampleBundleFixtureTests.swift
//  InSummaryTests
//
//  GREEN step (task 1.6) — pins the production `Bundle.main` contract for the
//  bundled `sample-bundle.pdf` fixture for Phase 2 of
//  `pdf-reader-pencilkit-ink-recovery`.
//
//  Every assertion below uses `Bundle.main` so the test verifies the same
//  resource resolution path the production app uses at runtime:
//    • `Bundle.main.url(forResource: "sample-bundle", withExtension: "pdf")`
//      must resolve and be non-nil — the resource must be present in the
//      production app's *Copy Bundle Resources* output (task 1.5).
//    • The bundled bytes must be non-empty.
//    • The bundled bytes must be ≤ 1 MB (the spec's size budget; the actual
//      canonical artifact is ~48 KB).
//    • The SHA-256 of the bundled bytes must equal the SHA-256 of
//      `PDFFixtureGenerator.generateFixture()` — the in-process generator
//      is the cross-process reconciliation point delivered by task 1.7, so
//      equality holds once bundle preference is active.
//    • `PDFDocument(url:).pageCount` on the bundled bytes must be exactly 20.
//
//  Strict TDD contract: this file is the GREEN specification for task 1.6.
//  In this slice the production wiring (tasks 1.3, 1.4, 1.5, 1.7) is already
//  in place, so the first run is expected to land GREEN; the apply-progress
//  records the observed state honestly.
//

import XCTest
import PDFKit
import CryptoKit
@testable import InSummary

@MainActor
final class SampleBundleFixtureTests: XCTestCase {

    /// The size budget for the Phase 2 fixture as pinned by task 1.6.
    private let maxFixtureSizeInBytes: Int = 1 * 1024 * 1024 // 1 MB

    /// The canonical page count for the Phase 2 fixture.
    private let expectedPageCount: Int = 20

    /// The exact resource name used in `Bundle.main.url(forResource:withExtension:)`.
    /// Mirrors the canonical path
    /// `InSummary/Resources/Fixtures/sample-bundle.pdf` declared in
    /// `openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pdf-fixture`.
    private let resourceName: String = "sample-bundle"
    private let resourceExtension: String = "pdf"

    /// `Bundle.main.url(forResource:withExtension:)` must resolve to the
    /// production-app-bundled `sample-bundle.pdf`. The fixture is wired into
    /// the production `InSummary` target's *Copy Bundle Resources* phase in
    /// task 1.5, so this lookup reaches the same artifact the app reads at
    /// runtime.
    ///
    /// RED until task 1.5 lands. GREEN once the production wiring exists.
    func test_resourceURLResolvesFromBundleMain() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
            "Bundle.main.url(forResource: \"\(resourceName)\", withExtension: \"\(resourceExtension)\") must resolve to a non-nil URL — the fixture MUST be wired into InSummary's Copy Bundle Resources phase"
        )

        // Sanity: the URL must point inside the production app bundle.
        let bundleRoot = Bundle.main.bundleURL
        XCTAssertTrue(
            url.path.hasPrefix(bundleRoot.path),
            "Resolved fixture URL must live inside Bundle.main; got \(url.path), bundle root \(bundleRoot.path)"
        )
    }

    /// `Data(contentsOf:)` on the resolved URL must yield non-empty bytes.
    /// An empty file would still satisfy URL resolution but would fail every
    /// downstream assertion, so this is the cheapest pre-condition.
    func test_bundledDataIsNonEmpty() throws {
        let url = try resolveFixtureURL()
        let data = try Data(contentsOf: url)

        XCTAssertGreaterThan(
            data.count,
            0,
            "The bundled sample-bundle.pdf must not be empty"
        )
    }

    /// The bundled fixture must respect the size budget pinned by task 1.6:
    /// the file must be ≤ 1 MB. The canonical artifact is ~48 KB so this is
    /// a generous guard, not a tight one — the guard exists so an accidental
    /// 50 MB PDF in the repo fails review.
    func test_bundledDataIsWithinOneMegabyte() throws {
        let url = try resolveFixtureURL()
        let data = try Data(contentsOf: url)

        XCTAssertLessThanOrEqual(
            data.count,
            maxFixtureSizeInBytes,
            "The bundled sample-bundle.pdf must be ≤ 1 MB; got \(data.count) bytes (budget \(maxFixtureSizeInBytes))"
        )
    }

    /// The SHA-256 of the bundled bytes must equal the SHA-256 of
    /// `PDFFixtureGenerator.generateFixture()`. Task 1.7 reconciles the
    /// cross-process `/ID` gap by making `generateFixture()` prefer the
    /// bundled resource, so equality holds inside any process that loads
    /// the generator and reads `Bundle.main` (the production app reads from
    /// `Bundle.main`, the test bundle from `Bundle(for:)` — the file is
    /// identical because the *Copy Bundle Resources* phase copies the same
    /// `PBXFileReference` bytes into both bundles).
    func test_bundledSHA256EqualsGeneratorSHA256() throws {
        let url = try resolveFixtureURL()
        let bundledData = try Data(contentsOf: url)
        let generatorData = PDFFixtureGenerator.generateFixture()

        let bundledDigest = sha256Hex(bundledData)
        let generatorDigest = sha256Hex(generatorData)

        XCTAssertEqual(
            bundledDigest,
            generatorDigest,
            """
            The SHA-256 of the bundled sample-bundle.pdf must equal the SHA-256 of \
            PDFFixtureGenerator.generateFixture(). \
            bundled=\(bundledDigest) generator=\(generatorDigest)
            """
        )
    }

    /// `PDFDocument(url:)` on the resolved URL must parse the fixture into a
    /// document with exactly 20 pages. This is the consumer-side witness of
    /// the canonical page count pinned by `PDFFixtureGenerator.fixturePageCount`.
    func test_pdfDocumentReportsTwentyPages() throws {
        let url = try resolveFixtureURL()
        let document = try XCTUnwrap(
            PDFDocument(url: url),
            "PDFDocument(url:) must parse the bundled sample-bundle.pdf"
        )

        XCTAssertEqual(
            document.pageCount,
            expectedPageCount,
            "PDFDocument(url:).pageCount must equal \(expectedPageCount); got \(document.pageCount)"
        )
    }

    // MARK: - Helpers

    /// Resolve the bundled fixture URL via `Bundle.main`. Centralised so
    /// every test starts from the same pre-condition.
    private func resolveFixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
            "Bundle.main.url(forResource: \"\(resourceName)\", withExtension: \"\(resourceExtension)\") must resolve"
        )
    }

    /// Lowercase hex SHA-256 of `data`. Centralised so the equality
    /// assertion reads cleanly and the hex format is consistent across
    /// tests.
    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}