# Especificación de capacidad — `pdf-fixture`

Espejo en español neutro profesional de
`openspec/changes/pdf-reader-pencilkit-ink-recovery/specs/pdf-fixture/spec.md`.
Cualquier cambio debe replicarse fielmente en ambos archivos.

## Propósito

Aportar un PDF de 20 páginas que sea **autoral del proyecto**,
**determinista**, **CC0** y empaquetado con la aplicación en tiempo
de compilación exactamente en
`InSummary/Resources/Fixtures/sample-bundle.pdf`, para que el lector
de PDF y la capa de tinta de PencilKit tengan un fixture estable y de
licencia limpia que leer en la Fase 2 — sin enviar un PDF binario
editado a mano al historial de git y sin recurrir a la red ni a
ninguna fuente de terceros.

Esta capacidad define el contrato del que dependen todas las
pruebas posteriores de la Fase 2, el `PDFReaderCoordinator`, la
`PencilCanvasOverlay` y la `ReaderContainerView`. La ruta del fixture
es canónica y no debe variar.

## Requisitos AÑADIDOS

### Requisito: Ruta canónica del fixture

El fixture DEBE estar ubicado exactamente en
`InSummary/Resources/Fixtures/sample-bundle.pdf` (plural `Fixtures`,
nombre con guion `sample-bundle.pdf`). Cada prueba, fase de
compilación, descripción de PR y especificación de capacidad DEBE
hacer referencia a esta ruta exacta. Las rutas incorrectas
`InSummary/Resources/Fixture/sample.pdf` (singular) e
`InSummary/Resources/Fixtures/sample.pdf` (sin guion) NO DEBEN
aparecer en ningún artefacto de la Fase 2.

#### Escenario: La ruta aparece en la fase de compilación

- **CUANDO** se ejecuta la fase de compilación
- **ENTONCES** el generador DEBE ejecutarse y escribir el fixture en
  `InSummary/Resources/Fixtures/sample-bundle.pdf`
- **Y** el `sample-bundle.pdf` resultante DEBE coincidir byte a byte
  con la salida del generador en proceso.

#### Escenario: El recurso del bundle resuelve

- **CUANDO** la aplicación lee el fixture en tiempo de ejecución
- **ENTONCES** la ruta de lectura DEBE resolverse a
  `Bundle.main.url(forResource: "sample-bundle", withExtension: "pdf")`
- **Y** la ruta de lectura NO DEBE resolverse a ninguna URL fuera
  del bundle.

### Requisito: Generador determinista autoral del proyecto

El fixture DEBE ser generado por código propio del proyecto que vive
en `InSummaryTests/Support/PDFFixtureGenerator.swift`. El generador
DEBE usar `PDFKit` para dibujar 20 páginas tamaño carta y DEBE ser
determinista entre máquinas y entre ejecuciones. El generador NO
DEBE importar ningún activo, fuente, imagen ni archivo de datos de
terceros.

#### Escenario: Regeneración determinista

- **CUANDO** el generador del fixture se invoca dos veces en la
  misma máquina
- **ENTONCES** las dos salidas DEBEN ser byte a byte idénticas
- **Y** el hash SHA-256 de cada salida DEBE coincidir con la
  constante canónica `fixtureContentHash`.

#### Escenario: Conteo de páginas

- **CUANDO** la salida del generador se carga como `PDFDocument`
- **ENTONCES** `PDFDocument.pageCount` DEBE ser igual a 20.

#### Escenario: Renderizado por página

- **CUANDO** cada página del fixture generado se renderiza a una
  `UIImage` a 72 DPI
- **ENTONCES** la imagen renderizada DEBE ser no vacía (no un lienzo
  en blanco)
- **Y** la imagen renderizada DEBE embeber el índice de página en una
  posición visible para una persona revisora.

### Requisito: Licencia y autoría del fixture

El fixture DEBE publicarse bajo la dedicación **CC0 1.0 Universal**.
El fixture NO DEBE contener **ningún contenido de terceros** de
ningún tipo; cada primitiva de dibujo DEBE originarse en el código
generador del propio proyecto. El código del generador DEBE llevar un
comentario en la cabecera `// SPDX-License-Identifier: CC0-1.0` que
afirme la autoría del proyecto.

#### Escenario: Atestación de licencia

- **CUANDO** una persona revisora lee el código del generador
- **ENTONCES** el primer comentario que no sea de documentación DEBE
  decir "CC0 1.0 Universal, autoral del proyecto"
- **Y** el generador NO DEBE importar ningún activo, fuente, imagen
  ni archivo de datos de terceros.

### Requisito: Registro de licencia en el repositorio

El repositorio DEBE contener
`InSummary/Resources/Fixtures/SAMPLE-BUNDLE-LICENSE.md` con la
dedicación CC0 1.0 Universal, el SHA-256 del generador y el conteo
de páginas. El archivo de licencia DEBE enviarse junto con el
binario en *Copy Bundle Resources*.

#### Escenario: El archivo de licencia está commiteado

- **CUANDO** una persona revisora inspecciona el directorio del
  fixture
- **ENTONCES** `SAMPLE-BUNDLE-LICENSE.md` DEBE existir junto a
  `sample-bundle.pdf`
- **Y** el archivo DEBE nombrar la dedicación CC0 1.0 Universal.

### Requisito: Detección de deriva

El hash canónico del contenido del fixture DEBE verificarse contra
la salida del generador en cada ejecución de pruebas. Un desajuste
de hash DEBE hacer fallar la compilación, porque indica que el
artefacto empaquetado y el generador han derivado.

#### Escenario: La deriva hace fallar la suite

- **CUANDO** el hash de contenido del fixture empaquetado difiere
  del hash de la salida del generador
- **ENTONCES** la XCTest dedicada DEBE fallar con un mensaje que
  nombre ambos hashes e indique a la persona desarrolladora que
  vuelva a ejecutar la fase de compilación.

### Requisito: Acceso solo local

El fixture DEBE cargarse únicamente desde el bundle o desde el
generador en proceso en el momento de las pruebas; la aplicación NO
DEBE recurrir al fixture a través de la red, del sistema de archivos
fuera del bundle ni de ningún almacenamiento remoto.

#### Escenario: Sin acceso a la red

- **CUANDO** se carga el fixture
- **ENTONCES** no DEBE abrirse ninguna sesión URL, socket ni URL
  remota
- **Y** una búsqueda de código de `URLSession`, `NWConnection` y
  `NSURLConnection` dentro del código de carga del fixture DEBE
  devolver cero coincidencias.

## Requisitos MODIFICADOS

*Ninguno.* Esta capacidad introduce un nuevo fixture y un nuevo
archivo de soporte para el generador. No modifica ninguna entidad de
la Fase 1.

## Requisitos ELIMINADOS

*Ninguno.*
