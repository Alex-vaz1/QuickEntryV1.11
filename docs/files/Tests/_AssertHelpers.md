---
file: Tests/_AssertHelpers.ahk
last_review: 2026-05-12
status: active
---

# `Tests/_AssertHelpers.ahk`

## Propósito

Biblioteca mínima de aserciones y reporting para el harness de tests de QuickEntry.
Define dos globals de estado (`g_failures`, `g_total`), dos funciones de aserción
(`AssertEq`, `AssertContains`) y una función de cierre (`ReportarYSalir`). No tiene
estado propio más allá de los contadores; no produce efectos de GUI ni interactúa con
el clipboard. Todos los archivos `Test_*.ahk` la incluyen vía `#Include _AssertHelpers.ahk`.

El formato de salida de `ReportarYSalir` (`=== N tests, F failures ===`) es el contrato
fijo que `Tests/runner.ps1` matchea con regex para determinar si una suite pasó o falló.

## API pública

### Globales

- **`g_failures`** — Contador de aserciones fallidas. Inicializado a `0` al nivel de
  script (línea 3). Incrementado en `AssertEq` y `AssertContains` cuando el assert falla.
  Leído en `ReportarYSalir` para emitir el resumen y como exit code.
  - Definida en: `Tests/_AssertHelpers.ahk:3`
  - Leída en: `Tests/_AssertHelpers.ahk:8, 15, 21, 27, 34, 35, 36` (vía `global g_failures, g_total` declarado en las tres funciones)

- **`g_total`** — Contador de aserciones ejecutadas (PASS + FAIL). Inicializado a `0`
  al nivel de script (línea 4). Incrementado en cada llamada a `AssertEq` y
  `AssertContains`, independientemente del resultado.
  - Definida en: `Tests/_AssertHelpers.ahk:4`
  - Leída en: `Tests/_AssertHelpers.ahk:8, 9, 21, 22, 34, 35` (vía `global` en mismas funciones)

### Funciones libres

- **`AssertEq(actual, expected, name)`** — Compara `actual == expected` (comparación
  estricta de AHK v2: tipo + valor). Si pasa, emite `"PASS  <name>\n"` a stdout (`"*"`).
  Si falla, incrementa `g_failures` y emite un bloque de tres líneas con
  `"FAIL  <name>"`, `"      expected: [<expected>]"` y `"      actual:   [<actual>]"`.
  - Firma exacta: `AssertEq(actual, expected, name)`
  - Definida en: `Tests/_AssertHelpers.ahk:6`
  - Llamada desde: todos los `Tests/Test_*.ahk` (7 archivos); no tiene callers en código productivo

- **`AssertContains(haystack, needle, name)`** — Verifica que `needle` es subcadena de
  `haystack` usando `InStr()` (case-sensitive por defecto de AHK v2). Si pasa, emite
  `"PASS  <name>\n"`. Si falla, incrementa `g_failures` y emite un bloque de tres líneas
  con `"FAIL  <name>"`, `"      haystack: [<haystack>]"` y `"      needle:   [<needle>]"`.
  - Firma exacta: `AssertContains(haystack, needle, name)`
  - Definida en: `Tests/_AssertHelpers.ahk:19`
  - Llamada desde: `Tests/Test_Cleaners.ahk`, `Tests/Test_TooltipFormatter.ahk` (y potencialmente otros Test_*.ahk que necesiten verificar substrings); no tiene callers en código productivo

- **`ReportarYSalir()`** — Emite la línea de resumen `"=== <g_total> tests, <g_failures> failures ==="` a stdout y llama a `ExitApp(g_failures > 0 ? 1 : 0)`. Exit code 0 = todos los tests pasaron; exit code 1 = al menos un fallo.
  - Firma exacta: `ReportarYSalir()`
  - Definida en: `Tests/_AssertHelpers.ahk:32`
  - Llamada desde: último statement de cada `Tests/Test_*.ahk` (7 archivos), como cierre obligatorio de la suite

## Dependencias

- **#Include directos**: ninguno (`#Requires AutoHotkey v2.0` únicamente)
- **Incluido por**:
  - `Tests/Test_AsignetHeader.ahk` (línea 6)
  - `Tests/Test_CaptureEngine.ahk` (línea 7)
  - `Tests/Test_Cleaners.ahk` (línea 5)
  - `Tests/Test_HudLayout.ahk` (línea 5)
  - `Tests/Test_Schema.ahk` (línea 6)
  - `Tests/Test_TooltipFormatter.ahk` (línea 6)
  - `Tests/Test_Validators.ahk` (línea 5)
- **Globales que define**: `g_failures` (línea 3), `g_total` (línea 4)
- **Globales que usa (leídas)**: las mismas `g_failures` y `g_total`, re-declaradas con `global g_failures, g_total` al inicio de cada función para satisfacer la semántica de AHK v2 (las globales nivel-script no son automáticamente visibles dentro de funciones)
- **Símbolos externos invocados**: `FileAppend()` (built-in, destino `"*"` = stdout), `InStr()` (built-in), `ExitApp()` (built-in)

## Notas técnicas (WHY no-obvio)

- **Destino `"*"` en `FileAppend`**: en AHK v2, `FileAppend(text, "*")` escribe a stdout del proceso. El runner `Tests/runner.ps1` captura este stdout para parsear resultados. Escribir a `"*"` en lugar de un archivo permite leer los resultados en tiempo real sin archivos temporales.

- **Formato de cierre matcheado por `runner.ps1`**: la línea `=== N tests, F failures ===` es el contrato con el harness PowerShell. `runner.ps1` usa un regex sobre este patrón para determinar si la suite pasó (exit code 0 del proceso AHK) o falló (exit code 1). Cambiar el formato rompe la integración con el runner sin ninguna advertencia visible en los tests mismos.

- **`global g_failures, g_total` dentro de cada función**: AHK v2 requiere declaración explícita de globales dentro de funciones (a diferencia de AHK v1). Sin estas declaraciones, cada función crearía variables locales homónimas y los contadores del nivel-script no se actualizarían. Esta es la causa más común de tests que siempre reportan `0 failures` silenciosamente en ports V1→V2.

- **`==` vs `=` en `AssertEq`**: el operador `==` en AHK v2 es case-sensitive (a diferencia de `=` que es case-insensitive para strings). La elección es deliberada: si un test espera `"ABC"` y recibe `"abc"`, debe fallar. Los callers que necesiten comparación case-insensitive deben normalizar los valores antes de llamar a `AssertEq`.

- **`InStr()` en `AssertContains` — case-sensitivity**: `InStr(haystack, needle)` sin parámetro de case es case-sensitive en AHK v2 por defecto (`CaseSense := true`). Si un test necesita búsqueda case-insensitive debe pre-aplicar `StrLower()` a ambos parámetros.

- **Sin `AssertNotEq` ni `AssertFalse`**: la biblioteca es intencionalmente mínima. Los tests de QuickEntry logran negación invirtiendo el expected (ej: `AssertEq(resultado, "", "campo vacío")`) o verificando que el resultado no contiene un substring (pasando haystack y needle en orden con expectativa de FAIL bloqueada por lógica de test). No se ha necesitado extender la API para las 756 aserciones actuales.

- **Hoja del grafo de dependencias**: `Tests/_AssertHelpers.ahk` tiene cero `#Include` (sólo `#Requires`). Es una de las cinco hojas del DAG de dependencias del repo (junto con `Lib/Cleaners.ahk`, `Lib/Schema.ahk`, `Lib/HudLayout.ahk`, `Lib/Validators.ahk`). No puede participar en ciclos.

- **`ExitApp` obligatorio al final de cada suite**: si un `Test_*.ahk` omite `ReportarYSalir()`, el proceso AHK queda en espera de hotkeys indefinidamente (comportamiento estándar de AHK). El runner.ps1 detecta esto como timeout y lo reporta como fallo de suite, no como error de test individual.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (no aplica — `_AssertHelpers.ahk` no contiene handlers de mouse ni referencias M720)

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno — el archivo no contiene comentarios de ningún tipo (ni banners, ni TODOs, ni código comentado). El fuente de 37 líneas es exclusivamente código ejecutable + `#Requires`. No hubo nada que borrar ni reescribir.

### Fase 3 — dead code
- [ ] Auditado
- Borrados:
- Candidatos para review senior:

## Ideas de simplificación pendientes

- Agregar `AssertTrue(cond, name)` y `AssertFalse(cond, name)` como azúcar para los tests que actualmente pasan `AssertEq(fn.Call(...), true, name)`. Cambio no-breaking: los callers existentes no cambiarían firma; sólo nuevos tests lo usarían.
- Unificar la lógica de "incrementar + emitir FAIL" en un helper interno `_Fail(name, lineas*)` para eliminar la duplicación entre `AssertEq` y `AssertContains`. Reducción de ~4 líneas repetidas a 1 llamada; no cambia comportamiento ni firma pública.
- El runner.ps1 podría recibir opcionalmente el conteo esperado de tests como argumento CLI y compararlo contra el `N` del resumen, detectando suites que terminan antes de tiempo (ej: un `ExitApp` prematuro por excepción no capturada). Requiere cambio coordinado en `runner.ps1` y una convención de comentario en cada `Test_*.ahk`.
