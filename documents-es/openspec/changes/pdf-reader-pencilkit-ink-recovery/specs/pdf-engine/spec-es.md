# Especificación de capacidad — `pdf-engine`

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pdf-engine/spec.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

## Propósito

Aportar un `PDFReaderCoordinator` `@MainActor` amigable con SwiftUI
que envuelva `PDFKit.PDFView` y renderice el fixture PDF
empaquetado en modo paginado horizontal o modo continuo vertical
según la **invariante de la Fase 1** `DocumentItem.paginationModeRaw`
(por defecto `"horizontal"`). El coordinador no introduce un campo
de SwiftData, no añade una entidad y no migra ninguna entidad de la
Fase 1. Lee y escribe las columnas existentes `paginationModeRaw` y
`updatedAt` tal cual.

Esta capacidad define el contrato del que dependen la capa de tinta
de PencilKit y la capa del lector. La fuente del fixture
empaquetado es el canónico `sample-bundle.pdf` (consulta
`specs/pdf-fixture/spec-es.md`); ninguna otra fuente de PDF es
alcanzable en la Fase 2.

## Requisitos AÑADIDOS

### Requisito: Coordinador del lector de PDF

El sistema DEBE exponer un `PDFReaderCoordinator` que envuelva
`PDFKit.PDFView` y renderice el fixture empaquetado. El coordinador
DEBE ser `@MainActor`. El coordinador DEBE exponer el índice de
página actual y el modo de paginación actual como bindings
observables para que la capa padre de SwiftUI pueda reaccionar ante
cualquier cambio.

#### Escenario: Cargar el fixture empaquetado

- **CUANDO** el coordinador recibe una referencia al `DocumentItem`
  semilla (Fase 1 `fileTypeRaw == "pdf"`,
  `localFileName.isEmpty == true`)
- **ENTONCES** el `PDFView` subyacente DEBE abrir el
  `sample-bundle.pdf` empaquetado
- **Y** el binding de índice de página DEBE publicar `0` como valor
  inicial.

#### Escenario: Identidad estable de vista entre reconstrucciones de SwiftUI

- **CUANDO** la vista padre de SwiftUI se reconstruye con el mismo
  `DocumentItem`
- **ENTONCES** `makeUIView` NO DEBE recrear innecesariamente el
  `PDFView` subyacente
- **Y** el binding de índice de página NO DEBE reiniciarse a `0`
  durante la lectura.

### Requisito: Modo paginado horizontal

El coordinador DEBE soportar un modo **paginado horizontal**. En
este modo el `PDFView` subyacente DEBE usar
`PDFDisplayMode.singlePage` y `PDFDisplayDirection.horizontal` con
`usePageViewController(true)`. El documento DEBE avanzar una página
a la vez usando el gesto de deslizamiento horizontal nativo de
PDFKit.

#### Escenario: El deslizamiento avanza una página

- **CUANDO** el lector está en modo horizontal y desliza a la
  izquierda sobre la página
- **ENTONCES** el `PDFView` subyacente DEBE avanzar exactamente una
  página
- **Y** el binding de índice de página DEBE publicar el nuevo índice
  de página mediante el publicador de cambio de página.

### Requisito: Modo continuo vertical

El coordinador DEBE soportar un modo **continuo vertical**. En este
modo el `PDFView` subyacente DEBE usar
`PDFDisplayMode.singlePageContinuous` y
`PDFDisplayDirection.vertical`. El documento DEBE desplazarse
verticalmente por las páginas.

#### Escenario: Desplazamiento continuo

- **CUANDO** el lector está en modo vertical y se desplaza hacia
  abajo
- **ENTONCES** el `PDFView` subyacente DEBE atravesar las páginas
  sin un corte brusco
- **Y** el binding de índice de página DEBE publicar la página que
  ocupa el centro del área visible.

### Requisito: Conmutador de modo de paginación desde una invariante de la Fase 1

El coordinador DEBE derivar el modo de paginación inicial desde la
columna existente `DocumentItem.paginationModeRaw`. El coordinador
NO DEBE introducir un nuevo campo de SwiftData, una nueva entidad ni
una nueva relación para modelar la preferencia. El coordinador DEBE
escribir el nuevo valor crudo de vuelta en la misma columna al
alternar y avanzar `DocumentItem.updatedAt`.

#### Escenario: La preferencia por defecto se lee desde la Fase 1

- **CUANDO** el coordinador abre un `DocumentItem` cuyo
  `paginationModeRaw == "horizontal"`
- **ENTONCES** el coordinador DEBE aplicar el modo paginado
  horizontal
- **Y** el `PDFView` subyacente DEBE coincidir con la configuración
  horizontal.

#### Escenario: La preferencia vertical se lee desde la Fase 1

- **CUANDO** el coordinador abre un `DocumentItem` cuyo
  `paginationModeRaw == "vertical"`
- **ENTONCES** el coordinador DEBE aplicar el modo continuo
  vertical
- **Y** el `PDFView` subyacente DEBE coincidir con la configuración
  vertical.

#### Escenario: Un valor crudo desconocido cae al horizontal

- **CUANDO** el coordinador abre un `DocumentItem` cuyo
  `paginationModeRaw` es cualquier valor distinto de `"horizontal"`
  o `"vertical"`
- **ENTONCES** el coordinador DEBE caer al modo paginado horizontal
- **Y** el coordinador DEBE registrar el valor desconocido mediante
  `os.Logger` exactamente una vez por apertura.

#### Escenario: La alternancia escribe de vuelta en la columna existente

- **CUANDO** la vista padre voltea el binding de modo a `"vertical"`
- **ENTONCES** `DocumentItem.paginationModeRaw` DEBE ser igual a
  `"vertical"` tras el siguiente tick del runloop
- **Y** `DocumentItem.updatedAt` DEBE avanzar
- **Y** cualquier otro campo de la fila DEBE permanecer sin
  cambios.

#### Escenario: Round-trip entre re-inicializaciones del coordinador

- **CUANDO** el lector alterna un documento a `"vertical"` y el
  documento se cierra y se vuelve a abrir
- **ENTONCES** el coordinador DEBE abrir en modo vertical.

### Requisito: Fuente del fixture empaquetado

El coordinador DEBE resolver su fuente de PDF únicamente desde el
bundle de la aplicación, nunca desde un selector de archivos
importado por el usuario, un directorio de documentos del sandbox ni
la red. El fixture es el `sample-bundle.pdf` enviado a través de
*Copy Bundle Resources* (consulta `specs/pdf-fixture/spec-es.md`).

#### Escenario: El fixture ausente es un fallo tipado

- **CUANDO** el bundle de la aplicación NO contiene
  `sample-bundle.pdf`
- **ENTONCES** el coordinador DEBE lanzar
  `PDFReaderError.fixtureMissing(resource: "sample-bundle")`
- **Y** la superficie del lector DEBE mostrar un error recuperable
  a quien invoca en lugar de sustituir silenciosamente un valor por
  defecto.

#### Escenario: El fixture ilegible es un fallo tipado

- **CUANDO** el `sample-bundle.pdf` empaquetado existe pero no
  puede parsearse como `PDFDocument`
- **ENTONCES** el coordinador DEBE lanzar
  `PDFReaderError.fixtureUnreadable`
- **Y** la superficie del lector DEBE mostrar un error recuperable
  a quien invoca en lugar de presentar un `PDFView` vacío.

### Requisito: El documento semilla es navegable sin importación

El coordinador DEBE ser alcanzable para el `DocumentItem` semilla de
la Fase 1 (`title: "Getting Started"`, `fileTypeRaw: "pdf"`,
`localFileName.isEmpty == true`) desde la capa de librería
existente. El coordinador NO DEBE requerir un gesto de navegación
por carpetas, un importador de archivos, un selector de documentos
ni un destino de arrastrar y soltar para hacerlo.

#### Escenario: Un documento que no es PDF o que no es semilla es rechazado

- **CUANDO** se solicita la superficie del lector para un
  `DocumentItem` cuyo `fileTypeRaw != "pdf"` o cuyo
  `localFileName.isEmpty == false`
- **ENTONCES** el coordinador DEBE lanzar
  `PDFReaderError.unsupportedDocument(reason:)`
- **Y** la superficie del lector DEBE mostrar un error recuperable
  de "no soportado en esta build" a quien invoca.

### Requisito: Sin red y sin E/S remota

El coordinador NO DEBE realizar ninguna petición de red y NO DEBE
leer ni escribir ningún archivo fuera del bundle de la aplicación o
del almacén SwiftData local.

#### Escenario: Sin acceso a la red

- **CUANDO** el coordinador abre el documento o pasa páginas
- **ENTONCES** no DEBE abrirse ninguna sesión URL, socket ni URL
  remota
- **Y** una búsqueda de código de `URLSession`, `NWConnection` y
  `NSURLConnection` dentro de `InSummary/Services/PDFEngine/` DEBE
  devolver cero coincidencias.

### Requisito: Sin `PencilKit` y sin nueva superficie SwiftData

El coordinador NO DEBE importar `PencilKit`. El coordinador NO DEBE
declarar nuevas entidades, nuevas relaciones ni nuevos campos sobre
entidades existentes. El coordinador NO DEBE introducir un almacén
adicional en archivos en disco.

#### Escenario: El límite de módulo se mantiene

- **CUANDO** se inspecciona el código del coordinador
- **ENTONCES** el archivo NO DEBE contener `import PencilKit`
- **Y** el archivo NO DEBE declarar ningún tipo `@Model`
- **Y** el archivo NO DEBE escribir ningún archivo fuera del bundle
  de la aplicación o del almacén SwiftData.

## Requisitos MODIFICADOS

*Ninguno.* Esta capacidad introduce el coordinador. No modifica
ninguna entidad de la Fase 1.

## Requisitos ELIMINADOS

*Ninguno.*
