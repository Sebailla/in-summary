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

### Requisito: Highlighter como herramienta predeterminada

La capa DEBE tener como valor predeterminado
`PKInkingTool(.highlighter, ...)` para que lo primero que vea el
lector al tomar el Pencil sea un highlighter, no un bolígrafo. La
herramienta predeterminada DEBE aplicarse en `makeUIView` y DEBE
persistir entre reproducciones desde un dibujo almacenado.

#### Escenario: La herramienta predeterminada es el highlighter en un lienzo en blanco

- **CUANDO** la capa se monta contra un `PageAnnotation` cuyo
  `drawingData == nil` o un `PKDrawing` vacío
- **ENTONCES** la herramienta de tinta del `PKCanvasView` subyacente
  DEBE ser una `PKInkingTool` con `InkType.highlighter`.

#### Escenario: La herramienta persiste entre reproducciones

- **CUANDO** la capa ha reproducido un `PKDrawing` no vacío desde
  `PageAnnotation.drawingData`
- **ENTONCES** la herramienta de tinta del `PKCanvasView`
  subyacente DEBE seguir siendo una `PKInkingTool` con
  `InkType.highlighter`.

### Requisito: Reproducir el dibujo almacenado al cargar la página

La capa DEBE reproducir el dibujo almacenado de la página actual
desde `PageAnnotation.drawingData` cada vez que una página se
convierte en la página visible del lector. Si no existe ninguna fila
de `PageAnnotation` para ese índice de página, la capa DEBE hacer
lazy-upsert de una contra el `DocumentItem` enlazado y tratar la
página como en blanco.

#### Escenario: Un dibujo no vacío se reproduce byte a byte

- **CUANDO** existe un `PageAnnotation` para la página actual con un
  `drawingData` no vacío
- **ENTONCES** la capa DEBE reemplazar el dibujo del `PKCanvasView`
  subyacente con `PKDrawing(data: drawingData!)`
- **Y** el `drawing.dataRepresentation()` del lienzo DEBE coincidir
  byte a byte con el `drawingData` almacenado.

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

### Requisito: Round-trip byte a byte entre páginas

El `PDFPageChangeObserver` compañero de la capa DEBE capturar los
bytes de la página saliente desde el lienzo mediante un closure
inyectado, persistirlos en el `PageAnnotation` saliente, cargar el
`PageAnnotation` entrante para `(documentID, pageIndex)` y pedir a
la capa que ejecute `activate(pageIndex:)`.

#### Escenario: El dibujo sobrevive a un round-trip entre páginas

- **CUANDO** el lector dibuja en la página 1, navega a la página 2,
  dibuja en la página 2 y luego vuelve a la página 1
- **ENTONCES** el `PKDrawing.dataRepresentation()` de la página 1
  DEBE ser byte a byte idéntico al dibujo que el lector hizo
  originalmente
- **Y** el dibujo de la página 2 TAMBIÉN DEBE preservarse.

#### Escenario: Cinco ciclos de navegación son estables

- **CUANDO** el lector alterna entre las páginas 1 y 2 cinco veces
- **ENTONCES** los payloads `PKDrawing.dataRepresentation()` de
  ambas páginas DEBEN permanecer byte a byte iguales a los últimos
  valores persistidos.

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
