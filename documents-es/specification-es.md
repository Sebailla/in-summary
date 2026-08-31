# Especificación Técnica — Lector y Anotador Universal para iPad

**Proyecto:** In-Summary (Lector y Anotador Universal para iPad)
**Plataforma:** iPadOS 17.0+
**Lenguaje / Herramientas:** Swift 5.10 / Swift 6, Xcode 15 / 16
**Estado del documento:** Especificación canónica — sustituye a `especifications.md` y `especifications-2.md`
**Audiencia:** Revisores, futuros colaboradores y la persona que implementará

---

## Resumen de Decisiones

In-Summary es un entorno personal de lectura y estudio, basado en biblioteca local, para iPad. Permite importar documentos en **PDF**, **EPUB** y **Markdown**, paginarlos en horizontal, soportar dos modos de anotación (resaltado semántico de texto y tinta libre con Apple Pencil), superponer notas adhesivas flotantes persistentes y sincronizar los metadatos de las anotaciones mediante una base de datos privada de CloudKit. Los archivos originales permanecen en el dispositivo que los importó; los metadatos y las anotaciones viajan por iCloud.

| Área | Decisión |
|---|---|
| Capa de lectura | Shell de SwiftUI que aloja un motor por formato mediante `UIViewRepresentable` |
| Paginación | Horizontal forzada; nunca desplazamiento vertical dentro de un documento |
| Capas de anotación | Cuatro capas en orden Z (resaltados semánticos → tinta PencilKit → post-its → superposiciones de UI) |
| Persistencia | Entidades SwiftData `@Model` con base de datos privada de CloudKit; binarios locales, assets opcionales |
| Unicidad | Sin `@Attribute(.unique)`; la unicidad se aplica en la capa de aplicación al importar |
| Seguridad EPUB | Descompresión en sandbox con protección contra path traversal, lista permitida de tipos de contenido, `WKWebView` aislado por documento |
| Rendimiento | Sin objetivos absolutos de FPS, latencia ni RAM; verificación manual de fluidez en hardware real |

**Qué está dentro del alcance (v1):** lectura, paginación, anotación, post-its, organización en carpetas, exportación de PDF con marcas quemadas y resumen de notas en Markdown, y sincronización de anotaciones entre los dispositivos iCloud del propio usuario.

**Qué queda fuera del alcance (v1):** edición colaborativa, compartir libros o notas con otros usuarios, renderizado en servidor, funciones de IA, reproducción de audio/video, conversión de formatos (p. ej., EPUB → PDF), contenido protegido por DRM, factores de forma distintos de iPad.

**Contradicciones resueltas (esta sección sustituye a borradores previos):**

1. **CloudKit no distribuye los archivos del sandbox.** CloudKit solo sincroniza los registros de SwiftData. Los documentos originales permanecen en el sandbox del dispositivo que los importó. Para que un libro esté disponible en otro dispositivo, el usuario activa de forma explícita la subida de su binario como asset de CloudKit (almacenado como `CKAsset` en `DocumentItem.contentCKAsset`). Hasta que ese asset llegue al dispositivo, la entrada de biblioteca muestra "no descargado" y el lector rehúsa abrirla. Esto evita bibliotecas silenciosamente rotas y evita que assets pesados se suban automáticamente sin consentimiento.
2. **El contenido reflowable no admite `pageIndex` como localizador estable.** Markdown y EPUB reflowean con el viewport y el tamaño de fuente, lo que vuelve inestables los números de página. Los localizadores estables son:
   - **PDF** → `(pageIndex, normalizedQuads: [CGRect])` en el espacio del documento PDF.
   - **Markdown** → `NSRange(location, length)` más un `contentHash` para invalidar cuando cambia el origen.
   - **EPUB** → una cadena **CFI** (Canonical Fragment Identifier) de EPUB 3, con serialización de Range DOM como respaldo si falla la generación de CFI.
   `pageIndex` se conserva solo como **pista de visualización** y como puntero de navegación; el anclaje canónico de los resaltados es específico del formato.
3. **Los espacios de coordenadas de anotación son explícitos y por capa.** Véase §3.4.
4. **La unicidad de SwiftData se aplica en la capa de aplicación**, no mediante `@Attribute(.unique)`, porque los esquemas compatibles con CloudKit prohíben restricciones de unicidad. Véase §3.5.
5. **La resolución de conflictos es el último escritor gana por registro** con `updatedAt` como desempate. Las fusiones a nivel de bytes en PencilKit quedan explícitamente fuera del alcance; los usuarios verán un aviso de "dos versiones" únicamente cuando ambos dispositivos editaron el mismo anclaje de texto de `TextHighlight` dentro de la ventana de cuota de CloudKit.
6. **Sin garantías absolutas de rendimiento.** Borradores anteriores afirmaban 120 FPS, latencia inferior a 9 ms y techos de memoria. Se eliminan y se sustituyen por pasos cualitativos de verificación en hardware real con Instruments.

---

## Ruta rápida para revisores

1. Leer §1 (Alcance) y §2 (Arquitectura) para orientarse — 5 minutos.
2. Repasar las tablas de §3 (Modelo de datos) y §4 (Motores de formato) — 10 minutos.
3. Validar los criterios de aceptación de §6 (Entrega por fases) frente a la estrategia de pruebas de §7.
4. Verificar que nada de §9 (Fuera del alcance) se esté implementando en silencio.

---

## 1. Alcance, Usuarios y Restricciones

### 1.1 Descripción del producto

Una aplicación iPad basada en biblioteca que permite a un único usuario:

- Importar archivos `.pdf`, `.epub` y `.md` a una biblioteca privada en el dispositivo.
- Leer cada documento con **paginación horizontal forzada** (sin desplazamiento vertical dentro del documento).
- Resaltar texto de forma semántica (por carácter) y/o pintar tinta libre con Apple Pencil.
- Colocar notas adhesivas flotantes en cualquier página, editarlas con teclado o Scribble y reposicionarlas mediante gestos de arrastre.
- Organizar documentos en carpetas creadas por el usuario.
- Reanudar la lectura en el último localizador de cada documento.
- Exportar un PDF con la tinta y los resaltados quemados, más un resumen en Markdown de todas las anotaciones del documento.
- Sincronizar anotaciones y metadatos (no los binarios originales, salvo activación explícita) entre los dispositivos iCloud del propio usuario.

### 1.2 Restricciones

- **Plataforma:** solo iPadOS 17.0+. Sin iPhone, sin Mac Catalyst, sin visionOS.
- **Conectividad:** la lectura, las anotaciones y la organización de la biblioteca funcionan completamente sin conexión. La sincronización con CloudKit es oportunista y del mejor esfuerzo.
- **Sin servicios de terceros:** sin servidores propios, sin SDKs de analítica, sin SDKs de pago.
- **Sin elusión de DRM:** la aplicación no evade el DRM de tiendas ni de editoriales.

### 1.3 Fuera del alcance (v1)

| Fuera del alcance | Motivo de exclusión |
|---|---|
| Compartir libros con otros usuarios | La BD privada de CloudKit es monousuario; compartir exige otro modelo de almacenamiento |
| Anotaciones colaborativas | Igual que arriba; queda fuera hasta introducir compartición |
| Conversión de formato (EPUB→PDF, etc.) | Añade mucha complejidad y riesgo de propiedad/licencias |
| Reproducción de audio/video | Los motores de lectura son textuales |
| Resumen por IA / OCR | No en v1; se pueden añadir hooks sin romper el esquema |
| Almacenamiento de libros en la nube por defecto | Privacidad, coste de almacenamiento y exposición accidental de datos; solo opt-in |
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
│            │ Sync Monitor + EPUB Security + Disponibilidad       │        │
│            └─────────────────────────────────────────────────────┘        │
└─────────────────────────────────┬──────────────────────────────────────────┘
                                  │
┌─────────────────────────────────▼──────────────────────────────────────────┐
│                     CAPA DE DATOS Y PERSISTENCIA                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │              ModelContainer SwiftData (CloudKit-privado)            │  │
│  │  FolderEntity ─< DocumentItem ─< PageAnnotation ─< {TextHighlight,  │  │
│  │                                                       StickyNote}   │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│           │                                            │                   │
│           ▼                                            ▼                   │
│   Application Support/Documents/<UUID>.<ext>    CloudKit Private DB        │
│   (binarios originales, locales)                 (metadatos + assets opt-in)│
└────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Mapa de módulos

| Módulo | Responsabilidad | Tipos clave |
|---|---|---|
| `App/` | Punto de entrada, DI, cableado de capabilities | `UniversalReaderApp`, `DependencyContainer` |
| `Models/` | Entidades SwiftData | `FolderEntity`, `DocumentItem`, `PageAnnotation`, `TextHighlight`, `StickyNoteEntity` |
| `Services/Storage/` | E/S de archivos en sandbox, caché de miniaturas, monitor de sync | `FileStorageService`, `ThumbnailCache`, `CloudSyncMonitor` |
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

### 2.3 Distribución del sandbox

| Ruta | Propósito | ¿Sincronizado? |
|---|---|---|
| `Application Support/Documents/<UUID>.<ext>` | Binarios originales importados | No (local del dispositivo) |
| `Application Support/Thumbnails/<UUID>.png` | Miniaturas de portada | No |
| `Caches/<UUID>/` | HTML/CSS/imágenes extraídos del EPUB | No (regenerable) |
| Almacén SwiftData (ubicación del sistema) | Todas las entidades siguientes | Sí, vía BD privada de CloudKit |
| `CKAsset` en `DocumentItem.contentCKAsset` | Sincronización opt-in del binario del libro | Sí, solo cuando el usuario lo sube |

---

## 3. Modelo de Datos

### 3.1 Entidades canónicas (esquema SwiftData autoritativo)

Estos nombres y nombres de campos son la fuente de verdad. Borradores anteriores mezclaban nombres (p. ej., `rotationDegrees` vs. `rotationAngle`, `fileTypeRaw` vs. `fileExtension` ausente); los nombres canónicos se usan de aquí en adelante.

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
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Disponibilidad del libro entre dispositivos (Fase 2+). Cuando es nil,
    // el documento no está disponible en este dispositivo.
    @Attribute(.externalStorage)
    var contentCKAsset: Data? = nil

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
|---|---|---|
| `rotationDegrees` | `rotationAngle` | Coherencia con el código de `especifications-2.md` |
| `fileTypeRaw` solo | `fileTypeRaw` + `fileExtension` | `fileExtension` simplifica la lógica de exportación |
| `lastReadPageIndex` solo | `lastReadLocator: Data` + `lastReadPageIndex` (pista de visualización) | Los localizadores estables no se pueden reducir a un índice de página |
| `contentHash` ausente | `contentHash` en `DocumentItem` | Detectar deriva de contenido entre dispositivos |
| `updatedAt` ausente en resaltado/nota | `updatedAt` en `TextHighlight` y `StickyNoteEntity` | Necesario para la resolución de conflictos LWW |
| `colorThemeRaw` | `colorTheme` | Coherencia |
| `anchorData` | `anchorPayload` + `anchorFormatRaw` | El discriminador de formato debe ser explícito |

### 3.3 Cargas del localizador por formato (`anchorPayload`)

Todas las cargas se codifican en JSON dentro de `Data`. El discriminador es `anchorFormatRaw`.

| Formato | Forma del JSON | Estabilidad |
|---|---|---|
| `pdf` | `{"page":Int,"rects":[[x,y,w,h],…],"quads":[[x,y,…],…]}` donde x/y/w/h están normalizados 0..1 al `MediaBox` de la página | Estable; el PDF es de layout fijo |
| `markdown` | `{"contentHash":String,"range":{"location":Int,"length":Int},"blockPath":[Int,…]}` | Estable entre viewports; se invalida cuando `contentHash` difiere |
| `epub` | `{"cfi":String,"fallbackRange":String?}` | Estable entre viewports; cae al Range serializado si el CFI falla |

Reglas de validación al cargar:

- **PDF:** los rects deben estar en `[0,1]`. Si están fuera de rango o cambió el número de páginas, el resaltado se oculta y se muestra en una lista de "revisión".
- **Markdown:** si `contentHash` no coincide con el documento actual, el resaltado se oculta y se marca.
- **EPUB:** si el CFI no se resuelve, se cae al Range serializado; si ninguno resuelve, se oculta y se marca.

### 3.4 Espacios de coordenadas

| Capa | Espacio de coordenadas de almacenamiento | Espacio de coordenadas de renderizado | Notas |
|---|---|---|---|
| Resaltado de texto PDF | **Espacio del documento PDF**, normalizado 0..1 al `MediaBox` de la página | Se convierte al espacio de vista mediante `PDFView.convert(_:to:)` | El origen de PDFKit está abajo a la izquierda |
| Tinta PencilKit (`drawingData`) | **Espacio del canvas PencilKit** (origen abajo a la izquierda, puntos), anclado al viewport | Se reproduce dentro de un `PKCanvasView` dimensionado al viewport | Cambiar de página carga un `PKDrawing` nuevo |
| Post-it | **Rect del viewport de página**, normalizado 0..1 del área de contenido renderizado | `(normalizedX * viewportWidth, normalizedY * viewportHeight)` | Sobrevive a rotación y Split View |
| Resaltado Markdown | `NSRange` en el texto fuente + `blockPath` | Se relocaliza recorriendo el AST y rehaciendo el layout | Inherentemente reflowable |

**Regla:** nunca mezclar espacios de coordenadas. La conversión vive en tipos `*CoordinateConverter` por motor. Cualquier valor que cruce el límite de una capa se convierte explícitamente y el espacio de origen se registra junto a él.

### 3.5 Invariantes de unicidad

| Invariante | Dónde se aplica | Motivo |
|---|---|---|
| `DocumentItem.localFileName` es único en el sandbox de la app | `FileStorageService.importDocument(_:)` genera `<UUID>.<ext>` y rechaza colisiones | El nombre basado en UUID da unicidad por construcción |
| `DocumentItem.id` es único en todos los dispositivos | UUID, fijado al insertar | Requerido por CloudKit |
| `DocumentItem.contentHash` coincide con los bytes del archivo en disco | Se recalcula al importar | Detección de deriva |
| `(documentId, anchorFormatRaw, anchorPayloadHash)` es único por app | Guardia de inserción en el contexto del modelo | Evita duplicados por replays LWW |

**No se usa `@Attribute(.unique)`.** SwiftData compatible con CloudKit prohíbe atributos únicos; la unicidad se aplica en la capa de aplicación.

### 3.6 Comportamiento ante conflictos

CloudKit aplica el último escritor gana a nivel de registro. In-Summary aplica las siguientes reglas:

| Tipo de conflicto | Comportamiento |
|---|---|
| Cambio de metadatos en cualquier lado (título, carpeta, lastReadLocator) | LWW por `updatedAt`; desempate: comparación determinista del id de registro |
| Dos `TextHighlight` distintos insertados a la vez con hash de anclaje igual en la misma página | Se conservan ambos; se deduplican en la UI por `(colorHex, selectedText, anchorHash)`; el usuario decide fusionar o borrar |
| Dos ediciones al mismo `TextHighlight` estando desconectado | LWW por `updatedAt`; al abrir de nuevo, se muestra una insignia de "revisar cambios" vinculada a la versión previa, guardada como `previousAnchorPayload: Data?` (campo añadido en Fase 2) |
| Dos dibujos de tinta distintos en la misma página en dos dispositivos | LWW por el `updatedAt` asociado a `drawingData`; el dispositivo que pierde muestra un aviso único: "tu tinta libre en esta página fue reemplazada por una versión más reciente desde otro dispositivo" |
| Binarios (CKAsset) | LWW por `updatedAt` de subida; los binarios antiguos se purgan tras 30 días desde CloudKit |

---

## 4. Motores de Formato

### 4.1 Comparación de motores

| Aspecto | Motor PDF | Motor Markdown | Motor EPUB |
|---|---|---|---|
| Tecnología base | `PDFKit` (`PDFView`, `PDFDocument`) | AST de `swift-markdown` + TextKit 2 (`NSTextLayoutManager`) | `WKWebView` + CSS Multi-Column + puente JS |
| Paginación | `displayMode = .singlePage`, `displayDirection = .horizontal`, `usePageViewController(true)` | Paginador propio: texto → AST → `NSAttributedString` → `NSTextContainer` repetidos dimensionados al viewport | Columnas CSS a 100vw; `window.scrollTo` horizontal controlado por JS |
| Gesto de cambio de página | Swipe nativo de `UIPageViewController` | SwiftUI `TabView(selection:)` con `.page(indexDisplayMode: .never)` | `window.scrollTo(left = pageIndex * innerWidth)` en JS disparado por Swift |
| Localizador estable de resaltados | `(pageIndex, [CGRect] normalizado)` | `(contentHash, NSRange, blockPath)` | Cadena CFI con Range DOM de respaldo |
| Superficie para tinta | Overlay `PKCanvasView` por página | Overlay `PKCanvasView` por "página" ordinal derivada del `NSRange` (Fase 1) | Overlay `PKCanvasView` por segmento de viewport resuelto por CFI |

### 4.2 Motor PDF

- `PDFView` se envuelve en `UIViewRepresentable`. Los gestos del Pencil se enrutan al canvas de superposición (véase §5) en lugar del PDFView.
- Conversión de coordenadas: pantalla → punto PDF → rect normalizado en `MediaBox`.
- `usePageViewController(true)` aporta swipe horizontal nativo con inercia.
- Se admite `autoScales = true` con zoom por pinza; el zoom no invalida los rects de resaltado porque están normalizados.

### 4.3 Motor Markdown

1. Leer el `.md` desde el sandbox.
2. Parsear con `swift-markdown` a un AST.
3. Renderizar a `NSAttributedString` con tipografía consistente (fuente, interletrado, espaciado de párrafo).
4. Calcular el tamaño del viewport a partir de las insets del área segura del lector menos los márgenes.
5. En bucle, asignar `NSTextContainer(size: viewport)` y pedir a `NSTextLayoutManager` el rango que llena el contenedor sin dividir párrafos entre contenedores cuando sea evitable.
6. Persistir `[(NSRange, containerIndex)]` por documento; exponer el `pageIndex` ordinal solo para visualización.
7. La búsqueda de resaltados se hace por `NSRange` dentro del contenido con `contentHash` coincidente; si el archivo cambió, el resaltado se oculta y se lista para revisión.
8. La tinta se persiste por "página" ordinal en Fase 1 con la salvedad de que la re-paginación (cambio de tamaño de fuente) desplaza los dibujos; la especificación lo acepta y deja como mejora Fase 2+ la ruta "reflow safe".

### 4.4 Motor EPUB

1. **Descompresión segura** (§5) en `Caches/<UUID>/`.
2. Leer `META-INF/container.xml` para localizar el OPF.
3. Parsear el OPF para enumerar los items del spine (orden de lectura).
4. Inyectar CSS para forzar columnas horizontales a 100vw y desactivar el scroll vertical.
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
|---|---|
| Nombre de entrada ZIP con `..`, ruta absoluta o NUL | Rechazar el EPUB completo |
| Nombre de entrada que escapa del directorio destino tras normalizar | Rechazar |
| `Content-Type` fuera de la lista permitida `text/html`, `text/css`, `image/png`, `image/jpeg`, `image/gif`, `image/svg+xml`, `application/xhtml+xml`, `application/xml` | Saltar entrada; registrar en advertencias |
| Etiqueta `<script>` encontrada en cualquier HTML/XHTML tras la extracción | Quitar la etiqueta y los manejadores en línea; registrar advertencia |
| Manejadores en línea `on*` en HTML | Quitar; registrar advertencia |
| URLs `javascript:` en `href`/`src` | Quitar; registrar advertencia |

El árbol descomprimido vive en `Caches/<UUID>/` y se regenera si falta.

### 5.2 Aislamiento del WebView

| Ajuste | Valor |
|---|---|
| `WKWebView.allowFileAccessFromFileURLs` | `false` |
| `WKWebView.allowUniversalAccessFromFileURLs` | `false` |
| `WKPreferences.javaScriptCanOpenWindowsAutomatically` | `false` |
| Navegación entre documentos | Desactivada vía `WKNavigationDelegate` |
| Canales de `WKScriptMessageHandler` | Solo nombres en lista permitida: `pageChange`, `selectionCapture`, `jumpToPage` |

### 5.3 Disponibilidad de archivos entre dispositivos

- **Por defecto:** los binarios son locales del dispositivo. La biblioteca muestra cada documento en el dispositivo que lo importó. Los demás dispositivos ven solo los metadatos y muestran "No descargado en este dispositivo".
- **Subida opt-in:** el usuario pulsa "Hacer disponible en mis otros dispositivos" en el menú contextual del documento. La app:
  1. Calcula `contentHash` si no estaba.
  2. Sube el binario como `CKAsset` en `DocumentItem.contentCKAsset` (almacenado mediante `@Attribute(.externalStorage)` de SwiftData).
  3. Registra `contentAssetUploadedAt: Date` (campo de Fase 2).
- **Descarga:** en otro dispositivo, la biblioteca detecta un `contentCKAsset` no nulo para un documento ausente localmente y ofrece "Descargar" con tamaño y progreso.
- **Revocación:** "Eliminar de iCloud" borra el `CKAsset` pero conserva los metadatos.

Esta estrategia mantiene privada la biblioteca del usuario, evita consumo accidental de ancho de banda y aporta un modelo mental claro.

---

## 6. Entrega por Fases

Cada fase termina con criterios de aceptación ejecutables y medibles. Las fases son secuenciales; las posteriores pueden solaparse una vez firmada la anterior.

### Fase 1 — Configuración del proyecto, modelo de datos, monitor de sync

| Tarea | Entregable concreto |
|---|---|
| Inicializar proyecto Xcode | Target iPadOS 17+; solo orientaciones iPad; capabilities iCloud + CloudKit + Background Modes (Remote Notifications) activadas |
| Definir entidades | Los cinco archivos `@Model` compilan sin advertencias de esquema de CloudKit (sin atributos únicos, todas las relaciones opcionales o con valor por defecto) |
| Contenedor | `ModelContainer` configurado con `cloudKitDatabase: .private("iCloud.<team-bundle-id>")` |
| Monitor de sync | `CloudSyncMonitor` publica `idle`, `syncing`, `noNetwork`, `error` vía `@Observable` |
| Shell de biblioteca | `LibraryGridView` muestra una carpeta y un documento de prueba |

**Criterios de aceptación:**

1. `xcodebuild -scheme InSummary -destination 'generic/platform=iOS Simulator' build` finaliza con cero advertencias sobre el esquema de CloudKit.
2. En un iPad real, crear una carpeta + documento persiste entre reinicios de la app.
3. En dos iPads reales con la misma cuenta de iCloud, crear una carpeta en el dispositivo A aparece en el dispositivo B en ≤ 5 minutos estando ambos en línea. (Medido con cronómetro; no se promete como garantía.)
4. El monitor de sync muestra `noNetwork` al activar el modo avión.

### Fase 2 — Motor PDF + tinta PencilKit

| Tarea | Entregable concreto |
|---|---|
| Lector PDF | `PDFReaderCoordinator` abre PDFs con `singlePage`/`horizontal`/`usePageViewController` |
| Overlay de tinta | `PencilCanvasOverlay` con `drawingPolicy = .pencilOnly`, herramienta por defecto `.highlighter` |
| Persistencia al cambiar página | En `PDFViewPageChangedNotification`, guardar el `PKDrawing` de la página anterior, cargar el `drawingData` de la siguiente |

**Criterios de aceptación:**

1. Abrir un PDF de 20 páginas; el swipe horizontal cambia de página con la transición nativa de `PDFView`.
2. Dibujar en la página 1, deslizar a la página 2 (en blanco), dibujar en la 2, volver a la 1 — los trazos originales se conservan byte a byte.
3. No aparece scroll vertical dentro del lector.
4. `PencilCanvasOverlay` ignora los toques con el dedo; solo dibuja el Pencil.

### Fase 3 — Motores Markdown y EPUB

| Tarea | Entregable concreto |
|---|---|
| Parser y paginador Markdown | `MarkdownParser` + `MarkdownPaginator` producen `[(NSRange, Int)]`; se renderizan en `TabView(selection:)` |
| Descompresión segura EPUB | `EPUBSandboxValidator` pasa el corpus de pruebas (casos table-driven) |
| Inyección CSS EPUB | Columnas 100vw, sin scroll vertical, puente JS para índice de página y selección de texto |
| Progreso de lectura | `lastReadLocator` (`NSRange` codificado para MD, CFI codificado para EPUB) persiste por documento |

**Criterios de aceptación:**

1. Un archivo Markdown de 5 KB pagina en ≥ 1 página al tamaño de fuente por defecto y en ≥ 1 página (posible número distinto) al +20% de fuente; ningún párrafo se corta a mitad de línea en ningún caso.
2. Un EPUB del corpus de pruebas carga los capítulos del spine en orden; el scroll horizontal entre páginas es fluido; no hay scroll vertical.
3. Reanudar un documento restaura al `NSRange` exacto (MD) o al CFI exacto (EPUB).
4. `EPUBSandboxValidator` rechaza el corpus malicioso de EPUBs (path traversal, inyección de `<script>`, tipos no permitidos).

### Fase 4 — Post-its y resaltado semántico

| Tarea | Entregable concreto |
|---|---|
| Overlay de post-it | `StickyNoteView` con colores pastel, gesto de arrastre que actualiza `normalizedX/Y`, `TextEditor` con Scribble |
| Resaltados semánticos | PDF: capturar `PDFSelection.bounds` → rects normalizados; MD: capturar `NSRange`; EPUB: capturar CFI |
| Modos de herramienta | Conmutador `Navigation` / `Pencil` / `Highlight` / `Eraser` |

**Criterios de aceptación:**

1. Un post-it nuevo aparece en el punto de toque, persiste entre cambios de página y sobrevive a rotación y cambios de tamaño en Split View (verificación manual con dos tamaños de ventana).
2. Seleccionar texto en cualquier motor y elegir un color crea un `TextHighlight` que reaparece al reabrir el documento.
3. Cambiar de herramienta deshabilita la entrada del Pencil en modo Navegación y deshabilita la selección de texto en modo Pencil.

### Fase 5 — Biblioteca, importación, exportación, assets en la nube opt-in

| Tarea | Entregable concreto |
|---|---|
| Importación | `.fileImporter` admite `.pdf`, `.epub`, `.md`; copia a `Application Support/Documents/<UUID>.<ext>`; rechaza duplicados por `contentHash` |
| Miniaturas | PDF: `PDFPage.thumbnail(of:size:)`; EPUB: portada del OPF; MD: render de fragmento de texto |
| Carpetas | Crear / renombrar / borrar carpetas; arrastrar documentos entre carpetas |
| Exportación | PDF con marcas quemadas (rasterizador del motor PDF + composición); resumen `.md` de resaltados + post-its |
| Assets en la nube | "Hacer disponible en mis otros dispositivos" activa `contentCKAsset`; UI de descarga en los dispositivos receptores |

**Criterios de aceptación:**

1. Importar el mismo archivo dos veces produce una única entrada de biblioteca con un único `contentHash`; la segunda importación se rechaza con un mensaje claro.
2. Exportar un PDF con tinta + resaltados + post-its produce un PDF válido donde las marcas son visibles en lectores estándar.
3. Exportar un resumen `.md` produce un archivo legible que lista los resaltados y post-its con localizadores estables.
4. Tras activar la disponibilidad en la nube en el dispositivo A, el documento en el dispositivo B muestra "Descargar"; al pulsarlo produce una copia local byte-idéntica (`contentHash` coincide).

### Fase 6 — Pulido, accesibilidad y estabilidad

| Tarea | Entregable concreto |
|---|---|
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

---

## 7. Estrategia de Pruebas

| Tipo de prueba | Alcance | Herramientas |
|---|---|---|
| Pruebas unitarias | `MarkdownParser`, `MarkdownPaginator`, `PDFCoordinateConverter`, `EPUBSandboxValidator`, `EPUBManifestParser`, validación de anclajes por formato | XCTest, casos table-driven |
| Pruebas de snapshot | Renderizado de páginas Markdown y EPUB | `swift-snapshot-testing` (decisión Fase 6) |
| Pruebas de UI | Flujo de importación, navegación de biblioteca, crear/mover/borrar post-it, cambio de tema | XCUITest |
| Corpus de seguridad | 8–12 EPUBs hostiles (path traversal, scripts, tipos no permitidos, entradas sobredimensionadas) | Bundle de fixtures XCTest |
| Prueba manual de sync | Dos iPads reales con la misma cuenta de iCloud | Manual + checklist; no automatizable en CI |
| Prueba manual de rendimiento | Latencia de tinta PencilKit, memoria bajo Instruments en una sesión de 30 minutos | Instruments, notas manuales |
| Accesibilidad | Recorrido VoiceOver, barrido de dynamic type | Manual + Xcode Accessibility Inspector |

**Regla para pruebas "manuales":** se registran como checklist con aprobado/fallo en hardware real antes de firmar la fase. No se afirman como garantías en el material dirigido al usuario.

---

## 8. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Invalidación del esquema de CloudKit tras un cambio de modelo | Media | Alto (pérdida de datos) | Las invariantes compatibles con CloudKit se integran en el checklist de revisión; cualquier cambio necesario se entrega como nueva versión de la entidad |
| Parser EPUB frágil ante entrada hostil | Alta | Medio | `EPUBSandboxValidator` bloquea path traversal, scripts y tipos no permitidos antes de cualquier renderizado |
| La re-paginación de Markdown desplaza los dibujos de tinta al cambiar el tamaño de fuente | Alta | Bajo | Se documenta la limitación; se enviará una superposición "reflow safe" en una fase posterior |
| Ediciones offline en dos dispositivos al mismo dibujo de tinta se sobrescriben en silencio | Media | Medio | LWW con aviso explícito "tu dibujo fue reemplazado"; se conserva la versión previa en el dispositivo durante un ciclo de sync |
| Los costes de almacenamiento de assets de CloudKit crecen con el tamaño de la biblioteca | Media | Media | Solo opt-in; la UI muestra el tamaño estimado del asset antes de subir; el borrado purga los assets tras 30 días |
| PDFKit no puede resolver rects normalizados tras un reflow (raro; los PDFs son de layout fijo) | Baja | Bajo | El validador marca "necesita revisión" cuando los rects salen de `[0,1]` |
| Uso indebido del puente JS del WKWebView que otorga capacidades no previstas | Baja | Alto | Nombres de mensaje en lista permitida; no se acepta `evaluateJavaScript` con código arbitrario del llamador; restricciones tipo CSP sobre el HTML extraído |

---

## 9. Fuera del Alcance (consolidado)

- Compartición multiusuario, comentarios, presencia.
- Renderizado en servidor o sync más allá de CloudKit.
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
2. Cuando SwiftData gane migración ligera más allá de lo que CloudKit permite, ¿debería moverse `contentCKAsset` a una entidad separada `DocumentAvailability` para reducir el tamaño del payload por registro?
3. ¿Deberían almacenarse los dibujos de tinta por página lógica o por instantánea de viewport? Decisión actual: por página lógica en PDF, por "página" ordinal en MD con la limitación documentada, por segmento CFI en EPUB.
4. ¿Debería el lector admitir carga de fuentes personalizadas más allá de la `Caveat-Regular.ttf` incrustada? Diferido — implicaciones de seguridad para archivos de fuente no confiables.

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

`UIPreferredFrameRateRangeMinimum` no se fija deliberadamente en esta especificación; la app se apoya en el comportamiento estándar de ProMotion sin prometer una tasa de frames.

## Apéndice B — Checklist de revisor

- [ ] Las no-objetivos de §1.3 se respetan en las tareas de cada fase.
- [ ] Las invariantes de §3.5 se aplican en `FileStorageService` y en los sitios de inserción.
- [ ] El motor EPUB de §4.4 nunca carga un `WKWebView` sin que `EPUBSandboxValidator` haya pasado.
- [ ] La estrategia de disponibilidad de archivos de §5.3 se refleja en la UI de la biblioteca (sin documentos silenciosamente rotos).
- [ ] Los criterios de aceptación de §6 se ejercitan antes del sign-off de cada fase.
- [ ] La prueba manual de sync de §7 pasa en dos dispositivos reales con la misma cuenta de iCloud.
- [ ] Los riesgos de §8 tienen mitigaciones concretas en código, no solo en este documento.