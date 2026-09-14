<!--
  SAMPLE-BUNDLE-LICENSE.md
  InSummary / sample-bundle.pdf

  SPDX-License-Identifier: CC0-1.0

  CC0 1.0 Universal, project-authored.
-->

# `sample-bundle.pdf` — License and authorship record

This document is the in-repo license and authorship record for the
bundled Phase 2 PDF fixture
[`sample-bundle.pdf`](./sample-bundle.pdf) used by the
`pdf-reader-pencilkit-ink-recovery` change.

## Dedication

The fixture is released under the **Creative Commons CC0 1.0 Universal**
public domain dedication. To the extent possible under law, the authors
have waived all copyright and related or neighboring rights to the
fixture. A copy of the full legal text of the CC0 1.0 Universal
dedication is published at
<https://creativecommons.org/publicdomain/zero/1.0/legalcode>.

SPDX-License-Identifier: `CC0-1.0`

## Authorship

The fixture is **project-authored**. Every drawing primitive in the
fixture — header text, geometric pattern, page-index footer, and CC0
paragraph — originates from the project's own generator code at
[`InSummaryTests/Support/PDFFixtureGenerator.swift`](../../../InSummaryTests/Support/PDFFixtureGenerator.swift).
The generator carries a top-of-file
`// SPDX-License-Identifier: CC0-1.0` comment and the assertion
"CC0 1.0 Universal, project-authored", as required by the
`pdf-fixture` capability spec, **Requirement: Fixture licensing and
authorship** and **Scenario: License attestation**.

The fixture contains **no third-party content**: no third-party
text, fonts, images, or data files are imported by the generator or
embedded in the PDF.

## Identity

| Field | Value |
| --- | --- |
| Canonical path | `InSummary/Resources/Fixtures/sample-bundle.pdf` |
| Page count | **20** |
| SHA-256 (lowercase hex, of the bundled bytes) | `2d0f772b75d928e469c3bdaa21aba01d1cb23e24773fe2f8851b687588c6d491` |

The SHA-256 above is the canonical bundled content hash. It is pinned
as a constant in `PDFFixtureGeneratorTests.test_bundledFixtureSHA256EqualsCanonicalConstant`
and is the value any test, build phase, or release pipeline must match
when reading the fixture from the bundle. A mismatch indicates the
bundled artifact and the generator have drifted apart and the build
phase must be re-run.

## Why CC0

The fixture exists solely to give the PDF reader, the PencilKit ink
overlay, and the page-change observer a stable, license-clean payload
to load at test time and during in-process comparison. Releasing it
under CC0 removes any downstream license-tracking overhead and lets
the bundled bytes travel with the application without attribution
churn.