# Cambio `pdf-reader-pencilkit-ink-recovery`

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/README.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

Fase 2 de **In-Summary** — el lector de PDF y la capa de tinta de
PencilKit — entregada mediante una cadena de ramas de funcionalidad
con este PR rastreador como punto único de fusión hacia `main`.

## Ruta rápida para revisores

1. Lee `proposal-es.md` (~2 minutos) para confirmar alcance y
   no-objetivos.
2. Lee `design-es.md` §1–§4 (~5 minutos) para la forma técnica.
3. Revisa `specs/` para confirmar que cada requisito es verificable.
4. Valida `tasks-es.md` contra la cadena **lineal** de PRs hijos.
5. Verifica el espejo en español bajo
   `documents-es/openspec/changes/pdf-reader-pencilkit-ink-recovery/`.

## Decisión en una pantalla

| Pregunta | Respuesta |
| --- | --- |
| ¿Qué se entrega en este cambio? | Un fixture PDF de 20 páginas, determinista, CC0, en `InSummary/Resources/Fixtures/sample-bundle.pdf`; un `PDFReaderCoordinator` con paginación horizontal y vertical; una `PencilCanvasOverlay` con `.pencilOnly` y `.highlighter`; un `PDFPageChangeObserver` que intercambia y persiste los bytes de `PKDrawing` entre páginas; y una `ReaderContainerView` alcanzable desde la capa de librería de la Fase 1. |
| ¿Qué reutiliza este cambio de la Fase 1? | `DocumentItem.paginationModeRaw` (por defecto `"horizontal"`) para la preferencia por documento y `PageAnnotation.drawingData` para la persistencia de la tinta. **Sin cambios de esquema.** |
| ¿Cuál es la ruta del fixture? | Exactamente `InSummary/Resources/Fixtures/sample-bundle.pdf` (plural `Fixtures`, nombre con guion). |
| ¿Cuál es la forma de la cadena de PRs? | Estrictamente lineal: `tracker ← PR #1 ← PR #2 ← PR #3 ← PR #4`. Solo el PR #1 apunta al rastreador. Solo el rastreador se fusiona en `main`. |
| ¿Qué queda fuera de alcance? | Importación, exportación, añadidos a la librería, notas adhesivas, resaltados semánticos, motores EPUB/Markdown, temas, multi-ventana, iCloud, CloudKit, `CKAsset`, notificaciones push, cualquier tipo de red. |

## Qué hay en este cambio

| Archivo | Propósito |
| --- | --- |
| `proposal-es.md` | Por qué, qué, alcance y plan de entrega |
| `design-es.md` | Decisiones técnicas, invariantes de la Fase 1 y límites de las rebanadas |
| `tasks-es.md` | Lista de comprobación de TDD estricto por cada PR hijo |
| `specs/pdf-fixture/spec-es.md` | Capacidad: PDF de 20 páginas, CC0, determinista y autoral del proyecto, empaquetado en compilación |
| `specs/pdf-engine/spec-es.md` | Capacidad: `PDFReaderCoordinator` con paginación horizontal y vertical |
| `specs/pencilkit-ink-overlay/spec-es.md` | Capacidad: capa de tinta solo-Pencil + persistencia del cambio de página sobre `PageAnnotation.drawingData` |
| `specs/pdf-reader-wiring/spec-es.md` | Capacidad: composición de `ReaderContainerView` + navegación desde la librería |

## Qué queda intencionalmente fuera

- No hay código de producto bajo `InSummary/` (este es el PR
  rastreador — el código llega en los PR hijos #1–#4).
- No hay PDF binario del fixture en ninguna parte del repositorio (el
  generador del fixture y su fase de compilación llegan en el PR #1).
- No hay iCloud, CloudKit, `CKAsset`, red, importación ni exportación.
- No hay modificación a `InSummary/Models/DocumentItem.swift` ni a
  `InSummary/Models/PageAnnotation.swift`. Ambos son invariantes de la
  Fase 1.
- No hay referencia al código parcial ni a los artefactos de
  planificación del intento previo bloqueado.

## Cadena de PR hijos (estrictamente lineal)

```
tracker/pdf-reader-pencilkit-ink-recovery   ← 🧭 rastreador (este PR, borrador / sin fusión)
        ↑
        │ el PR #1 apunta al rastreador
        │
feat/pdf-fixture                             ← PR #1 (Rebanada 1 — fixture + fase de compilación)
        ↑
        │ el PR #2 apunta a la rama del PR #1
        │
feat/pdf-engine                              ← PR #2 (Rebanada 2 — núcleo del lector de PDF)
        ↑
        │ el PR #3 apunta a la rama del PR #2
        │
feat/pencilkit-ink-overlay                   ← PR #3 (Rebanada 3 — capa + observador)
        ↑
        │ el PR #4 apunta a la rama del PR #3
        │
feat/pdf-reader-wiring                       ← PR #4 (Rebanada 4 — capa + navegación de librería)
```

**Regla de topología:** cada PR hijo posterior al #1 apunta a la rama
de su **predecesor inmediato**. No hay bifurcación. Ningún PR hijo
apunta al rastreador excepto el PR #1. Solo el rastreador se fusiona
en `main`.

Cada cuerpo de PR hijo lleva:
- Un diagrama de dependencias que se marca a sí mismo con 📍 y al
  rastreador con 🧭.
- El bloque de contexto de la cadena (inicio, fin, dependencia previa,
  trabajo siguiente, elementos fuera de alcance).
- Una justificación de `size:exception` **solo** si el PR excede las 400
  líneas modificadas (ninguno de los cuatro PR hijos pronostica
  hacerlo).

## Siguiente paso

Abre el **PR rastreador** como **borrador / sin fusión**. Pasa al
orquestador padre para que genere el PR hijo #1 (`feat/pdf-fixture`)
una vez que el PR rastreador esté abierto.
