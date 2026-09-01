# Tareas — pdf-reader-pencilkit-ink-recovery

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/tasks.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

> Lista de comprobación de TDD estricto. Las tareas se agrupan por
> PR hijo. Cada tarea que introduce un símbolo público añade también
> la XCTest que fija el comportamiento. Las tareas fuera de alcance
> se enumeran al final y **no** deben abordarse dentro de ningún PR
> de la Fase 2.
>
> Leyenda de estado: `[ ]` abierta · `[~]` en curso · `[x]` cerrada.

## Pronóstico de carga de revisión

| Campo | Valor |
| --- | --- |
| Líneas modificadas estimadas | ~990 en total a lo largo de cuatro PR hijos (sin binarios); PR más grande ≈ 320 líneas (PR #3) |
| Riesgo de presupuesto de 400 líneas | Bajo |
| PRs encadenados recomendados | Sí |
| Topología de la cadena | **Lineal** (`tracker ← #1 ← #2 ← #3 ← #4`) |
| Estrategia de entrega | feature-branch-chain (lineal) |
| Destino de fusión del rastreador | `main` (solo el rastreador se fusiona en `main`) |

Decisión necesaria antes de aplicar: **No** — la cadena está fijada
por `openspec/config.yaml` y por el preflight del orquestador.

## 0. PR rastreador (este cambio)

- [x] 0.1 Escribir `openspec/config.yaml` (con la topología lineal
      explícita y la ruta canónica del fixture) y
      `openspec/project-context.md`.
- [x] 0.2 Escribir `proposal.md`, `design.md`, `tasks.md` y las
      cuatro especificaciones de capacidad bajo
      `openspec/changes/pdf-reader-pencilkit-ink-recovery/`.
- [x] 0.3 Escribir los espejos en español bajo
      `documents-es/openspec/changes/pdf-reader-pencilkit-ink-recovery/`.
- [ ] 0.4 Abrir el PR rastreador como **borrador / sin fusión** con
      el diagrama de dependencia de la cadena.
- [ ] 0.5 Mantener el rastreador en estado borrador hasta que todos
      los PR hijos (#1–#4) se hayan fusionado en verde.
      <!-- sdd-owner: parent -->

## 1. PR hijo #1 — `feat/pdf-fixture` (destino: rastreador)

El fixture es una dependencia dura de cada prueba de la Fase 2 y se
aísla en su propio PR para que cada PR posterior pueda revisar el
comportamiento del lector sin ruido de fixture.

- [ ] 1.1 ROJO — añadir
      `InSummaryTests/Support/PDFFixtureGeneratorTests.swift`
      (junto al generador) cubriendo: dos llamadas consecutivas a
      `generateFixture() -> Data` producen bytes byte a byte
      idénticos; `PDFDocument(data:).pageCount == 20`; cada página se
      renderiza a una `UIImage` no vacía a 72 DPI; la constante
      canónica `fixtureContentHash` coincide con el SHA-256 de la
      salida. Ejecutar contra la línea base y confirmar que la suite
      está en rojo.
      <!-- sdd-owner: implementation -->
- [ ] 1.2 VERDE — añadir
      `InSummaryTests/Support/PDFFixtureGenerator.swift` exponiendo
      `generateFixture() -> Data`, `fixtureContentHash: String` y
      `fixturePageCount: Int`. El generador usa `PDFKit`
      (`UIGraphicsPDFRenderer` es aceptable; la API elegida debe ser
      determinista) para dibujar 20 páginas tamaño carta, cada una
      con el índice de página en la esquina inferior derecha, un
      patrón geométrico determinista y un bloque de texto CC0
      extraído de una constante congelada.
      <!-- sdd-owner: implementation -->
- [ ] 1.3 VERDE — añadir `InSummary/Resources/Fixtures/sample-bundle.pdf`
      (binario) ejecutando el generador localmente. La ruta exacta es
      canónica y no debe variar.
      <!-- sdd-owner: implementation -->
- [ ] 1.4 VERDE — añadir
      `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` con la
      dedicación CC0 1.0 Universal, el SHA-256 del generador, el
      conteo de páginas y una línea de "autoral del proyecto".
      <!-- sdd-owner: implementation -->
- [ ] 1.5 VERDE — cablear `InSummary/Resources/Fixtures/sample-bundle.pdf`
      en la fase *Copy Bundle Resources* de `InSummary.xcodeproj`
      sobre el objetivo `InSummary`. Confirmar que el archivo aparece
      en el bundle de salida de la compilación bajo la misma ruta
      relativa.
      <!-- sdd-owner: implementation -->
- [ ] 1.6 VERDE — añadir
      `InSummaryTests/Fixtures/SampleBundleFixtureTests.swift`
      afirmando: `Bundle.main.url(forResource: "sample-bundle",
      withExtension: "pdf")` resuelve y no es `nil`; el archivo no
      está vacío; el archivo pesa ≤ 1 MB; el SHA-256 de los bytes
      empaquetados coincide con el SHA-256 de la salida del generador
      en proceso; `PDFDocument(url:).pageCount == 20`. Ejecutar la
      suite y confirmar verde.
      <!-- sdd-owner: implementation -->
- [ ] 1.7 REFACTOR — colapsar la configuración duplicada del
      generador en un único helper privado; mantener el dibujo
      página por página en un único lugar; confirmar que dos
      ejecuciones consecutivas del generador siguen produciendo bytes
      byte a byte idénticos.
      <!-- sdd-owner: implementation -->
- [ ] 1.8 VERIFICAR — ejecutar las guardas de grep sobre el diff del
      PR y confirmar cero coincidencias para la lista de subcadenas
      bloqueadas (especialmente `NSPersistentCloudKitContainer`,
      `URLSession`, `.fileImporter`, `https?://`). Ejecutar
      `xcodebuild test -scheme InSummary -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=26.0'`
      y confirmar verde. Reversión: revertir el binario, el archivo
      de licencia, el generador, las pruebas y la entrada PBX de
      `Copy Bundle Resources` — ninguna otra rebanada toca estos
      archivos.
      <!-- sdd-owner: implementation -->

## 2. PR hijo #2 — `feat/pdf-engine` (destino: rama del PR #1)

`PDFReaderCoordinator` es independiente de PencilKit y se beneficia
de una revisión aislada. Apunta al PR #1 porque el fixture debe
existir antes de que el coordinador pueda ejecutar sus pruebas
red-first.

- [ ] 2.1 ROJO — añadir
      `InSummaryTests/PDFReaderCoordinatorTests.swift` cubriendo: el
      coordinador carga el fixture empaquetado; el modo horizontal
      fija `displayMode = .singlePage` + `displayDirection =
      .horizontal` + `usePageViewController(true)`; el modo vertical
      fija `displayMode = .singlePageContinuous` + `displayDirection =
      .vertical`; un `paginationModeRaw` desconocido cae al
      horizontal; el round-trip de `paginationModeRaw` preserva el
      valor a través de una re-inicialización del coordinador; el
      coordinador persiste solo `paginationModeRaw` + `updatedAt` en
      la fila SwiftData; un fixture ausente expone
      `PDFReaderError.fixtureMissing(resource:)`; un fixture
      ilegible expone `.fixtureUnreadable`; un documento que no es
      PDF expone `.unsupportedDocument(reason:)`; un documento con
      `localFileName` no vacío expone `.unsupportedDocument(reason:)`.
      Ejecutar contra la línea base y confirmar rojo.
      <!-- sdd-owner: implementation -->
- [ ] 2.2 VERDE — añadir
      `InSummary/Services/PDFEngine/PDFReaderError.swift` con errores
      tipados: `fixtureMissing(resource:)`, `fixtureUnreadable`,
      `unsupportedDocument(reason:)`, `paginationSaveFailed(underlying:)`.
      <!-- sdd-owner: implementation -->
- [ ] 2.3 VERDE — añadir
      `InSummary/Services/PDFEngine/PDFReaderCoordinator.swift`
      (`@MainActor`, sin `import PencilKit`, sin tipos modelo
      `SwiftData` públicos más allá de la referencia existente a
      `DocumentItem`) para poner en verde las pruebas nuevas.
      <!-- sdd-owner: implementation -->
- [ ] 2.4 VERDE — cablear los dos archivos nuevos en la fase
      *Sources* de `InSummary.xcodeproj` sobre el objetivo
      `InSummary`.
      <!-- sdd-owner: implementation -->
- [ ] 2.5 TRIANGULAR — añadir una prueba que afirme que
      `setPaginationMode` llama a `modelContext.save()` y que el
      `updatedAt` de la fila persistida avanza mientras cualquier
      otro campo permanece igual.
      <!-- sdd-owner: implementation -->
- [ ] 2.6 REFACTOR — mantener el coordinador libre de `PencilKit` y
      de cualquier import de modelo `SwiftData` más allá de
      `DocumentItem`; colapsar la búsqueda duplicada de la URL del
      fixture en un único helper privado.
      <!-- sdd-owner: implementation -->
- [ ] 2.7 VERIFICAR — ejecutar
      `xcodebuild test -scheme InSummary -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=26.0' -only-testing:InSummaryTests/PDFReaderCoordinatorTests`
      y confirmar verde. Ejecutar las guardas de grep acotadas a
      `InSummary/Services/PDFEngine/`:
      ```bash
      rg -n --type swift \
         -e 'NSPersistentCloudKitContainer' \
         -e 'CKContainer' \
         -e 'CKDatabase' \
         -e 'CKAsset' \
         -e 'cloudKitDatabase' \
         -e 'CloudSyncMonitor' \
         -e 'RemoteNotification' \
         -e '.fileImporter' \
         -e 'UIDocumentPickerViewController' \
         -e 'PHPickerViewController' \
         -e 'URLSession.shared' \
         -e 'NWConnection' \
         -e 'NWPath' \
         -e 'https?://' \
         InSummary/Services/PDFEngine
      ```
      Una sola coincidencia hace fallar la verificación. Reversión:
      eliminar los dos archivos fuente, la prueba y las entradas
      PBX de *Sources* — ninguna rebanada posterior los importa.
      <!-- sdd-owner: implementation -->

## 3. PR hijo #3 — `feat/pencilkit-ink-overlay` (destino: rama del PR #2)

La capa y el observador dependen de la señal de cambio de página del
coordinador (PR #2) y del fixture empaquetado (PR #1). Apuntan al
PR #2 para que la cadena permanezca lineal.

- [ ] 3.1 ROJO — añadir
      `InSummaryTests/PencilCanvasOverlayTests.swift` cubriendo:
      `drawingPolicy == .pencilOnly`; la herramienta predeterminada
      es el highlighter (`PKInkingTool.InkType.highlighter`); la
      reproducción es byte a byte cuando el `PageAnnotation`
      proporcionado tiene `drawingData` no vacío; un `PageAnnotation`
      ausente activa el lazy-upsert y la capa se renderiza en blanco;
      limpiar la capa persiste bytes vacíos; un fallo de decodificación
      fija `lastError = .drawingDecodeFailed`, renderiza la capa
      vacía y deja intacto el `drawingData` ilegible en la fila.
      Ejecutar contra la línea base y confirmar rojo.
      <!-- sdd-owner: implementation -->
- [ ] 3.2 VERDE — añadir
      `InSummary/Services/AnnotationEngine/AnnotationError.swift` con
      errores tipados: `drawingDecodeFailed`,
      `drawingPersistenceFailed(underlying:)`.
      <!-- sdd-owner: implementation -->
- [ ] 3.3 VERDE — añadir
      `InSummary/Services/AnnotationEngine/PencilCanvasOverlay.swift`
      (`UIViewRepresentable` envolviendo `PKCanvasView`, `@MainActor`,
      sin `import PDFKit`, sin imports públicos de modelo `SwiftData`
      más allá de la referencia existente a `PageAnnotation`) para
      poner en verde las pruebas nuevas.
      <!-- sdd-owner: implementation -->
- [ ] 3.4 ROJO — añadir
      `InSummaryTests/PDFPageChangeObserverTests.swift` cubriendo:
      el round-trip preserva payloads `PKDrawing` byte a byte entre
      páginas 1 → 2 → 1; cinco ciclos de navegación son estables; el
      observador descarta notificaciones cuyo `currentPageIndex`
      coincide con el último índice observado (coalescencia por
      valor); una re-inicialización del coordinador conserva los
      dibujos almacenados; un fallo de guardado expone
      `AnnotationError.drawingPersistenceFailed(underlying:)` y
      `lastObservedPageIndex` **no** se muta ante un fallo. Ejecutar
      contra la línea base y confirmar rojo.
      <!-- sdd-owner: implementation -->
- [ ] 3.5 VERDE — añadir
      `InSummary/Services/AnnotationEngine/PDFPageChangeObserver.swift`
      (`final class` `@MainActor`, sin `import PDFKit`, sin imports
      públicos de modelo `SwiftData` más allá de `DocumentItem.id` y
      del `PageAnnotation` proporcionado) para poner en verde las
      pruebas nuevas.
      <!-- sdd-owner: implementation -->
- [ ] 3.6 VERDE — cablear los tres archivos nuevos en la fase
      *Sources* de `InSummary.xcodeproj` sobre el objetivo
      `InSummary`.
      <!-- sdd-owner: implementation -->
- [ ] 3.7 REFACTOR — colapsar la configuración duplicada de la capa
      en un único helper privado; mantener la configuración de
      `PKCanvasView` en un único lugar; llevar la suscripción a
      `NotificationCenter` a la capa de vista (añadida en el PR #4)
      para que el observador siga siendo testeable de forma aislada.
      <!-- sdd-owner: implementation -->
- [ ] 3.8 VERIFICAR — ejecutar
      `xcodebuild test -scheme InSummary -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=26.0' -only-testing:InSummaryTests/PencilCanvasOverlayTests -only-testing:InSummaryTests/PDFPageChangeObserverTests`
      y confirmar verde. Reversión: eliminar los archivos fuente, el
      archivo de errores, las pruebas y las entradas PBX de *Sources*
      — la capa y el observador aún no se referencian fuera de su
      propio objetivo de pruebas.
      <!-- sdd-owner: implementation -->

## 4. PR hijo #4 — `feat/pdf-reader-wiring` (destino: rama del PR #3)

Esta rebanada cablea todo en la capa de librería existente. Depende
del PR #1 (fixture), del PR #2 (coordinador) y del PR #3 (capa +
observador). Apunta al PR #3 porque la cadena debe permanecer lineal
— es el PR hijo terminal antes del cierre del rastreador.

- [ ] 4.1 Añadir `InSummary/Views/Reader/PDFViewRepresentable.swift`
      (`UIViewRepresentable` alrededor de `PDFView`; entrega la
      referencia `pdfView` al coordinador tras `makeUIView`).
      <!-- sdd-owner: implementation -->
- [ ] 4.2 Añadir `InSummary/Views/Reader/ReaderContainerView.swift`
      (v1): capa SwiftUI que aloja
      `PDFViewRepresentable(coordinator:)` más un banner
      recuperable para `PDFReaderError`. **No** referenciar
      `PencilCanvasOverlay` ni `PDFPageChangeObserver` en la v1; se
      cablean en el paso 4.4.
      <!-- sdd-owner: implementation -->
- [ ] 4.3 Modificar `InSummary/Views/Library/LibraryGridView.swift`:
      la fila del `DocumentItem` semilla se convierte en un
      `NavigationLink` a `ReaderContainerView(document:)`; cualquier
      otra fila expone la alerta recuperable "no soportado en esta
      build". Mantener el cambio al archivo de la librería bajo
      ~30 líneas.
      <!-- sdd-owner: implementation -->
- [ ] 4.4 Extender `ReaderContainerView` (v2): añadir
      `PencilCanvasOverlay(pageIndex:, pageAnnotation:, modelContext:)`
      al cuerpo, añadir un banner para `AnnotationError`, construir
      `PDFPageChangeObserver` contra el `PDFView` en vivo y suscribir
      al publicador de cambio de página del coordinador mediante
      `.onReceive` para que cada evento enrute a
      `observer.handlePageChange(to:)`.
      <!-- sdd-owner: implementation -->
- [ ] 4.5 Añadir un `#Preview` a `ReaderContainerView.swift` que se
      monte sobre `PreviewContainer.previewContainer` y renderice dos
      páginas con tinta distinta para que la persona revisora pueda
      verificar el round-trip de forma visual.
      <!-- sdd-owner: implementation -->
- [ ] 4.6 ROJO — añadir `InSummaryTests/ReaderIntegrationTests.swift`
      cubriendo: abrir el fixture empaquetado, navegar entre páginas,
      dibujar en página 1 y página 2, volver a página 1 y afirmar
      que `PKDrawing.dataRepresentation()` se preserva byte a byte en
      ambas páginas; round-trip de preferencia a través de la
      reapertura del documento. Ejecutar contra la línea base y
      confirmar rojo.
      <!-- sdd-owner: implementation -->
- [ ] 4.7 VERDE — cablear los dos archivos nuevos en la fase
      *Sources* de `InSummary.xcodeproj` sobre el objetivo
      `InSummary`.
      <!-- sdd-owner: implementation -->
- [ ] 4.8 REFACTOR — confirmar que `ReaderContainerView.swift` (v2)
      compila sin `import PDFKit` (solo usa el coordinador y la
      capa); aislar el banner en una sub-vista pequeña.
      <!-- sdd-owner: implementation -->
- [ ] 4.9 VERIFICAR — ejecutar la suite completa de XCTest
      (`SampleBundleFixtureTests` + `PDFFixtureGeneratorTests` +
      `PDFReaderCoordinatorTests` + `PencilCanvasOverlayTests` +
      `PDFPageChangeObserverTests` + `ReaderIntegrationTests`) en el
      destino del simulador iPadOS y confirmar verde. El `#Preview`
      renderiza dos páginas con tinta distinta. Ejecutar las guardas
      de grep acotadas a `InSummary/Services/PDFEngine/`,
      `InSummary/Services/AnnotationEngine/` e
      `InSummary/Views/Reader/`; cero coincidencias requeridas.
      Reversión: revertir `ReaderContainerView.swift` a su estado v1,
      eliminar el `UIViewRepresentable` de `PDFView`, eliminar las
      pruebas de integración, retirar las entradas PBX de *Sources* —
      la rebanada 4 es el punto de integración y es totalmente
      removible.
      <!-- sdd-owner: implementation -->

## 5. Cierre del rastreador (tras fundirse los cuatro PR hijos en verde)

- [ ] 5.1 Rebasar (o hacer fast-forward) `tracker/pdf-reader-pencilkit-ink-recovery`
      sobre la cabeza de la rama del PR #4 para que el rastreador
      cargue cada hijo fusionado.
      <!-- sdd-owner: parent -->
- [ ] 5.2 Ejecutar los portones de integración sobre la rama del
      rastreador (suite completa de XCTest, guardas de grep sobre
      todo el árbol `InSummary/`, aceptación en modo avión) y
      confirmar verde antes de promover el PR rastreador fuera del
      estado borrador.
      <!-- sdd-owner: parent -->
- [ ] 5.3 Promover el PR rastreador de **borrador** → **listo** y
      fusionar `tracker/pdf-reader-pencilkit-ink-recovery` en `main`.
      **Solo el rastreador se fusiona en `main`; ningún PR hijo
      apunta a `main` directamente.**
      <!-- sdd-owner: parent -->
- [ ] 5.4 Autorizar `openspec/changes/pdf-reader-pencilkit-ink-recovery/verification.md`
      con casillas de aprobado/reprobado para cada criterio de
      aceptación de la Fase 2 del `proposal.md`, el fragmento del
      registro capturado, los resultados de grep y el resultado en
      modo avión.
      <!-- sdd-owner: implementation -->
- [ ] 5.5 Archivar el cambio: mover
      `openspec/changes/pdf-reader-pencilkit-ink-recovery/` a
      `openspec/archive/pdf-reader-pencilkit-ink-recovery/` y anexar
      `openspec/archive/pdf-reader-pencilkit-ink-recovery/archive.md`
      con el SHA final, el fragmento del registro en verde y el
      puntero al informe de verificación. Crear el espejo en
      `documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/`.
      <!-- sdd-owner: implementation -->

## Restricciones que carga cada tarea

- Solo iPad. Los destinos de iPhone / Mac Catalyst permanecen
  deshabilitados.
- Solo local. Sin red, sin iCloud, sin CloudKit, sin capacidades del
  Apple Developer Program.
- TDD estricto: red-first; las pruebas llegan con el código en la
  misma unidad de trabajo (rebanada); la única excepción es el
  esqueleto de la capa SwiftUI en el paso 4.2, que compila contra el
  coordinador existente del PR #2 y se verifica mediante la suite
  completa de XCTest en el paso 4.8.
- Sin cambios de esquema. `DocumentItem.paginationModeRaw` y
  `PageAnnotation.drawingData` son invariantes de la Fase 1. La Fase
  2 los lee y los escribe tal cual.
- La ruta del fixture es **exactamente**
  `InSummary/Resources/Fixtures/sample-bundle.pdf` (plural
  `Fixtures`, nombre con guion). Las rutas prohibidas
  (`Fixture/sample.pdf`, `Fixtures/sample.pdf`, o cualquier otra
  variante) se enumeran en `openspec/config.yaml` y deben hacer
  fallar la revisión si aparecen.
- Topología lineal. Cada PR hijo posterior al #1 apunta a la rama de
  su predecesor inmediato. Solo el PR #1 apunta al rastreador. Solo
  el rastreador se fusiona en `main`. Sin bifurcación, sin abanico.
- El presupuesto de revisión es **400 líneas** por PR. La skill
  `chained-pr` con la estrategia `feature-branch-chain` se aplica
  con **cuatro** PR hijos: `#1` → `#2` → `#3` → `#4`. Una rama de
  larga duración `tracker/pdf-reader-pencilkit-ink-recovery` lleva un
  PR en borrador/sin fusión apuntando a `main`. No agrupes
  implementación + verificación en el mismo PR si el diff excede el
  presupuesto, y no solicites `size:exception` — la división en
  cuatro PR mantiene cada PR bien por debajo de las 400 líneas
  modificadas.

## Fuera de alcance (no abordar dentro de ningún PR de la Fase 2)

- Resaltados semánticos (Fase 4).
- Notas adhesivas (Fase 4).
- Motor de EPUB, motor de Markdown (Fase 3).
- Importación, exportación, carpetas, añadidos a la librería (Fase 5).
- Multi-ventana, temas, pulido de accesibilidad (Fase 6).
- iCloud / CloudKit / `CKAsset` / monitor de sincronización /
  notificaciones push (aplazados para una fase futura; prohibidos
  por las guardas de la Fase 2 en `openspec/config.yaml`).
- Peticiones de red de cualquier tipo.
- Pruebas de snapshot (diferidas a la Fase 6 según la
  especificación).
- Añadir, alterar, fijar por defecto o migrar cualquier entidad de la
  Fase 1 (`DocumentItem`, `FolderEntity`, `PageAnnotation`,
  `TextHighlight`, `StickyNoteEntity`).
- Un almacén de tinta separado en archivos en disco. Se reutiliza
  directamente `PageAnnotation.drawingData`.
