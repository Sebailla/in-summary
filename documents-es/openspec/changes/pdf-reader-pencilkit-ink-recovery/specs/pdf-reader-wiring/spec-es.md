# Especificación de capacidad — `pdf-reader-wiring`

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pdf-reader-wiring/spec.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

## Propósito

Componer el `PDFReaderCoordinator` (capacidad `pdf-engine`) y la
`PencilCanvasOverlay` + `PDFPageChangeObserver` (capacidad
`pencilkit-ink-overlay`) en una única `ReaderContainerView` de
SwiftUI, y cablear la capa de librería de la Fase 1 para que el
documento PDF semilla sea alcanzable desde la fila de la librería
sin introducir importación, exportación, carpetas ni ninguna otra
superficie de la Fase 5.

Esta capacidad define el contrato del que dependen las pruebas de
integración y la comprobación de aceptación sin conexión. No
introduce un nuevo campo de SwiftData; la preferencia de paginación
por documento es la invariante de la Fase 1
`DocumentItem.paginationModeRaw`.

## Requisitos AÑADIDOS

### Requisito: Composición de la capa del lector

El sistema DEBE exponer una `ReaderContainerView` de SwiftUI que
componga el `PDFReaderCoordinator` y la `PencilCanvasOverlay` y
posea su ciclo de vida. La capa DEBE:

1. Aceptar el `DocumentItem` semilla (Fase 1 `fileTypeRaw == "pdf"`,
   `localFileName.isEmpty == true`) mediante navegación de SwiftUI,
   no mediante un singleton global.
2. Construir el coordinador contra el documento enlazado; el
   coordinador lee la columna existente `paginationModeRaw`.
3. Suscribir el `PDFPageChangeObserver` al publicador de cambio de
   página del coordinador mediante `.onReceive`.
4. Montar la `PencilCanvasOverlay` encima del `PDFView` del
   coordinador y pasar el `PageAnnotation` actual (con lazy-upsert
   si falta) más el `ModelContext`.
5. Mostrar banners de error recuperables desde `PDFReaderError` y
   `AnnotationError`.
6. Desmontar ambas subvistas al desaparecer; ningún `PKCanvasView`
   retenido DEBE sobrevivir a la capa.

#### Escenario: El lector abre el fixture empaquetado

- **CUANDO** la capa recibe un `DocumentItem` semilla
- **ENTONCES** el coordinador DEBE cargar el `sample-bundle.pdf`
  empaquetado
- **Y** la capa DEBE montarse encima del coordinador.

#### Escenario: La capa se desmonta limpiamente

- **CUANDO** la capa desaparece
- **ENTONCES** ambas subvistas de UIKit DEBEN eliminarse de la
  jerarquía de vistas
- **Y** ningún `PKCanvasView` retenido DEBE sobrevivir a la capa.

### Requisito: Navegación desde la capa de librería

La `LibraryGridView` de la Fase 1 DEBE modificarse para que la fila
del `DocumentItem` semilla se convierta en un `NavigationLink` a
`ReaderContainerView(document:)`. Las filas de cualquier otro
`DocumentItem` DEBEN mostrar una alerta recuperable de "no
soportado en esta build".

#### Escenario: El documento semilla abre el lector

- **DADO** que el almacén SwiftData local contiene el `DocumentItem`
  semilla producido por `LibrarySeedService`
- **CUANDO** el lector pulsa esa fila en la capa de librería
- **ENTONCES** la librería DEBE navegar a
  `ReaderContainerView(document:)`
- **Y** NO DEBE presentarse al usuario ningún importador de
  archivos, navegador de carpetas ni selector de documentos.

#### Escenario: Una fila que no es PDF o que no es semilla es rechazada

- **CUANDO** el lector pulsa una fila cuyo `fileTypeRaw != "pdf"` o
  cuyo `localFileName.isEmpty == false`
- **ENTONCES** la librería DEBE mostrar una alerta recuperable que
  diga "no soportado en esta build"
- **Y** la librería NO DEBE navegar a `ReaderContainerView`.

### Requisito: Binding de UI para alternar el modo

La capa DEBE exponer un binding de SwiftUI para que una vista padre
pueda alternar el modo de paginación de forma declarativa. La capa
DEBE escribir el nuevo modo de vuelta en `DocumentItem.paginationModeRaw`
(la columna de la Fase 1) para que la preferencia sobreviva a la
siguiente apertura.

#### Escenario: La alternancia escribe la preferencia

- **CUANDO** la vista padre voltea el binding de modo a `"vertical"`
- **ENTONCES** `DocumentItem.paginationModeRaw` DEBE ser igual a
  `"vertical"` tras el siguiente tick del runloop
- **Y** `DocumentItem.updatedAt` DEBE avanzar.

### Requisito: Round-trip de extremo a extremo byte a byte

Cuando el lector abre el fixture empaquetado, dibuja en la página
1, navega a la página 2, dibuja en la página 2, vuelve a la página
1 y cierra el documento, los payloads
`PKDrawing.dataRepresentation()` de ambas páginas DEBEN ser byte a
byte iguales a los valores que el lector dibujó originalmente,
ambos persistidos en `PageAnnotation.drawingData`.

#### Escenario: Round-trip de integración del lector

- **CUANDO** la prueba de integración abre el fixture empaquetado,
  dibuja en la página 1 y la página 2, vuelve a la página 1 y sale
- **ENTONCES** los payloads `PKDrawing.dataRepresentation()` de
  ambas páginas DEBEN coincidir byte a byte con los bytes esperados
- **Y** el `PageAnnotation.drawingData` de ambas páginas DEBE ser
  byte a byte igual a los bytes de
  `PKDrawing.dataRepresentation()` en memoria.

### Requisito: Aceptación sin conexión

Cuando el dispositivo está en modo avión (sin red, sin sesión de
iCloud), el lector DEBE abrir el fixture empaquetado, renderizar
ambos modos de paginación, aceptar el dibujo con Pencil en ambas
páginas y hacer round-trip de los trazos entre navegaciones.

#### Escenario: Round-trip en modo avión

- **DADO** que el dispositivo está en modo avión
- **CUANDO** la prueba abre el fixture, dibuja en la página 1,
  dibuja en la página 2, navega de vuelta a la página 1 y sale
- **ENTONCES** los dibujos de ambas páginas DEBEN preservarse byte a
  byte
- **Y** `DocumentItem.paginationModeRaw` DEBE sobrevivir a la
  reapertura del documento.

### Requisito: Sin nuevos entitlements

La capa NO DEBE requerir ninguna entrada nueva en `Info.plist`. El
bundle de la aplicación NO DEBE ganar entitlements de iCloud,
CloudKit, notificaciones push ni modos en segundo plano como
resultado de este cambio.

#### Escenario: El delta de entitlements es vacío

- **CUANDO** se calcula el diff de `InSummary/Info.plist` y de los
  archivos de entitlements a lo largo de este cambio
- **ENTONCES** el diff DEBE estar vacío.

### Requisito: Sin nueva superficie SwiftData

La capa NO DEBE declarar nuevas entidades, nuevas relaciones ni
nuevos campos sobre entidades existentes. La capa DEBE leer y
escribir únicamente las columnas de la Fase 1
`DocumentItem.paginationModeRaw`, `DocumentItem.updatedAt` y
`PageAnnotation.drawingData`.

#### Escenario: El límite de módulo se mantiene

- **CUANDO** se inspecciona el archivo fuente de la capa
- **ENTONCES** el archivo NO DEBE contener `@Model`
- **Y** el archivo NO DEBE añadir ninguna propiedad a un tipo
  `@Model`
- **Y** el archivo NO DEBE introducir un nuevo almacén en archivos
  en disco.

## Requisitos MODIFICADOS

### MODIFICADA: `LibraryGridView.swift` (Fase 1)

La `LibraryGridView.swift` de la Fase 1 DEBE modificarse para que la
fila del `DocumentItem` semilla se convierta en un `NavigationLink`
a `ReaderContainerView(document:)` y para que cualquier otra fila
muestre una alerta recuperable de "no soportado en esta build". La
maquetación de las filas de la librería (sección de carpetas +
sección de documentos, etiquetas de accesibilidad, vista previa)
DEBE preservarse.

#### Escenario: La maquetación de las secciones se preserva

- **CUANDO** se renderiza la capa de librería tras el cambio
- **ENTONCES** la sección de Carpetas DEBE seguir renderizando filas
  de `FolderEntity`
- **Y** la sección de Documentos DEBE seguir renderizando filas de
  `DocumentItem`
- **Y** las etiquetas de accesibilidad DEBEN seguir combinando
  título y subtítulo.

## Requisitos ELIMINADOS

*Ninguno.*
