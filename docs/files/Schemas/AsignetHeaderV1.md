---
file: Schemas/AsignetHeaderV1.ahk
last_review: 2026-05-12
status: active
---

# `Schemas/AsignetHeaderV1.ahk`

## Propósito

Define el schema de header de factura del sistema web Asignet. Declara 9 campos en orden fijo con sus cleaners, validators, `expectedFn`, `preScanSteps` y `prePasteSteps`. Es el único schema activo en producción y el que ejercitan la mayoría de los tests de integración.

## API pública

### Funciones libres

- **`CrearAsignetHeaderV1() → InvoiceSchema`** — construye y devuelve el `InvoiceSchema` completo con los 9 `Campo` de Asignet, `ordenPegado`, `prePasteSteps` y `preScanSteps`.
  - Llamado desde: `QuickEntry.ahk:35`, `Tests/Test_AsignetHeader.ahk:14, 235, 260`, `Tests/Test_CaptureEngine.ahk:524, 541, 690, 699`, `Tests/Test_TooltipFormatter.ahk:24, 133, 143, 165, 171, 181, 202, 225, 256, 264, 287, 305`
  - Llama a: `Campo` (×9, `Lib/Schema.ahk`), `InvoiceSchema` (`Lib/Schema.ahk`), `CleanRaw`, `CleanPasoPegado`, `CleanPasoPegadoForzandoNegativo`, `ValidarNoVacio`, `ValidarFechaEstricta`, `ValidarNumero`, `ValidarSumaTol`, `ExpectedSlot5`, `ExpectedSlot9`

### Helpers internos (file-scope, no expuestos fuera del archivo)

- **`CleanRaw(raw) → raw`** — passthrough; usado en Corp name (slot 4) donde el form acepta el texto crudo como filtro de búsqueda.
  - Llamado desde: `CrearAsignetHeaderV1()` como argumento `clean` del `Campo` slot 4
  - Llama a: (ninguno)

- **`CleanPasoPegado(raw) → String`** — delega a `LimpiarComoPegadoEspecial(raw)`; normaliza fechas, precios y texto.
  - Llamado desde: `CrearAsignetHeaderV1()` como `clean` de los slots 1, 2, 3, 7, 8, 9
  - Llama a: `LimpiarComoPegadoEspecial` (`Lib/Cleaners.ahk`)

- **`CleanPasoPegadoForzandoNegativo(raw) → String`** — igual que `CleanPasoPegado` pero fuerza el resultado a negativo; usado en slot 6 (Past Total Payments, siempre egreso).
  - Llamado desde: `CrearAsignetHeaderV1()` como `clean` del slot 6
  - Llama a: `LimpiarComoPegadoEspecial` (`Lib/Cleaners.ahk`), `ForzarNegativo` (`Lib/Cleaners.ahk`)

- **`EsperadoSuma(slotsIdx, cola) → String`** — suma los valores en `cola` en las posiciones indicadas por `slotsIdx` (1-based); devuelve `""` si alguna posición está vacía o `cola` es más corta que el índice máximo. Formatea con `{:.2f}`.
  - Llamado desde: `ExpectedSlot5`, `ExpectedSlot9`
  - Llama a: `Number`, `Format` (built-ins AHK v2)

- **`ExpectedSlot5(cola) → String`** — `EsperadoSuma([5, 6], cola)`; valor esperado para slot 7 (Past due = Previous balance + Past Total Payments).
  - Llamado desde: `CrearAsignetHeaderV1()` como `expectedFn` del slot 7

- **`ExpectedSlot9(cola) → String`** — `EsperadoSuma([8, 7], cola)`; valor esperado para slot 9 (Invoice Total Including PastDue = Total($) + Past due).
  - Llamado desde: `CrearAsignetHeaderV1()` como `expectedFn` del slot 9

## Dependencias

- **#Include directos**: `..\Lib\Cleaners.ahk`, `..\Lib\Validators.ahk`, `..\Lib\Schema.ahk`
- **Incluido por**: `QuickEntry.ahk` (línea 7), `Tests/Test_AsignetHeader.ahk` (línea 4), `Tests/Test_CaptureEngine.ahk` (línea 6), `Tests/Test_TooltipFormatter.ahk` (línea 5)
- **Globales que define**: (ninguna)
- **Globales que usa (leídas)**: (ninguna)
- **Símbolos externos invocados**:
  - `LimpiarComoPegadoEspecial` (de `Lib/Cleaners.ahk`) — vía `CleanPasoPegado` y `CleanPasoPegadoForzandoNegativo`
  - `ForzarNegativo` (de `Lib/Cleaners.ahk`) — vía `CleanPasoPegadoForzandoNegativo`
  - `ValidarNoVacio` (de `Lib/Validators.ahk`) — `clean` de slots 1 y 4
  - `ValidarFechaEstricta` (de `Lib/Validators.ahk`) — slots 2 y 3
  - `ValidarNumero` (de `Lib/Validators.ahk`) — slots 5, 6 y 8
  - `ValidarSumaTol` (de `Lib/Validators.ahk`) — slots 7 y 9 (con `[5,6]` y `[8,7]` respectivamente)
  - `Campo` (de `Lib/Schema.ahk`) — constructor de cada campo (×9)
  - `InvoiceSchema` (de `Lib/Schema.ahk`) — constructor del schema completo

## Notas técnicas (WHY no-obvio)

- **Orden de pegado ≠ orden de la factura.** El operador copia los campos en orden de lectura natural del documento (`[1, 2, 3, 4, 7, 5, 6, 8, 9]`); el `ordenPegado` reordena el volcado al form, que tiene disposición distinta. El array `ordenPegado := [1, 2, 3, 4, 7, 5, 6, 8, 9]` indica que el quinto campo que se pega en el form es el valor del slot 7 de la cola.

- **Slot 6 siempre negativo.** Past Total Payments es un egreso acumulado; el cleaner `CleanPasoPegadoForzandoNegativo` garantiza que el valor sea negativo independientemente de cómo lo traiga el clipboard, evitando errores aritméticos silenciosos en la validación de `ValidarSumaTol([5, 6])` del slot 7.

- **`expectedFn` de Past due (slot 7).** `ExpectedSlot5(cola)` computa `cola[5] + cola[6]`; slot 7 valida que `Past due = Previous balance + Past Total Payments`. La aritmética es correcta sólo si slot 6 llega negativo (ver punto anterior): `balance + (−payments) = past due neto`.

- **`expectedFn` de Invoice Total (slot 9).** `ExpectedSlot9(cola)` computa `cola[8] + cola[7]`; slot 9 valida que `Invoice Total = Total($) + Past due`. El orden de los índices es `[8, 7]`, no `[7, 8]` — ambos son commutative pero el orden refleja la secuencia lógica "cargo corriente + deuda anterior".

- **`prePasteSteps` de Corp name (slot 4).** El campo Corp name tiene un dropdown con autocomplete en el form de Asignet. Los pasos embebidos en el argumento `prePasteSteps` del `Campo` slot 4 incluyen: 300 ms de settling para que el autocomplete termine, dos `{Tab}` para llegar al campo Currency, tipeo de `"US"` + 500 ms de espera para que aparezca el sugerido "US Dollars", `{Enter}` para seleccionarlo, y tres `{Tab}` adicionales para llegar a Past due. Si se altera el timing o el número de tabs, el foco cae en el campo equivocado sin error detectable en runtime.

- **`prePasteSteps` globales.** Navegan desde el tope de la página hasta el input Account number: `{Up 3}`, `{Down}`, `{Enter}`, `{Tab}`, escriben `"Invoice"` (tipo de documento), `{Tab}`. El `{Down}` + `{Enter}` abre el dropdown "Type of Document" y selecciona el primer ítem que matchea `"Invoice"`.

- **`preScanSteps`.** En el form ya rellenado, "Type of Document" es readonly/no-tab-stop, así que dos `{Tab}` consecutivos llevan directamente al campo Account number sin necesidad de tipear `"Invoice"` nuevamente. La diferencia entre `prePasteSteps` y `preScanSteps` es intencionada: paste = form vacío; scan = form ya cargado.

- **`EsperadoSuma` devuelve `""`** si cualquier slot del grupo está vacío o la cola es más corta que el índice máximo. Esto previene que el tooltip muestre una suma parcial engañosa cuando el operador no ha llenado todos los slots de la ecuación.

- **Slots 1 y 4 con lupa.** Account number y Corp name activan un filtro de búsqueda en el form (no edición directa): el pegado rellena el campo como filtro y el operador hace clic en el resultado. `ValidarNoVacio` es suficiente; no se valida formato porque el form lo resuelve.

## Campos declarados (resumen tabular)

| # | Nombre | Clean | Validate | Tabs | skipPaste | expectedFn | expectedDeps |
|---|---|---|---|---|---|---|---|
| 1 | Account number | `CleanPasoPegado` | `ValidarNoVacio` | 2 | false | — | — |
| 2 | Invoice date | `CleanPasoPegado` | `ValidarFechaEstricta` | 1 | false | — | — |
| 3 | Due date | `CleanPasoPegado` | `ValidarFechaEstricta` | 3 | false | — | — |
| 4 | Corp name | `CleanRaw` | `ValidarNoVacio` | 5 | false | — | — |
| 5 | Previous balance | `CleanPasoPegado` | `ValidarNumero` | 1 | false | — | — |
| 6 | Past Total Payments | `CleanPasoPegadoForzandoNegativo` | `ValidarNumero` | 10 | false | — | — |
| 7 | Past due | `CleanPasoPegado` | `ValidarSumaTol([5,6])` | 1 | false | `ExpectedSlot5` | `[5, 6]` |
| 8 | Total ($) | `CleanPasoPegado` | `ValidarNumero` | 5 | false | — | — |
| 9 | Invoice Total Including PastDue | `CleanPasoPegado` | `ValidarSumaTol([8,7])` | 1 | false | `ExpectedSlot9` | `[8, 7]` |

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **BORRADO** — template note ("Para crear un schema para OTRA EMPRESA…"): narrativa documental, pertenece al .md, no al código.
  - **BORRADO** — banner `; --- Definicion declarativa del schema ---` antes de `CrearAsignetHeaderV1()`: tercer banner (máx 2). La función es el único símbolo público y su nombre es autoexplicativo.
  - **BORRADO** — comment-header de columnas en el array `fields` (`; #  name  clean  validate  tabs  skipPaste  expectedFn  expectedDeps`): los nombres de parámetros son los de `Campo()` en `Schema.ahk`; el comentario solo duplicaba la firma.
  - **REESCRITO** — banner top: removida la nota de template, corregido el typo "aritmeticascambiado 7 por 5 y reorden" → ecuaciones limpias; añadida la razón del forzado negativo ("para que la suma del slot 7 sea aritmeticamente correcta").
  - **REESCRITO** — comentario `ordenPegado`: de dos líneas descriptivas + redundante última frase → tres líneas WHY que explicitan el caso no-obvio (slot 7 pegado en posición 5).
  - **REESCRITO** — comentario `prePasteSteps`: de tres líneas narrativas → dos líneas WHY que mencionan `{Down}+{Enter}` como mecanismo de apertura del dropdown.
  - **REESCRITO** — comentario `preScanSteps`: de cuatro líneas (con delimitadores `---`) → dos líneas WHY que justifican la diferencia con `prePasteSteps` (readonly/no-tab-stop).
  - **CONSERVADOS** — dos banners de sección (`; --- Cleaners…` y `; --- Helpers de "esperado"…`): orientan la estructura del archivo dentro del límite de 2.
  - **CONSERVADOS** — inline comments del bloque `prePasteSteps` de Corp name (slot 4): timings críticos con razón explícita; alterar sin entenderlos rompe el foco silenciosamente.

### Fase 3 — dead code
- [x] Auditado 2026-05-12
- Borrados (0 referencias en producción + tests): **ninguno** — todos los símbolos tienen al menos una referencia interna activa dentro del mismo archivo.
- Candidatos para review senior (NO borrados): ninguno.
- Resultado: USADO ×6, NO USADO ×0, DUDOSO ×0. Sintaxis OK (AHK64 /validate sin errores).
- Detalle por símbolo:
  - `CrearAsignetHeaderV1` — USADO: `QuickEntry.ahk:33`, `Tests/Test_AsignetHeader.ahk:14,235,260`, `Tests/Test_CaptureEngine.ahk:472,489,622,629`, `Tests/Test_TooltipFormatter.ahk` (×12 llamadas).
  - `CleanRaw` — USADO: argumento `clean` del slot 4 (Corp name) en `CrearAsignetHeaderV1()`. No existe referencia externa; es helper interno legítimo.
  - `CleanPasoPegado` — USADO: argumentos `clean` de slots 1, 2, 3, 5, 7, 8, 9 en `CrearAsignetHeaderV1()`. Mención en comentario `Test_CaptureEngine.ahk:621` (solo documental, no llamada).
  - `CleanPasoPegadoForzandoNegativo` — USADO: argumento `clean` del slot 6 (Past Total Payments) en `CrearAsignetHeaderV1()`.
  - `EsperadoSuma` — USADO: llamado desde `ExpectedSlot5` y `ExpectedSlot9` (mismo archivo).
  - `ExpectedSlot5` — USADO: argumento `expectedFn` del slot 7 (Past due) en `CrearAsignetHeaderV1()`.
  - `ExpectedSlot9` — USADO: argumento `expectedFn` del slot 9 (Invoice Total Including PastDue) en `CrearAsignetHeaderV1()`.

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **CORREGIDO** — línea 92 (`preScanSteps`): indentación de tab a 4 spaces (consistente con resto del archivo).
  - **AGREGADO** — trailing newline al final del archivo (buena práctica POSIX; sin él `git diff` marcaba el archivo como sin newline final).
- Resultado: 2 microcambios. Sintaxis OK (AHK64 /validate exit 0).

## Ideas de simplificación pendientes (input para plan posterior)

- `EsperadoSuma` podría vivir en `Lib/Schema.ahk` o `Lib/Validators.ahk` como helper genérico, ya que `_Plantilla_NuevaEmpresa.ahk` duplica el mismo patrón. Un move reduce copy-paste al crear schemas de nuevas empresas.
- Los helpers `CleanRaw`, `CleanPasoPegado`, `CleanPasoPegadoForzandoNegativo` son thin wrappers de un solo cleaner con flags distintos; un único helper con parámetro (`CleanCampo(raw, forzarNeg := false)`) eliminaría las tres definiciones sin cambiar la API de `Campo`.
- El bloque `prePasteSteps` de Corp name (slot 4) es un array literal de 10 elementos hardcodeado dentro del `Campo()`; extraerlo a una constante con nombre (`CORP_NAME_CURRENCY_STEPS`) mejoraría la legibilidad y facilitaría el ajuste de timings sin releer la definición completa del campo.
