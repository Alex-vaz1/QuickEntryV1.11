---
file: Tests/Test_Validators.ahk
last_review: 2026-05-12
last_cleanup: 2026-05-12
status: active
---

# `Tests/Test_Validators.ahk`

## Propósito

Suite de tests unitarios de caja negra para `Lib/Validators.ahk`. Cubre las cinco funciones del módulo: el predicado base `EsImporteValido`, los tres validators atómicos (`ValidarNoVacio`, `ValidarNumero`, `ValidarFechaEstricta`) y el builder `ValidarSumaTol` (que engloba indirectamente a `ValidarSumaCheck`). Se ejecuta con el harness `Tests/runner.ps1` y reporta exit-code via `ReportarYSalir()`.

## API pública

Este archivo es un **script ejecutable**, no un módulo. No expone funciones ni clases. Su API es implícita: al terminar, `ReportarYSalir()` hace exit con código 0 (todos OK) o 1 (algún fallo).

### Bloques de cobertura

- **`EsImporteValido`** (líneas 10–23) — 14 asserts.
  - Casos válidos: entero positivo, decimal, entero negativo, decimal negativo, cero, cero decimal.
  - Casos inválidos: vacío, letras, símbolo `$`, coma de miles, punto sin decimales, decimal sin parte entera, signo sufijo, doble signo.

- **`ValidarNoVacio`** (líneas 28–30) — 3 asserts.
  - Acepta texto no vacío y strings con espacios (no trim).
  - Rechaza cadena vacía; mensaje contiene `"vacio"`.

- **`ValidarNumero`** (líneas 35–40) — 6 asserts.
  - Acepta decimal, negativo, cero.
  - Rechaza texto, vacío, símbolo; mensaje contiene `"numero"`.

- **`ValidarFechaEstricta`** (líneas 45–54) — 10 asserts.
  - Acepta `MM/DD/YYYY` con padding correcto (dic, ene, sep).
  - Rechaza mes sin pad, día sin pad, año de 2 dígitos, formato textual, mes 13, día 32, vacío; mensaje contiene `"fecha"`.

- **`ValidarSumaTol` builder + `ValidarSumaCheck`** (líneas 59–99) — 19 asserts.
  - Builder `v7` con slots `[5, 6]` (tol default `0.01`): suma correcta, suma errónea (mensaje incluye valor esperado formateado).
  - Tolerancia `±0.01`: acepta `+0.01` y `-0.01`, rechaza `+0.02` y `-0.02`.
  - Semántica skip: slot vacío en dep5, slot vacío en dep6, cola más corta que maxIdx — todos retornan `""`.
  - Builder `v3` con slots `[1, 2, 3]`: suma OK, suma errónea con esperado formateado.
  - Tolerancia custom `1.0` (`v7Loose`): acepta `±0.50`, rechaza `+2.00`.
  - Rechazo pre-suma: no-número y vacío producen mensaje `"numero"` antes de comparar suma.
  - Closures independientes (`vA` slots `[1,2]`, `vB` slots `[3,4]`): cada closure suma su propio subconjunto sin interferencia.

## Dependencias

- **#Include directos**:
  - `../Lib/Validators.ahk` (línea 4) — módulo bajo test.
  - `_AssertHelpers.ahk` (línea 5) — helpers `AssertEq`, `AssertContains`, `ReportarYSalir`.
- **Incluido por**: `Tests/runner.ps1` (descubierto por glob `Test_*.ahk`).
- **Globales que define**: (ninguna propias — hereda `g_failures` y `g_total` de `_AssertHelpers.ahk`).
- **Globales que usa (leídas)**: `g_failures`, `g_total` (vía `ReportarYSalir`).
- **Símbolos externos invocados**: `AssertEq`, `AssertContains`, `ReportarYSalir` (de `_AssertHelpers.ahk`); toda la API de `Lib/Validators.ahk`.

## Notas técnicas (WHY no-obvio)

- **Patrón `[5, 6]` en `v7`**: los índices `5` y `6` corresponden a los slots Amount1 y Amount2 del schema real `AsignetHeaderV1`. El array `cola` usado en los tests simula la fila completa con 6 elementos (`["A", "D1", "D2", "Corp", "1000.00", "-500.00"]`), reflejando la posición exacta que tendría en producción. Los tests de skip (`""` en dep5, dep6 y cola corta) documentan el contrato de graceful degradation.

- **Closures independientes (`vA`/`vB`)**: el bloque final (líneas 94–99) prueba que dos invocaciones de `ValidarSumaTol` no comparten estado — cada closure cierra sobre su propio `slotsIndices`. Es un test de regresión contra el anti-pattern de captura de variable por referencia en lugar de por valor (relevante en AHK v2 donde `.Bind` fija parámetros parciales en el momento de la llamada).

- **`cola` pasado como `[]` en validators atómicos**: `ValidarNoVacio`, `ValidarNumero` y `ValidarFechaEstricta` reciben `[]` vacío como segundo argumento, documentando que ignoran `cola` y que la firma `(val, cola)` es uniforme aunque solo `ValidarSumaCheck` la use.

- **Ausencia de tests de `ValidarSumaCheck` directo**: la función es helper interno (sin callers externos). Los 19 asserts de `ValidarSumaTol` la cubren exhaustivamente de forma indirecta; no hay valor en testearla directamente porque hacerlo requeriría conocer su firma extendida `(slotsIndices, tol, val, cola)` que no es API pública.

- **Conteo total de asserts en este archivo**: 14 + 3 + 6 + 10 + 19 = **52 asserts**.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (ninguno — `Tests/Test_Validators.ahk` no contiene handlers de mouse ni referencias a M720)

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Borrados**: ninguno — el archivo no contenía banners decorativos puros, código comentado ni TODOs.
  - **Reescritos (QUÉ → WHY)**:
    - Línea 66: `; --- Tolerancia +-0.01 ---` → `; --- tol=0.01 es la frontera: cubre redondeo bancario a 2 dec sin enmascarar errores reales ---`
    - Línea 89: `; --- Validator rechaza no-numero ---` → `; --- la validacion de formato precede a la suma: evita que "abc" llegue a Float() ---`
  - **Conservados con justificación**: 5 banners de sección (`ValidarSumaTol` skip, 3 slots, tolerancia custom, closures independientes) + los 7 banners de función de nivel superior — todos orientativos, no decorativos.
  - **Sintaxis**: validada con `AutoHotkey64.exe /validate` → exit 0, sin errores.

### Fase 3 — dead code
- [ ] Auditado
- Borrados (0 referencias en producción + tests):
- Candidatos para review senior (NO borrados):

## Ideas de simplificación pendientes (input para plan posterior)

- El bloque de `ValidarSumaTol` (19 asserts en ~40 líneas) podría reorganizarse en sub-secciones comentadas más granulares (tolerancia / skip / closures independientes) para reducir la carga cognitiva al leer el archivo; actualmente los comentarios de sección son escasos.
- Los arrays `cola` hardcodeados en cada assert de `ValidarSumaTol` se repiten con mínimas variaciones; extraer una constante `colaBase` al tope del bloque eliminaría la redundancia y haría los diffs más legibles si el schema real cambia de longitud.
- Agregar un assert que verifique que `v7.Call("500.00", colaConNaN, ...)` (un slot con valor no numérico como `"abc"`) dispara skip en lugar de un crash, completando el contrato de `ValidarSumaCheck` para inputs malformados en las dependencias (hoy solo se cubre vacío y cola corta).
