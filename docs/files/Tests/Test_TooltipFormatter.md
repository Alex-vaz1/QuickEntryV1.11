---
file: Tests/Test_TooltipFormatter.ahk
last_review: 2026-05-12
status: active
---

# `Tests/Test_TooltipFormatter.ahk`

## Propósito
Suite de tests de integración para `Lib/TooltipFormatter.ahk`. Ejerce las 8 funciones públicas del módulo (`EnNegrita`, `LineaPrompt`, `LineaPrevio`, `LineasOperandos`, `TooltipPostAccion`, `TooltipError`, `LineaInputInvalido`, `TooltipConError`) a través de un `CaptureEngine` real instanciado con `CrearAsignetHeaderV1()`. No hay mocks de engine: los tests validan contratos de presentación de extremo a extremo — formato de líneas, orden de secciones, invariantes de comportamiento por acción y cobertura del flujo de validación con error.

## Cobertura por función bajo test

### `EnNegrita` (líneas 17–19)
- Wrapping con flechas Unicode ▶ / ◀ en valor numérico, string vacío y string con espacios.
- 3 asserts.

### `TooltipPostAccion` (líneas 30–128, 258–259)
- **Estado inicial** (FilledCount=0): solo prompt, sin newline (t0).
- **Tras pushear slot 1**: línea 1 = prompt slot 2; línea 2 = previo formato C (`▶ valor ◀ (nombre)`); orden: prompt antes que previo.
- **Tras pushear hasta slot 5**: prompt con FilledCount correcto; previo del slot 5 en formato C.
- **Acciones sobre slot sin operandos** (`omitido`, `descartado`, `""`): prefijo `"omitido: "` / `"descartado: "` en línea previo; acción `""` (manual) NO agrega prefijo `"manual:"`.
- **Slot 7 con `expectedDeps`** (Past due): prompt con `"esperado: 500.00"`; 2 líneas de operandos (`Previous balance:` + `Past Total Payments:`); sin flechas ▶◀ en operandos; orden correcto (slot 5 antes de slot 6); exactamente 3 líneas totales.
- **Slot 7 con acción `omitido` cuando hay operandos**: operandos inalterados, acción ignorada.
- **Slot 9 con `expectedDeps`** (Invoice Total Including PastDue): `esperado: 3000.00`; operandos `Total ($):` + `Past due:`; orden definido por deps `[8, 7]`.
- **Cola completa** (9/9): `"Listo 9/9"`, `"cola llena"`, hints `^+s para pegar` y `^+e para revisar`; previo último slot en formato C.
- **Slot omitido muestra `(vacio)`**: formato C con `▶ (vacio) ◀ (Account number)`; FilledCount=0 no sube.
- **Engine con actionLog vacío + acción**: solo prompt (no crashea).
- 30 asserts distribuidos.

### `LineaPrompt` (líneas 151–153, 270–281)
- Slot 9 con deps: prompt incluye nombre y `"esperado: 3000.00"`.
- Cola completa: `"Listo 9/9"`, `"cola llena"`, hint paste + hint review siempre presente.
- Skip x9 sin autocalc: FilledCount=0, IsComplete=false (no se considera cola llena).
- 7 asserts.

### `LineasOperandos` (líneas 159–191)
- Engine en slot 9 (con deps `[8, 7]`): retorna 2 líneas separadas por `\n` con `Total ($):` y `Past due:`.
- Slot sin deps (slot 2): retorna `""`.
- Engine completo: retorna `""`.
- Dep omitida (slot 5 = `""`): línea muestra `"(vacio)"` en lugar del valor.
- 7 asserts.

### `LineaInputInvalido` (líneas 196–197)
- Formato default con hotkey `"^+a"`.
- Hotkey custom `"F8"`.
- 2 asserts.

### `TooltipConError` (líneas 202–237)
- **Slot sin operandos, detalle con validación**: mantiene prompt + previo formato C; agrega `"<label> invalido: <mensaje>"` + línea genérica con hotkey.
- **Slot sin operandos, detalle vacío** (rechazo del cleaner): mantiene prompt + previo; NO agrega línea `": mensaje"`; agrega solo línea genérica.
- **Hotkey custom propaga**: línea genérica refleja el hotkey pasado.
- **Slot con `expectedDeps`, detalle con validación**: prompt + ambos operandos + línea de detalle + línea genérica.
- 13 asserts.

### `TooltipError` (líneas 242–250)
- Formato `"<label> invalido: <mensaje>"` con label = nombre de campo (no número de slot).
- 3 casos: `"Past due"`, `"Invoice date"`, `"Previous balance"`.
- 3 asserts.

### `LineaPrevio` (líneas 287–311)
- Formato C: valor con flechas antes de nombre entre paréntesis; NO usa formato `"Nombre: valor"`.
- Tras `JumpTo(1)` + nuevo push: previo refleja el slot reemplazado, no el último ordinal.
- Con acción `"omitido"` y slot vacío: prefijo `"omitido: "` + `▶ (vacio) ◀ (Invoice date)`.
- 6 asserts.

## Dependencias

- **#Include directos**: `..\Lib\TooltipFormatter.ahk` (línea 4), `..\Schemas\AsignetHeaderV1.ahk` (línea 5), `_AssertHelpers.ahk` (línea 6)
- **Incluido por**: `Tests/runner.ps1` (discovery automático de `Test_*.ahk`)
- **Globales que define**: `NEGRITA_OPEN` (línea 11), `NEGRITA_CLOSE` (línea 12) — constantes locales usadas en asserts para comparación
- **Globales que usa (leídas)**: `g_failures`, `g_total` (vía `_AssertHelpers.ahk`)
- **Símbolos externos invocados**: `CaptureEngine` (instanciado 12 veces — líneas 24, 133, 143, 165, 171, 181, 202, 225, 256, 264, 287, 305), `CrearAsignetHeaderV1()` (12 veces — mismas líneas), `AssertEq`, `AssertContains`, `ReportarYSalir` (vía `_AssertHelpers.ahk`), `EnNegrita`, `LineaPrompt`, `LineaPrevio`, `LineasOperandos`, `TooltipPostAccion`, `TooltipError`, `LineaInputInvalido`, `TooltipConError` (vía `TooltipFormatter.ahk`)
- **Métodos de `CaptureEngine` invocados directamente**: `.Arm()`, `.PushRaw()`, `.SkipCurrent()`, `.JumpTo()`, `.FilledCount`, `.IsComplete`

## Notas técnicas (WHY no-obvio)

- **Tests de integración, no unitarios**: cada escenario construye un engine real con schema real (`CrearAsignetHeaderV1`). Esto valida que `TooltipFormatter` funcione correctamente con los tipos de campos, cleaners y deps que usa el sistema en producción — un mock de engine introduciría superficie de error que estos tests no detectarían.
- **12 engines distintos, sin reutilización entre secciones**: cada bloque de test arm-and-go con un engine fresco para evitar que el estado de una sección enmascare fallos en la siguiente. El coste en líneas es intencional.
- **`NEGRITA_OPEN`/`NEGRITA_CLOSE` declarados como globales locales**: los asserts comparan strings con `Chr(0x25B6)` y `Chr(0x25C0)`. Declararlos una vez evita que un cambio en el encoding de las constantes Unicode rompa los asserts silenciosamente.
- **Slot 7 y 9 prueban el contrato de `LineasOperandos` > `LineaPrevio`**: cuando hay `expectedDeps`, `TooltipPostAccion` NO muestra el previo del slot anterior (lo reemplaza con el breakdown de operandos). Los tests verifican explícitamente la ausencia de flechas ▶◀ en el bloque de operandos (`AssertEq(InStr(t7, NEGRITA_OPEN), 0, ...)`).
- **Acción `""` ≠ acción `"manual"`**: los tests en líneas 73–75 validan que pasar `accion=""` es el contrato para el flujo manual — no agrega prefijo. La string `"manual"` usada en línea 258 verifica el mismo contrato desde un engine vacío (sin actionLog).
- **`AssertEq(eOmCompl.IsComplete, false, ...)` (línea 282)**: valida que skip de todos los slots sin autocalc no dispara `IsComplete`; es un contrato de `CaptureEngine` verificado desde el contexto de `TooltipFormatter` porque `LineaPrompt` usa `IsComplete` para decidir el mensaje de "Listo".

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **BORRADOS (5 banners ====):** Setup engine con AsignetHeaderV1 (QUÉ puro), Tras pushear slot 1 (QUÉ puro), Tras pushear hasta slot 5 (QUÉ puro), Slot 9/Invoice Total Including PastDue (redundante con labels de asserts), Edge case: accion sin valor (absorbido por TooltipPostAccion), LineaPrompt cola llena (continuación, no función nueva).
  - **BORRADOS (4 comentarios inline):** `; 3 lineas exactas: prompt + op1 + op2` (QUÉ — el assert lo dice), `; Ahora proximo es slot 9 con esperado 3000.00` (QUÉ obvio del código), `; Hotkey custom propaga` (trivial, el assert habla), blank-line doble huérfano.
  - **REESCRITOS (3 comentarios):** Banner Constantes Unicode → WHY (cambio de encoding rompe asserts de forma visible). `; --- Linea 1 PRIMERO, linea 2 despues ---` → `; --- Orden garantizado: prompt (linea 1) va antes que previo (linea 2) ---`. `; Slot 7 con cola hasta 6: operandos [...]` → `; e3 esta en slot 9 (8 slots pusheados): verifica ops del slot actual, no del historico` (corregía además un label engañoso).
  - **AÑADIDOS (2 comentarios inline orientadores):** `; TooltipPostAccion con actionLog vacio + accion: no crashea, devuelve solo prompt` (antes de eEmpty). `; LineaPrompt cola llena: hints ^+s y ^+e SIEMPRE presentes (no dependen del estado)` (antes de eFin).
  - **Banners ====  conservados (8):** Constantes Unicode, EnNegrita, Estado inicial (TooltipPostAccion), Acciones omitido/descartado/manual, Slot 7 operandos (invariante LineasOperandos ⊥ LineaPrevio), Cola completa, Slot omitido (vacio), LineaPrompt, LineasOperandos, LineaInputInvalido, TooltipConError, TooltipError, LineaPrevio.
  - **Comentarios inline conservados (WHY):** `LineaPrevio vacia con actionLog vacio`, contrato `accion=""`, operandos NO usan flechas, orden definido operandos, operandos NO se afectan por accion, dep omitida muestra (vacio), caso validacion fallo vs rechazo, slot con expectedDeps, ahora en slot 7, Skip x9 sin autocalc, Tras Jump+Push, Previo con accion (omitido).
  - **Sintaxis validada:** `AutoHotkey64.exe /validate` → exit code 0, stderr vacío.

### Fase 3 — dead code
- [ ] Auditado
- Borrados (0 referencias en producción + tests):
- Candidatos para review senior (NO borrados):

## Ideas de simplificación pendientes (input para plan posterior)

- El bloque de setup repetido `e := CaptureEngine(CrearAsignetHeaderV1()) / e.Arm()` aparece 12 veces. Una función helper `NuevoEngine(autoCalc := true)` de 2 líneas eliminaría el boilerplate y haría cada sección más legible sin alterar los contratos probados.
- Los 30 asserts de `TooltipPostAccion` están lineales en el archivo (sin función wrapper). Agruparlos en bloques nomeados (o comentarios de sección más explícitos tipo `; === SUITE: acciones ===`) facilitaría buscar por funcionalidad cuando un assert falla y su número de línea es la única pista.
- `eOmCompl` (líneas 277–282) prueba un invariante de `CaptureEngine` (`IsComplete` con skip x9), no de `TooltipFormatter`. Podría moverse a `Test_CaptureEngine.ahk` para mantener la responsabilidad del archivo estrictamente en la capa de presentación.
