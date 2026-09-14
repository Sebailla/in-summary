# Archivo — `pdf-reader-pencilkit-ink-recovery`

> Registro de archivo de la **Fase 2 de v1 de In-Summary**, el lector
> de PDF y la capa de tinta de PencilKit. El cambio fue aprobado, los
> cuatro PR hijos se fusionaron en verde en el rastreador y el
> rastreador se fusionó en `main`. El directorio de cambio de OpenSpec
> (`openspec/changes/pdf-reader-pencilkit-ink-recovery/`) ahora se
> archiva aquí; el árbol activo `openspec/changes/` ya no carga este
> cambio. El espejo en español se archivó concomitantemente en
> `documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/`.

## 1. Veredicto

- **Veredicto de la Fase 2**: ✅ **Aprobado** — los siete criterios de
  aceptación de la Fase 2 enumerados en `proposal.md` §"Acceptance" se
  cumplen.
- **PR rastreador**: PR #19 (`tracker/pdf-reader-pencilkit-ink-recovery`
  → `main`).
- **SHA final de la fusión en `main`**:
  `973415d508a4d22a788e0408558f7875313ad3c4`.
- **SHA de integración local del rastreador**: `e2f71fb`.
- **Paso de archivo**: tarea 5.5, realizado por esta rebanada (sin
  código de producto, sin pruebas, sin PBX, sin fixture, sin modelos,
  sin recursos modificados).

## 2. SHA final de la fusión en `main`

| Campo | Valor |
| --- | --- |
| Rama | `main` |
| SHA del commit de fusión (completo) | `973415d508a4d22a788e0408558f7875313ad3c4` |
| SHA del commit de fusión (corto) | `973415d` |
| PR rastreador | #19 (`tracker/pdf-reader-pencilkit-ink-recovery` → `main`) |
| Integración local del rastreador | `e2f71fb` |
| PR hijos acarreados | `#1 feat/pdf-fixture`, `#2 feat/pdf-engine`, `#3 feat/pencilkit-ink-overlay`, `#4 feat/pdf-reader-wiring` |
| Regla de topología lineal | Respetada — solo el rastreador se fusionó en `main` |

El SHA anterior es la cabeza canónica de `main` al cierre de la Fase 2
y es el objetivo de referencia para este archivo. Cualquier
re-verificación futura debe extraer
`973415d508a4d22a788e0408558f7875313ad3c4` de `main` para reproducir la
evidencia consolidada de la Fase 2.

## 3. Evidencia consolidada de pruebas

### 3.1 Suite completa de XCTest — 95/95 en verde

La suite completa de XCTest se ejecutó en el simulador
iPad Pro 13-inch (M5), iOS 26.5 (el destino configurado M4 iOS 26.0 no
está instalado en este equipo; la sustitución preserva el factor de
forma del iPad Pro 13-inch y el contrato de TDD estricto — documentado
en `apply-progress.md` a lo largo de las rebanadas 1–4). El fragmento
capturado es el registro exacto producido por `xcodebuild test` en la
rama del rastreador al cierre de la rebanada 4.

### Comando exacto

```text
xcodebuild test \
  -project InSummary.xcodeproj \
  -scheme InSummary \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
```

### Resultado observado — suite completa de XCTest, 95/95 en verde

```text
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

### 3.2 Desglose por suite

| Suite | Pruebas | Fase |
| --- | ---: | --- |
| `DocumentItemTests` | 16 | Fase 1 (sin cambios) |
| `FolderEntityTests` | 6 | Fase 1 (sin cambios) |
| `LibrarySeedServiceTests` | 6 | Fase 1 (sin cambios) |
| `PDFFixtureGeneratorTests` | 9 | **Rebanada 1** (`feat/pdf-fixture`) |
| `PageAnnotationTests` | 7 | Fase 1 (sin cambios) |
| `PersistenceControllerTests` | 4 | Fase 1 (sin cambios) |
| `PencilCanvasOverlayTests` | 7 | **Rebanada 3** (`feat/pencilkit-ink-overlay`) |
| `PDFPageChangeObserverTests` | 5 | **Rebanada 3** (`feat/pencilkit-ink-overlay`) |
| `PDFReaderCoordinatorTests` | 11 | **Rebanada 2** (`feat/pdf-engine`) |
| `ReaderIntegrationTests` | 2 | **Rebanada 4** (`feat/pdf-reader-wiring`) |
| `SampleBundleFixtureTests` | 5 | **Rebanada 1** (`feat/pdf-fixture`) |
| `StickyNoteEntityTests` | 9 | Fase 1 (sin cambios) |
| `TextHighlightTests` | 8 | Fase 1 (sin cambios) |
| **Total** | **95** | **0 fallos** |

### 3.3 Delta de pruebas (Fase 1 → Fase 2)

| Rebanada | Suite(s) | Pruebas añadidas |
| --- | --- | ---: |
| Rebanada 1 (`feat/pdf-fixture`) | `PDFFixtureGeneratorTests`, `SampleBundleFixtureTests` | 14 |
| Rebanada 2 (`feat/pdf-engine`) | `PDFReaderCoordinatorTests` | 11 |
| Rebanada 3 (`feat/pencilkit-ink-overlay`) | `PencilCanvasOverlayTests`, `PDFPageChangeObserverTests` | 12 |
| Rebanada 4 (`feat/pdf-reader-wiring`) | `ReaderIntegrationTests` | 2 |
| **Delta total Fase 2** | | **39** |
| Línea base Fase 1 (sin cambios) | `DocumentItemTests`, `FolderEntityTests`, `LibrarySeedServiceTests`, `PageAnnotationTests`, `PersistenceControllerTests`, `StickyNoteEntityTests`, `TextHighlightTests` | 56 |
| **Gran total** | | **95** |

### 3.4 Otros portones de integración

- **Barrido de guardas de grep** (`openspec/config.yaml`
  `guards.blocked_substrings_in_product_code` contra
  `InSummary/Services/PDFEngine/`, `InSummary/Services/AnnotationEngine/`
  e `InSummary/Views/Reader/`): cero coincidencias entre los 17 patrones
  de bloqueo. `rg` código de salida 1 (sin coincidencias). El barrido
  defensivo más amplio sobre todo el árbol de producción `InSummary/`
  también devuelve cero coincidencias. Comando completo del bloqueo y
  resultado por patrón registrados en `verification-es.md` §5.
- **Diff check**: limpio. Ruta canónica del fixture respetada
  (`InSummary/Resources/Fixtures/sample-bundle.pdf`, 48 474 bytes,
  SHA-256
  `2d0f772b75d928e469c3bdaa21aba01d1cb23e24773fe2f8851b687588c6d491`).
  Cada `PBXBuildFile` resuelve desde una `PBXSourcesBuildPhase` /
  `PBXResourcesBuildPhase` real. Sin referencias huérfanas. Invariantes
  de la Fase 1 preservados (`git diff main..HEAD -- InSummary/Models/`
  no reporta cambios).
- **Aceptación en modo avión**: aprobada por construcción. No existe
  ningún punto de llamada con capacidad remota en ningún archivo de la
  Fase 2; la suite de XCTest es independiente del tiempo (sin
  `Task.sleep`, sin `DispatchQueue.main.asyncAfter`, sin `Timer`, sin
  stub de `URLProtocol`).

## 4. Punteros al informe de verificación

El informe de verificación de la Fase 2 captura cada criterio de
aceptación con su prueba pin, el fragmento capturado del registro de
XCTest y el veredicto portón por portón. Tras el archivo, el informe
de verificación vive junto a este archivo bajo la misma raíz de
archivo.

| Artefacto | Ruta | Notas |
| --- | --- | --- |
| Informe de verificación (inglés) | `../../../../openspec/archive/pdf-reader-pencilkit-ink-recovery/verification.md` | Criterios de aceptación de la Fase 2 aprobado/reprobado por criterio con evidencia de soporte. |
| Informe de verificación (espejo en español) | `./verification-es.md` | Espejo fiel en español neutro profesional de `verification.md`. |

Las referencias cruzadas registradas en `verification-es.md` §8 (nota
de tarea diferida) y §6.4 (alcance del cierre) confirman que este paso
de archivo es la fuente autoritativa para el cierre de la Fase 2; el
archivo sustituye a la nota de tarea diferida que las rebanadas
anteriores llevaban.

## 5. Qué se archivó

El directorio completo de cambio de OpenSpec y su espejo en español se
movieron desde `changes/` hacia `archive/`. El contenido de abajo es
byte a byte idéntico al que estaba previamente en `changes/`, con las
únicas ediciones siendo el volteo de la casilla de la tarea 5.5 en
`tasks.md` / `tasks-es.md` (ahora ambas `[x]`) y la anexión de este
`archive.md` y `archive-es.md`.

### 5.1 Raíz del archivo en inglés

```text
openspec/archive/pdf-reader-pencilkit-ink-recovery/
├── README.md
├── archive.md                 (este archivo — espejo en este directorio)
├── apply-progress.md
├── design.md
├── proposal.md
├── tasks.md                   (tarea 5.5 volcada [ ] → [x])
├── verification.md
└── specs/
    ├── pdf-engine/spec.md
    ├── pdf-fixture/spec.md
    ├── pdf-reader-wiring/spec.md
    └── pencilkit-ink-overlay/spec.md
```

### 5.2 Raíz del archivo espejo en español

```text
documents-es/openspec/archive/pdf-reader-pencilkit-ink-recovery/
├── README-es.md
├── archive-es.md              (NUEVO, espejo fiel en español neutro)
├── design-es.md
├── proposal-es.md
├── tasks-es.md                (tarea 5.5 marcada [ ] → [x])
├── verification-es.md
└── specs/
    ├── pdf-engine/spec-es.md
    ├── pdf-fixture/spec-es.md
    ├── pdf-reader-wiring/spec-es.md
    └── pencilkit-ink-overlay/spec-es.md
```

## 6. Paso de archivo (tarea 5.5) — alcance y autoridad

### 6.1 Alcance

La tarea 5.5 es una **unidad de documentación** en manos de la fila
`<!-- sdd-owner: implementation -->`. El trabajo realizado es:

1. Voltear la fila `5.5` de `[ ]` a `[x]` en `tasks.md` (inglés) y en
   `tasks-es.md` (español), de modo que el artefacto de tarea
   persistido registra el paso de archivo como completado.
2. Crear los directorios vacíos `openspec/archive/` y
   `documents-es/openspec/archive/` y mover el directorio completo del
   cambio `pdf-reader-pencilkit-ink-recovery/` desde cada árbol
   `changes/` al árbol `archive/` correspondiente, dejando los árboles
   `changes/` vacíos (los directorios `changes/` vacíos se eliminaron
   en este repositorio de un solo cambio).
3. Autoría de `archive.md` (inglés) y `archive-es.md` (español) con
   este registro de archivo (SHA final de la fusión en `main`,
   punteros al informe de verificación, evidencia consolidada de
   pruebas).
4. Anexión de una entrada final a `apply-progress.md` (ahora viviendo
   en la raíz del archivo) documentando el paso de archivo.

### 6.2 Autoridad

- No se tocó código de producción bajo `InSummary/`.
- No se tocó ninguna prueba, PBX, binario del fixture, modelo ni
  recurso.
- No se emitió ningún `git commit`, `git push`, `git reset`, apertura
  de PR, cambio de rama ni `git mv`. El trabajo permanece solo en
  disco, en espera de la decisión de commit de la persona usuaria.
- No se emitió ningún `acquire` / `settle` / `reset` nativo de SDD. El
  token del intento retenido por el padre (registrado en
  `verification-es.md` §6.4 y en el cierre de la rebanada 5 de
  `apply-progress.md`) se preserva sin cambios.
- La edición se limita a las superficies de edición permitidas
  enumeradas en el prompt del padre.

### 6.3 Desviaciones

- **Ninguna.** La tarea 5.5 es un movimiento puramente documental; el
  prompt del padre autorizó `maintainer-authorized documentation
  archive` como el modo `size:exception` para esta unidad de trabajo.

## 7. Resumen del cierre de la Fase 2

La Fase 2 de v1 llega a `main` (PR #19, commit
`973415d508a4d22a788e0408558f7875313ad3c4`):

- **Cuatro capacidades** introducidas mediante
  `feature-branch-chain` (lineal, cuatro PR hijos): `pdf-fixture`,
  `pdf-engine`, `pencilkit-ink-overlay`, `pdf-reader-wiring`. Solo el
  PR rastreador se fusionó en `main` (regla de topología lineal
  respetada).
- **39 pruebas nuevas** añadidas a lo largo de las rebanadas 1–4
  (14 + 11 + 12 + 2). Línea base de la Fase 1 (56 pruebas) byte a
  byte sin cambios. Suite completa: 95/95 en verde.
- **Cero coincidencias de subcadenas bloqueadas** en cualquier
  directorio del módulo de la Fase 2. Las importaciones de la Fase 2
  son exclusivamente marcos de trabajo locales de primer nivel
  (`Foundation`, `SwiftData`, `PDFKit`, `PencilKit`, `SwiftUI`,
  `UIKit`, `os`).
- **Ninguna entidad de la Fase 1 mutada**. `DocumentItem.paginationModeRaw`
  y `PageAnnotation.drawingData` siguen siendo invariantes de la Fase
  1; la Fase 2 los lee y los escribe tal cual.
- **Solo iPad, solo local**: sin red, sin iCloud, sin CloudKit, sin
  importación de PDF, sin capacidades del Apple Developer Program.

La verificación de la Fase 2 se cierra con los siete criterios de
aceptación cumplidos. El paso de archivo (tarea 5.5) es la única tarea
de implementación restante; este registro de archivo es su evidencia
de completitud.
