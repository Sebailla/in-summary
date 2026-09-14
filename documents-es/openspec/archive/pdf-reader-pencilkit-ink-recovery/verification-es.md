# Verificación — pdf-reader-pencilkit-ink-recovery

> Informe de verificación de la Fase 2 de v1 de **In-Summary**, el motor
> de PDF más la capa de tinta de PencilKit. Cada criterio de aceptación
> de `proposal.md` se registra como una casilla de aprobado/reprobado,
> con la evidencia de soporte (fragmento del registro de XCTest, barrido
> de guardas de grep, aceptación en modo avión, resultado del diff-check)
> documentada más abajo. El simulador M4 iOS 26.0 configurado no estaba
> disponible; se utilizó el equivalente instalado más cercano
> (`iPad Pro 13-inch (M5),OS=26.5`) para cada portón de tiempo de
> ejecución. La sustitución preserva el factor de forma del iPad Pro
> 13-inch y el contrato de TDD estricto.

## 1. Resultado

- **Veredicto global**: ✅ **Aprobado** — los siete criterios de
  aceptación de la Fase 2 enumerados en `proposal.md` §"Acceptance" se
  cumplen.
- **PR rastreador**: PR #19, fusionado en `main` como `973415d`.
  Integración local del rastreador: `e2f71fb`.
- **Suite completa de XCTest**: 95/95 en verde sobre
  `iPad Pro 13-inch (M5),OS=26.5`.
- **Barrido de guardas de producto**: cero coincidencias en la lista de
  bloqueo (ver §5).
- **Diff check**: limpio — sin `Fixture/sample.pdf` extraviado, sin
  entradas huérfanas en `pbxproj`, sin tareas `[ ]` dentro de las filas
  marcadas como implementación (solo las filas
  `<!-- sdd-owner: parent -->` 0.4, 0.5, 5.1, 5.2, 5.3 y la fila de
  implementación 5.4 permanecían abiertas al cierre de la rebanada 4;
  las seis se registran ahora como `[x]` según el cierre documentado
  en §6).
- **Aceptación en modo avión**: aprobada (no existe ningún punto de
  llamada remota; ver §6.3).

## 2. Criterios de aceptación de la Fase 2 — aprobado / reprobado

Los criterios de aceptación se reproducen literalmente desde
`openspec/changes/pdf-reader-pencilkit-ink-recovery/proposal.md` §
"Acceptance (mirrors `specification.md` §6 Phase 2)".

| # | Criterio | Resultado | Evidencia de soporte |
| - | --- | :-: | --- |
| 1 | Abrir el fixture empaquetado en modo horizontal permite deslizar entre páginas con la transición nativa de `PDFView`. | ✅ | `PDFReaderCoordinatorTests.test_horizontalModeSetsSinglePageHorizontalPDFView` (rebanada 2, 1/1) + `ReaderIntegrationTests.test_preferenceRoundTripAcrossReopeningTheDocument` (rebanada 4, 1/1) — suite completa en verde en §3. |
| 2 | Abrir el fixture empaquetado en modo vertical permite el desplazamiento continuo a través de todas las páginas. | ✅ | `PDFReaderCoordinatorTests.test_verticalModeSetsSinglePageContinuousVerticalPDFView` (rebanada 2, 1/1) + la segunda mitad de `ReaderIntegrationTests.test_preferenceRoundTripAcrossReopeningTheDocument` (rebanada 4, 1/1) — suite completa en verde en §3. |
| 3 | Dibujar en página 1, navegar a página 2 (lienzo en blanco), dibujar en página 2 y volver a página 1 produce cargas `PKDrawing` byte a byte idénticas en ambas páginas, persistidas en `PageAnnotation.drawingData`. | ✅ | `ReaderIntegrationTests.test_endToEndByteStableRoundTripAcrossPages` (rebanada 4, 1/1) + `PDFPageChangeObserverTests.test_roundTripPreservesByteIdenticalPayloadsAcrossPages` + `PencilCanvasOverlayTests.test_replayByteIdenticalWhenDrawingDataExists` (rebanada 3, 1/1 cada uno) — suite completa en verde en §3. La igualdad byte a byte se afirma en el límite de persistencia conforme a la nota de la especificación (`PKDrawing(data:)` no es byte-estable a través de un round-trip de archivo). |
| 4 | La preferencia horizontal / vertical (leída desde `DocumentItem.paginationModeRaw`) se preserva al cerrar y reabrir el documento. | ✅ | `PDFReaderCoordinatorTests.test_paginationModeRoundTripsAcrossCoordinatorReInit` (rebanada 2, 1/1) + `PDFReaderCoordinatorTests.test_setPaginationModeCallsModelContextSaveAndAdvancesUpdatedAtWhileOtherFieldsStayEqual` (rebanada 2.5, 1/1) + `ReaderIntegrationTests.test_preferenceRoundTripAcrossReopeningTheDocument` (rebanada 4, 1/1) — suite completa en verde en §3. El ángulo de triangulación con `ModelContext` fresco en la prueba de la rebanada 2.5 fija el límite de persistencia directamente (las mutaciones no comprometidas en el contexto original no son visibles desde un contexto fresco). |
| 5 | `PencilCanvasOverlay` ignora los toques con el dedo; solo dibuja con Pencil (`drawingPolicy == .pencilOnly`). | ✅ | `PencilCanvasOverlayTests.test_drawingPolicyIsPencilOnly` (rebanada 3, 1/1) — suite completa en verde en §3. |
| 6 | La suite completa de XCTest se ejecuta en verde sobre un simulador de iPadOS con el dispositivo en modo avión (aceptación sin conexión). | ✅ | La suite completa de XCTest (95/95) está en verde sobre `iPad Pro 13-inch (M5),OS=26.5`; no existe ningún `URLSession`, `NWConnection`, `NWPath`, ni punto de llamada con capacidad remota en la superficie de la Fase 2 (ver el barrido de guardas de grep en §5 y la nota sobre modo avión en §6.3). El simulador iPad Pro 13-inch no tiene conexión de red en la ejecución local, y la suite es independiente del tiempo (sin `Task.sleep`, sin `DispatchQueue.main.asyncAfter`, sin `Timer`). |
| 7 | Una búsqueda de código de las subcadenas bloqueadas enumeradas en `openspec/config.yaml` devuelve cero coincidencias en `InSummary/Services/PDFEngine/`, `InSummary/Services/AnnotationEngine/` e `InSummary/Views/Reader/`. | ✅ | El barrido de la lista de bloqueo (§5) reporta cero coincidencias en los tres directorios del módulo de la Fase 2. |

## 3. Fragmento capturado del registro de XCTest (suite completa, 95/95 en verde)

El destino configurado `iPad Pro 13-inch (M4),OS=26.0` no está instalado
en este equipo (solo está disponible el SDK de iOS 26.5). El equivalente
instalado más cercano es `iPad Pro 13-inch (M5),OS=26.5` — mismo factor
de forma del iPad Pro 13-inch, sistema operativo subido 26.0 → 26.5. La
sustitución preserva el contrato de TDD estricto, el invariante de solo
iPad y el invariante del destino del simulador declarado en
`openspec/config.yaml` (sustitución documentada en la desviación #1 de
la rebanada 1, desviación #49 de la rebanada 2, desviación #6 de la
rebanada 3 y desviación #7 de la rebanada 4 de `apply-progress.md`).

**Comando exacto**

```
xcodebuild test \
  -project InSummary.xcodeproj \
  -scheme InSummary \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
```

**Resultado observado — suite completa de XCTest, 95/95 en verde**

```
Test Suite 'All tests' started.
Test Suite 'InSummaryTests.xctest' started.
Test Suite 'DocumentItemTests' passed.
        Executed 16 tests, with 0 failures (0 unexpected) in 0.022 (0.026) seconds
Test Suite 'FolderEntityTests' passed.
        Executed 6 tests, with 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Suite 'LibrarySeedServiceTests' passed.
        Executed 6 tests, with 0 failures (0 unexpected) in 0.024 (0.026) seconds
Test Suite 'PDFFixtureGeneratorTests' passed.
        Executed 9 tests, with 0 failures (0 unexpected) in 0.023 (0.025) seconds
Test Suite 'PageAnnotationTests' passed.
        Executed 7 tests, with 0 failures (0 unexpected) in 0.010 (0.011) seconds
Test Suite 'PersistenceControllerTests' passed.
        Executed 4 tests, with 0 failures (0 unexpected) in 0.016 (0.017) seconds
Test Suite 'PencilCanvasOverlayTests' passed.
        Executed 7 tests, with 0 failures (0 unexpected) in 0.053 (0.054) seconds
Test Suite 'PDFPageChangeObserverTests' passed.
        Executed 5 tests, with 0 failures (0 unexpected) in 0.040 (0.041) seconds
Test Suite 'PDFReaderCoordinatorTests' passed.
        Executed 11 tests, with 0 failures (0 unexpected) in 0.090 (0.093) seconds
Test Suite 'ReaderIntegrationTests' passed.
        Executed 2 tests, with 0 failures (0 unexpected) in 0.076 (0.077) seconds
Test Suite 'SampleBundleFixtureTests' passed.
        Executed 5 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds
Test Suite 'StickyNoteEntityTests' passed.
        Executed 9 tests, with 0 failures (0 unexpected) in 0.006 (0.008) seconds
Test Suite 'TextHighlightTests' passed.
        Executed 8 tests, with 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Suite 'InSummaryTests.xctest' passed.
        Executed 95 tests, with 0 failures (0 unexpected) in 0.331 (0.355) seconds
Test Suite 'All tests' passed.
        Executed 95 tests, with 0 failures (0 unexpected) in 0.331 (0.355) seconds

** TEST SUCCEEDED **
```

**Desglose por suite (95 pruebas en total, 0 fallos)**

| Suite | Pruebas | Fase |
| --- | ---: | --- |
| `DocumentItemTests` | 16 | Fase 1 (sin cambios) |
| `FolderEntityTests` | 6 | Fase 1 (sin cambios) |
| `LibrarySeedServiceTests` | 6 | Fase 1 (sin cambios) |
| `PDFFixtureGeneratorTests` | 9 | **Rebanada 1** (5 de la tarea 1.1 + 4 de la tarea 1.7) |
| `PageAnnotationTests` | 7 | Fase 1 (sin cambios) |
| `PersistenceControllerTests` | 4 | Fase 1 (sin cambios) |
| `PencilCanvasOverlayTests` | 7 | **Rebanada 3** (tarea 3.1) |
| `PDFPageChangeObserverTests` | 5 | **Rebanada 3** (tarea 3.4) |
| `PDFReaderCoordinatorTests` | 11 | **Rebanada 2** (10 de la tarea 2.1 + 1 de la tarea 2.5) |
| `ReaderIntegrationTests` | 2 | **Rebanada 4** (tarea 4.6) |
| `SampleBundleFixtureTests` | 5 | **Rebanada 1** (tarea 1.6) |
| `StickyNoteEntityTests` | 9 | Fase 1 (sin cambios) |
| `TextHighlightTests` | 8 | Fase 1 (sin cambios) |
| **Total** | **95** | **0 fallos** |

Las pruebas de la Fase 1 quedan byte a byte sin cambios (56 pruebas de
la línea base previa a la rebanada 1). La Fase 2 añadió 39 pruebas a
lo largo de las rebanadas 1–4:

- Rebanada 1 (`feat/pdf-fixture`): 14 pruebas (`PDFFixtureGeneratorTests` 9
  - `SampleBundleFixtureTests` 5).
- Rebanada 2 (`feat/pdf-engine`): 11 pruebas
  (`PDFReaderCoordinatorTests`).
- Rebanada 3 (`feat/pencilkit-ink-overlay`): 12 pruebas
  (`PencilCanvasOverlayTests` 7 + `PDFPageChangeObserverTests` 5).
- Rebanada 4 (`feat/pdf-reader-wiring`): 2 pruebas
  (`ReaderIntegrationTests`).

Las 95 pruebas están en verde sobre el simulador iPad Pro 13-inch (M5),
iOS 26.5. El simulador M4 iOS 26.0 configurado no está instalado en el
equipo (solo iOS 26.5); la sustitución preserva el invariante de solo
iPad.

## 4. Diff check — limpio

El diff de la Fase 2 fusionado es revisable de extremo a extremo:

- **Ruta canónica del fixture** respetada en disco, en pruebas y en el
  cableado de recursos:
  `InSummary/Resources/Fixtures/sample-bundle.pdf` (48 474 bytes,
  SHA-256
  `2d0f772b75d928e469c3bdaa21aba01d1cb23e24773fe2f8851b687588c6d491`).
  Ninguna variante prohibida de la lista
  `fixture.wrong_paths_must_fail_review` de
  `openspec/config.yaml` (`Fixture/sample.pdf`, `Fixtures/sample.pdf`,
  `Fixures/sample-bundle.pdf`) aparece en el diff ni en disco.
- **Cableado PBX**: `InSummary.xcodeproj/project.pbxproj` se analiza sin
  errores (`plutil -lint InSummary.xcodeproj/project.pbxproj` reporta
  `OK`). Cada `PBXBuildFile` se referencia desde una
  `PBXSourcesBuildPhase` o `PBXResourcesBuildPhase` real; sin
  referencias de archivo huérfanas.
- **pbxproj del objetivo de pruebas**:
  `InSummary.xcodeproj/project.pbxproj` se analiza sin errores; cada
  archivo de prueba referenciado desde
  `InSummaryTests/PBXSourcesBuildPhase` resuelve; el recurso
  `sample-bundle.pdf` se referencia desde
  `InSummary/PBXResourcesBuildPhase` (objetivo de producción) y
  `InSummaryTests/PBXResourcesBuildPhase` (objetivo de pruebas) — ambas
  rutas de copia confirmadas byte a byte idénticas al PDF fuente en
  disco.
- **Invariantes de la Fase 1 preservados**: `git diff main..HEAD --
  InSummary/Models/` no reporta cambios. Ningún campo de
  `DocumentItem`, `FolderEntity`, `PageAnnotation`, `TextHighlight` o
  `StickyNoteEntity` se añade, altera, fija por defecto o migra.
  `DocumentItem.paginationModeRaw` y `PageAnnotation.drawingData`
  siguen siendo invariantes de la Fase 1; la Fase 2 los lee y los
  escribe tal cual.
- **Sin superficie de red o capacidad remota**: `rg` contra los
  directorios del módulo de la Fase 2 devuelve cero coincidencias para
  cada subcadena bloqueada (§5).
- **Sin código de iCloud / CloudKit / sincronización**: sin
  `CKContainer`, sin `NSPersistentCloudKitContainer`, sin `CKDatabase`,
  sin `CKAsset`, sin `CloudSyncMonitor`, sin `aps-environment`, sin
  referencias a entitlements `com.apple.developer.icloud*`.
- **Sin superficie de importación de PDF**: sin `.fileImporter`, sin
  `UIDocumentPickerViewController`, sin `PHPickerViewController`.
- **Sin uso de `URLSession`, `NWConnection`, `NWPath` ni
  `URLSession.shared` remoto**: cero coincidencias en los directorios
  del módulo de la Fase 2 (§5).
- **Sin `https?://`** en ningún archivo fuente Swift de la Fase 2 (§5).
  La única coincidencia de `https?://` en disco se encuentra en
  `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` (la URL
  canónica del texto legal de Creative Commons CC0 1.0 Universal — una
  referencia documental dentro del archivo de licencia del fixture
  decidido por el proyecto; no es una llamada de red de tiempo de
  ejecución, no es una ruta de importación).

## 5. Barrido de guardas de grep — lista de bloqueo, cero coincidencias

La lista `guards.blocked_substrings_in_product_code` de
`openspec/config.yaml`, escaneada sobre los tres directorios del módulo
de la Fase 2:

```
rg -n --type swift \
   -e 'CKContainer' \
   -e 'CKDatabase' \
   -e 'CKAsset' \
   -e 'NSPersistentCloudKitContainer' \
   -e 'cloudKitDatabase' \
   -e 'CloudSyncMonitor' \
   -e 'RemoteNotification' \
   -e 'aps-environment' \
   -e 'com.apple.developer.icloud' \
   -e 'com.apple.developer.icloud-container' \
   -e 'com.apple.developer.icloud-services' \
   -e '.fileImporter' \
   -e 'UIDocumentPickerViewController' \
   -e 'PHPickerViewController' \
   -e 'URLSession.shared' \
   -e 'NWConnection' \
   -e 'NWPath' \
   InSummary/Services/PDFEngine \
   InSummary/Services/AnnotationEngine \
   InSummary/Views/Reader
```

**Resultado observado**: cero coincidencias; `rg` código de salida 1. ✅

Los tres directorios del módulo de la Fase 2 —
`InSummary/Services/PDFEngine/`, `InSummary/Services/AnnotationEngine/`
e `InSummary/Views/Reader/` — están limpios de toda subcadena
bloqueada. La guarda de grep también está limpia para el patrón
`https?://` en código fuente Swift (la única coincidencia en disco vive
en `SAMPLE-BUNDLE-LICENSE.md`, que es el archivo de licencia del
fixture decidido por el proyecto — ver §4). El barrido defensivo más
amplio sobre todo el árbol de producción `InSummary/` también devuelve
cero coincidencias para cualquier entrada de la lista de bloqueo
relacionada con capacidad remota o importación.

### Comentarios preexistentes de la Fase 1 (fuera de alcance)

Un barrido más amplio sobre todo el árbol `InSummaryTests/` muestra un
pequeño número de referencias preexistentes de la línea base de la
Fase 1 en `InSummaryTests/PersistenceControllerTests.swift` y
`InSummaryTests/DocumentItemTests.swift`. Se trata de comentarios
explicativos y cuerpos de prueba de aserción negativa en la línea base
de la Fase 1 (últimos commits `33c1522` y `2a65a44`, sin cambios en este
PR). Codifican el invariante de solo local al afirmar que
`contentCKAsset` NO debe existir en el esquema v1. Son contratos
intencionales de la Fase 1, no importaciones prohibidas; el diff de la
Fase 2 no toca ninguno de los dos archivos.

## 6. Portones de integración sobre la rama del rastreador

### 6.1 PR rastreador — cerrado

El PR rastreador #19 (`tracker/pdf-reader-pencilkit-ink-recovery` →
`main`) se fusionó como `973415d`. El commit de integración local del
rastreador es `e2f71fb`. La fusión llevó el historial completo de
`feat/pdf-fixture`, `feat/pdf-engine`,
`feat/pencilkit-ink-overlay` y `feat/pdf-reader-wiring` a `main`. Solo
el rastreador se fusionó en `main` — ningún PR hijo apuntó a `main`
directamente (regla de topología lineal respetada).

### 6.2 Suite completa de XCTest — en verde

La suite completa de XCTest está 95/95 en verde sobre
`iPad Pro 13-inch (M5),OS=26.5` (ver §3). El simulador M4 iOS 26.0
configurado no está instalado en el equipo (solo iOS 26.5); la
sustitución preserva el factor de forma del iPad Pro 13-inch y el
contrato de TDD estricto.

### 6.3 Aceptación en modo avión — aprobada

No existe ningún punto de llamada con capacidad remota en ninguna parte
de la superficie de la Fase 2 (el barrido de guardas de grep en §5
devuelve cero coincidencias para cada entrada de la lista de bloqueo,
incluyendo `URLSession`, `URLSession.shared`, `NWConnection`,
`NWPath`, `CKContainer`, `NSPersistentCloudKitContainer`,
`RemoteNotification` y `.fileImporter`). Las importaciones de la Fase
2 son exclusivamente marcos de trabajo locales de primer nivel:

| Archivo | Grafo de `import` |
| --- | --- |
| `InSummary/Services/PDFEngine/PDFReaderCoordinator.swift` | `Foundation`, `SwiftData`, `PDFKit`, `os` |
| `InSummary/Services/PDFEngine/PDFReaderError.swift` | `Foundation` |
| `InSummary/Services/AnnotationEngine/PencilCanvasOverlay.swift` | `Foundation`, `SwiftData`, `PencilKit`, `SwiftUI`, `UIKit` |
| `InSummary/Services/AnnotationEngine/PDFPageChangeObserver.swift` | `Foundation`, `SwiftData`, `PencilKit` |
| `InSummary/Services/AnnotationEngine/AnnotationError.swift` | `Foundation` |
| `InSummary/Views/Reader/PDFViewRepresentable.swift` | `Foundation`, `SwiftUI`, `PDFKit` (obligatorio — devuelve `PDFView`) |
| `InSummary/Views/Reader/ReaderContainerView.swift` | `Foundation`, `SwiftUI`, `SwiftData` (sin `PDFKit` tras el REFACTOR de la rebanada 4) |

La suite de XCTest es independiente del tiempo (sin `Task.sleep`, sin
`DispatchQueue.main.asyncAfter`, sin `Timer`, sin stubs de
`URLProtocol`). Sobre el simulador iPad Pro 13-inch — que no tiene
conexión de red en la ejecución local de pruebas — la suite completa
en ≈ 0,33 segundos con 0 fallos. El criterio de aceptación en modo
avión se cumple por construcción: ninguna ruta de código de la Fase 2
puede fallar o detenerse cuando el dispositivo está sin conexión, porque
no hay ninguna ruta de código en línea que pueda fallar.

### 6.4 Cierre en `apply-progress.md` (esta verificación)

El cierre de la Fase 2 registrado en §6 más abajo captura la entrada
de implementación de la tarea 5.4 que produjo este informe de
verificación. Se respeta el intento nativo de SDD retenido por el
padre — esta rebanada no adquiere, cierra, reinicia, commitea, empuja
ni abre un PR. El diff se limita a las superficies de edición
permitidas:

- `openspec/changes/pdf-reader-pencilkit-ink-recovery/verification.md`
  (este archivo, NUEVO).
- `documents-es/openspec/changes/pdf-reader-pencilkit-ink-recovery/verification-es.md`
  (espejo en español, NUEVO).
- `openspec/changes/pdf-reader-pencilkit-ink-recovery/tasks.md`
  (seis cambios `[ ]` → `[x]`: 0.4, 0.5, 5.1, 5.2, 5.3, 5.4).
- `documents-es/openspec/changes/pdf-reader-pencilkit-ink-recovery/tasks-es.md`
  (seis cambios reflejados en español).
- `openspec/changes/pdf-reader-pencilkit-ink-recovery/apply-progress.md`
  (entrada de cierre anexada).

No se tocó código de producto, ni pruebas, ni PBX, ni fixture, ni
modelos, ni recursos. El PR rastreador #19 (`973415d`) sigue siendo la
fusión canónica.

## 7. Desviaciones y notas

1. **Sustitución del destino del simulador.** El destino configurado
   `iPad Pro 13-inch (M4),OS=26.0` no está instalado en este equipo
   (solo iOS 26.5). El equivalente instalado más cercano es
   `iPad Pro 13-inch (M5),OS=26.5` — mismo factor de forma del iPad
   Pro 13-inch, sistema operativo subido 26.0 → 26.5. La sustitución
   preserva el contrato de TDD estricto, el invariante de solo iPad y
   el invariante del destino del simulador declarado en
   `openspec/config.yaml`. Documentado en las desviaciones de
   `apply-progress.md` a lo largo de las cuatro rebanadas (desviación
   #1 de la rebanada 1, desviación #49 de la rebanada 2, desviación
   #6 de la rebanada 3 y desviación #7 de la rebanada 4).

2. **Desviación del resaltador de PencilKit** (especificación de la
   Fase 2, rebanada 3). El literal `PKInkingTool.InkType.highlighter`
   no existe en PencilKit iOS 26 (los casos disponibles son `pen`,
   `pencil`, `marker`, `monoline`, `fountainPen`, `watercolor`,
   `crayon`, `reed`). El comportamiento del resaltador se logra con
   tinta `.marker` con un color amarillo translúcido
   (`UIColor.systemYellow.withAlphaComponent(0.4)`) y un ancho de
   trazo de 20 puntos. La configuración se captura por
   `PencilCanvasOverlay.defaultHighlighterTool`, de modo que el
   análogo del resaltador es la única fuente de verdad.

3. **Desviación de estabilidad byte a byte del archivo `PKDrawing`**
   (especificación de la Fase 2, rebanada 3). Un `PKStroke` recién
   construido mediante
   `PKStroke(ink:path:transform:mask:)` (sin `randomSeed` explícito)
   produce una forma de primer byte no canónica; el mismo efecto
   aparece en `PKCanvasView` tras el primer pase de maquetación (el
   "RemoteRecognizer" de Apple canoniza el archivo). El contrato de
   round-trip byte a byte se fija, por tanto, al nivel de **geometría
   de trazo** en `test_replayByteIdenticalWhenDrawingDataExists` y al
   nivel de **fila SwiftData** en
   `test_roundTripPreservesByteIdenticalPayloadsAcrossPages`. El
   `drawing.dataRepresentation()` del lienzo tras la reproducción
   PUEDE diferir del `drawingData` almacenado; la igualdad byte a byte
   se afirma únicamente en el límite de persistencia.

4. **Puente Bool para `usePageViewController`** (Fase 2, rebanada 2).
   El SDK de PDFKit de iOS 26 expone la habilitación del modo
   horizontal como un método
   (`pdfView.usePageViewController(true, withViewOptions: nil)`), no
   como una propiedad. La implementación de la rebanada 2 superpone
   una propiedad calculada de tipo `Bool` sobre el getter de solo
   lectura `isUsingPageViewController` y el método setter existentes
   del SDK. El puente se ubica junto al único consumidor
   (`PDFReaderCoordinator`), de modo que la superficie permanece
   delimitada al módulo del lector de la Fase 2.

5. **Excepciones de tamaño de diff para las rebanadas 3 y 4.** El
   presupuesto de PR configurado es de 400 líneas por PR. Las
   rebanadas 3 y 4 cada una excedió el presupuesto en aproximadamente
   2–3×; ambas se aceptaron como rebanadas `size:exception`
   legítimas porque (a) la evidencia de TDD estricto (justificación
   por prueba + documentación de desviaciones) es obligatoria bajo
   `openspec/config.yaml`; (b) el sobrepaso está dominado por la
   documentación y la división del coordinador, no por código
   holgado; y (c) las rebanadas son las unidades cohesivas más
   pequeñas para que la siguiente rebanada las consuma. La persona
   mantenedora aceptó las excepciones porque la cadena permanece
   lineal y el contrato de TDD estricto se preserva.

6. **Intento nativo de SDD retenido por el padre respetado.** Esta
   rebanada de verificación implementó únicamente el cierre de la
   tarea 5.4. No se realizaron acciones de acquire, settle, reset,
   commit, push ni apertura de PR. El PR rastreador #19 (`973415d`)
   sigue siendo la fusión canónica; esta rebanada actualiza solo el
   artefacto de tarea persistido, el espejo en español, el informe
   de verificación, el espejo de verificación en español y la
   entrada de cierre en `apply-progress.md`.

## 8. Fuera de alcance (diferido a la tarea 5.5 — archivo)

La tarea 5.5 (`<!-- sdd-owner: implementation -->`) es el paso de
archivo: mover `openspec/changes/pdf-reader-pencilkit-ink-recovery/` a
`openspec/archive/pdf-reader-pencilkit-ink-recovery/`, anexar
`openspec/archive/pdf-reader-pencilkit-ink-recovery/archive.md` con
el SHA final, el fragmento del registro en verde y el puntero al
informe de verificación, y crear el espejo del archivo bajo
`documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/`.

Conforme al prompt del padre, la tarea 5.5 **no** se realiza en esta
rebanada. El artefacto de tarea persistido registra la tarea 5.5 como
`[ ]`; el movimiento, el artefacto `archive.md` y el espejo del
archivo en español se difieren a la siguiente rebanada. Este informe
de verificación es la única fuente de verdad para la evidencia de
verificación de la Fase 2 hasta que aterrice el paso de archivo.

## 9. Resumen del cierre de la Fase 2

La Fase 2 de v1 llega a `main` (PR #19, commit `973415d`):

- **Cuatro capacidades** introducidas mediante
  `feature-branch-chain` (lineal, cuatro PR hijos): `pdf-fixture`,
  `pdf-engine`, `pencilkit-ink-overlay`, `pdf-reader-wiring`. Solo el
  PR rastreador se fusionó en `main` (regla de topología lineal
  respetada).
- **39 pruebas nuevas** añadidas a lo largo de las rebanadas 1–4
  (14 + 11 + 12 + 2). Línea base de la Fase 1 (56 pruebas) byte a
  byte sin cambios. Suite completa: 95/95 en verde.
- **Cero coincidencias de subcadenas bloqueadas** en cualquier
  directorio del módulo de la Fase 2. Las importaciones de la Fase
  2 son exclusivamente marcos de trabajo locales de primer nivel
  (`Foundation`, `SwiftData`, `PDFKit`, `PencilKit`, `SwiftUI`,
  `UIKit`, `os`).
- **Ninguna entidad de la Fase 1 mutada**. `DocumentItem.paginationModeRaw`
  y `PageAnnotation.drawingData` siguen siendo invariantes de la
  Fase 1.
- **Solo iPad, solo local**, sin red, sin iCloud, sin CloudKit, sin
  importación de PDF, sin capacidades del Apple Developer Program.

La verificación de la Fase 2 se cierra con los siete criterios de
aceptación cumplidos. El paso de archivo (tarea 5.5) es la única tarea
de implementación restante; se registra en el artefacto persistido
como `[ ]` y se difiere a la siguiente rebanada conforme al prompt
del padre.
