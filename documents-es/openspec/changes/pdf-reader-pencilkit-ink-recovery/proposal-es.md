# Propuesta — pdf-reader-pencilkit-ink-recovery

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/proposal.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

## Por qué

La Fase 2 de v1 introduce la primera superficie real de lectura en
**In-Summary**: el motor de PDF con paginación horizontal y vertical,
la capa de tinta de PencilKit que registra la escritura del lector
por página lógica, y la persistencia del cambio de página que
mantiene intacto el `PKDrawing.dataRepresentation()` de cada página a
lo largo de la navegación.

Este cambio es una **recuperación** del mismo alcance cuyo primer
portón de inicialización falló por tres motivos:

1. Inventó un campo de esquema `paginationModeRaw` que la Fase 1 ya
   entrega como `var paginationModeRaw: String = "horizontal"` en
   `InSummary/Models/DocumentItem.swift`.
2. Usó la ruta equivocada del fixture
   (`InSummary/Resources/Fixture/sample.pdf`) en lugar de la ruta
   canónica `InSummary/Resources/Fixtures/sample-bundle.pdf`.
3. Produjo una topología de PRs con bifurcación (dos PRs hijos
   apuntando a la rama rastreadora) en lugar de la cadena
   estrictamente lineal que la skill `chained-pr` exige para
   `feature-branch-chain`.

Este sucesor **no** reutiliza ni referencia ningún código parcial del
intento previo. Solo recupera las decisiones de producto confirmadas:

- Solo iPad y solo local — la Fase 2 no incorpora rutas de iCloud,
  CloudKit, red, importación, exportación ni sincronización.
- El fixture que se utiliza para ejercitar el lector es un **PDF de
  20 páginas, CC0, determinista y autoral del proyecto** ubicado
  exactamente en `InSummary/Resources/Fixtures/sample-bundle.pdf`.
- La entrega sigue una cadena de ramas de funcionalidad con un PR
  rastreador en estado borrador / sin fusión; cada PR hijo tiene un
  tope de 400 líneas modificadas y se revisa en ≤ 60 minutos.
- La cadena de PRs es **estrictamente lineal**: cada PR hijo posterior
  al #1 apunta a la rama de su predecesor inmediato; solo el PR #1
  apunta al rastreador.

## Qué cambia

Una nueva ruta de lectura abre un PDF local de 20 páginas y permite
al lector:

1. Elegir el modo paginado horizontal o el modo continuo vertical;
   la elección se lee desde `DocumentItem.paginationModeRaw` (una
   invariante de la Fase 1) y se escribe de vuelta al alternar, de
   modo que se conserva por documento entre reaperturas.
2. Navegar con la pila de gestos nativa de `PDFView` (deslizar en
   horizontal, desplazar en vertical).
3. Dibujar con Apple Pencil en cualquier página; los toques con el
   dedo se ignoran.
4. Abandonar la página y volver — los trazos dibujados en cada página
   sobreviven a la navegación byte a byte, persistidos en la columna
   `PageAnnotation.drawingData` de la Fase 1 (ya declarada con
   `@Attribute(.externalStorage)`).

Con este cambio se introducen cuatro capacidades:

- `pdf-fixture` — el PDF de 20 páginas, CC0, determinista y autoral
  del proyecto, entregado exactamente en
  `InSummary/Resources/Fixtures/sample-bundle.pdf`.
- `pdf-engine` — `PDFReaderCoordinator` con modos horizontal y
  vertical; lee `paginationModeRaw` (no añade ni altera el campo).
- `pencilkit-ink-overlay` — `PencilCanvasOverlay` (`.pencilOnly`,
  `.highlighter`) más `PDFPageChangeObserver` que persiste
  `PKDrawing.dataRepresentation()` en `PageAnnotation.drawingData`.
- `pdf-reader-wiring` — composición de `ReaderContainerView` y
  cableado de navegación desde la capa de librería de la Fase 1 para
  que el PDF semilla sea alcanzable sin introducir importación.

## Invariantes de la Fase 1 que este cambio reutiliza (no modificar)

| Invariante | Dónde vive | Qué hace la Fase 2 |
| --- | --- | --- |
| `DocumentItem.paginationModeRaw: String` por defecto `"horizontal"` | `InSummary/Models/DocumentItem.swift` | Leerlo al abrir el coordinador; escribirlo de vuelta al alternar el modo. **Sin cambio de esquema.** |
| `PageAnnotation.drawingData: Data?` con `@Attribute(.externalStorage)` | `InSummary/Models/PageAnnotation.swift` (declarado en `specification.md` §3.1) | Usarlo como almacén de tinta por página. `PencilCanvasOverlay` lee y escribe esta columna directamente. No se introduce ningún almacén paralelo en archivos. |
| Sin `@Attribute(.unique)` en ninguna parte del esquema SwiftData local | Fase 1 + `specification.md` §3.5 | Intacto. No se añaden entidades, ni relaciones, ni campos. |
| Compatible con CloudKit por diseño | Fase 1 + `specification.md` §3.1 | Intacto. La Fase 2 no introduce campos ni relaciones que rompan la sincronización futura. |

## No-objetivos (explícitos)

| No-objetivo | Por qué se excluye |
| --- | --- |
| Añadir, alterar, poner por defecto o migrar `DocumentItem.paginationModeRaw` | La Fase 1 ya lo entrega. La Fase 2 lee y escribe el campo tal cual. |
| Añadir, alterar, poner por defecto o migrar `PageAnnotation.drawingData` | La Fase 1 ya lo entrega con `@Attribute(.externalStorage)`. La Fase 2 lo reutiliza. |
| Importación de PDF con `.fileImporter`, `UIDocumentPickerViewController` o `PHPickerViewController` | Fase 5 — fuera de `phases.in_scope`. El lector solo se ejercita con el fixture empaquetado. |
| Librería, carpetas, organización por arrastrar y soltar | Fase 5 — fuera de alcance. |
| Exportación de PDF con marcas quemadas | Fase 5 — fuera de alcance. |
| Notas adhesivas | Fase 4 — fuera de alcance. |
| Resaltados semánticos (selección de texto en PDF) | Fase 4 — fuera de alcance. |
| Motores de Markdown o EPUB | Fase 3 — fuera de alcance. |
| Sincronización con iCloud/CloudKit, "Hacer disponible en mis otros dispositivos", `CKAsset`, notificaciones push | Fase futura — no debe entrar en v1. La lista de subcadenas bloqueadas en `openspec/config.yaml` lo aplica en el código de producto. |
| Capacidades del Apple Developer Program (push, contenedor CloudKit, App Group entre dispositivos) | Para v1 basta con firma personal o de desarrollo. |
| Peticiones de red de cualquier tipo (`URLSession`, `NWConnection`, sockets crudos, analítica, telemetría) | Invariante de solo local. |
| Un almacén de tinta separado en archivos en disco | `PageAnnotation.drawingData` ya existe en la Fase 1. La Fase 2 no inventa un almacén paralelo. |

## Frontera de producto (este cambio)

- **Solo iPad.** Sin destino para iPhone, sin destino para Mac
  Catalyst, sin visionOS.
- **Solo local.** Todas las lecturas de archivo provienen del bundle
  de la app o del almacén SwiftData local. Cero peticiones de red
  salientes.
- **Sin capacidades remotas.** Sin iCloud, CloudKit, push, notificación
  remota ni sesión URL en segundo plano.
- **Sin Apple Developer Program.** Basta con firma personal o de
  desarrollo.
- **Solo marcos locales y de primera mano.** `PDFKit`, `PencilKit`,
  `SwiftData`, `SwiftUI`, `UIKit`. Sin SDKs de terceros.

## Qué se entrega en código

| Ruta | Capa | Notas |
| --- | --- | --- |
| `InSummary/Services/PDFEngine/PDFReaderCoordinator.swift` | Dominio | `UIViewRepresentable` `@MainActor` que posee un `PDFView`. Lee `paginationModeRaw` una vez y lo escribe de vuelta al alternar. Sin `import PencilKit`. |
| `InSummary/Services/PDFEngine/PDFReaderError.swift` | Dominio | Errores tipados: `fixtureMissing(resource:)`, `fixtureUnreadable`, `unsupportedDocument(reason:)`, `paginationSaveFailed(underlying:)`. |
| `InSummary/Services/AnnotationEngine/PencilCanvasOverlay.swift` | Dominio | `UIViewRepresentable` que envuelve `PKCanvasView` con `drawingPolicy = .pencilOnly` y la herramienta predeterminada highlighter. Lee y escribe `PageAnnotation.drawingData`. Sin `import PDFKit`. |
| `InSummary/Services/AnnotationEngine/PDFPageChangeObserver.swift` | Dominio | `final class` `@MainActor` que observa la señal de cambio de página e intercambia `PKDrawing` entre páginas. Sin `import PDFKit`; acepta un índice de página inyectado. |
| `InSummary/Services/AnnotationEngine/AnnotationError.swift` | Dominio | Errores tipados: `drawingDecodeFailed`, `drawingPersistenceFailed(underlying:)`. |
| `InSummary/Views/Reader/ReaderContainerView.swift` | Presentación | Capa SwiftUI. Compone el coordinador y la capa; suscribe el observador al publicador de cambio de página del coordinador; muestra banners de error recuperables. |
| `InSummary/Views/Reader/PDFViewRepresentable.swift` | Presentación | Envoltorio `UIViewRepresentable` delgado alrededor de `PDFView` para que el coordinador pueda leer la referencia en vivo. |
| `InSummary/Views/Library/LibraryGridView.swift` (modificado) | Presentación | La fila del PDF semilla se convierte en `NavigationLink` a `ReaderContainerView(document:)`; las filas que no son PDF o que no son semilla muestran una alerta recuperable "no soportado en esta build". |
| `Tools/generate-sample-bundle-pdf.swift` | Herramientas | Generador determinista autoral del proyecto que emite 20 páginas de texto CC0 en `InSummary/Resources/Fixtures/sample-bundle.pdf`. Se ejecuta localmente y en la fase de compilación. |

## Qué se entrega en recursos

| Ruta | Propósito |
| --- | --- |
| `InSummary/Resources/Fixtures/sample-bundle.pdf` | El fixture PDF. Autoral del proyecto, determinista, CC0, 20 páginas. La fase de compilación lo añade en el PR #1. La ruta exacta es canónica y no debe variar. |
| `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` | Dedicación CC0, SHA-256 del generador, conteo de páginas. Añadido por el PR #1. |

## Qué se entrega en pruebas

| Ruta | Cubre |
| --- | --- |
| `InSummaryTests/Support/PDFFixtureGeneratorTests.swift` | Determinismo del generador (dos ejecuciones producen el mismo hash), conteo de páginas = 20, tamaño del papel, renderizado por página. |
| `InSummaryTests/Fixtures/SampleBundleFixtureTests.swift` | El fixture empaquetado se resuelve desde `Bundle.main`, no está vacío, ≤ 1 MB, y se carga como `PDFDocument` de 20 páginas. |
| `InSummaryTests/PDFReaderCoordinatorTests.swift` | Abre el fixture empaquetado; el modo horizontal fija `displayMode = .singlePage` + `displayDirection = .horizontal`; el modo vertical fija `displayMode = .singlePageContinuous` + `displayDirection = .vertical`; un modo desconocido cae al horizontal; el round-trip de `paginationModeRaw` persiste el valor; el fixture ausente produce `PDFReaderError.fixtureMissing`; el fixture ilegible produce `.fixtureUnreadable`; un documento que no es PDF o no es semilla produce `.unsupportedDocument`. |
| `InSummaryTests/PencilCanvasOverlayTests.swift` | `drawingPolicy == .pencilOnly`; herramienta predeterminada es el highlighter; la reproducción desde `PageAnnotation.drawingData` es byte a byte; un `PageAnnotation` ausente activa el lazy-upsert; limpiar el lienzo persiste bytes vacíos. |
| `InSummaryTests/PDFPageChangeObserverTests.swift` | El round-trip preserva payloads `PKDrawing` byte a byte entre páginas 1 → 2 → 1; cinco ciclos de navegación son estables; el observador descarta notificaciones cuyo `currentPageIndex` coincide con el último índice observado (coalescencia por valor). |
| `InSummaryTests/ReaderIntegrationTests.swift` | De extremo a extremo: abrir el fixture empaquetado, navegar entre páginas, dibujar en página 1 y página 2, volver y comprobar que los trazos se preservan byte a byte; comprobación de aceptación sin conexión (modo avión). |

## Intocado

- `InSummary/Models/*` — sin cambios de esquema; se reutilizan las
  entidades de la Fase 1.
- `InSummary/Services/Persistence/*` — esquema sin cambios; este cambio
  reutiliza el `ModelContainer` y `LibrarySeedService` de la Fase 1.
- `InSummary/Info.plist` — sin nuevas descripciones de uso; el acceso
  a PDF es solo desde el bundle en v1.

## Aceptación (espejo de `specification.md` §6 Fase 2)

1. Abrir el fixture empaquetado en modo horizontal permite deslizar
   entre páginas con la transición nativa de `PDFView`.
2. Abrir el fixture empaquetado en modo vertical permite el
   desplazamiento continuo por todas las páginas.
3. Dibujar en la página 1, navegar a la página 2 (lienzo en blanco),
   dibujar en la página 2 y volver a la página 1 produce payloads
   `PKDrawing` byte a byte idénticos en ambas páginas, ambos
   persistidos en `PageAnnotation.drawingData`.
4. La preferencia horizontal / vertical (leída desde
   `DocumentItem.paginationModeRaw`) se conserva entre el cierre y la
   reapertura del documento.
5. `PencilCanvasOverlay` ignora los toques con el dedo; solo el Pencil
   dibuja (`drawingPolicy == .pencilOnly`).
6. La suite completa de XCTest se ejecuta en verde en un simulador de
   iPadOS con el dispositivo en modo avión (aceptación sin conexión).
7. Una búsqueda de las subcadenas bloqueadas listadas en
   `openspec/config.yaml` devuelve cero coincidencias en
   `InSummary/Services/PDFEngine/`,
   `InSummary/Services/AnnotationEngine/` e
   `InSummary/Views/Reader/`.

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| Deriva entre el `sample-bundle.pdf` empaquetado y la salida del generador en proceso | Un XCTest dedicado carga ambos, los hashea y hace fallar la suite ante cualquier deriva. La fase de compilación regenera el archivo cuando cambia el código del generador. |
| Las notificaciones de cambio de página de `PDFView` se disparan en renderizados en segundo plano | `PDFPageChangeObserver` aplica coalescencia por valor sobre `currentPageIndex`; las pruebas verifican el contrato de guardado/carga, no la temporización. Sin `Task.sleep`, sin `DispatchQueue.main.asyncAfter`, sin temporizador. |
| Rechazo del decodificador de los bytes de `PKDrawing` almacenados | `AnnotationError.drawingDecodeFailed` muestra un error recuperable; el `drawingData` ilegible queda intacto y el lienzo se renderiza vacío. |
| Tamaño del lector en un iPad real | Fuera de alcance para v1; la invariante de solo iPad mantiene la matriz pequeña. El fixture de 20 páginas es la cota. |
| Filtración de los artefactos del intento previo fallido a esta recuperación | La rama rastreadora de recuperación se creó en la fusión de la Fase 1 (`94b0f0c`). Los archivos de planificación no rastreados del intento previo se han eliminado de este worktree. No se referencia ningún código ni fixture del intento previo. |

## Entrega

Este es el **PR rastreador**. Solo contiene artefactos de planificación
— sin código de producción ni binario de fixture. La implementación
llega a través de cuatro PR hijos, cada uno ≤ 400 líneas modificadas,
empujados sobre una rama `feat/<slice-id>` a partir de la rama del
predecesor inmediato (o, solo para el PR #1, a partir de la rama
rastreadora):

| # | Rama | Rebanada | Rama destino | Líneas pronosticadas |
| - | --- | --- | --- | --- |
| 1 | `feat/pdf-fixture` | PDF de 20 páginas CC0, determinista y autoral del proyecto + fase de compilación + archivo de licencia + pruebas del fixture | `tracker/pdf-reader-pencilkit-ink-recovery` | ~ 150 |
| 2 | `feat/pdf-engine` | `PDFReaderCoordinator` + `PDFReaderError` + pruebas del coordinador, sin capa de UI | Rama del PR #1 | ~ 280 |
| 3 | `feat/pencilkit-ink-overlay` | `PencilCanvasOverlay` + `PDFPageChangeObserver` + `AnnotationError` + pruebas de capa y observador | Rama del PR #2 | ~ 320 |
| 4 | `feat/pdf-reader-wiring` | `ReaderContainerView` + `PDFViewRepresentable` + navegación desde `LibraryGridView` + pruebas de integración | Rama del PR #3 | ~ 240 |

**Regla de topología (estricta):** cada PR hijo posterior al #1
apunta a la rama de su predecesor inmediato. Solo el PR #1 apunta al
rastreador. Solo el rastreador se fusiona en `main`. Sin
bifurcación, sin abanico, sin PR hijo apuntando al rastreador excepto
el PR #1.

El PR rastreador permanece en estado **borrador / sin fusión** hasta
que todos los PR hijos se hayan fusionado en verde. Solo entonces se
rebasa el rastreador sobre `main` y se fusiona.

## Confirmación

- [x] La propuesta se enmarca contra `specification.md` §6 Fase 2.
- [x] No se referencia ni se reutiliza código del intento previo
      bloqueado.
- [x] `DocumentItem.paginationModeRaw` se trata como una invariante de
      la Fase 1 — no se añade, no se altera, no se migra, no se
      cambia su valor por defecto.
- [x] `PageAnnotation.drawingData` se reutiliza como almacén de tinta
      por página — no se introduce ningún almacén paralelo en
      archivos.
- [x] La ruta del fixture es exactamente
      `InSummary/Resources/Fixtures/sample-bundle.pdf` en todos los
      artefactos, pruebas, fases de compilación y descripciones de PR.
- [x] La cadena de PRs es estrictamente lineal
      (`tracker ← #1 ← #2 ← #3 ← #4`).
- [x] No se proponen `iCloud`, `CloudKit`, `CKAsset`,
      `NSPersistentCloudKitContainer`, `URLSession`, `NWConnection`,
      `.fileImporter`, `UIDocumentPickerViewController` ni
      `PHPickerViewController` en código de producto.
- [x] El bundle es solo local; solo `PDFKit`, `PencilKit`,
      `SwiftData`, `SwiftUI` y `UIKit` se importan en el código
      nuevo.
