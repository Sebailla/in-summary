# Especificación de capacidad — `pencilkit-ink-overlay`

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pencilkit-ink-overlay/spec.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

## Propósito

Renderizar tinta libre de Apple Pencil sobre el lector de PDF usando
`PencilKit`, persistir el dibujo de cada página como un payload
byte a byte idéntico de `PKDrawing.dataRepresentation()` sobre la
columna existente de la Fase 1 `PageAnnotation.drawingData`, y
mantener la tinta estable entre cambios de página, reinicios de la
aplicación y re-inicializaciones de `PDFReaderCoordinator` — todo
ello sin introducir notas adhesivas, resaltados semánticos, el modo
de herramienta borrador, un almacén paralelo en archivos en disco ni
ninguna capacidad remota.

La igualdad byte a byte entre el `drawingData` almacenado y el
`drawing.dataRepresentation()` del lienzo se afirma únicamente en el
límite de persistencia (lado de escritura). Como decodificar y luego
re-codificar un `PKDrawing` puede canonizar su archivo, el contrato
de reproducción en la UI preserva la semántica del dibujo y no la
igualdad byte a byte: un lienzo reconstruido a partir de
`PKDrawing(data: drawingData)` renderiza los trazos que el lector
dibujó, pero su `drawing.dataRepresentation()` PUEDE diferir de los
bytes almacenados.

La capa es un `UIViewRepresentable` alrededor de `PKCanvasView`. El
`PDFPageChangeObserver` es su compañero que dirige el ciclo de
guardado/carga. Ambos viven bajo
`InSummary/Services/AnnotationEngine/` y no importan `PDFKit`.

## Requisitos AÑADIDOS

### Requisito: Política de dibujo solo Pencil

La capa DEBE envolver un `PKCanvasView` cuyo `drawingPolicy` sea
`PKCanvasViewDrawingPolicy.pencilOnly`. La capa DEBE ignorar los
eventos de toque cuyo `UITouch.Type` no sea `.pencil`. Los toques,
deslizamientos y arrastres con el dedo NO DEBEN añadir trazos al
lienzo.

#### Escenario: Los toques con el dedo no dibujan

- **CUANDO** el lector toca el lienzo con un dedo
- **ENTONCES** el conteo de trazos del lienzo NO DEBE cambiar
- **Y** el `PKDrawing.strokes` del lienzo DEBE permanecer sin
  cambios.

#### Escenario: Los toques con Pencil sí dibujan

- **CUANDO** el lector arrastra el Apple Pencil sobre el lienzo
- **ENTONCES** el conteo de trazos del lienzo DEBE aumentar
  exactamente en uno por gesto de arrastre
- **Y** `canvasViewDrawingDidChange` DEBE dispararse.

### Requisito: La herramienta predeterminada es un marker amarillo translúcido

La capa DEBE tener como valor predeterminado
`PKInkingTool(.marker, color: <PKInkingColor amarillo translúcido con
alpha ≤ 0,5>, width: <ancho del marker>)`. Este es el análogo
canónico del highlighter en iOS 26 porque
`PKInkingTool.InkType.highlighter` no está expuesto en iOS 26. La
herramienta predeterminada DEBE aplicarse en `makeUIView` y DEBE
persistir entre reproducciones desde un dibujo almacenado.

#### Escenario: La herramienta predeterminada es un marker amarillo translúcido en un lienzo en blanco

- **CUANDO** la capa se monta contra un `PageAnnotation` cuyo
  `drawingData == nil` o un `PKDrawing` vacío
- **ENTONCES** la herramienta de tinta del `PKCanvasView` subyacente
  DEBE ser una `PKInkingTool` con `InkType.marker` cuyo
  `PKInkingColor` sea amarillo translúcido con alpha ≤ 0,5.

#### Escenario: La herramienta persiste entre reproducciones

- **CUANDO** la capa ha reproducido un `PKDrawing` no vacío desde
  `PageAnnotation.drawingData`
- **ENTONCES** la herramienta de tinta del `PKCanvasView`
  subyacente DEBE seguir siendo una `PKInkingTool` con
  `InkType.marker` cuyo `PKInkingColor` sea amarillo translúcido con
  alpha ≤ 0,5.

### Requisito: Reproducir el dibujo almacenado al cargar la página

La capa DEBE reproducir el dibujo almacenado de la página actual
desde `PageAnnotation.drawingData` cada vez que una página se
convierte en la página visible del lector. Si no existe ninguna fila
de `PageAnnotation` para ese índice de página, la capa DEBE hacer
lazy-upsert de una contra el `DocumentItem` enlazado y tratar la
página como en blanco.

#### Escenario: Un dibujo no vacío se reproduce con la semántica preservada

- **CUANDO** existe un `PageAnnotation` para la página actual con un
  `drawingData` no vacío
- **ENTONCES** la capa DEBE reemplazar el dibujo del `PKCanvasView`
  subyacente con `PKDrawing(data: drawingData!)`
- **Y** el `PKDrawing.strokes` del lienzo DEBE renderizar los trazos
  codificados por el `drawingData` almacenado
- **Y** el `drawing.dataRepresentation()` del lienzo PUEDE diferir
  del `drawingData` almacenado porque decodificar y luego
  re-codificar un `PKDrawing` puede canonizar su archivo; la
  igualdad byte a byte se afirma únicamente en el límite de
  persistencia antes de la reproducción, no después.

#### Escenario: Una anotación ausente es un lienzo en blanco

- **CUANDO** no existe ningún `PageAnnotation` para el índice de
  página actual
- **ENTONCES** la capa DEBE hacer lazy-upsert de un `PageAnnotation`
  cuyo `pageIndex` coincida con el índice de página activo
- **Y** el `PKDrawing.strokes` del `PKCanvasView` subyacente DEBE
  estar vacío.

### Requisito: Persistencia write-on-change sobre la columna de la Fase 1

La capa DEBE persistir cada cambio del lienzo escribiendo
`pageAnnotation.drawingData = canvas.drawing.dataRepresentation()`
y llamando a `modelContext.save()`. La capa NO DEBE introducir un
almacén paralelo en archivos en disco.

#### Escenario: Los bytes persistidos coinciden con el dibujo en memoria

- **CUANDO** `canvasViewDrawingDidChange` se dispara tras un trazo
  del Pencil
- **ENTONCES** `pageAnnotation.drawingData` DEBE ser byte a byte
  igual a `canvas.drawing.dataRepresentation()`
- **Y** `modelContext.save()` DEBE ser invocado.

#### Escenario: Limpiar el lienzo persiste bytes vacíos

- **CUANDO** el lector limpia el lienzo
- **ENTONCES** `pageAnnotation.drawingData` DEBE ser igual a un
  `Data` vacío
- **Y** los bytes persistidos con anterioridad DEBEN sobrescribirse
  en disco.

#### Escenario: Un fallo de guardado expone un error recuperable

- **CUANDO** `modelContext.save()` lanza una excepción
- **ENTONCES** la capa DEBE fijar `lastError =
  .drawingPersistenceFailed(underlying:)`
- **Y** el dibujo en memoria DEBE conservarse durante la sesión
  actual
- **Y** los bytes persistidos con anterioridad DEBEN permanecer
  intactos en disco.

### Requisito: El round-trip entre páginas preserva la semántica del dibujo

El `PDFPageChangeObserver` compañero de la capa DEBE capturar los
bytes de la página saliente desde el lienzo mediante un closure
inyectado en el límite de persistencia, persistirlos en el
`PageAnnotation` saliente, cargar el `PageAnnotation` entrante para
`(documentID, pageIndex)` y pedir a la capa que ejecute
`activate(pageIndex:)`. La igualdad byte a byte se afirma únicamente
en el límite de persistencia; como decodificar y luego re-codificar un
`PKDrawing` puede canonizar su archivo, la ruta de reproducción
preserva la semántica del dibujo y no la igualdad byte a byte entre el
`drawing.dataRepresentation()` del lienzo tras la reproducción y el
`drawingData` almacenado.

#### Escenario: El dibujo sobrevive a un round-trip entre páginas

- **CUANDO** el lector dibuja en la página 1, navega a la página 2,
  dibuja en la página 2 y luego vuelve a la página 1
- **ENTONCES** el `PKCanvasView` de la página 1 DEBE renderizar
  trazos semánticamente equivalentes a los que el lector dibujó
  originalmente en la página 1
- **Y** el `PKCanvasView` de la página 2 TAMBIÉN DEBE renderizar
  trazos semánticamente equivalentes a los dibujados allí
- **Y** el `drawing.dataRepresentation()` del lienzo tras la
  reproducción PUEDE diferir del `drawingData` almacenado porque
  decodificar y luego re-codificar un `PKDrawing` puede canonizar
  su archivo; la igualdad byte a byte se afirma únicamente en el
  límite de persistencia antes de cada reproducción.

#### Escenario: Cinco ciclos de navegación son estables

- **CUANDO** el lector alterna entre las páginas 1 y 2 cinco veces
- **ENTONCES** las filas `pageAnnotation.drawingData` de ambas
  páginas DEBEN permanecer iguales a los últimos bytes persistidos
  en el momento de escritura
- **Y** los lienzos de ambas páginas DEBEN renderizar trazos
  semánticamente equivalentes a los dibujos almacenados
- **Y** el `drawing.dataRepresentation()` del lienzo tras la
  reproducción PUEDE diferir del `drawingData` almacenado porque
  decodificar y luego re-codificar un `PKDrawing` puede canonizar
  su archivo; la igualdad byte a byte se afirma únicamente en el
  límite de persistencia antes de la reproducción.

### Requisito: Coalescencia por valor en las notificaciones de cambio de página

El `PDFPageChangeObserver` DEBE aplicar coalescencia por valor a
las notificaciones sobre `currentPageIndex` en el actor principal.
El observador DEBE descartar las notificaciones cuyo
`currentPageIndex` coincida con el último índice observado. NO DEBEN
usarse `Task.sleep`, `DispatchQueue.main.asyncAfter` ni
temporizadores.

#### Escenario: Una notificación redundante se descarta

- **CUANDO** el observador recibe dos notificaciones con el mismo
  `currentPageIndex` seguidas
- **ENTONCES** la segunda notificación DEBE descartarse
- **Y** NO DEBE ocurrir ningún guardado ni carga adicional.

### Requisito: Un fallo de decodificación preserva los bytes ilegibles

Cuando `PKDrawing(data:)` rechaza el `drawingData` almacenado, el
lienzo DEBE renderizarse vacío y el `drawingData` ilegible DEBE
permanecer intacto en la fila.

#### Escenario: El rechazo del decodificador expone un error recuperable

- **CUANDO** `PKDrawing(data: drawingData)` lanza una excepción
- **ENTONCES** la capa DEBE fijar `lastError = .drawingDecodeFailed`
- **Y** el `PKDrawing.strokes` del lienzo DEBE estar vacío
- **Y** `pageAnnotation.drawingData` DEBE permanecer igual a los
  bytes leídos de la fila.

### Requisito: Sin `PDFKit` y sin nueva superficie SwiftData

La capa y el observador NO DEBEN importar `PDFKit`. La capa y el
observador NO DEBEN declarar nuevas entidades, nuevas relaciones ni
nuevos campos sobre entidades existentes. Ambos DEBEN usar la columna
de la Fase 1 `PageAnnotation.drawingData` directamente.

#### Escenario: El límite de módulo se mantiene

- **CUANDO** se inspeccionan los archivos fuente de la capa y del
  observador
- **ENTONCES** ninguno de los archivos DEBE contener
  `import PDFKit`
- **Y** ninguno de los archivos DEBE declarar ningún tipo `@Model`
- **Y** ninguno de los archivos DEBE escribir ningún archivo fuera
  del bundle de la aplicación o del almacén SwiftData.

## Requisitos MODIFICADOS

*Ninguno.* Esta capacidad introduce la capa y el observador. No
modifica ninguna entidad de la Fase 1.

## Requisitos ELIMINADOS

*Ninguno.*
