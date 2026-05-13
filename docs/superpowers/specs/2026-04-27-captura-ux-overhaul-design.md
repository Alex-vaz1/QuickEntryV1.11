# Captura UX Overhaul — Design

**Fecha:** 2026-04-27
**Sub-proyecto:** A (de la decomposición A/B/C en sesión de brainstorm 2026-04-27)
**Estado:** aprobado para writing-plans

---

## Goal

Mejorar la experiencia del operador durante la fase de captura (entre `^+a` y `^+s`):

1. **Tooltip de previo invertido**: el valor antes que el nombre del campo, para que el operador no termine "buscando dos veces" el nombre que acaba de cargar.
2. **Listo `x/n` con `cola llena` lema** y hint persistente de `^+e para revisar`, en vez del tooltip transitorio "Cola completa - usa ^+s o ^+u".
3. **Picker compacto de slots vía `^+e`**: GUI muestra los slots con sus valores actuales; click en una fila salta a ese slot. Tras llenarlo o omitirlo, el motor auto-avanza al **próximo slot vacío** (no sequential).
4. **Autocalc activado** para slots con `expectedFn` (Past due, Invoice Total Including PastDue): omitirlos pushea el valor calculado en vez de `""`.

---

## Contexto

Sesión de captura actual:
- `^+a` arma. Tooltip muestra `Busca "X" (slot/N)` + previo `Nombre: ▶ valor ◀`.
- `Ctrl+C` empuja a la cola via `OnClipboardChange`.
- `^+a` con cola activa = omitir slot actual (push `""` o autocalc según `AUTO_CALCULAR_TOTALES_OMITIDOS` global).
- `^+u` = undo del último.
- `^+e` = abre GUI de entrada manual para el slot actual (single-input, sin lista).
- `^+s` = paste batch + reset.

Limitaciones:
- Cola monotónica: no se puede volver a un slot omitido sin hacer `^+u`.
- "Cola completa" tooltip se muestra con timer de 1.5s y desaparece — el operador puede perder el aviso.
- En el previo, el nombre va primero (`Account number: ▶ ACC-1234 ◀`); el operador lo lee y "busca" ese nombre por reflejo, gasta tiempo confirmando que es el campo previo y no el siguiente.
- Autocalc desactivado por default → al omitir Past due, queda `""` y el operador tiene que ingresar el cálculo a mano.

---

## Decisiones

| ID | Decisión | Alternativas descartadas |
|---|---|---|
| **D1** | Formato del previo: `▶ valor ◀ (NombreCampo)` (paréntesis) | A) `: nombre` (mantenía ambigüedad). B) `— nombre`. D) Línea separada. |
| **D2** | Listo `x/n - cola llena - ^+s para pegar, ^+e para revisar` persistente; hint `^+e` siempre presente cuando `IsComplete`. | Mantener timer. Mostrar `^+e` solo si hay vacíos. |
| **D3** | `x` = `FilledCount` (slots con `queue[i] != ""`). Autocalc'd cuentan como llenos. Omitidos sin autocalc no cuentan. | `x` = `queue.Length` (cuenta omitidos). |
| **D4** | Click en slot lleno desde el picker = JUMP + input vacío; el próximo push **reemplaza** el valor previo. | A) Pre-fill input con valor (edit). C) Slots llenos read-only. |
| **D5** | Engine refactor α: `queue` pre-alocada a tamaño `schema.Length` con `""` en `Arm()`. `actionLog: Array<{slot, prevValue}>` para Undo. `targetSlot: Integer` (0 = sequential). | β) Mantener queue monotónica + Map paralelo `slotOverrides` (dos fuentes de verdad). |
| **D6** | Autocalc activado: `AUTO_CALCULAR_TOTALES_OMITIDOS := true` por default en QuickEntry. Slot sin `expectedFn` o con deps incompletas → sigue pusheando `""`. | Per-slot opt-out (over-engineered). |
| **D7** | Picker UX: input box arriba (bound a `NextSlot`), lista compacta abajo (solo slots vacíos por default), botón "Ver todos" expande la lista a los N slots. Click en fila = JumpTo + cierra GUI (input box no rebindea live). | Model 2: click rebindea input, Enter pushea al slot clickeado. Más complejo, fuera de scope. |

---

## Arquitectura — cambios por archivo

### `Lib/Schema.ahk`
Sin cambios. Las clases `Campo` y `InvoiceSchema` mantienen su contrato.

### `Lib/CaptureEngine.ahk` — refactor del estado

**Estado interno nuevo:**
```ahk
class CaptureEngine
{
    schema := ""
    queue := []                ; pre-alocada a schema.Length, todos ""
    actionLog := []            ; Array<Map>: cada accion = {slot, prevValue}
    targetSlot := 0            ; 0 = sequential; sino = slot al que saltar
    isCapturing := false
    clipBackup := ""
    autoCalcFlag := false
}
```

**Métodos modificados:**

- `Arm(snapshot := "")`:
  - `this.queue := []`
  - `Loop this.schema.Length: this.queue.Push("")`
  - `this.actionLog := []`
  - `this.targetSlot := 0`
  - `this.isCapturing := true`
  - `this.clipBackup := snapshot`

- `Reset()`:
  - `this.queue := []`
  - `this.actionLog := []`
  - `this.targetSlot := 0`
  - `this.isCapturing := false`
  - `this.clipBackup := ""`

- `NextSlot` (getter):
  - Si `targetSlot != 0` → retorna `targetSlot`
  - Sino primer índice `i` en `1..schema.Length` con `queue[i] = ""` → retorna `i`
  - Sino → retorna `0` (cola llena)

- `IsComplete => this.NextSlot = 0`

- `FilledCount`: cuenta de `queue[i] != ""` para `i in 1..schema.Length`. Para `x/n`.

- `PushRaw(raw)`:
  - `slot := this.NextSlot`
  - Si `slot = 0` → `Map(ok=false, error="cola completa", ...)`
  - `campo := schema.Field(slot)`
  - `limpio := campo.clean.Call(raw)`; si `""` → rechazo
  - `err := campo.validate.Call(limpio, this.queue)`; si `err != ""` → rechazo
  - **Registrar acción:** `this.actionLog.Push(Map("slot", slot, "prevValue", this.queue[slot]))`
  - `this.queue[slot] := limpio`
  - `this.targetSlot := 0` (clear override)
  - `this.AutoAdvance(slot)`
  - Retorna `Map(ok=true, slot=slot, label=campo.name, value=limpio, error="")`

- `PushManual(value) => this.PushRaw(value)` (sin cambios)

- `SkipCurrent()`:
  - `slot := this.NextSlot`; si `0` → `Map(slot=0, label="", value="")`
  - `campo := schema.Field(slot)`
  - `valor := ""`
  - Si `this.autoCalcFlag && IsObject(campo.expectedFn)`:
    - `valor := campo.expectedFn.Call(this.queue)` (puede retornar `""` si deps incompletas)
  - **Registrar acción** y mutar igual que PushRaw
  - `this.AutoAdvance(slot)`
  - Retorna `Map(slot, label, value)`

- `Undo()`:
  - Si `this.actionLog.Length = 0` → `Map(ok=false, slot=0, label="")`
  - `accion := this.actionLog.Pop()`
  - `slot := accion["slot"]`
  - `this.queue[slot] := accion["prevValue"]`
  - `this.targetSlot := slot` (cursor vuelve al slot deshecho)
  - Retorna `Map(ok=true, slot=slot, label=schema.Field(slot).name)`

- `JumpTo(slot)` **(nuevo)**:
  - Si `slot < 1 || slot > schema.Length` → throw `ValueError`
  - `this.targetSlot := slot`
  - Retorna `Map(slot=slot, label=schema.Field(slot).name)`

- `AutoAdvance(slotJustActed)` **(nuevo, helper privado)**:
  - Busca primer `i` en `slotJustActed+1 .. schema.Length` con `queue[i] = ""` → si encuentra, `targetSlot := i`, return
  - Sino busca primer `i` en `1 .. slotJustActed-1` con `queue[i] = ""` → si encuentra, `targetSlot := i`, return
  - Sino `targetSlot := 0` (cola llena)

- `ExpectedFor(slot)`: sin cambios (delega a `expectedFn` con `this.queue`).

- `PasteBatch(sendFn?, sleepFn?)`: sin cambios. Itera `schema.ordenPegado`, accede `queue[slot]`. La pre-alocación garantiza que `queue[slot]` siempre exista — slots con `""` no se pegan (gracias al `if (valor != "" && !campo.skipPaste)` existente).

### `Lib/TooltipFormatter.ahk` — formato y nuevo estado

- `EnNegrita(valor) => Chr(0x25B6) " " valor " " Chr(0x25C0)` (sin cambios)

- `LineaPrompt(engine)`:
  - Si `engine.IsComplete`:
    - retorna `"Listo " engine.FilledCount "/" engine.schema.Length " - cola llena - ^+s para pegar, ^+e para revisar"`
  - Sino:
    - `slot := engine.NextSlot`
    - `nombre := engine.schema.Field(slot).name`
    - `base := 'Busca "' nombre '" (' engine.FilledCount "/" engine.schema.Length ")"`
    - Si `engine.ExpectedFor(slot) != ""` → ` " - esperado: " esperado`
    - retorna `base`
  - **Cambio clave:** `x/n` ahora usa `FilledCount/schema.Length` (no `slot/schema.Length`).

- `LineaPrevio(engine, accion := "", valorOverride := "")`:
  - Si `engine.actionLog.Length = 0` → retorna `""`
  - `prevAccion := engine.actionLog[engine.actionLog.Length]`
  - `prevSlot := prevAccion["slot"]`
  - `prevNombre := engine.schema.Field(prevSlot).name`
  - `prevValor := (valorOverride != "") ? valorOverride : engine.queue[prevSlot]`
  - Si `prevValor = ""` → `prevValor := "(vacio)"`
  - `prefijo := (accion != "") ? accion ": " : ""`
  - retorna `prefijo EnNegrita(prevValor) " (" prevNombre ")"`
  - **Cambios:** (a) usa actionLog en vez de `queue.Length` para saber cuál es el "previo". (b) formato C: valor primero, nombre entre paréntesis.

- `LineasOperandos(engine)`: sin cambios estructurales. Sigue retornando líneas `Operando: valor`.

- `TooltipPostAccion`, `TooltipError`, `LineaInputInvalido`, `TooltipConError`: sin cambios.

### `Lib/ManualInputGui.ahk` — picker compacto

**Renombrar conceptualmente** (no el archivo): la GUI sigue siendo "manual input" pero ahora incluye una sección de slots.

**Layout:**
```
┌─────────────────────────────────────────────┐
│ Entrada manual / Picker — slot N (M/N)      │  ← titulo dinamico
├─────────────────────────────────────────────┤
│ Escribi el valor para "X" y dale Enter:     │  ← X = nombre del slot actual
│ [edit field..............................] │
│                          [Aceptar][Cancelar]│
├─────────────────────────────────────────────┤
│ Slots vacios:                               │
│   3.  Due date                              │  ← clickable
│   8.  Total ($)                             │
│   9.  Invoice Total Including PastDue       │
│                                             │
│ [Ver todos los slots]                       │  ← boton expand
└─────────────────────────────────────────────┘
```

Cuando se aprieta "Ver todos":
```
│ Todos los slots:                            │
│   1.  Account number          ACC-12345     │
│   2.  Invoice date            09/15/2026    │
│ → 3.  Due date                (vacio)       │  ← marca current
│   4.  Corp name               Empresa S.A.  │
│   ...                                       │
│ [Ocultar llenos]                            │
└─────────────────────────────────────────────┘
```

**Comportamiento:**
- `Open()`: si `engine.IsComplete`, abre igual (operador puede revisar/editar).
- Input box bound al `engine.NextSlot` actual al momento de Open. Si NextSlot=0 (cola llena), el input está deshabilitado (solo lectura) y el título dice "Cola llena - click en un slot para editar".
- `Confirm()` (input + Enter o botón Aceptar): `engine.PushManual(texto)` → si OK, cierra y refresca tooltip. Si error, deja GUI abierta y muestra `TooltipError`.
- Click en una fila de slot:
  - `engine.JumpTo(slot)`
  - `this.Close()`
  - `onAfterPush.Call(Map("slot", slot, "label", ..., "value", engine.queue[slot]), "jump")` para refrescar tooltip
- "Ver todos / Ocultar llenos": toggle del filtro de la lista.
- `Esc` o botón Cancelar: cierra sin acción.

### `QuickEntry.ahk`

- `global AUTO_CALCULAR_TOTALES_OMITIDOS := true` (flip).
- `RefrescarTooltip(res, accion := "")`: sin cambios estructurales. Cuando `accion = "jump"`, no muestra prefijo (similar a `"manual"`).

```ahk
RefrescarTooltip(res, accion := "")
{
    global engine
    accionMostrar := (accion = "manual" || accion = "jump") ? "" : accion
    ToolTip(TooltipPostAccion(engine, accionMostrar))
}
```

---

## Modelo de estado — diagrama

```
Arm()
  queue   = ["", "", "", "", "", "", "", "", ""]       (9 vacios)
  actionLog = []
  targetSlot = 0
  NextSlot = 1, FilledCount = 0, IsComplete = false

PushRaw("ACC-1234")
  queue[1] := "ACC-1234"
  actionLog := [{slot:1, prevValue:""}]
  targetSlot = 0; AutoAdvance(1) -> targetSlot = 0 (next "" es slot 2 via getter)
  NextSlot = 2, FilledCount = 1

PushRaw("Sep 15, 2026")
  queue[2] := "09/15/2026"
  actionLog := [{1,""}, {2,""}]
  NextSlot = 3, FilledCount = 2

SkipCurrent()  // slot 3, sin expectedFn -> ""
  queue[3] := ""
  actionLog := [{1,""}, {2,""}, {3,""}]
  AutoAdvance(3) -> primer "" desde slot 4 = slot 4
  NextSlot = 4, FilledCount = 2

PushRaw("Empresa S.A.")
  queue[4] := "Empresa S.A."
  actionLog := [{1,""}, {2,""}, {3,""}, {4,""}]
  NextSlot = 5 (siguiente "" desde 5 = 5), FilledCount = 3

[operador llena 5, 6, 7 (autocalc 500), 8]
  FilledCount = 7, queue[3] sigue ""
  NextSlot = 9 (8 esta lleno, 9 es el primer "")

[^+e -> picker abre, click en slot 3]
  JumpTo(3): targetSlot = 3
  GUI cierra. Tooltip: 'Busca "Due date" (7/9)'
  NextSlot = 3 (override)

PushRaw("10/15/2026")
  queue[3] := "10/15/2026"
  actionLog := [..., {3, ""}]
  targetSlot := 0
  AutoAdvance(3) -> slot 4 lleno, 5 lleno, ..., 9 vacio = slot 9
  NextSlot = 9, FilledCount = 8
  Tooltip: 'Busca "Invoice Total..." (8/9) - esperado: 3000.00'

SkipCurrent() // slot 9, autocalc -> "3000.00"
  queue[9] := "3000.00"
  AutoAdvance(9) -> ningun "" -> targetSlot = 0
  NextSlot = 0, FilledCount = 9, IsComplete = true
  Tooltip: 'Listo 9/9 - cola llena - ^+s para pegar, ^+e para revisar'

[^+s] -> PasteBatch itera ordenPegado, pega 9 valores (incluyendo el slot 3 recuperado)
```

---

## Edge cases

| # | Caso | Comportamiento |
|---|---|---|
| 1 | `^+e` con cola vacía | Abre picker. Lista vacíos = los 9 slots. Input bound a slot 1. |
| 2 | `^+e` con cola llena | Abre picker. Lista vacíos = vacía → muestra mensaje "Sin vacíos. Usa Ver todos para editar". Input deshabilitado. |
| 3 | Click en slot durante captura, después cierro picker sin push | `targetSlot` queda seteado. Próximo `Ctrl+C` o `^+e+manual` va a ese slot. Para "cancelar el jump", reabrir picker y clickear otro slot, o `^+u` (que también limpia el targetSlot al hacer pop). |
| 4 | `^+u` cuando `targetSlot != 0` y no hubo push después del jump | Pop del actionLog (la acción anterior al jump). `targetSlot` queda apuntando al slot deshecho (no al slot del jump). El jump no se registra en actionLog y queda implícitamente cancelado al sobrescribir `targetSlot`. Regla clara: `^+u` SIEMPRE deshace la última mutación de `queue`, nunca un jump. |
| 5 | Skip en slot con autocalc y deps incompletas | `expectedFn` retorna `""`. Pushea `""`. AutoAdvance al siguiente vacío. |
| 6 | AutoAdvance ciclo completo sin encontrar vacío (todo lleno tras un jump+push) | `targetSlot := 0`, IsComplete = true. Listo n/n. |
| 7 | Picker abierto, operador hace `Ctrl+C` (push externo) | `OnClipboardChange` dispara → `HandlerCaptura` push igual. La GUI no se actualiza live (la lista queda stale). Después de cerrar picker, si reabre, se refresca. **Aceptable por ahora.** Mejora futura: refresh on clipboard change. |
| 8 | Validación falla en push manual desde el picker | `Confirm` deja GUI abierta y muestra `TooltipError`. Ya es el comportamiento actual; no cambia. |
| 9 | `Reset()` mientras targetSlot está seteado | Limpia todo, vuelve a estado virgen. ✓ |
| 10 | `^+a` (omit) cuando `IsComplete` pero `targetSlot=0` | Tooltip ya muestra "Listo n/n". `^+a` no debería hacer nada destructivo. **Mantener comportamiento actual:** muestra mensaje "Cola completa..." y no omite. (En el flujo nuevo el operador usaría `^+e` para editar, no `^+a`.) |

---

## Testing

### Tests modificados

**`Tests/Test_CaptureEngine.ahk`** (~25 asserts adaptados):
- `e.queue.Length` → `e.schema.Length` o `e.FilledCount` según semántica.
- `e.queue[N]` siempre válido (pre-alocada).
- Asserts de Push: en vez de `e.queue.Length` post-push, validar `e.FilledCount` y `e.NextSlot`.
- Asserts de Skip: ídem.
- Asserts de Undo: `e.actionLog.Length` cambia, `e.queue[slot]` restaurado al `prevValue`.

### Tests nuevos

**`Tests/Test_CaptureEngine.ahk`**:
- `JumpTo(slot)` válido → `targetSlot = slot`, `NextSlot = slot`, `IsComplete = false`.
- `JumpTo(0)` o `JumpTo(N+1)` → throws `ValueError`.
- Push tras Jump: queue[slot] reemplazado, actionLog crece, targetSlot=0, AutoAdvance al próximo vacío.
- Skip tras Jump con autocalc: queue[slot] = calculado, AutoAdvance.
- Undo tras Jump+Push: pop, queue[slot] restaurado, targetSlot=slot.
- AutoAdvance: con queue[1,2,4,5] llenos y slot 3 vacío, push slot 1→targetSlot=2, push 2→targetSlot=3, etc.
- AutoAdvance ciclo: todo lleno excepto slot 5; jump a 9, push 9 → AutoAdvance encuentra slot 5 (escanea desde 10 = N+1 inválido, vuelve al 1..8, encuentra 5).
- `FilledCount` correcto: omitidos sin autocalc no cuentan; omitidos con autocalc sí.

**`Tests/Test_AsignetHeader.ahk`**:
- Pipeline con `autoCalc=true`: push 1-6 happy, skip 7 → `queue[7] = "500.00"`. Push 8 → `queue[8] = "2500.00"`. Skip 9 → `queue[9] = "3000.00"`. `IsComplete = true`, `FilledCount = 9`.
- Variante: skip 7 con dep5="" → `queue[7] = ""` (autocalc retorna "" porque deps incompletas).

**`Tests/Test_TooltipFormatter.ahk`**:
- `LineaPrompt` con cola llena → `"Listo N/N - cola llena - ^+s para pegar, ^+e para revisar"`.
- `LineaPrompt` con cola parcial usa `FilledCount/N`, no `slot/N`.
- `LineaPrevio` formato C: `▶ valor ◀ (NombreCampo)`.
- `LineaPrevio` consume `actionLog` (no `queue.Length`): después de jump+push, el "previo" es el slot que se acaba de pushear (no el último índice).

### Tests sin tocar

`Test_Cleaners.ahk`, `Test_Validators.ahk`, `Test_Schema.ahk` — el modelo de Campo/InvoiceSchema no cambia.

### Verificación final

`Tests/runner.ps1` debe terminar con `ALL TESTS PASSED` y ≥ 540 asserts (estimación: 519 actuales + ~25 nuevos).

---

## Out of scope (esta iteración)

- Refresh live de la GUI del picker cuando llega un `OnClipboardChange` con la GUI abierta.
- Pre-fill del input al clickear un slot lleno (Modelo 2 del picker).
- Per-slot opt-out del autocalc.
- Mostrar el valor calculado en el tooltip ANTES de omitir (preview ya existe via `esperado: X.XX` en LineaPrompt; no se cambia).
- Cambios al pipeline de paste (Sub-proyecto B).
- Variantes Asignet por lupa (Sub-proyecto C).

---

## Riesgos

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Tests rotos por refactor de queue (de monotonic a fixed-length) | Alta (esperado) | Plan implementación adapta tests slot por slot. ~25 asserts mecánicos. |
| Operador encuentra confuso que `^+u` "vuelva al slot deshecho" en vez de quedarse en NextSlot | Baja | Documentar en MANUAL_USUARIO. UX se siente bien: undo + recopia es flujo natural. |
| Picker bloquea input cuando `IsComplete && no vacios` | Baja | Mensaje claro + botón "Ver todos" para editar llenos. |

---

## Migración de docs

Después de implementar, actualizar:
- `docs/MANUAL_USUARIO.md`: nueva descripción del picker, Listo `x/n`, autocalc activado.
- `docs/GUIA_TECNICA.md`: estado interno del engine (queue pre-alocada, actionLog, targetSlot, AutoAdvance).
- `docs/PERSONALIZACION_HOTKEYS.md`: sin cambios (hotkeys siguen iguales).
- `docs/AGREGAR_EMPRESA.md`: sin cambios (contrato Schema/Campo no cambia).

---

## Próximo paso

Pasar a `superpowers:writing-plans` para producir el plan de implementación bite-sized en `docs/superpowers/plans/2026-04-27-captura-ux-overhaul-plan.md`.
