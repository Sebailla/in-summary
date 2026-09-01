# Especificación Técnica — Lector y Anotador Universal para iPad

**Proyecto:** In-Summary (Lector y Anotador Universal para iPad)
**Plataforma:** iPadOS 26.0+
**Lenguaje / Herramientas:** Swift 5.10 / Swift 6, Xcode 15 / 16
**Estado del documento:** Especificación canónica — sustituye a `especifications.md` y `especifications-2.md`
**Audiencia:** Revisores, futuros colaboradores y la persona que implementará
**Decisión de producto (v1):** local-first; sin cuenta de Apple Developer Program requerida. La sincronización entre dispositivos vía iCloud/CloudKit y la subida de binarios (`CKAsset`) quedan explícitamente diferidas a una fase posterior.

---

## Resumen de Decisiones

In-Summary es un entorno personal de lectura y estudio, basado en biblioteca local, para iPad. Permite importar documentos en **PDF**, **EPUB** y **Markdown**, leerlos con paginación horizontal o vertical según la elección del lector, soportar dos modos de anotación (resaltado semántico de texto y tinta libre con Apple Pencil) y superponer notas adhesivas flotantes persistentes. La interfaz adopta el lenguaje visual Liquid Glass de iOS 26, adaptado para iPadOS. Los archivos originales y los metadatos viven exclusivamente en el sandbox del dispositivo que los importó; v1 no realiza llamadas de red de ningún tipo. La sincronización entre dispositivos y la disponibilidad de libros en la nube quedan diferidas a una fase posterior.

| Área | Decisión |
| --- | --- |
| Capa de lectura | Shell de SwiftUI que aloja un motor por formato mediante `UIViewRepresentable` |
| Paginación | Horizontal o vertical, elegida por el lector y persistida por documento |
| Diseño de interfaz | Liquid Glass de iOS 26, adaptado para iPadOS y respetando accesibilidad y contraste |
| Capas de anotación | Cuatro capas en orden Z (resaltados semánticos → tinta PencilKit → post-its → superposiciones de UI) |
| Persistencia | `ModelContainer` SwiftData **local**; sin capacidades iCloud/CloudKit activas en v1. La sincronización queda diferida a una fase posterior |
| Esquema SwiftData | Compatible con CloudKit por anticipación (sin atributos únicos, todas las relaciones opcionales o con valor por defecto), para reducir el coste de la fase de sincronización futura |
| Unicidad | Sin `@Attribute(.unique)`; la unicidad se aplica en la capa de aplicación al importar |
| Seguridad EPUB | Descompresión en sandbox con protección contra path traversal, lista permitida de tipos de contenido, `WKWebView` aislado por documento |
| Rendimiento | Sin objetivos absolutos de FPS, latencia ni RAM; verificación manual de fluidez en hardware real |

**Qué está dentro del alcance (v1):** lectura, paginación, anotación, post-its, organización en carpetas, exportación de PDF con marcas quemadas y resumen de notas en Markdown, todo 100 % local y sin servidor.

**Qué queda fuera del alcance (v1):** edición colaborativa, compartir libros o notas con otros usuarios, sincronización entre dispositivos (iCloud/CloudKit), subida o descarga de binarios como `CKAsset`, "Hacer disponible en mis otros dispositivos", cualquier backend, analítica de terceros, SDKs de pago, renderizado en servidor, funciones de IA, reproducción de audio/video, conversión de formatos (p. ej., EPUB → PDF), contenido protegido por DRM, factores de forma distintos de iPad.

**Diferido a una fase posterior (no es v1):** sincronización de anotaciones y metadatos entre los dispositivos del propio usuario mediante una base de datos privada de CloudKit; subida opt-in del binario del libro como `CKAsset`; descarga entre dispositivos; revocación del binario en la nube. El diseño se conserva más adelante para no contradecir la línea base, pero **ninguno** de estos comportamientos se entrega en v1.

**Contradicciones resueltas (esta sección sustituye a borradores previos):**

1. **La disponibilidad entre dispositivos queda diferida.** En v1 los binarios y los metadatos son exclusivamente locales. Cuando se introduzca la fase de sincronización futura, CloudKit solo sincronizará los registros de SwiftData; los documentos originales permanecerán en el sandbox del dispositivo que los importó. Hasta entonces, la biblioteca no muestra estados de descarga ni remotos. Esto evita bibliotecas silenciosamente rotas y mantiene una superficie mínima en v1.
2. **El contenido reflowable no admite `pageIndex` como localizador estable.** Markdown y EPUB reflowean con el viewport y el tamaño de fuente, lo que vuelve inestables los números de página. Los localizadores estables son:
   - **PDF** → `(pageIndex, normalizedQuads: [CGRect])` en el espacio del documento PDF.
   - **Markdown** → `NSRange(location, length)` más un `contentHash` para invalidar cuando cambia el origen.
   - **EPUB** → una cadena **CFI** (Canonical Fragment Identifier) de EPUB 3, con serialización de Range DOM como respaldo si falla la generación de CFI.
   `pageIndex` se conserva solo como **pista de visualización** y como puntero de navegación; el anclaje canónico de los resaltados es específico del formato.
3. **Los espacios de coordenadas de anotación son explícitos y por capa.** Véase §3.4.
4. **La unicidad de SwiftData se aplica en la capa de aplicación**, no mediante `@Attribute(.unique)`. Además de producir mejores mensajes de error, esto mantiene el esquema compatible con CloudKit por anticipación, de modo que la fase de sincronización futura no exija reescritura de entidades. Véase §3.5.
5. **La resolución de conflictos entre dispositivos queda diferida.** v1 no tiene sincronización, por lo que no existen escenarios de conflicto entre dispositivos. La semántica local de SwiftData (orden de escritura sobre el mismo dispositivo) aplica tal cual. Cuando se reactive la fase de sincronización, la regla prevista es **último escritor gana por registro** con `updatedAt` como desempate; las fusiones a nivel de bytes en PencilKit quedan explícitamente fuera del alcance.
6. **Sin garantías absolutas de rendimiento.** Borradores anteriores afirmaban 120 FPS, latencia inferior a 9 ms y techos de memoria. Se eliminan y se sustituyen por pasos cualitativos de verificación en hardware real con Instruments.

---

## Ruta rápida para revisores

1. Leer §1 (Alcance) y §2 (Arquitectura) para orientarse — 5 minutos.
2. Repasar las tablas de §3 (Modelo de datos) y §4 (Motores de formato) — 10 minutos.
3. Validar los criterios de aceptación de §6 (Entrega por fases) frente a la estrategia de pruebas de §7.
4. Verificar que nada de §9 (Fuera del alcance) se esté implementando en silencio, y que todo lo etiquetado como "diferido" siga etiquetado como tal y ausente del código de producto de v1.

---

## 1. Alcance, Usuarios y Restricciones

### 1.1 Descripción del producto

Una aplicación iPad basada en biblioteca que permite a un único usuario:

- Importar archivos `.pdf`, `.epub` y `.md` a una biblioteca privada en el dispositivo.
- Leer cada documento con **paginación horizontal o vertical**, según la preferencia elegida por el lector.
- Resaltar texto de forma semántica (por carácter) y/o pintar tinta libre con Apple Pencil.
- Colocar notas adhesivas flotantes en cualquier página, editarlas con teclado o Scribble y reposicionarlas mediante gestos de arrastre.
- Organizar documentos en carpetas creadas por el usuario.
- Reanudar la lectura en el último localizador de cada documento.
- Exportar un PDF con la tinta y los resaltados quemados, más un resumen en Markdown de todas las anotaciones del documento.

**Sin servidor, sin cuenta de desarrollador de Apple y sin dependencia de red.** Todo el contenido y todos los metadatos viven en el sandbox local del dispositivo que importó los archivos.

### 1.2 Restricciones

- **Plataforma:** solo iPadOS 26.0+. Sin iPhone, sin Mac Catalyst, sin visionOS.
- **Interfaz:** usar el sistema visual Liquid Glass de iOS 26, adaptado a iPadOS; los efectos translúcidos no pueden reducir la legibilidad, el contraste ni la compatibilidad con VoiceOver.
- **Conectividad:** v1 está diseñada para funcionar **completamente sin conexión** y **sin capacidades iCloud/CloudKit activas**. No se realizan llamadas de red hacia Apple ni hacia ningún tercero.
- **Membresía de Apple Developer Program:** no se requiere para v1; las capabilities iCloud, CloudKit, push notifications y firma de distribución quedan desactivadas.
- **Sin servicios de terceros:** sin servidores propios, sin SDKs de analítica, sin SDKs de pago.
- **Sin elusión de DRM:** la aplicación no evade el DRM de tiendas ni de editoriales.

### 1.3 Fuera del alcance (v1)

| Fuera del alcance | Motivo de exclusión |
| --- | --- |
| Compartir libros con otros usuarios | v1 es monousuario y local; compartir exige otro modelo de almacenamiento |
| Anotaciones colaborativas | Igual que arriba; queda fuera hasta introducir compartición |
| Conversión de formato (EPUB→PDF, etc.) | Añade mucha complejidad y riesgo de propiedad/licencias |
| Reproducción de audio/video | Los motores de lectura son textuales |
| Resumen por IA / OCR | No en v1; se pueden añadir hooks sin romper el esquema |
| Sincronización entre dispositivos (iCloud/CloudKit) | Diferida a una fase posterior; v1 es local-first y no requiere membresía del Apple Developer Program |
| Subida o descarga de binarios como `CKAsset` | Diferida con la sincronización; depende de CloudKit |
| Disponibilidad de libros entre dispositivos ("Hacer disponible en mis otros dispositivos") | Diferida con la sincronización |
| Backend propio, restauración manual o copia de seguridad remota | No se afirma; v1 no implementa ninguna ruta de backup remoto |
| Targets de Windows/macOS | Reduce la superficie de pruebas de PencilKit y multiwindow a un target conocido |

---

## 2. Arquitectura

### 2.1 Capas

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          CAPA DE PRESENTACIÓN                              │
│  ┌────────────────┐  ┌─────────────────────────┐  ┌────────────────────┐  │
│  │ LibraryGrid    │  │ ReaderContainerView     │  │ StickyNote / Tools │  │
│  └────────────────┘  └────────────┬────────────┘  └────────────────────┘  │
│                                   │                                        │
│                                   ▼                                        │
│                          Reader ViewModels                                 │
└─────────────────────────────────┬──────────────────────────────────────────┘
                                      │
┌─────────────────────────────────▼──────────────────────────────────────────┐
│                              CAPA DE DOMINIO                               │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Motor PDF   │  │ Motor MD    │  │ Motor EPUB   │  │ Motor Anotación  │  │
│  └─────────────┘  └─────────────┘  └──────────────┘  └──────────────────┘  │
│            ┌─────────────────────────────────────────────────────┐        │
│            │ EPUB Security + Disponibilidad (diferida)            │        │
│            └─────────────────────────────────────────────────────┘        │
└─────────────────────────────────┬──────────────────────────────────────────┘
                                      │
┌─────────────────────────────────▼──────────────────────────────────────────┐
│                     CAPA DE DATOS Y PERSISTENCIA                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │              ModelContainer SwiftData LOCAL (sin CloudKit)          │  │
│  │  FolderEntity ─< DocumentItem ─< PageAnnotation ─< {TextHighlight,  │  │
│  │                                                       StickyNote}   │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│           │                                                                │
│           ▼                                                                │
│   Application Support/Documents/<UUID>.<ext>                               │
│   (binarios originales, exclusivamente locales)                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Mapa de módulos

| Módulo | Responsabilidad | Tipos clave |
| --- | --- | --- |
| `App/` | Punto de entrada, DI, cableado de capabilities (sin iCloud/CloudKit en v1) | `UniversalReaderApp`, `DependencyContainer` |
| `Models/` | Entidades SwiftData (esquema local en v1; compatible con CloudKit por anticipación) | `FolderEntity`, `DocumentItem`, `PageAnnotation`, `TextHighlight`, `StickyNoteEntity` |
| `Services/Storage/` | E/S de archivos en sandbox y caché de miniaturas; sin monitor de sync activo en v1 | `FileStorageService`, `ThumbnailCache` |
| `Services/PDFEngine/` | Wrapper de PDFKit, conversión de coordenadas | `PDFReaderCoordinator`, `PDFCoordinateConverter` |
| `Services/MarkdownEngine/` | Parseo y paginación de Markdown | `MarkdownParser`, `MarkdownPaginator` |
| `Services/EPUBEngine/` | Descompresión EPUB, parseo OPF, puente JS | `EPUBUnarchiver`, `EPUBManifestParser`, `EPUBBridgeScript.js` |
| `Services/AnnotationEngine/` | Ciclo de vida PencilKit, física de post-its | `PencilManager`, `PostItLayoutEngine` |
| `Services/Security/` | Descompresión segura EPUB, lista permitida de tipos | `EPUBSandboxValidator` |
| `Views/Library/` | Cuadrícula de biblioteca + carpetas | `LibraryGridView`, `FolderSidebarView` |
| `Views/Reader/` | Shell del lector + vistas por formato | `ReaderContainerView`, `PDFViewRepresentable`, `MarkdownPageView`, `EPUBWebViewRepresentable` |
| `Views/Reader/Overlays/` | Superposiciones de anotación | `StickyNoteView`, `PencilCanvasOverlay`, `HighlightRendererView` |
| `Views/Components/` | UI reutilizable | `CustomToolBar`, `ColorPalettePicker` |
| `Resources/` | Fuentes incrustadas, assets | `Caveat-Regular.ttf`, `Assets.xcassets` |

> **Diferido (fase posterior):** `Services/Storage/CloudSyncMonitor` se introducirá cuando se reactive la sincronización. En v1 no existe, no se inicializa y su ausencia no debe modelarse como un estado "sin red" pendiente.

### 2.3 Distribución del sandbox

| Ruta | Propósito | ¿Sincronizado? |
| --- | --- | --- |
| `Application Support/Documents/<UUID>.<ext>` | Binarios originales importados | No (local del dispositivo) |
| `Application Support/Thumbnails/<UUID>.png` | Miniaturas de portada | No |
| `Caches/<UUID>/` | HTML/CSS/imágenes extraídos del EPUB | No (regenerable) |
| Almacén SwiftData (ubicación del sistema) | Todas las entidades siguientes | **No** (local en v1; sincronización diferida) |

---

## 3. Modelo de Datos

### 3.1 Entidades canónicas (esquema SwiftData autoritativo)

Estos nombres y nombres de campos son la fuente de verdad. El esquema evita atributos únicos y mantiene relaciones opcionales o con valor por defecto. **Ninguna entidad está conectada a una base de datos CloudKit en v1**; reactivar la sincronización futura exige una migración explícita.

```swift
@Model final class FolderEntity {
    var id: UUID = UUID()
    var name: String = "Nueva Carpeta"
    var colorHex: String = "#5AC8FA"
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DocumentItem.folder)
    var documents: [DocumentItem]? = []
}

@Model final class DocumentItem {
    var id: UUID = UUID()
    var title: String = ""
    var fileTypeRaw: String = "pdf"          // "pdf" | "epub" | "md"
    var fileExtension: String = "pdf"        // minúsculas, sin punto
    var localFileName: String = ""           // "UUID.<ext>" en el sandbox
    var fileSize: Int64 = 0
    var contentHash: String = ""             // SHA-256 de los bytes originales (hex)
    var lastReadLocator: Data = Data()       // localizador estable codificado en JSON
    var lastReadPageIndex: Int = 0           // SOLO PISTA de visualización — véase §3.4
    var totalPages: Int = 1                  // SOLO PISTA para reflowable
    var paginationModeRaw: String = "horizontal" // "horizontal" | "vertical"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var folder: FolderEntity?

    @Relationship(deleteRule: .cascade, inverse: \PageAnnotation.document)
    var annotations: [PageAnnotation]? = []
}

@Model final class PageAnnotation {
    var id: UUID = UUID()
    var pageIndex: Int = 0                   // PISTA de visualización para PDFs; 0 para reflowable

    @Attribute(.externalStorage)
    var drawingData: Data? = nil             // PKDrawing.dataRepresentation()

    var document: DocumentItem?

    @Relationship(deleteRule: .cascade, inverse: \TextHighlight.pageAnnotation)
    var highlights: [TextHighlight]? = []

    @Relationship(deleteRule: .cascade, inverse: \StickyNoteEntity.pageAnnotation)
    var stickyNotes: [StickyNoteEntity]? = []
}

@Model final class TextHighlight {
    var id: UUID = UUID()
    var colorHex: String = "#FFEB3B"
    var selectedText: String = ""
    var anchorPayload: Data = Data()         // localizador específico del formato, JSON
    var anchorFormatRaw: String = "pdf"      // "pdf" | "markdown" | "epub"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var pageAnnotation: PageAnnotation?
}

@Model final class StickyNoteEntity {
    var id: UUID = UUID()
    var text: String = ""
    var colorTheme: String = "yellow"        // "yellow" | "pink" | "blue" | "green"
    var normalizedX: Double = 0.5            // 0..1 en el espacio del viewport
    var normalizedY: Double = 0.5
    var width: Double = 180.0                // tamaño base; redimensionable en runtime (futuro)
    var height: Double = 140.0
    var rotationAngle: Double = 0.0          // grados, ±3.0 estético
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var pageAnnotation: PageAnnotation?
}
```

### 3.2 Reconciliación de nombres

| Nombre en borrador previo | Nombre canónico | Motivo |
| --- | --- | --- |
| `rotationDegrees` | `rotationAngle` | Coherencia con el código de `especifications-2.md` |
| `fileTypeRaw` solo | `fileTypeRaw` + `fileExtension` | `fileExtension` simplifica la lógica de exportación |
| `lastReadPageIndex` solo | `lastReadLocator: Data` + `lastReadPageIndex` (pista de visualización) | Los localizadores estables no se pueden reducir a un índice de página |
| `contentHash` ausente | `contentHash` en `DocumentItem` | Detectar deriva de contenido local entre dispositivos (sentará base cuando se reactive la sync) |
| `updatedAt` ausente en resaltado/nota | `updatedAt` en `TextHighlight` y `StickyNoteEntity` | Necesario para la resolución de conflictos LWW cuando se reactive la sync |
| `colorThemeRaw` | `colorTheme` | Coherencia |
| `anchorData` | `anchorPayload` + `anchorFormatRaw` | El discriminador de formato debe ser explícito |

### 3.3 Cargas del localizador por formato (`anchorPayload`)

Todas las cargas se codifican en JSON dentro de `Data`. El discriminador es `anchorFormatRaw`.

| Formato | Forma del JSON | Estabilidad |
| --- | --- | --- |
| `pdf` | `{"page":Int,"rects":[[x,y,w,h],…],"quads":[[x,y,…],…]}` donde x/y/w/h están normalizados 0..1 al `MediaBox` de la página | Estable; el PDF es de layout fijo |
| `markdown` | `{"contentHash":String,"range":{"location":Int,"length":Int},"blockPath":[Int,…]}` | Estable entre viewports; se invalida cuando `contentHash` difiere |
| `epub` | `{"cfi":String,"fallbackRange":String?}` | Estable entre viewports; cae al Range serializado si el CFI falla |

Reglas de validación al cargar:

- **PDF:** los rects deben estar en `[0,1]`. Si están fuera de rango o cambió el número de páginas, el resaltado se oculta y se muestra en una lista de "revisión".
- **Markdown:** si `contentHash` no coincide con el documento actual, el resaltado se oculta y se marca.
- **EPUB:** si el CFI no se resuelve, se cae al Range serializado; si ninguno resuelve, se oculta y se marca.

### 3.4 Espacios de coordenadas

| Capa | Espacio de coordenadas de almacenamiento | Espacio de coordenadas de renderizado | Notas |
| --- | --- | --- | --- |
| Resaltado de texto PDF | **Espacio del documento PDF**, normalizado 0..1 al `MediaBox` de la página | Se convierte al espacio de vista mediante `PDFView.convert(_:to:)` | El origen de PDFKit está abajo a la izquierda |
| Tinta PencilKit (`drawingData`) | **Espacio del canvas PencilKit** (origen abajo a la izquierda, puntos), anclado al viewport | Se reproduce dentro de un `PKCanvasView` dimensionado al viewport | Cambiar de página carga un `PKDrawing` nuevo |
| Post-it | **Rect del viewport de página**, normalizado 0..1 del área de contenido renderizado | `(normalizedX * viewportWidth, normalizedY * viewportHeight)` | Sobrevive a rotación y Split View |
| Resaltado Markdown | `NSRange` en el texto fuente + `blockPath` | Se relocaliza recorriendo el AST y rehaciendo el layout | Inherentemente reflowable |

**Regla:** nunca mezclar espacios de coordenadas. La conversión vive en tipos `*CoordinateConverter` por motor. Cualquier valor que cruce el límite de una capa se convierte explícitamente y el espacio de origen se registra junto a él.

### 3.5 Invariantes de unicidad

| Invariante | Dónde se aplica | Motivo |
| --- | --- | --- |
| `DocumentItem.localFileName` es único en el sandbox de la app | `FileStorageService.importDocument(_:)` genera `<UUID>.<ext>` y rechaza colisiones | El nombre basado en UUID da unicidad por construcción |
| `DocumentItem.id` es único por app (UUID generado al insertar) | Generado por SwiftData al insertar | Identificación estable; preserva la ruta hacia una futura sincronización |
| `DocumentItem.contentHash` coincide con los bytes del archivo en disco | Se recalcula al importar | Detección de deriva local |
| `(documentId, anchorFormatRaw, anchorPayloadHash)` es único por app | Guardia de inserción en el contexto del modelo | Evita duplicados por replays LWW |

**No se usa `@Attribute(.unique)`.** Esta restricción se mantiene por dos motivos: (a) los mensajes de error son más expresivos cuando la validación vive en la capa de aplicación, y (b) el esquema queda listo para una fase de sincronización futura sin reescritura.

### 3.6 Comportamiento ante conflictos (diferido)

> **Esta sección describe un comportamiento previsto para una fase posterior. v1 no tiene sincronización, por lo que no existen escenarios de conflicto entre dispositivos.** Se conserva como referencia de diseño y para que la implementación futura parta de una línea base explícita.

Cuando se reactive la fase de sincronización entre dispositivos (CloudKit privado), se aplicarán las reglas siguientes. Hasta entonces, el orden de escritura sobre el mismo dispositivo lo gestiona SwiftData de forma natural.

| Tipo de conflicto | Comportamiento previsto |
| --- | --- |
| Cambio de metadatos en cualquier lado (título, carpeta, lastReadLocator) | LWW por `updatedAt`; desempate: comparación determinista del id de registro |
| Dos `TextHighlight` distintos insertados a la vez con hash de anclaje igual en la misma página | Se conservan ambos; se deduplican en la UI por `(colorHex, selectedText, anchorHash)`; el usuario decide fusionar o borrar |
| Dos ediciones al mismo `TextHighlight` estando desconectado | LWW por `updatedAt`; al abrir de nuevo, se muestra una insignia de "revisar cambios" vinculada a la versión previa, guardada como `previousAnchorPayload: Data?` (campo que se introducirá junto con la fase de sync) |
| Dos dibujos de tinta distintos en la misma página en dos dispositivos | LWW por el `updatedAt` asociado a `drawingData`; el dispositivo que pierde muestra un aviso único: "tu tinta libre en esta página fue reemplazada por una versión más reciente desde otro dispositivo" |
| Binarios (CKAsset) | LWW por `updatedAt` de subida; los binarios antiguos se purgan tras 30 días desde CloudKit |

---

## 4. Motores de Formato

### 4.1 Comparación de motores

| Aspecto | Motor PDF | Motor Markdown | Motor EPUB |
| --- | --- | --- | --- |
| Tecnología base | `PDFKit` (`PDFView`, `PDFDocument`) | AST de `swift-markdown` + TextKit 2 (`NSTextLayoutManager`) | `WKWebView` + CSS Multi-Column + puente JS |
| Paginación | Preferencia por documento: horizontal con `displayMode = .singlePage`, `displayDirection = .horizontal`, `usePageViewController(true)`; vertical con scroll continuo | Preferencia por documento: `TabView` paginado horizontal o `ScrollView` vertical sobre las páginas calculadas | Preferencia por documento: columnas CSS a 100vw con desplazamiento horizontal controlado por JS o flujo vertical con scroll habilitado |
| Gesto de cambio de página | Swipe nativo de `UIPageViewController` | SwiftUI `TabView(selection:)` con `.page(indexDisplayMode: .never)` | `window.scrollTo(left = pageIndex * innerWidth)` en JS disparado por Swift |
| Localizador estable de resaltados | `(pageIndex, [CGRect] normalizado)` | `(contentHash, NSRange, blockPath)` | Cadena CFI con Range DOM de respaldo |
| Superficie para tinta | Overlay `PKCanvasView` por página | Overlay `PKCanvasView` por "página" ordinal derivada del `NSRange` (Fase 1) | Overlay `PKCanvasView` por segmento de viewport resuelto por CFI |

### 4.2 Motor PDF

- `PDFView` se envuelve en `UIViewRepresentable`. Los gestos del Pencil se enrutan al canvas de superposición (véase §5) en lugar del PDFView.
- Conversión de coordenadas: pantalla → punto PDF → rect normalizado en `MediaBox`.
- En modo horizontal, `usePageViewController(true)` aporta swipe nativo con inercia; en modo vertical, el lector usa desplazamiento continuo.
- Se admite `autoScales = true` con zoom por pinza; el zoom no invalida los rects de resaltado porque están normalizados.

### 4.3 Motor Markdown

1. Leer el `.md` desde el sandbox.
2. Parsear con `swift-markdown` a un AST.
3. Renderizar a `NSAttributedString` con tipografía consistente (fuente, interletrado, espaciado de párrafo).
4. Calcular el tamaño del viewport a partir de las insets del área segura del lector menos los márgenes.
5. En bucle, asignar `NSTextContainer(size: viewport)` y pedir a `NSTextLayoutManager` el rango que llena el contenedor sin dividir párrafos entre contenedores cuando sea evitable.
6. Persistir `[(NSRange, containerIndex)]` por documento; exponer el `pageIndex` ordinal solo para visualización.
7. Mostrar los contenedores en `TabView(selection:)` para el modo horizontal o en `ScrollView` para el modo vertical, según la preferencia persistida del documento.
8. La búsqueda de resaltados se hace por `NSRange` dentro del contenido con `contentHash` coincidente; si el archivo cambió, el resaltado se oculta y se lista para revisión.
9. La tinta se persiste por "página" ordinal en Fase 1 con la salvedad de que la re-paginación (cambio de tamaño de fuente) desplaza los dibujos; la especificación lo acepta y deja como mejora Fase 2+ la ruta "reflow safe".

### 4.4 Motor EPUB

1. **Descompresión segura** (§5) en `Caches/<UUID>/`.
2. Leer `META-INF/container.xml` para localizar el OPF.
3. Parsear el OPF para enumerar los items del spine (orden de lectura).
4. Inyectar CSS según la preferencia de lectura: columnas horizontales a 100vw o flujo vertical con scroll habilitado.
5. Hacer de puente mediante `WKScriptMessageHandler` para exponer: índice de página actual, número de páginas, petición de salto a índice, captura de selección de texto (range → CFI).
6. **Seguridad:** `WKWebView` se configura con `allowFileAccessFromFileURLs = false`, `allowUniversalAccessFromFileURLs = false`. El HTML del lector se carga desde un directorio aislado por documento. La navegación entre documentos está desactivada.

### 4.5 Pipeline de anotación (neutro al motor)

Por cada evento de cambio de página:

1. Persistir el `drawingData` (PencilKit) de la página saliente y cualquier edición pendiente de post-it en SwiftData.
2. Cargar el `PageAnnotation` de la página entrante (lazy).
3. Reproducir el `PKDrawing` en el canvas de superposición.
4. Reaplicar los post-its en `(normalizedX * viewportWidth, normalizedY * viewportHeight)`.
5. Reaplicar los resaltados semánticos re-resolviendo su localizador en el espacio del motor.

---

## 5. Seguridad y Disponibilidad de Archivos

### 5.1 Descompresión segura de EPUB (`EPUBSandboxValidator`)

| Comprobación | Acción ante fallo |
| --- | --- |
| Nombre de entrada ZIP con `..`, ruta absoluta o NUL | Rechazar el EPUB completo |
| Nombre de entrada que escapa del directorio destino tras normalizar | Rechazar |
| `Content-Type` fuera de la lista permitida `text/html`, `text/css`, `image/png`, `image/jpeg`, `image/gif`, `image/svg+xml`, `application/xhtml+xml`, `application/xml` | Saltar entrada; registrar en advertencias |
| Etiqueta `<script>` encontrada en cualquier HTML/XHTML tras la extracción | Quitar la etiqueta y los manejadores en línea; registrar advertencia |
| Manejadores en línea `on*` en HTML | Quitar; registrar advertencia |
| URLs `javascript:` en `href`/`src` | Quitar; registrar advertencia |

El árbol descomprimido vive en `Caches/<UUID>/` y se regenera si falta.

### 5.2 Aislamiento del WebView

| Ajuste | Valor |
| --- | --- |
| `WKWebView.allowFileAccessFromFileURLs` | `false` |
| `WKWebView.allowUniversalAccessFromFileURLs` | `false` |
| `WKPreferences.javaScriptCanOpenWindowsAutomatically` | `false` |
| Navegación entre documentos | Desactivada vía `WKNavigationDelegate` |
| Canales de `WKScriptMessageHandler` | Solo nombres en lista permitida: `pageChange`, `selectionCapture`, `jumpToPage` |

### 5.3 Disponibilidad de archivos entre dispositivos (diferida)

> **Esta sección describe un comportamiento previsto para una fase posterior. v1 no tiene sincronización entre dispositivos ni subida de binarios a la nube.** Se conserva el diseño para que la fase futura tenga una línea base explícita; ningún menú, ningún botón ni ninguna ruta de código la activa en v1.

- **Predeterminado (previsto para la fase de sync futura):** los binarios serán locales del dispositivo. La biblioteca mostrará cada documento en el dispositivo que lo importó. Los demás dispositivos verán solo los metadatos y mostrarán "No descargado en este dispositivo".
- **Subida opt-in (prevista):** el usuario pulsará "Hacer disponible en mis otros dispositivos" en el menú contextual del documento. La app:
  1. Calculará `contentHash` si no estaba.
  2. Aplicará la migración de la fase de sync y subirá el binario como `CKAsset` mediante la nueva entidad de disponibilidad.
  3. Registrará `contentAssetUploadedAt: Date` en esa entidad.
- **Descarga (prevista):** en otro dispositivo, la biblioteca detectará un asset de disponibilidad migrado para un documento ausente localmente y ofrecerá "Descargar" con tamaño y progreso.
- **Revocación (prevista):** "Eliminar de iCloud" borrará el `CKAsset` pero conservará los metadatos.

En v1 **no existe** ninguna de estas cuatro rutas: ni predeterminado cross-device, ni subida opt-in, ni descarga, ni revocación. El menú contextual del documento no muestra esas opciones. v1 **no implementa** ninguna ruta de backup remoto, restauración manual ni exportación a un servidor propio.

---

## 6. Entrega por Fases

Cada fase termina con criterios de aceptación ejecutables y medibles. Las fases son secuenciales; las posteriores pueden solaparse una vez firmada la anterior. La numeración refleja el orden de entrega real: la fase de sincronización (CloudKit, `CKAsset`, monitor de sync) **no** forma parte de v1 y queda reservada para una fase posterior con su propia rúbrica.

### Fase 1 — Configuración del proyecto, modelo de datos local, shell de biblioteca

| Tarea | Entregable concreto |
| --- | --- |
| Inicializar proyecto Xcode | Target iPadOS 26+; solo orientaciones iPad; **sin** capability iCloud, **sin** capability CloudKit, **sin** Background Modes (Remote Notifications); interfaz Liquid Glass |
| Definir entidades | Los cinco archivos `@Model` compilan sin advertencias; no usan atributos únicos, todas las relaciones son opcionales o con valor por defecto, y `DocumentItem.paginationModeRaw` empieza en `"horizontal"` |
| Contenedor | `ModelContainer` SwiftData **local**; el `ModelConfiguration` no declara ninguna opción de sincronización remota |
| Monitor de sync | **No existe en v1.** No se inicializa ningún `CloudSyncMonitor` ni equivalente; ningún código lo busca ni lo publica |
| Shell de biblioteca | `LibraryGridView` muestra una carpeta y un documento de prueba |

**Criterios de aceptación:**

1. `xcodebuild -scheme InSummary -destination 'generic/platform=iOS Simulator' build` finaliza sin advertencias relacionadas con el esquema de datos, y el binario resultante **no** incluye entitlements de iCloud, CloudKit ni `aps-environment` (push notifications).
2. En un iPad real, crear una carpeta + documento persiste entre reinicios de la app **sin** red y **sin** sesión de iCloud iniciada.
3. El shell de biblioteca crea y muestra una carpeta y un documento semilla, y ambos persisten localmente con el dispositivo en modo avión. La importación, lectura, anotación y exportación se validan en sus fases posteriores.
4. Búsqueda en el código por `cloudKit`, `CKContainer`, `CKDatabase`, `CKAsset`, `NSPersistentCloudKitContainer`, `cloudKitDatabase`, `CloudSyncMonitor`, `RemoteNotification` devuelve **cero** ocurrencias en código de producto. (Las menciones en este documento de especificación no cuentan.)
5. La app se instala y firma con un perfil personal / de desarrollo sin membresía de Apple Developer Program.

### Fase 2 — Motor PDF + tinta PencilKit

| Tarea | Entregable concreto |
| --- | --- |
| Lector PDF | `PDFReaderCoordinator` abre PDFs en modo horizontal paginado o vertical continuo según la preferencia del lector |
| Overlay de tinta | `PencilCanvasOverlay` con `drawingPolicy = .pencilOnly`, herramienta por defecto `.highlighter` |
| Persistencia al cambiar página | En `PDFViewPageChangedNotification`, guardar el `PKDrawing` de la página anterior, cargar el `drawingData` de la siguiente |

**Criterios de aceptación:**

1. Abrir un PDF de 20 páginas; en modo horizontal, el swipe cambia de página con la transición nativa de `PDFView`; en modo vertical, el desplazamiento continuo recorre el documento.
2. Dibujar en la página 1, navegar a la página 2 (en blanco), dibujar en la 2, volver a la 1 — los trazos originales se conservan byte a byte.
3. La preferencia de paginación horizontal o vertical se conserva al cerrar y volver a abrir el documento.
4. `PencilCanvasOverlay` ignora los toques con el dedo; solo dibuja el Pencil.

### Fase 3 — Motores Markdown y EPUB

| Tarea | Entregable concreto |
| --- | --- |
| Parser y paginador Markdown | `MarkdownParser` + `MarkdownPaginator` producen `[(NSRange, Int)]`; se renderizan en `TabView(selection:)` horizontal o `ScrollView` vertical según la preferencia del lector |
| Descompresión segura EPUB | `EPUBSandboxValidator` pasa el corpus de pruebas (casos table-driven) |
| Inyección CSS EPUB | Columnas 100vw para modo horizontal o flujo vertical para modo vertical; puente JS para índice de página y selección de texto |
| Progreso de lectura | `lastReadLocator` (`NSRange` codificado para MD, CFI codificado para EPUB) persiste por documento |

**Criterios de aceptación:**

1. Un archivo Markdown de 5 KB pagina en ≥ 1 página al tamaño de fuente por defecto y en ≥ 1 página (posible número distinto) al +20% de fuente; ningún párrafo se corta a mitad de línea en ningún caso.
2. El mismo documento Markdown se puede leer en `TabView` horizontal y en `ScrollView` vertical; la preferencia elegida se conserva al volver a abrirlo.
3. Un EPUB del corpus de pruebas carga los capítulos del spine en orden; la navegación horizontal entre páginas y el desplazamiento vertical continuo funcionan según la preferencia elegida.
4. Reanudar un documento restaura al `NSRange` exacto (MD) o al CFI exacto (EPUB).
5. `EPUBSandboxValidator` rechaza el corpus malicioso de EPUBs (path traversal, inyección de `<script>`, tipos no permitidos).

### Fase 4 — Post-its y resaltado semántico

| Tarea | Entregable concreto |
| --- | --- |
| Overlay de post-it | `StickyNoteView` con colores pastel, gesto de arrastre que actualiza `normalizedX/Y`, `TextEditor` con Scribble |
| Resaltados semánticos | PDF: capturar `PDFSelection.bounds` → rects normalizados; MD: capturar `NSRange`; EPUB: capturar CFI |
| Modos de herramienta | Conmutador `Navigation` / `Pencil` / `Highlight` / `Eraser` |

**Criterios de aceptación:**

1. Un post-it nuevo aparece en el punto de toque, persiste entre cambios de página y sobrevive a rotación y cambios de tamaño en Split View (verificación manual con dos tamaños de ventana).
2. Seleccionar texto en cualquier motor y elegir un color crea un `TextHighlight` que reaparece al reabrir el documento.
3. Cambiar de herramienta deshabilita la entrada del Pencil en modo Navegación y deshabilita la selección de texto en modo Pencil.

### Fase 5 — Biblioteca, importación, exportación

| Tarea | Entregable concreto |
| --- | --- |
| Importación | `.fileImporter` admite `.pdf`, `.epub`, `.md`; copia a `Application Support/Documents/<UUID>.<ext>`; rechaza duplicados por `contentHash` |
| Miniaturas | PDF: `PDFPage.thumbnail(of:size:)`; EPUB: portada del OPF; MD: render de fragmento de texto |
| Carpetas | Crear / renombrar / borrar carpetas; arrastrar documentos entre carpetas |
| Exportación | PDF con marcas quemadas (rasterizador del motor PDF + composición); resumen `.md` de resaltados + post-its |

**Criterios de aceptación:**

1. Importar el mismo archivo dos veces produce una única entrada de biblioteca con un único `contentHash`; la segunda importación se rechaza con un mensaje claro.
2. Exportar un PDF con tinta + resaltados + post-its produce un PDF válido donde las marcas son visibles en lectores estándar.
3. Exportar un resumen `.md` produce un archivo legible que lista los resaltados y post-its con localizadores estables.
4. Tras importar y exportar localmente, los bytes relevantes vuelven a coincidir con el original (`contentHash` se mantiene) y no se ha realizado ninguna petición de red.

### Fase 6 — Pulido, accesibilidad y estabilidad

| Tarea | Entregable concreto |
| --- | --- |
| Temas de lectura | Temas Claro, Sepia, Oscuro por documento |
| Modo inmersivo | Tocar el centro oculta los chrome |
| Multiwindow | Dos ventanas abren dos documentos distintos simultáneamente |
| Accesibilidad | Etiquetas VoiceOver para todos los elementos interactivos; dynamic type hasta AX5 |
| Estabilidad | Sesión larga de lectura (60 min) sin crashes en hardware real |

**Criterios de aceptación:**

1. VoiceOver puede navegar la biblioteca, abrir un documento, colocar un post-it y leerlo de vuelta.
2. Abrir dos ventanas con documentos distintos y anotar cada uno persiste las anotaciones de forma independiente.
3. Una sesión de 60 minutos en un iPad real no produce crash ni la advertencia de iPadOS "usando demasiada memoria".
4. Cambiar de tema no invalida ningún localizador o coordenada almacenada.

### Fase posterior (no es v1) — Sincronización iCloud/CloudKit y subida opt-in del binario

> **Esta fase no entra en v1.** Se documenta para que el equipo conozca la forma prevista, pero **ninguno** de los criterios siguientes es un criterio de aceptación de v1.

- `ModelContainer` se conecta a una base de datos privada de CloudKit (`cloudKitDatabase: .private("iCloud.<team-bundle-id>")`).
- Se introduce `CloudSyncMonitor` con estados `idle`, `syncing`, `noNetwork`, `error`.
- Se reactiva el menú "Hacer disponible en mis otros dispositivos", la descarga, la revocación y los avisos de conflicto descritos en §3.6 y §5.3.
- Esta fase requerirá una membresía activa del Apple Developer Program para emitir entitlements iCloud válidos.

---

## 7. Estrategia de Pruebas

| Tipo de prueba | Alcance | Herramientas |
| --- | --- | --- |
| Pruebas unitarias | `MarkdownParser`, `MarkdownPaginator`, `PDFCoordinateConverter`, `EPUBSandboxValidator`, `EPUBManifestParser`, validación de anclajes por formato | XCTest, casos table-driven |
| Pruebas de snapshot | Renderizado de páginas Markdown y EPUB | `swift-snapshot-testing` (decisión Fase 6) |
| Pruebas de UI | Flujo de importación, navegación de biblioteca, crear/mover/borrar post-it, cambio de tema | XCUITest |
| Corpus de seguridad | 8–12 EPUBs hostiles (path traversal, scripts, tipos no permitidos, entradas sobredimensionadas) | Bundle de fixtures XCTest |
| Prueba de offline | Sesión completa de lectura + anotación + exportación con el dispositivo en modo avión | Manual + checklist en hardware real |
| Prueba manual de rendimiento | Latencia de tinta PencilKit, memoria bajo Instruments en una sesión de 30 minutos | Instruments, notas manuales |
| Accesibilidad | Recorrido VoiceOver, barrido de dynamic type | Manual + Xcode Accessibility Inspector |

**Regla para pruebas "manuales":** se registran como checklist con aprobado/fallo en hardware real antes de firmar la fase. No se afirman como garantías en el material dirigido al usuario.

> **Diferido (fase posterior):** la "prueba manual de sync entre dos dispositivos" que aparecía en borradores previos. No se ejecuta en v1 porque no hay sync. Cuando se introduzca la fase de sync volverá a esta tabla.

---

## 8. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
| --- | --- | --- | --- |
| El esquema SwiftData se vuelve incompatible con CloudKit si en el futuro se añade `@Attribute(.unique)` o una relación sin valor por defecto | Media | Alto (forzaría migración al reactivar sync) | La compatibilidad con CloudKit es una invariante del checklist de revisión (§B); cualquier cambio necesario se entrega como nueva versión de la entidad |
| Parser EPUB frágil ante entrada hostil | Alta | Medio | `EPUBSandboxValidator` bloquea path traversal, scripts y tipos no permitidos antes de cualquier renderizado |
| La re-paginación de Markdown desplaza los dibujos de tinta al cambiar el tamaño de fuente | Alta | Bajo | Se documenta la limitación; se enviará una superposición "reflow safe" en una fase posterior |
| Ediciones locales concurrentes al mismo dibujo de tinta (caso raro de multi-ventana) sobre el mismo dispositivo | Baja | Bajo | SwiftData serializa el orden de escritura; no hay pérdida silenciosa. Las fusiones a nivel de bytes siguen fuera del alcance |
| PDFKit no puede resolver rects normalizados tras un reflow (raro; los PDFs son de layout fijo) | Baja | Bajo | El validador marca "necesita revisión" cuando los rects salen de `[0,1]` |
| Uso indebido del puente JS del WKWebView que otorga capacidades no previstas | Baja | Alto | Nombres de mensaje en lista permitida; no se acepta `evaluateJavaScript` con código arbitrario del llamador; restricciones tipo CSP sobre el HTML extraído |
| Riesgo diferido (futura fase de sync): ediciones offline en dos dispositivos al mismo dibujo de tinta se sobrescriben en silencio | Media | Medio | Cuando se reactive la sync: LWW con aviso explícito "tu dibujo fue reemplazado"; se conserva la versión previa en el dispositivo durante un ciclo de sync |
| Riesgo diferido (futura fase de sync): los costes de almacenamiento de assets de CloudKit crecen con el tamaño de la biblioteca | Media | Media | Cuando se reactive la sync: solo opt-in; la UI muestra el tamaño estimado del asset antes de subir; el borrado purga los assets tras 30 días |

---

## 9. Fuera del Alcance (consolidado)

- Compartición multiusuario, comentarios, presencia.
- Sincronización entre dispositivos (iCloud/CloudKit) — **diferida a una fase posterior**.
- Subida o descarga de binarios como `CKAsset`, "Hacer disponible en mis otros dispositivos", disponibilidad de libros entre dispositivos — **diferidos con la sincronización**.
- Backend propio, restauración manual o copia de seguridad remota. v1 no implementa ni afirma ninguna ruta de backup remoto.
- Renderizado en servidor o sync más allá del sandbox local.
- Elusión de DRM o descifrado de contenido más allá de lo que EPUB/PDF permiten de forma nativa.
- Audio, video o widgets interactivos dentro de los documentos.
- Funciones de IA (resumen, OCR, Q&A).
- Conversión de formato (EPUB ↔ PDF, MD → PDF).
- Targets iPhone, Mac Catalyst o visionOS.
- Distribución pública en App Store con analítica sensible a privacidad.
- Colaboración en el dispositivo.

---

## 10. Preguntas Abiertas

Estas quedan diferidas intencionadamente; no bloquean v1 pero se registran para que los futuros colaboradores sepan que existen.

1. ¿Debería migrarse `lastReadLocator` a un tipo Swift `Codable` cuando SwiftData gane soporte nativo para enums (actualmente `Data` + JSON)?
2. **Diferido a la fase de sincronización futura:** ¿qué migración agregará la entidad de disponibilidad y su asset binario opt-in cuando se reactive la sincronización? v1 no incluye ese campo ni toma esta decisión.
3. ¿Deberían almacenarse los dibujos de tinta por página lógica o por instantánea de viewport? Decisión actual: por página lógica en PDF, por "página" ordinal en MD con la limitación documentada, por segmento CFI en EPUB.
4. ¿Debería el lector admitir carga de fuentes personalizadas más allá de la `Caveat-Regular.ttf` incrustada? Diferido — implicaciones de seguridad para archivos de fuente no confiables.
5. **(Nueva)** ¿Cuál es la rúbrica exacta (entitlements, identifier de contenedor, esquema de despliegue) para reactivar la fase de sincronización cuando se decida retomarla? Diferida hasta que se obtenga membresía del Apple Developer Program.

---

## Apéndice A — Requisitos de Info.plist

```xml
<key>UIAppFonts</key>
<array>
    <string>Caveat-Regular.ttf</string>
</array>

<key>UISupportsDocumentBrowser</key>
<false/>

<key>UIFileSharingEnabled</key>
<true/>

<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

> **v1 no requiere entitlements de iCloud, CloudKit ni APS (push notifications).** El archivo `.entitlements` del target está vacío o contiene únicamente entitlements ajenos a iCloud. Cualquier futura adición se justifica en el PR que reactive la fase de sincronización.

`UIPreferredFrameRateRangeMinimum` no se fija deliberadamente en esta especificación; la app se apoya en el comportamiento estándar de ProMotion sin prometer una tasa de frames.

## Apéndice B — Checklist de revisor

- [ ] Las no-objetivos de §1.3 se respetan en las tareas de cada fase.
- [ ] Las invariantes de §3.5 se aplican en `FileStorageService` y en los sitios de inserción.
- [ ] El motor EPUB de §4.4 nunca carga un `WKWebView` sin que `EPUBSandboxValidator` haya pasado.
- [ ] **No existe código activo de CloudKit/iCloud en v1.** Búsqueda por `cloudKit`, `CKContainer`, `CKAsset`, `NSPersistentCloudKitContainer`, `cloudKitDatabase`, `CloudSyncMonitor`, `RemoteNotification` devuelve cero coincidencias en código de producto.
- [ ] Los entitlements del target no incluyen iCloud, CloudKit ni `aps-environment`.
- [ ] El `ModelContainer` se construye sin `cloudKitDatabase:` y sin `NSPersistentCloudKitContainer`.
- [ ] Las menciones a CloudKit/iCloud en este documento están todas etiquetadas como "diferido" o "fase posterior".
- [ ] Los criterios de aceptación de §6 se ejercitan antes del sign-off de cada fase.
- [ ] La prueba de offline (modo avión) de §7 pasa en hardware real para el flujo completo de v1.
- [ ] Los riesgos de §8 tienen mitigaciones concretas en código, no solo en este documento.

---
