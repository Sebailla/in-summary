# Registro de cambios

Todos los cambios relevantes de In-Summary se documentan en este archivo.
El proyecto se adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
y registra la evidencia de cada entrega por slice bajo `openspec/archive/`.

## [1.0.0] — 2026-09-14

Fase 2 de la v1 de In-Summary. Primera entrega con el lector local de PDF
y la superposición de tinta de PencilKit anclada por página en iPad.
Solo iPad, solo local, totalmente sin conexión. En la v1 no se incluye
ninguna ruta de código de iCloud, CloudKit, red, importación, exportación
ni sincronización.

### Añadido

- **`pdf-fixture` — PDF determinista incluido en el paquete**
  - `InSummary/Resources/Fixtures/sample-bundle.pdf` — PDF de muestra
    generado por el proyecto, determinista, bajo licencia CC0, de 20
    páginas, ubicado exactamente en la ruta canónica. Se regenera con
    `Tools/generate-sample-bundle-pdf.swift` cada vez que cambia el
    código fuente del generador.
  - `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` — dedicación
    CC0, SHA-256 del generador y cantidad de páginas.

- **`pdf-engine` — coordinador local del lector**
  - `InSummary/Services/PDFEngine/PDFReaderCoordinator.swift` —
    `UIViewRepresentable` anotado con `@MainActor` que posee un
    `PDFView`. Lee `DocumentItem.paginationModeRaw` una vez al abrir y
    lo escribe de vuelta al alternar el modo; no agrega, altera ni
    migra el campo.
  - `InSummary/Services/PDFEngine/PDFReaderError.swift` — errores
    tipados (`fixtureMissing`, `fixtureUnreadable`,
    `unsupportedDocument`, `paginationSaveFailed`).

- **`pencilkit-ink-overlay` — escritura manual anclada por página**
  - `InSummary/Services/AnnotationEngine/PencilCanvasOverlay.swift` —
    `UIViewRepresentable` que envuelve un `PKCanvasView` con
    `drawingPolicy = .pencilOnly`, marcador resaltador como herramienta
    predeterminada, y lectura/escritura directa de
    `PageAnnotation.drawingData` (sin almacén paralelo en disco).
  - `InSummary/Services/AnnotationEngine/PDFPageChangeObserver.swift` —
    `final class` anotado con `@MainActor` que intercambia los
    `PKDrawing` entre páginas y fusiona por valor sobre
    `currentPageIndex`.
  - `InSummary/Services/AnnotationEngine/AnnotationError.swift` —
    errores tipados (`drawingDecodeFailed`,
    `drawingPersistenceFailed`).

- **`pdf-reader-wiring` — superficie del lector en SwiftUI**
  - `InSummary/Views/Reader/ReaderContainerView.swift` — compone el
    coordinador y la superposición, suscribe el observador de cambio
    de página al editor del coordinador y muestra banners de error
    recuperables.
  - `InSummary/Views/Reader/PDFViewRepresentable.swift` —
    `UIViewRepresentable` delgado sobre `PDFView` para que el
    coordinador pueda leer la referencia activa.
  - `InSummary/Views/Library/LibraryGridView.swift` — la fila del PDF
    semilla se convierte en un `NavigationLink` hacia
    `ReaderContainerView(document:)`; las filas que no son PDF o que no
    son semilla muestran una alerta recuperable de "no compatible con
    esta compilación".

### Línea base de Fase 1 (preservada byte a byte, reutilizada como invariantes de v1)

- `InSummary/Models/DocumentItem.swift` — `paginationModeRaw: String`
  con valor predeterminado `"horizontal"`. La Fase 2 lo lee al abrir y
  lo escribe al alternar.
- `InSummary/Models/PageAnnotation.swift` — `drawingData: Data?`
  declarado con `@Attribute(.externalStorage)`. La Fase 2 lo reutiliza
  como almacén de tinta por página.
- `InSummary/Services/Persistence/` — esquema, `ModelContainer` y
  `LibrarySeedService` sin cambios.
- `InSummary/Info.plist` — sin nuevas descripciones de uso; el acceso a
  PDF en v1 es exclusivamente desde el paquete.

### Evidencia de pruebas

- 39 casos XCTest nuevos añadidos en los cuatro slices de la Fase 2
  (14 + 11 + 12 + 2). La línea base de Fase 1 (56 pruebas) se conserva
  byte a byte sin cambios.
- Suite XCTest completa en el simulador iPad Pro de 13 pulgadas (M5)
  con iOS 26.5: **95/95 en verde**, registrada en
  `openspec/archive/pdf-reader-pencilkit-ink-recovery/archive.md` §3.1.
- Guardia de búsqueda de cadenas bloqueadas (sin iCloud, CloudKit,
  red, importación, exportación ni sincronización en código de
  producto): cero coincidencias en
  `InSummary/Services/PDFEngine/`,
  `InSummary/Services/AnnotationEngine/` y
  `InSummary/Views/Reader/`.
- Aceptación en modo avión: aprobada por construcción; la suite es
  independiente del tiempo y no usa ningún punto de llamada con
  capacidad remota.

### Stack y plataformas

- Destino: solo iPad (`TARGETED_DEVICE_FAMILY = 2`). Sin iPhone, sin
  Mac Catalyst, sin visionOS.
- Únicamente marcos de trabajo de primera parte: `Foundation`,
  `SwiftData`, `PDFKit`, `PencilKit`, `SwiftUI`, `UIKit`, `os`. Sin
  SDKs de terceros.
- Swift 6.0, objetivo de despliegue de iOS 26.0.
- Firma: personal / de desarrollo. No se ejercen capacidades del
  Apple Developer Program (push, contenedor de CloudKit, App Group
  entre dispositivos).

### Entrega

- Cadena `feature-branch-chain` estrictamente lineal de cuatro PR
  hijos más un PR tracker, cada uno ≤ 400 líneas modificadas, todos
  fusionados en verde:
  - #20 `feat/pdf-fixture` → #22 `feat/pdf-engine` → #23
    `feat/pencilkit-ink-overlay` → #26 `feat/pdf-reader-wiring` →
    #19 `tracker/pdf-reader-pencilkit-ink-recovery` → `main`.
- SHA final de merge en `main`:
  `973415d508a4d22a788e0408558f7875313ad3c4`.
- Archivo de OpenSpec:
  `openspec/archive/pdf-reader-pencilkit-ink-recovery/` con el espejo
  en español bajo
  `documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/`.
- Disciplina de TDD estricto aplicada en los cuatro PR hijos.

### Fuera de alcance (explícito, diferido fuera de v1.0.0)

- Importación de PDF mediante `.fileImporter`,
  `UIDocumentPickerViewController` o `PHPickerViewController` — Fase 5.
- Biblioteca, carpetas y organización con arrastrar y soltar — Fase 5.
- Exportación de PDF con marcas grabadas — Fase 5.
- Notas adhesivas — Fase 4.
- Resaltados semánticos (selección de texto en PDF) — Fase 4.
- Motores de Markdown o EPUB — Fase 3.
- Sincronización con iCloud / CloudKit, "Disponible en mis otros
  dispositivos", `CKAsset`, notificaciones push y sesiones de URL en
  segundo plano — fase futura; la lista de bloqueo en
  `openspec/config.yaml` lo aplica sobre el código de producto.

### Comandos de verificación

```bash
plutil -lint InSummary/Info.plist
grep -E "MARKETING_VERSION" InSummary.xcodeproj/project.pbxproj
plutil -extract CFBundleShortVersionString raw InSummary/Info.plist
plutil -extract CFBundleVersion raw InSummary/Info.plist
```

Esperado para v1.0.0: `MARKETING_VERSION = 1.0.0` en cada
configuración de Xcode (Debug + Release, destino de la aplicación +
destino de pruebas), `CFBundleShortVersionString = 1.0.0` y
`CFBundleVersion = 1`.
