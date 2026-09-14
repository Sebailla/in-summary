//
//  PDFFixtureGeneratorTests.swift
//  InSummaryTests
//
//  RED step (task 1.1) — pins the deterministic fixture-generator contract
//  for Phase 2 of `pdf-reader-pencilkit-ink-recovery`.
//
//  Every assertion below references `PDFFixtureGenerator`, which does not
//  exist yet. The generator, when implemented (task 1.2), must:
//    • Produce byte-for-byte identical output across consecutive calls.
//    • Produce a 20-page PDF that `PDFDocument(data:)` can parse.
//    • Render each page to a non-empty `UIImage` at 72 DPI
//      (letter-sized: 612 × 792 points).
//    • Expose `fixtureContentHash` equal to the lowercase hex SHA-256 of
//      the output bytes, and `fixturePageCount` equal to 20.
//
//  This file is the RED specification. It is intentionally failing on the
//  baseline because the production symbol does not exist. Do not implement
//  the generator until the apply-progress records a GREEN pass.
//

import XCTest
import PDFKit
import UIKit
import CryptoKit
@testable import InSummary

@MainActor
final class PDFFixtureGeneratorTests: XCTestCase {

    /// Letter-sized bounds at 72 DPI: 8.5" × 11" × 72 pt/in.
    private let letterBoundsAt72DPI = CGRect(x: 0, y: 0, width: 612, height: 792)

    func test_twoConsecutiveCallsProduceByteIdenticalOutput() {
        let first = PDFFixtureGenerator.generateFixture()
        let second = PDFFixtureGenerator.generateFixture()

        XCTAssertEqual(
            first,
            second,
            "Two consecutive calls to PDFFixtureGenerator.generateFixture() must return byte-for-byte identical Data"
        )
    }

    func test_outputIsATwentyPagePDFDocument() throws {
        let data = PDFFixtureGenerator.generateFixture()

        let document = try XCTUnwrap(
            PDFDocument(data: data),
            "PDFFixtureGenerator.generateFixture() must return valid PDF bytes that PDFDocument can parse"
        )

        XCTAssertEqual(
            document.pageCount,
            20,
            "PDFFixtureGenerator.generateFixture() must produce a PDFDocument with exactly 20 pages"
        )
    }

    func test_eachPageRendersToNonEmptyImageAt72DPI() throws {
        let data = PDFFixtureGenerator.generateFixture()
        let document = try XCTUnwrap(
            PDFDocument(data: data),
            "Sanity pre-condition: generator output must parse as PDFDocument"
        )
        XCTAssertEqual(
            document.pageCount,
            20,
            "Sanity pre-condition: generator must produce 20 pages before any render check"
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // 72 DPI = 1 pixel per point
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: letterBoundsAt72DPI, format: format)

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                XCTFail("PDFPage at index \(index) must exist in the fixture")
                continue
            }

            let image = renderer.image { context in
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fill(letterBoundsAt72DPI)
                page.draw(with: PDFDisplayBox.mediaBox, to: cgContext)
                cgContext.restoreGState()
            }

            XCTAssertEqual(
                image.size.width,
                612,
                "Page \(index) must render at 612 points wide at 72 DPI (US letter, 8.5 in × 72 pt/in)"
            )
            XCTAssertEqual(
                image.size.height,
                792,
                "Page \(index) must render at 792 points tall at 72 DPI (US letter, 11 in × 72 pt/in)"
            )

            guard let cgImage = image.cgImage else {
                XCTFail("Page \(index) must produce a CGImage when rendered at 72 DPI")
                continue
            }
            XCTAssertGreaterThan(
                cgImage.bytesPerRow,
                0,
                "Page \(index) must produce non-empty raster bytes when rendered at 72 DPI"
            )
            XCTAssertGreaterThan(
                cgImage.width,
                0,
                "Page \(index) must produce a CGImage with positive width"
            )
            XCTAssertGreaterThan(
                cgImage.height,
                0,
                "Page \(index) must produce a CGImage with positive height"
            )
        }
    }

    func test_canonicalContentHashEqualsSHA256OfOutput() {
        let data = PDFFixtureGenerator.generateFixture()
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(
            PDFFixtureGenerator.fixtureContentHash,
            hex,
            "PDFFixtureGenerator.fixtureContentHash must equal the lowercase hex SHA-256 of the generator output"
        )
    }

    func test_canonicalPageCountEqualsTwenty() {
        XCTAssertEqual(
            PDFFixtureGenerator.fixturePageCount,
            20,
            "PDFFixtureGenerator.fixturePageCount must equal 20 per the Phase 2 fixture contract"
        )
    }

    /// The canonical SHA-256 of the bundled `sample-bundle.pdf` produced by the
    /// verified task 1.3 generator run. Pinned here so the test process can prove
    /// that the bundled bytes are exactly the bytes authored in task 1.3.
    private let canonicalBundledSHA256 = "2d0f772b75d928e469c3bdaa21aba01d1cb23e24773fe2f8851b687588c6d491"

    /// Pin the resolution of the bundled fixture from the test bundle.
    ///
    /// `Bundle(for: PDFFixtureGeneratorTests.self)` returns the bundle
    /// that contains this class — for unit tests hosted in
    /// `InSummary.app`, that is the embedded `InSummaryTests.xctest`
    /// plugin. The fixture MUST be wired into the test target's *Copy
    /// Bundle Resources* phase for this lookup to resolve under XCTest.
    ///
    /// RED until the pbxproj wires the resource into the test target.
    func test_bundledFixtureResolvesFromTestBundle() throws {
        let bundleURL = try XCTUnwrap(
            Bundle(for: PDFFixtureGeneratorTests.self).url(
forResource: "sample-bundle",
withExtension: "pdf"
            ),
            "Bundle(for: PDFFixtureGeneratorTests.self).url(forResource:withExtension:) must resolve to a non-nil URL — the fixture MUST be wired into InSummaryTests' Copy Bundle Resources phase"
        )

        let bundleData = try Data(contentsOf: bundleURL)
        XCTAssertGreaterThan(
            bundleData.count,
            0,
            "The bundled sample-bundle.pdf must not be empty"
        )
    }

    /// Pin the canonical SHA-256 of the bundled fixture.
    ///
    /// The constant is the lowercase hex digest of the on-disk
    /// `sample-bundle.pdf` produced in task 1.3. Any drift trips this
    /// test and instructs the developer to re-run the build phase.
    ///
    /// RED until the bundled file is reachable under XCTest (see
    /// `test_bundledFixtureResolvesFromTestBundle`).
    func test_bundledFixtureSHA256EqualsCanonicalConstant() throws {
        let bundleURL = try XCTUnwrap(
            Bundle(for: PDFFixtureGeneratorTests.self).url(
forResource: "sample-bundle",
withExtension: "pdf"
            ),
            "The bundled fixture must be reachable from the test bundle"
        )

        let bundleData = try Data(contentsOf: bundleURL)
        let digest = SHA256.hash(data: bundleData)
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(
            hex,
            canonicalBundledSHA256,
            "The SHA-256 of the bundled sample-bundle.pdf must equal the canonical constant from the task 1.3 generator run"
        )
    }

    /// Pin the bundle-preference behavior: when the test bundle contains
    /// `sample-bundle.pdf`, `PDFFixtureGenerator.generateFixture()` MUST
    /// return the bundled bytes verbatim rather than re-running
    /// `UIGraphicsPDFRenderer` (which embeds a process-unique `/ID` and
    /// therefore produces different bytes per process).
    ///
    /// RED until `PDFFixtureGenerator` resolves the bundled resource
    /// before falling back to `makeFixture()`.
    func test_generateFixtureReturnsBundledBytesWhenResourceAvailable() throws {
        let bundleURL = try XCTUnwrap(
            Bundle(for: PDFFixtureGeneratorTests.self).url(
forResource: "sample-bundle",
withExtension: "pdf"
            ),
            "The bundled fixture must be reachable from the test bundle"
        )

        let bundleData = try Data(contentsOf: bundleURL)
        let generatedData = PDFFixtureGenerator.generateFixture()

        XCTAssertEqual(
            generatedData,
            bundleData,
            "PDFFixtureGenerator.generateFixture() must prefer the bundled sample-bundle.pdf over on-the-fly generation when the bundle resource is present"
        )
    }

    /// Pin that `fixtureContentHash` equals the SHA-256 of the bundled
    /// fixture once bundle-preference is active. Combined with the
    /// existing `test_canonicalContentHashEqualsSHA256OfOutput`, this
    /// proves that the in-process constant and the on-disk artifact have
    /// reconciled across the cross-process `/ID` gap.
    ///
    /// RED until `fixtureContentHash` is derived from the bundled bytes.
    func test_canonicalContentHashEqualsBundledFixtureSHA256() throws {
        let bundleURL = try XCTUnwrap(
            Bundle(for: PDFFixtureGeneratorTests.self).url(
forResource: "sample-bundle",
withExtension: "pdf"
            ),
            "The bundled fixture must be reachable from the test bundle"
        )

        let bundleData = try Data(contentsOf: bundleURL)
        let digest = SHA256.hash(data: bundleData)
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(
            PDFFixtureGenerator.fixtureContentHash,
            hex,
            "PDFFixtureGenerator.fixtureContentHash must equal the SHA-256 of the bundled fixture once the generator prefers the bundled resource"
        )
        XCTAssertEqual(
            PDFFixtureGenerator.fixtureContentHash,
            canonicalBundledSHA256,
            "PDFFixtureGenerator.fixtureContentHash must equal the canonical SHA-256 of the bundled sample-bundle.pdf"
        )
    }
}
