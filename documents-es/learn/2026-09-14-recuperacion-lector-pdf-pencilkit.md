# Recuperación local del lector PDF y anotaciones PencilKit

## What
Se implementó y entregó la Fase 2 del lector local de PDF para iPad, incluyendo fixture determinista, coordinación de PDFKit, anotaciones PencilKit por página e integración con la biblioteca.

## How
Se trabajó con SwiftUI, PDFKit, PencilKit, SwiftData y XCTest bajo TDD estricto. La entrega se dividió en una cadena lineal de cuatro PRs y un tracker; la verificación final ejecutó 95 pruebas XCTest en un simulador iPad Pro de 13 pulgadas (M5) con iOS 26.5, el equivalente disponible del destino configurado.

## Where
- `InSummary/Services/PDFEngine/` — carga del fixture y coordinación de la vista PDF.
- `InSummary/Services/AnnotationEngine/` — persistencia y restauración de trazos por página.
- `InSummary/Views/Reader/` — composición SwiftUI del lector, PDFView y overlay PencilKit.
- `InSummaryTests/` — pruebas de fixture, coordinación, overlay, observación e integración.
- `openspec/archive/pdf-reader-pencilkit-ink-recovery/` — especificación, evidencia y archivo final.

## Why
La aplicación necesitaba una base local y verificable para leer el PDF incluido y anotar cada página sin red, importación, iCloud ni cambios en el esquema de la Fase 1.

## How it works
1. La biblioteca abre el documento PDF incluido mediante una navegación a `ReaderContainerView`.
2. `PDFReaderCoordinator` carga el fixture local y aplica la preferencia de paginación persistida.
3. El lector observa los cambios de página y guarda el trazo saliente en `PageAnnotation.drawingData`.
4. Al volver a una página, el overlay restaura semánticamente su dibujo guardado.
5. Errores de fixture o persistencia se muestran como banners recuperables; el fallback no fuerza construcciones que puedan terminar la aplicación.

## Workflows
- Cadena de PRs: fixture → motor PDF → overlay PencilKit → integración del lector → tracker.
- Verificación: XCTest completo, guardas contra red, CloudKit e importación, y revisión nativa de confiabilidad.
- Archivo SDD: los artefactos en inglés y sus espejos en español se trasladan juntos al directorio de archivo tras el merge del tracker.
