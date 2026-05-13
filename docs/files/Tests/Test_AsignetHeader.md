---
file: Tests/Test_AsignetHeader.ahk
last_review: 2026-05-12
last_cleanup: 2026-05-12
status: active
---

# `Tests/Test_AsignetHeader.ahk`

## Propósito

Suite de tests de integración para el schema declarativo `AsignetHeaderV1`. Verifica que `CrearAsignetHeaderV1()` produce una instancia `InvoiceSchema` correctamente configurada, y que la instancia se comporta fielmente con `CaptureEngine` en modo `autoCalc`. Es el único archivo de tests que ejerce el schema Asignet de extremo a extremo; los tests unitarios de cleaners y validators individuales viven en `Test_Cleaners.ahk` y `Test_Validators.ahk` respectivamente.

No exporta ningún símbolo. Es un script top-level AHK v2: se ejecuta, corre los asserts en secuencia y termina con `ReportarYSalir()`.

## API pública

Este archivo no define funciones ni clases. En su lugar, documenta las **áreas de cobertura** que ejerce:

### Bloque 1 — Estructura del schema (líneas 14–67)

- Nombre del schema (`s.name = "Asignet Header v1"`).
- Longitud: 9 campos (`s.Length`).
- Nombres en orden de los 9 slots (`s.Field(i).name`).
- `tabsAfter` por slot: refleja la topografía real del form Asignet (tabs requeridos para navegar entre campos).
- `ordenPegado`: orden visual del paste, que difiere del orden de escaneo (slots 5–7 intercambiados).
- `prePasteSteps`: 6 pasos (desde dropdown "Type") para posicionar el cursor antes del paste.
- `preScanSteps`: 2 pasos (`{Tab}`, `{Tab}`) para posicionar el cursor antes del scan.
- `skipPaste`: confirmación de que los 9 slots tienen `skipPaste = false` (ninguno se omite en paste).

### Bloque 2 — Cleaners por slot (líneas 79–109)

Ejerce `s.Field(i).clean.Call(raw)` para los 9 slots con valores representativos:

| Slot | Campo | Comportamientos verificados |
|---|---|---|
| 1 | Account number | passthrough alfanumérico |
| 2 | Invoice date | texto → `MM/DD/YYYY`; numérica passthrough |
| 3 | Due date | texto → `MM/DD/YYYY` (mismo cleaner) |
| 4 | Corp name | passthrough raw; NO trimea espacios |
| 5 | Previous balance | limpia `$` y coma; passthrough sin símbolo; sufijo `CR` → negativo |
| 6 | Past Total Payments | fuerza negativo a positivo; `CR` mantiene negativo; negativo passthrough; cero sin signo; vacío passthrough |
| 7 | Past due | precio normal |
| 8 | Total ($) | precio con coma |
| 9 | Invoice Total Including PastDue | precio con coma |

### Bloque 3 — Validators por slot (líneas 114–146)

Ejerce `s.Field(i).validate.Call(value, cola)` para los 9 slots:

| Slot | Validator | Casos cubiertos |
|---|---|---|
| 1 | `ValidarNoVacio` | acepta texto; rechaza vacío (mensaje contiene "vacio") |
| 2–3 | `ValidarFechaEstricta` | acepta `MM/DD/YYYY`; rechaza texto libre (mensaje contiene "fecha") |
| 4 | `ValidarNoVacio` | acepta texto; rechaza vacío |
| 5–6 | `ValidarNumero` | acepta número; rechaza texto (mensaje contiene "numero"); acepta negativo |
| 7 | `ValidarSumaTol([5,6])` | suma `1000 + (-500) = 500` OK; suma errónea genera mensaje con "suma" e imprime el esperado |
| 8 | `ValidarNumero` | acepta número |
| 9 | `ValidarSumaTol([8,7])` | suma `2500 + 500 = 3000` OK; suma errónea genera mensaje con "suma" e imprime el esperado |

### Bloque 4 — `expectedFn` (líneas 151–189)

- Confirma que solo los slots 7 y 9 tienen `expectedFn` (función asignada); el resto tienen `expectedFn = ""`.
- `expectedDeps` de slot 7: `[5, 6]` (Previous balance, Past Total Payments).
- `expectedDeps` de slot 9: `[8, 7]` (Total, Past due).
- `expectedFn.Call(cola)` calcula correctamente: slot 7 → `"500.00"`, slot 9 → `"3000.00"`.
- Casos de dependencia incompleta: retorna `""` si la cola es más corta que el índice requerido o si la dependencia es cadena vacía (no rompe).

### Bloque 5 — Pipeline integral happy path (líneas 194–228)

Recorre los 9 slots en secuencia con datos OCR realistas, verificando que:
- `clean` transforma la entrada al valor esperado.
- `validate` no produce error para el valor limpio y la cola acumulada hasta ese punto.
- La cola final tiene exactamente 9 ítems.

Cubre el flujo completo sin usar `CaptureEngine` — ejercita la composición `clean → validate → push` manualmente.

### Bloque 6 — AutoCalc end-to-end con `CaptureEngine` (líneas 234–269)

Usa `CaptureEngine(CrearAsignetHeaderV1(), true)` (flag `autoCalc = true`):

- **Slot 7 autocalc**: tras empujar 6 slots, `ExpectedFor(7)` devuelve `"500.00"` y `SkipCurrent()` rellena automáticamente el slot con ese valor. `queue[7]` queda `"500.00"`, `FilledCount = 7`.
- **Slot 9 autocalc en cadena**: empujar slot 8 manualmente y luego `SkipCurrent()` en slot 9 usa el valor autocalculado del slot 7 como dependencia. `queue[9] = "3000.00"`, `IsComplete = true`, `FilledCount = 9`.
- **Dep incompleta**: `CaptureEngine` con slots 5 y 6 vacíos (sólo 4 slots empujados + `JumpTo(7)`): `SkipCurrent()` retorna `value = ""` y `queue[7] = ""` sin lanzar error.

## Dependencias

- **#Include directos**:
  - `../Schemas/AsignetHeaderV1.ahk` — provee `CrearAsignetHeaderV1()`
  - `../Lib/CaptureEngine.ahk` — provee la clase `CaptureEngine`
  - `_AssertHelpers.ahk` — provee `AssertEq`, `AssertContains`, `ReportarYSalir`
- **Incluido por**: nadie (`runner.ps1` lo lanza como proceso independiente)
- **Globales que define**: ninguna propia (usa `g_failures` y `g_total` de `_AssertHelpers.ahk`)
- **Globales que usa**: `g_failures`, `g_total` (vía `_AssertHelpers.ahk`)
- **Símbolos externos invocados**:
  - `CrearAsignetHeaderV1()` — instanciado en líneas 14, 235, 260
  - `CaptureEngine(schema, autoCalcFlag)` — instanciado en líneas 235, 260
  - `AssertEq`, `AssertContains` — usados a lo largo del archivo
  - `ReportarYSalir()` — línea 271

## Notas técnicas (WHY no-obvio)

- **Dos instancias de `CaptureEngine`**: `ea` (línea 235, el happy path de autocalc) y `eaPartial` (línea 260, el caso de dependencia incompleta). Están separadas para que el estado de `eaPartial` no contamine el happy path; `eaPartial.JumpTo(7)` necesita un engine virgen sin slots 5 y 6 cargados.
- **`cola6` y `cola8` como fixtures de validator**: los validators de slots 7 y 9 requieren la cola completa hasta el slot previo; `cola6` y `cola8` son arrays literales definidos ad-hoc (líneas 134 y 143) para pasar como segundo argumento a `validate.Call`. No es estado compartido entre bloques.
- **Pipeline manual vs. `CaptureEngine`**: el Bloque 5 construye la cola iterando `clean → validate → push` a mano para aislar el comportamiento del schema de cualquier bug de `CaptureEngine`. El Bloque 6, en cambio, delega todo el flujo al engine para testear la integración real.
- **`ordenPegado` [1,2,3,4,7,5,6,8,9]**: el form Asignet tiene los campos "Past due" (slot 7) visualmente antes de "Previous balance" (slot 5) y "Past payments" (slot 6); por eso el orden de pegado no es secuencial. El Bloque 1 verifica esta inversión para detectar regresiones si el schema cambia.
- **Ausencia de mocks de I/O**: a diferencia de `Test_CaptureEngine.ahk`, este archivo no necesita `sendFn` ni `sleepFn` mockeados porque ningún test llama a `Scan` o `PasteBatch` (que son las únicas operaciones con side-effects de teclado/clipboard).

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Borrado** `(paso pegado)` de `; Slot 1: Account number (paso pegado)` — QUÉ puro; el test ya lo dice.
  - **Borrado** `(paso pegado convierte fecha)` de `; Slot 2: Invoice date (paso pegado convierte fecha)` — QUÉ puro; los asserts lo cubren.
  - **Borrado** `(raw passthrough)` de `; Slot 4: Corp name (raw passthrough)` — QUÉ puro; redundante con el assert "Slot4 raw passthrough".
  - **Borrado** `(paso pegado normaliza precio)` de `; Slot 5: Previous balance (paso pegado normaliza precio)` — QUÉ puro; tests lo cubren.
  - **Reescrito** `; --- expectedFn calcula correctamente ---` → `; --- expectedFn.Call devuelve valor correcto dado cola completa ---` — aclara que el contrato depende de cola completa (contrasta con el siguiente bloque "dep incompleta").
- Conservados (WHY no-obvio):
  - `; Slot 3: Due date (mismo cleaner)` — "mismo cleaner" explica por qué la cobertura de slot 3 es más corta que la de slot 2.
  - `; Slot 6: Past payments (paso pegado + forzar negativo)` — "forzar negativo" anuncia el comportamiento asimétrico que cubre 5 sub-casos.
  - Todos los banners de sección (6 en total): Estructura / Cleaners / Validators / expectedFn / Pipeline / AutoCalc.
  - `; --- prePasteSteps: 6 pasos (cursor inicia en dropdown Type) ---` — WHY de por qué son exactamente 6 pasos.
  - `; --- preScanSteps: 2 pasos (cursor en Type, Type of Document es no-tab-stop) ---` — WHY topográfico del form.
  - `; --- AutoCalc slot 9 - usa el slot 7 autocalc'd como dependencia ---` — WHY: dependencia en cadena entre dos autocalcs.
  - `; --- AutoCalc con dep incompleta retorna "" (no rompe) ---` — guard de regresión explícito.
  - `; --- expectedFn devuelve "" si dependencias incompletas ---` — guard de regresión explícito.
- Dudosos (no tocados, borderline):
  - `; --- skipPaste siempre false (Asignet) ---` — podría eliminarse (Asignet es obvio en contexto), pero la frase "siempre false" sí documenta el contrato del schema; se conserva.
  - `; Slot 7-9: paso pegado normal` — agrupa tres slots con un solo line; podría reescribirse como "Slots 7-9 usan el cleaner de precio estándar (sin lógica de signo)". Se deja para Fase 3.

### Fase 3 — dead code
- [ ] Auditado
- Borrados:
- Candidatos para review senior:

## Ideas de simplificación pendientes (input para plan posterior)

- Los fixtures `cola6` y `cola8` se construyen como arrays literales en líneas 134 y 143 y luego se reutilizan en el Bloque 4 (líneas 183–184); definirlos una sola vez al inicio del bloque y referenciarlos evitaría la duplicación implícita de estado entre bloques.
- El Bloque 1 verifica `tabsAfter` y `ordenPegado` con `Loop 9` + array de esperados; el patrón es idéntico al de `nombresEsperados`. Un helper local `AssertArray(schema, getter, esperados, label)` eliminaría la repetición de tres loops casi idénticos sin afectar la legibilidad de las aserciones individuales.
- Los tres `CaptureEngine` del Bloque 6 (`ea`, `eaPartial`, y la instancia implícita de pipeline) podrían organizarse en secciones con comentarios de encabezado más explícitos para facilitar la lectura cuando se agreguen nuevos casos de autocalc en cadena.
