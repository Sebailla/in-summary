# Diseño — pdf-reader-pencilkit-ink-recovery

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/design.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

> Decisiones técnicas para la Fase 2. Las decisiones se enuncian
> primero y se justifican después. Las referencias cruzadas a
> `specification.md` y al esquema canónico de la Fase 1 son explícitas
> para que las personas revisoras puedan confirmar la intención sin
> releer ninguna de las dos fuentes.

## 1. Composición del lector

El lector de PDF se compone de dos capas SwiftUI y dos motores
`@MainActor`:

```
LibraryGridView (Fase 1, lista para producción, modificada en el PR #4)
        └─► ReaderContainerView (PR #4 NUEVO, envuelve a PDFReaderCoordinator)
                ├─► PDFReaderCoordinator (PR #2 NUEVO, UIViewRepresentable)
                │       └─► PDFView (PDFKit, pila de gestos nativa)
                └─► PencilCanvasOverlay (PR #3 NUEVO, UIViewRepresentable)
                        └─► PKCanvasView (PencilKit)
```

- `PDFReaderCoordinator` posee el `PDFView` y el conmutador de modo
  de paginación (horizontal `PDFDisplayMode.singlePage` + dirección
  horizontal frente a vertical `PDFDisplayMode.singlePageContinuous`).
- `PencilCanvasOverlay` es un `UIViewRepresentable` hermano colocado
  **encima** del `PDFView`; aloja un `PKCanvasView` por página lógica.
- `PDFPageChangeObserver` (introducido en el PR #3 junto con la capa)
  es el puente entre el coordinador y la capa: vigila la señal de
  cambio de página, captura el `PKDrawing` saliente, lo persiste en
  `PageAnnotation.drawingData` y pide a la capa que cargue el dibujo
  entrante.
- `ReaderContainerView` posee el ciclo de vida de los tres: carga el
  documento, cablea la señal de cambio de página, lee y escribe la
  preferencia de paginación por documento, y desmonta ambas subvistas
  al desaparecer.

**Por qué dos `UIViewRepresentable`, no uno**: `PDFView` y
`PKCanvasView` tienen pilas de gestos distintas y ciclos de
actualización SwiftUI distintos. Fusionarlos en un único coordinador
hace que el intercambio de página sea engorroso y obliga a que un
ciclo de actualización arrastre al otro. Mantenerlos separados
permite que cada vista observe su propio publicador.

**Por qué la capa se sitúa encima, no dentro, del `PDFView`**: PDFKit
renderiza el contenido de la página como `CALayer`. Dibujar encima de
esa capa con una vista hermana mantiene el espacio de coordenadas de
PencilKit independiente del de PDFKit y simplifica el intercambio de
página — la capa solo reemplaza el `PKCanvasView` activo al cambiar
de página.

## 2. Preferencia de paginación (invariante de la Fase 1)

`DocumentItem.paginationModeRaw: String` ya existe en
`InSummary/Models/DocumentItem.swift` como invariante de la Fase 1,
con valor por defecto `"horizontal"`. La Fase 2 **no** añade, altera,
fija por defecto ni migra el campo; lo lee una vez al iniciar el
coordinador y lo escribe de vuelta cuando el lector alterna el modo.

- `PDFReaderCoordinator` expone un `paginationMode: PaginationMode`
  calculado a partir del `paginationModeRaw` del documento en el
  momento de la construcción.
- El conmutador se expone a la capa SwiftUI como un binding; el
  coordinador escribe el nuevo valor crudo de vuelta en la misma fila
  de `DocumentItem` mediante `modelContext.save()` y avanza
  `updatedAt`.
- La preferencia es **por documento**, no por sesión de aplicación.
- La enumeración envoltorio (`PaginationMode.horizontal | .vertical`)
  se construye en el sitio de lectura y se decodifica en el sitio de
  escritura; ambos sitios viven en el módulo del lector para que el
  límite de tipos sea obvio.
- Un valor crudo desconocido (por ejemplo `"foo"`) cae al horizontal y
  se registra una vez mediante `os.Logger` para que una fila
  corrupta nunca quede silenciosamente rota.

**Por qué `String` y no una enumeración en la entidad**: la entidad ya
persiste `paginationModeRaw: String` como invariante de la Fase 1. La
Fase 2 no migra el tipo de almacenamiento. La migración queda
aplazada hasta la fase de sincronización futura que formalice el
almacenamiento de anotaciones.

## 3. Persistencia de tinta — `PageAnnotation.drawingData` (invariante de la Fase 1)

`PageAnnotation.drawingData: Data?` ya existe en
`InSummary/Models/PageAnnotation.swift` (declarado con
`@Attribute(.externalStorage)` según `specification.md` §3.1). La Fase
2 **reutiliza** esta columna directamente. Sin almacén paralelo en
archivos, sin actor `InkDrawingStore`, sin entidad nueva, sin relación
nueva.

- `PencilCanvasOverlay` recibe una referencia
  `pageAnnotation: PageAnnotation` (o `nil` para el lazy-upsert en el
  primer montaje) y un `modelContext: ModelContext`.
- En `canvasViewDrawingDidChange`, la capa escribe
  `pageAnnotation.drawingData = canvas.drawing.dataRepresentation()`
  y llama a `modelContext.save()`. Los fallos se exponen como
  `AnnotationError.drawingPersistenceFailed(underlying:)` a través del
  canal `@Observable` `lastError`.
- `PDFPageChangeObserver` es el puente: captura los bytes de la
  página saliente desde la capa (mediante un closure inyectado), los
  persiste en el `PageAnnotation` saliente, carga el `PageAnnotation`
  entrante por `(document.id, pageIndex)`, hace lazy-upsert si falta
  uno, y pide a la capa que ejecute `activate(pageIndex:)`.
- El round-trip byte a byte es un requisito firme: los bytes
  persistidos por la capa DEBEN ser exactamente los que produce
  `PKDrawing.dataRepresentation()`, byte a byte.

**Por qué no hay un almacén separado en archivos**: el intento previo
inventó un almacén JSON bajo
`Application Support/Ink/<documentID>.ink.json` para "evitar un cambio
de esquema". Ese cambio de esquema ya lo entrega la Fase 1. Reutilizar
`PageAnnotation.drawingData` mantiene la Fase 2 pequeña, mantiene
canónico el modelo de datos y mantiene intacta la invariante de
compatibilidad con CloudKit (`@Attribute(.externalStorage)` funciona
con la sincronización futura).

## 4. Persistencia del cambio de página y coalescencia por valor

Tanto `PDFView.publish(for: \.currentPage)` como
`NotificationCenter.default.publisher(for: .PDFViewPageChanged)` se
disparan en renderizados en segundo plano, pases de maquetación y
deslizamientos del usuario. Sin coalescencia, la capa escribiría los
mismos bytes al disco en cada tick de renderizado.

- `PDFPageChangeObserver` es `@MainActor` y aplica **coalescencia por
  valor** sobre el `currentPageIndex` resuelto. El observador descarta
  las notificaciones cuyo `currentPageIndex` coincide con el último
  índice observado.
- El observador **no** usa `Task.sleep`,
  `DispatchQueue.main.asyncAfter`, ni temporizador alguno. Sin
  pruebas basadas en tiempo.
- La suscripción SwiftUI es un `.onReceive` del publicador expuesto
  por `PDFReaderCoordinator`, no un `NotificationCenter.addObserver`
  libre dentro de la vista.

## 5. Fixture — PDF de 20 páginas, CC0, determinista y autoral del proyecto

Los criterios de aceptación de la Fase 2 requieren un PDF de 20
páginas que se pueda abrir, navegar y anotar. El fixture es
**autoral del proyecto, determinista, CC0 y empaquetado en
compilación** exactamente en
`InSummary/Resources/Fixtures/sample-bundle.pdf` (plural `Fixtures`,
nombre con guion).

- `Tools/generate-sample-bundle-pdf.swift` es un script Swift
  autoral del proyecto y determinista que usa `PDFKit` para dibujar
  20 páginas tamaño carta. Cada página lleva: el índice de página en
  la esquina inferior derecha, un patrón geométrico determinista que
  cambia solo con el índice de página, y un bloque de texto CC0
  extraído de una constante congelada.
- El generador expone `generateFixture() -> Data` y un
  `fixtureContentHash` calculado sobre la salida página por página.
  Las pruebas verifican el hash contra una constante válida conocida,
  de modo que cualquier deriva hace fallar la suite.
- El generador se ejecuta en el momento de las pruebas (en proceso) y
  en la fase de compilación (escribe los bytes en
  `InSummary/Resources/Fixtures/sample-bundle.pdf` cada vez que cambia
  el código del generador). Las pruebas nunca leen el recurso del
  bundle directamente — llaman al generador en proceso y comparan los
  bytes cargados del bundle con la salida del generador en proceso.
- `InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` registra la
  dedicación CC0, el SHA-256 del generador y el conteo de páginas.
- El fixture es **CC0** porque cada primitiva de dibujo proviene de
  código de primera mano; no se incrusta contenido de terceros.

**Por qué generar, no enviar un binario**: enviar un PDF binario
significa que la suite de pruebas puede derivar respecto al artefacto
que la aplicación realmente carga, y el binario se convierte en una
caja negra que nadie puede revisar. Un generador determinista
mantiene el artefacto bajo revisión del código fuente, hace trivial
la regeneración y mantiene revisables los diffs de git.

**Por qué CC0**: las guardas de la Fase 2 en `openspec/config.yaml`
fijan la licencia del fixture en `CC0`. CC0 hace que el fixture sea
seguro para empaquetar en el binario de la aplicación y para
redistribuir en los registros de pruebas.

**Por qué importa la ruta canónica**: el intento previo fallido
usó `InSummary/Resources/Fixture/sample.pdf` (singular `Fixture`, sin
guion). Esa ruta es incorrecta porque (a) `Assets.xcassets` y el
resto del bundle usan directorios de recursos en plural, (b) el glob
del archivo de proyecto del bundle es
`InSummary/Resources/Fixtures/*.pdf`, y (c) cada especificación,
prueba, fase de compilación y descripción de PR debe hacer
referencia a una y solo una ruta.

## 6. Concurrencia y threading

- `PDFView`, `PKCanvasView` y el `ModelContext` principal de
  SwiftData se tocan únicamente en el actor principal;
  `PDFReaderCoordinator`, `PencilCanvasOverlay` y
  `PDFPageChangeObserver` son todos `@MainActor`.
- El closure de intercambio de página se entrega a la capa de forma
  sincrónica en el actor principal.
- Los fallos de persistencia se exponen como errores recuperables a
  través de `AnnotationError`; el lienzo conserva el dibujo en
  memoria durante la sesión actual y los bytes persistidos con
  anterioridad quedan intactos en disco.

**Por qué no hay async/await en el intercambio de página**: la ruta
de intercambio es del actor principal y está acotada firmemente por
el presupuesto de cuadro del gesto. Añadir concurrencia estructurada
allí no aporta nada y arriesga una señal de cancelación de SwiftUI
durante un deslizamiento rápido.

## 7. Estrategia de pruebas

TDD estricto según `openspec/config.yaml`. Cada requisito se entrega
con cobertura XCTest que falla antes del cambio y pasa después. Las
pruebas llegan en el mismo PR que el código que cubren.

| Capa | Cobertura |
| --- | --- |
| `Tools/generate-sample-bundle-pdf.swift` (llamado desde el soporte de pruebas) | Determinismo: hashear la salida del generador dos veces produce los mismos bytes; el hash de contenido canónico coincide con la constante; la salida es un `PDFDocument` de 20 páginas; cada página se renderiza a una `UIImage` no vacía. |
| `SampleBundleFixtureTests` (objetivo: `InSummaryTests`) | El fixture empaquetado se resuelve desde `Bundle.main`; el archivo no está vacío y pesa ≤ 1 MB; la salida del generador en proceso y los bytes empaquetados hashean idénticamente. |
| `PDFReaderCoordinator` | Carga el fixture empaquetado; fija `displayMode` + `displayDirection` a partir de `DocumentItem.paginationModeRaw`; actualiza el binding de preferencia cuando el lector alterna el modo; preserva la preferencia cuando la vista se desmonta y se reconstruye; expone `PDFReaderError` para fixture ausente, fixture ilegible, documento que no es PDF y documento que no es semilla. |
| `PencilCanvasOverlay` | Ignora los eventos de toque que no se originan en `UITouch.Type.pencil`; persiste un dibujo no vacío al abandonar la página; carga el mismo dibujo byte a byte al volver a la página; renderiza la herramienta predeterminada como `.highlighter`; hace lazy-upsert de un `PageAnnotation` cuando no existe para el índice de página activo. |
| `PDFPageChangeObserver` | El round-trip preserva payloads `PKDrawing` byte a byte entre páginas 1 → 2 → 1; cinco ciclos de navegación son estables; el observador descarta notificaciones cuyo `currentPageIndex` coincide con el último índice observado; un fallo de guardado expone `AnnotationError.drawingPersistenceFailed(underlying:)` y **no** muta `lastObservedPageIndex`. |
| `ReaderIntegrationTests` | De extremo a extremo: abrir el fixture empaquetado, navegar entre páginas, dibujar en página 1 y página 2, volver y comprobar que los trazos se preservan byte a byte; comprobación de aceptación sin conexión (modo avión). |

Las pruebas de UI y las pruebas de snapshot se difieren a la Fase 6.
La Fase 2 entrega pruebas unitarias y la XCTest de extremo a extremo
sin conexión descrita arriba.

## 8. Justificación del límite de las rebanadas (para la cadena de ramas de funcionalidad lineal)

| Rebanada | Por qué es un PR propio | Rama destino |
| --- | --- | --- |
| `pdf-fixture` (PR #1) | El fixture es una dependencia dura de cada prueba de la Fase 2 y es un generador de una sola vez. Aislarlo mantiene cada PR posterior centrado en el comportamiento del lector. | `tracker/pdf-reader-pencilkit-ink-recovery` |
| `pdf-engine` (PR #2) | El ciclo de vida del `PDFView` y el conmutador de modo de paginación son independientes de PencilKit y se benefician de una revisión aislada. | Rama del PR #1 (`feat/pdf-fixture`) |
| `pencilkit-ink-overlay` (PR #3) | Depende del publicador de cambio de página del coordinador (PR #2) y del fixture empaquetado (PR #1). La capa y el observador son lo bastante pequeños para entrar en un solo PR con sus pruebas. | Rama del PR #2 (`feat/pdf-engine`) |
| `pdf-reader-wiring` (PR #4) | Depende de los PR #1, #2 y #3. Cablea todo en la capa de librería existente y añade las pruebas de integración. | Rama del PR #3 (`feat/pencilkit-ink-overlay`) |

**Regla de topología lineal (estricta):** cada PR hijo posterior al
#1 apunta a la rama de su predecesor inmediato. La cadena es una
sola línea, no un árbol:

```
tracker ← PR #1 ← PR #2 ← PR #3 ← PR #4
```

El único PR que apunta a la rama rastreadora es el PR #1. El único
PR que alguna vez se fusiona en `main` es el rastreador. Sin
bifurcación, sin cadenas paralelas, sin fusión a `main` por parte de
ningún PR hijo.

## 9. Tabla de decisiones

| # | Decisión | Justificación |
| - | --- | --- |
| D1 | Reutilizar `DocumentItem.paginationModeRaw` tal cual; no añadir, alterar, fijar por defecto ni migrar el campo. | Invariante de la Fase 1. El fallo de portón del intento previo provino de inventar este campo. |
| D2 | Reutilizar `PageAnnotation.drawingData` como almacén de tinta por página; no inventar un almacén paralelo en archivos. | Invariante de la Fase 1 (`@Attribute(.externalStorage)`). Evita el `InkDrawingStore` inventado por el intento previo. |
| D3 | Usar exactamente `InSummary/Resources/Fixtures/sample-bundle.pdf` como ruta del fixture en todas partes (especificaciones, tareas, fase de compilación, pruebas, descripción de PR). | El intento previo usó la ruta equivocada (`Fixture/sample.pdf`). La ruta canónica es plural `Fixtures`, nombre con guion `sample-bundle.pdf`. |
| D4 | La fila de documento de la librería navega a `ReaderContainerView` para `DocumentItem` donde `fileTypeRaw == "pdf"` AND `localFileName.isEmpty == true`; todo lo demás expone un error recuperable "no soportado en esta build". | El §pdf-reader de la especificación "Seeded Document Is Navigable Without Import" exige que el lector sea alcanzable para el PDF semilla sin introducir importación. Ningún otro tipo de documento califica en la Fase 2. |
| D5 | Solo `Bundle.main.url(forResource: "sample-bundle", withExtension: "pdf")` es una fuente resoluble para el lector. Los fixtures ausentes o ilegibles lanzan errores tipados `PDFReaderError.fixtureMissing(resource:)` / `.fixtureUnreadable` y muestran un error recuperable. | El §pdf-reader "Bundled Fixture Source" prohíbe cualquier otra fuente de PDF para la Fase 2. |
| D6 | `PDFPageChangeObserver` aplica coalescencia por valor sobre `currentPageIndex` en `MainActor`. Sin `Task.sleep`, sin `DispatchQueue.main.asyncAfter`, sin temporizador. | El §pencil-canvas-overlay "Page-Change Save/Load Cycle" exige que el observador coalesza las notificaciones redundantes; la coalescencia por valor es determinista y reproducible. |
| D7 | `PencilCanvasOverlay` es dueña del write-on-change (vía `canvasViewDrawingDidChange`) Y del lazy-upsert de `PageAnnotation` en el primer montaje por índice de página. `PDFPageChangeObserver` es dueña del ciclo de guardado/carga entre páginas. | El §pencil-canvas-overlay reparte la responsabilidad limpiamente. Mantiene los imports de `ModelContext` dentro de la superficie del lector, no dentro del código de PencilKit. |
| D8 | Los fallos de guardado dentro del lienzo muestran un error recuperable mediante la propiedad `@Observable` `lastError: AnnotationError?`; el dibujo en memoria se conserva durante la sesión actual y los bytes persistidos con anterioridad quedan intactos en disco. Los fallos de decodificación muestran `AnnotationError.drawingDecodeFailed`; el lienzo se renderiza vacío y el `drawingData` ilegible se preserva. | El §pencil-canvas-overlay "Failure handling" exige errores recuperables y preservación en disco. |
| D9 | El fixture es **autoral del proyecto y determinista**: un script Swift (`Tools/generate-sample-bundle-pdf.swift`) genera un PDF de 20 páginas usando `PDFKit`, con semillas fijas para contenido de página, fuente y maquetación. Los bytes generados se escriben en `InSummary/Resources/Fixtures/sample-bundle.pdf` mediante la fase de compilación. Un `SAMPLE-BUNDLE-LICENSE.md` dedicado registra la dedicación CC0, el SHA-256 del generador y el conteo de páginas. | Petición del usuario: autoral del proyecto, determinista, 20 páginas, CC0, generado localmente. Evita el riesgo de licenciamiento y la invariante de solo local. |
| D10 | Todas las llamadas de UI y persistencia corren en `MainActor`. `PDFView`, `PKCanvasView` y el `ModelContext` principal de SwiftData están ligados a `MainActor` en este código; las pruebas comparten el mismo hilo. Sin cola en segundo plano, sin `Task.detached`. | El §pencil-canvas-overlay "no time-based tests" y el aislamiento `MainActor` ya existente en `LibraryGridView` y `PreviewContainer`. |
| D11 | `PDFReaderCoordinator` no importa `PencilKit`. `PencilCanvasOverlay` y `PDFPageChangeObserver` no importan `PDFKit` públicamente; aceptan valores ya cargados y un índice de página. | Mantiene los motores independientemente testeables. Refleja la separación del §4 entre el motor de PDF y el motor de anotaciones. |
| D12 | La entrega usa la estrategia `feature-branch-chain` con **cuatro** PR hijos en una topología **estrictamente lineal**. Una rama de larga duración `tracker/pdf-reader-pencilkit-ink-recovery` lleva un PR en borrador/sin fusión apuntando a `main`; el PR #1 apunta al rastreador; el PR #N (N > 1) apunta a la rama del PR #(N-1); solo el rastreador se fusiona alguna vez en `main`. | Skill `chained-pr`: cada PR hijo ≤ 400 líneas (el mayor ≈ 320 líneas para el PR #3), unidad de entrega única, tests con código, sin bundle entre slices, el PR del rastreador en borrador es la única ruta hacia `main`. La topología con bifurcación del intento previo violaba esta regla. |
| D13 | La capa del lector enlaza el `id` del `DocumentItem` semilla a la vista del lector mediante navegación SwiftUI, no mediante un singleton global. La capa se abre, el coordinador se inicializa contra el documento enlazado y el observador se cablea al `PDFView` en vivo. Re-entrar a la capa reinicializa contra el mismo documento. | El §pdf-reader "Preference Round-Trip": el `paginationModeRaw` persistido debe sobrevivir a una re-inicialización del coordinador. |
