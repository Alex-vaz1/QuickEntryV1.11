# Guía Técnica — Asignet QuickEntry

Documentación de arquitectura para devs que vayan a mantener o extender QuickEntry.

---

## Vista de pájaro

QuickEntry permite cargar el header de una factura (9 campos) en el sistema web de Asignet con un solo hotkey de disparo, en vez de 9 ciclos manuales de copy/paste/Tab. El operador copia los campos en orden, el motor limpia/valida cada uno (texto OCR → valor canónico) y los pega todos juntos cuando se le dice.

**Filosofía:** un *schema* declara qué campos tiene una factura y cómo se limpian/validan. El motor (`CaptureEngine`) y el formateador de tooltips no saben nada de Asignet — funcionan con cualquier schema. Cambiar de empresa = escribir un schema nuevo, sin tocar el motor.

```
┌─────────────────┐     declara    ┌──────────────────────┐
│ Schema (lista   │ ─────────────► │ Campo (name, clean,  │
│  de Campos)     │                │ validate, tabs, ...) │
└────────┬────────┘                └──────────────────────┘
         │ alimenta
         ▼
┌─────────────────┐    push/undo    ┌──────────────────────┐
│ CaptureEngine   │ ◄────────────── │ QuickEntry.ahk       │
│ (cola + estado) │ ─────tooltip──► │ (hotkeys + handlers) │
└────────┬────────┘                 └─────┬────────────────┘
         │ paste batch                    │ formatea
         ▼                                ▼
   sistema web                    TooltipFormatter
                                  (puro, sin estado)
```

---

## Flujo end-to-end

| Hotkey | Qué hace |
|---|---|
| `^+a` | Triple rol según estado: (a) si HUD oculto/minimizado → **restaurar al frente**; (b) si captura activa con slot pendiente → **omitir** el slot actual (push `""` o autocálculo); (c) si captura no activa → **armar** + mostrar HUD. |
| _copy normal_ (`Ctrl+C`) | `OnClipboardChange` → `HandlerCaptura` → `engine.PushRaw(crudo)` → limpia, valida, encola o rechaza. |
| `^+e` | Toggle GUI manual para tipear el slot actual sin pasar por el clipboard. |
| `^+u` | Undo del último push. |
| `^+h` | **HeaderScan**: `engine.Scan()` lee los campos del form ya cargado, pre-popula la cola. Los preloaded se saltean en `PasteBatch`. |
| `^+s` | **Soltar**: `engine.PasteBatch()` pega los N valores con Tabs entre cada uno. |
| `^+r` | Reset (cancela sin pegar). |
| `^+v` | `PegadoEspecial()` — single-paste con limpieza, independiente del batch. |

Mientras hay captura activa, un tooltip persistente muestra:
- **Línea 1:** `Busca "Past due" (7/9) - esperado: 500.00`
- **Líneas 2-3** (si el campo tiene `expectedDeps`): breakdown de los operandos del cálculo. Si no, una sola línea con el campo previo `Previous balance: ▶ 1000 ◀`.
- Si un copy es inválido, se mantiene la base + `Past due inválido: suma debe ser 500.00` + `Input inválido, recopia o ^+a para omitir`.

---

## Las libs en detalle

### 1. `Lib/Schema.ahk` — el contrato
Define las dos clases más importantes del sistema. **No tiene lógica de negocio**, solo estructura.

- **`Campo`** — descriptor de un slot. Sus 7 propiedades:
  - `name` — display ("Past due"). Aparece en tooltips y errores.
  - `clean(raw) → string` — limpia el clipboard crudo. Devuelve `""` si rechaza.
  - `validate(val, cola) → ""|"error"` — valida el limpio contra la cola actual. La cola permite validaciones cruzadas (ej: "este número debe ser igual a la suma de los slots 5+6").
  - `tabsAfter` — Tabs tras pegar (1 default; útil para formularios donde un campo ocupa 2 controles).
  - `skipPaste` — si `true`, no pega valor, solo manda Tabs (campos con lupa).
  - `expectedFn(cola) → string` — opcional. Calcula el valor esperado para mostrarlo en el tooltip antes de copiar.
  - `expectedDeps: Array<Integer>` — opcional. Slots que alimentan `expectedFn`. El tooltip los muestra abajo del prompt.

- **`InvoiceSchema`** — colección ordenada de Campos.
  - `Length`, `Field(slot)` (1-based, lanza `ValueError` fuera de rango).
  - `ordenPegado: Array<Integer>` — opcional. Orden en que `PasteBatch` pega los slots al form. Default `[1..N]`. Permite copiar en orden de lectura y pegar en orden visual del form.
  - `prePasteSteps: Array<String>` — opcional. Directivas SendInput a ejecutar ANTES de pegar el primer slot (navegación al form, selección de tipo, etc.). Cada string se pasa tal cual a SendInput con 150ms entre pasos. Default `[]`.
  - `preScanSteps: Array<String>` — opcional. Navegación previa al HeaderScan. Si vacío, Scan usa `prePasteSteps`. Necesario cuando el form ya lleno tiene distinto tab-order que el form vacío (ej: campos readonly que no son tab stop en el form lleno pero sí en el vacío).

### 2. `Lib/Cleaners.ahk` — funciones puras de normalización
Sin estado, sin clipboard, sin GUI. Convierten el texto OCR crudo a la forma canónica.

| Función | Hace |
|---|---|
| `LimpiarFechaRobusta` | Múltiples formatos (`Sep 15 2026`, `15/09/26`, `2026-09-15`, etc.) → `MM/DD/YYYY`. |
| `MesTextoANumero`, `FormatearFecha`, `FormatearFechaTexto` | Helpers de fecha. |
| `NormalizarPrecio` | `$1,234.56`, `1.234,56`, `100 CR`, `-50` → `1234.56` o `-1234.56`. Maneja la ambigüedad coma/punto inteligentemente. |
| `DetectarNegativo` | Reconoce `CR`, `-`, `($100)`, etc. |
| `ForzarNegativo` | Para campos que siempre son egresos (Past payments). |
| `LimpiarComoPegadoEspecial` | Pipeline: prueba fecha → precio → texto. Es el cleaner "default" del schema actual. |
| `LimpiarBillingItem` | Strip de prefijos tipo "Item:", "Description:". |

**Cuándo agregar uno nuevo:** si tu empresa tiene un campo con formato exótico (CUIT, RUT, código alfanumérico con checksum), agregalo acá y referencialo desde el schema.

### 3. `Lib/Validators.ahk` — funciones puras de validación
Firma uniforme: `(val, cola) → ""` (OK) o `"mensaje"` (error). El error se muestra junto al `name` del campo en el tooltip.

- **Atómicos:** `ValidarNoVacio`, `ValidarNumero`, `ValidarFechaEstricta` (regex `MM/DD/YYYY`).
- **Builder:** `ValidarSumaTol(slotsIndices, tol := 0.01)` — devuelve un validator que verifica `val ≈ sum(cola[s] for s in slotsIndices)`. Si la cola aún no tiene esos slots, retorna `""` (skip). Esto es lo que valida que `Past due == Previous balance + Past payments`.

### 4. `Lib/CaptureEngine.ahk` — el motor
Estado y lógica de la cola. **Casi todo es testeable sin runtime AHK real** porque inyectamos cleaner/validator/sendFn.

Estado interno:
- `schema` (InvoiceSchema, inmutable durante una captura)
- `queue: Array<String>` — **pre-alocada a `schema.Length`** con `""` en `Arm`. `queue[i] != ""` significa "slot i lleno". Length es siempre `schema.Length`.
- `actionLog: Array<Map>` — cada `Push`/`Skip` registra `{slot, prevValue}`. `Undo` hace pop y restaura.
- `targetSlot: Integer` — `0` = sequential (`NextSlot` escanea queue por primer `""`). `!= 0` = el picker o un `Undo` forzó el cursor a ese slot.
- `preloadedSlots: Map<Integer, true>` — slots leídos por `Scan()`. `PasteBatch` los **saltea** (no re-pega, solo manda Tabs). Un `Push`/`Skip` manual sobre un slot preloaded lo quita del map.
- `isCapturing: Boolean`, `clipBackup: String`, `autoCalcFlag: Boolean`.

Métodos puros:
- `Arm(snapshot)` / `Reset()` — resetean estado vía `ResetState()` helper.
- `PushRaw(raw)` — limpia, valida, registra en actionLog, escribe `queue[NextSlot]`, llama `AutoAdvance`. Retorna `Map(ok, error, label, slot, value)`.
- `PushManual(value)` — alias.
- `SkipCurrent()` — push `""` o `expectedFn(queue)` si `autoCalcFlag` y hay `expectedFn`. Mismo pipeline de actionLog + AutoAdvance.
- `Undo()` — pop actionLog, `queue[slot] := prevValue`, `targetSlot := slot`. Retorna `Map(ok, slot, label)`.
- `JumpTo(slot)` — setea `targetSlot`. Throw `ValueError` fuera de rango.
- `ExpectedFor(slot)` — delega a `expectedFn` con `queue` como contexto.
- `NextSlot` — getter: `targetSlot` si != 0, sino primer `i` con `queue[i] = ""`, sino 0.
- `IsComplete` — `NextSlot = 0`.
- `FilledCount` — cuenta de `queue[i] != ""`. Usado en `LineaPrompt` para `x/n`.

Helper privado:
- `AutoAdvance(slotJustActed)` — busca primer `""` desde `slotJustActed+1` hacia adelante; si no, desde `1` hasta `slotJustActed-1`. Si no hay vacíos, `targetSlot := 0`.

Métodos con side effects (probados en integración manual):
- `Scan(captureFieldFn?, sendFn?, sleepFn?, clipSnapshot?)` — ejecuta `schema.preScanSteps` (o `prePasteSteps` si no hay preScanSteps), luego itera `ordenPegado`: para cada slot lee el campo del form con `captureFieldFn` (default: Ctrl+A + Ctrl+C), limpia el valor y si es válido lo guarda en `queue` + marca como `preloadedSlots`. Al final, `AutoAdvance(0)` posiciona en el primer slot vacío.
- `PasteBatch(sendFn?, sleepFn?)` — ejecuta `schema.prePasteSteps`, luego itera `schema.ordenPegado` poniendo valor en clipboard + `^v` + `tabsAfter` Tabs. **Saltea paste para slots preloaded** (solo manda Tabs). **No manda Tabs después del último slot.** Restaura `clipBackup` al final. `sendFn`/`sleepFn` son inyectables para tests.

**Cambio semántico importante:** `Skip` sin autocalc deja `queue[slot] = ""` y `AutoAdvance` puede volver a ese slot después (ciclico). La cola solo es `IsComplete` cuando todos los slots están `!= ""` (autocalc o push real). Esto habilita el flujo del picker: omitir → seguir adelante → volver a llenar el slot vacío más tarde.

### 5. `Lib/TooltipFormatter.ahk` — funciones puras, generan strings
- `LineaPrompt(engine)`:
  - Cola llena: `Listo x/n - cola llena - ^+s para pegar, ^+e para revisar` (persistente, hint `^+e` siempre).
  - Captura activa: `Busca "X" (x/n)` donde `x = FilledCount`. Si el slot tiene `expectedFn`: ` - esperado: 500.00`.
- `LineaPrevio(engine, accion?, valorOverride?)` — formato C: `▶ valor ◀ (NombreCampo)`. Lee el último entry de `actionLog` (no `queue.Length`), por lo que tras un `JumpTo` + `PushRaw` refleja el slot recién actuado, no "el último de la cola". Para `accion = "manual"` o `"jump"` no hay prefijo.
- `LineasOperandos(engine)` — si el próximo slot tiene `expectedDeps`, devuelve N líneas con `Operando: valor`. Subsume al previo.
- `TooltipPostAccion` — compone prompt + (operandos | previo).
- `TooltipError(label, msg)` → `"Past due invalido: suma debe ser 500.00"`.
- `LineaInputInvalido(hotkey)` → `"Input invalido, recopia o ^+a para omitir"`.
- `TooltipConError(engine, detalle, hotkey)` — base completa + detalle (vacío para rechazo del cleaner) + línea genérica.

### 6. `Lib/PegadoEspecial.ahk` — paste inteligente standalone
Función `PegadoEspecial()` con lock global `pegadoEnCurso`. Snapshot clipboard → `LimpiarComoPegadoEspecial` → paste → restaura. Los timings críticos están nombrados como constantes a nivel de módulo (`PEGADO_MODIFIER_DRAIN_MS`, `PEGADO_CLIPBOARD_WAIT_S`, `PEGADO_POST_PASTE_SETTLE_MS`, `PEGADO_MUTEX_DRAIN_MS`). El `Sleep PEGADO_MUTEX_DRAIN_MS` en `finally` antes de soltar el lock drena los `OnClipboardChange` encolados, evitando contaminar la cola si el batch está armado.

### 7. `Lib/HudLayout.ahk` — layout puro (sin estado, sin GUI)
Módulo de utilidades estáticas para layout responsive del HUD principal. Sin estado, sin clases instanciables, sin dependencias. Todo testeable con asserts puros.

- `IsCompact(width) → Bool` — `width < 540` ⇒ modo compacto (breakpoint inclusive del lado normal: `540` es normal, `539` es compact).
- `LabelForSlot(idx, isCompact) → String` — devuelve el nombre de slot (`"Past due"` vs `"PD"`). Tabla `slotLabels` con 9 entradas.
- `LabelForButton(id, isCompact) → String` — texto del botón (`"▶▶ Pegar"` vs `"▶▶"`). Tabla `buttonLabels` con 11 entradas.
- `NameColWidth(isCompact) → Integer` — 200 px normal, 100 px compact (calibrado al label más largo del schema).
- `IsRectVisibleAgainst(x, y, w, h, monitors) → Bool` — devuelve `true` si el rect se solapa al menos 100×100 px con algún monitor. Lo usa `MainHud.LoadPosition` para recuperar de configuraciones de monitor obsoletas (desconexión, cambio de resolución).

### 8. `Lib/MainHud.ahk` — HUD principal con captura inline
Clase `MainHud(engine)` que construye y mantiene la GUI principal: tabla de slots con valores actuales, botones de acción, posición persistida en INI, modo template, inline-edit de slot. Tema light (`bg #F8FAFC`, labels `#1F2937`, fuente Segoe UI / Cascadia Mono).

Responsabilidades:
- **Build y render.** `Build()` construye la GUI (slot rows + footer buttons + botones de acción). `Update()` reescribe valores cada vez que el engine cambia. `RenderMode()` decide normal vs compact según el ancho actual.
- **Inline edit.** `OpenInlineEditOnCurrentSlot()` (hotkey `^+e`) y `ShowInlineEdit(slot)` (click sobre la fila) abren un Edit overlay sobre la celda. `OnInlineEditCommit` llama `engine.PushManual` o `PushForce` según corresponda. ESC cancela.
- **Persistencia INI.** `LoadPosition()` lee `QuickEntry.ini` y restaura la posición de la GUI; si la posición guardada queda fuera de los monitores actuales (`!IsRectVisibleAgainst`), cae a default. `SaveLastPosition` / `SaveAsDefault` / `SaveTemplateMode` escriben al INI según gatillo.
- **Callbacks por nombre.** Los botones del footer hacen `DoArmOrSkip()`, `DoHeaderScan(true)`, `DoSoltar(true)`, `DoReset()`, `DoUndo()` — funciones globales definidas en `QuickEntry.ahk`. Esta es la única dependencia invertida del grafo: HUD → entry point, resuelta en runtime porque AHK v2 carga todo en el mismo scope.

Sin tests unit (es GUI con side effects). Smoke test manual.

### 9. `Lib/AutoCalculator.ahk` — calculadora flotante
Clase `AutoCalculator()` opcional para sumar manualmente valores que el operador ve en el PDF. Toggle vía botón del HUD. GUI minimal:
- Input multilínea: el operador pega tokens crudos (con $, comas, paréntesis).
- `ExtractNumberTokens` los parsea con regex tolerante a OCR.
- Lista de números detectados.
- Total al fondo, copiable al clipboard con un click.

Útil para verificar a ojo que `Past due = Previous balance + Past payments` antes de copiar. Tema alineado con el HUD principal vía globals `AUTOCALC_*`.

### 10. `QuickEntry.ahk` — entry point
Cablea todo: hotkeys de teclado, `OnClipboardChange HandlerCaptura`, instancia `engine := CaptureEngine(...)` y `hud := MainHud(engine)` con el schema. Define las funciones top-level `DoArmOrSkip`, `DoSoltar`, `DoHeaderScan`, `DoReset`, `DoUndo`, `DoPegadoEspecial` que los hotkeys y los botones del HUD invocan. Para cambiar de empresa, **solo se toca este archivo** (la línea `CrearAsignetHeaderV1()`).

---

## Por qué los Schemas son el corazón del sistema

El motor no sabe qué es una "factura de Asignet". Sabe que hay N slots ordenados, cada uno con su `clean`/`validate`/`tabsAfter`. Toda la lógica específica de la empresa vive en un único archivo declarativo en `Schemas/`.

**Ventajas:**
- **Open/Closed:** agregar Empresa B = nuevo archivo en `Schemas/`, cero cambios en `Lib/`.
- **Testeable:** `Test_AsignetHeader.ahk` valida el schema entero sin tocar runtime.
- **Auditable:** todo el comportamiento de un formulario está en una tabla de ~10 líneas.
- **Reutilizable:** validators y cleaners se comparten entre schemas.

> Para agregar una empresa nueva paso a paso, ver [AGREGAR_EMPRESA.md](AGREGAR_EMPRESA.md).

---

## Tests

```powershell
powershell -ExecutionPolicy Bypass -File Tests\runner.ps1
```

7 archivos de test:
- `Test_Cleaners.ahk` — pipelines de limpieza (fechas, precios, texto sucio).
- `Test_Validators.ahk` — validators atómicos y builders.
- `Test_Schema.ahk` — contrato Campo / InvoiceSchema.
- `Test_CaptureEngine.ahk` — push, undo, skip, paste batch (con sendFn/sleepFn inyectados).
- `Test_TooltipFormatter.ahk` — composición de líneas prompt/previo/operandos/error.
- `Test_AsignetHeader.ahk` — schema integrado end-to-end.
- `Test_HudLayout.ahk` — modo compact, labels por slot/button, visibilidad rect-vs-monitor.

Salida esperada: `ALL TESTS PASSED`, **756 asserts**, exit 0. El runner detecta crashes mirando si la línea de summary apareció (no se confía solo en exit code: AHK con `/ErrorStdOut=utf-8` puede salir 0 incluso ante errores no atrapados).

El path de AutoHotkey64 se resuelve automáticamente con discovery portable: `$env:AHK_V2` → `$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe` → `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`. Si AHK v2 no está instalado en una ubicación estándar, definir `$env:AHK_V2` apuntando al ejecutable.

---

## Decisiones de diseño clave

- **Schema declarativo** en lugar de un `if (slot == 7)` por todos lados. Una empresa nueva = un archivo nuevo en `Schemas/`. La lógica del motor no cambia.
- **Validators puros + builders.** `ValidarSumaTol([5, 6])` retorna un closure (`.Bind()`). No hace falta tocar el motor para sumar slots distintos.
- **Errores con nombre del campo.** El operador no piensa en "slot 7", piensa en "Past due".
- **Tooltip de dos líneas con `▶ valor ◀`.** Línea 1 = qué viene; línea 2 = qué acabás de cargar (con marca visual fácil de revisar a ojo).
- **Sin `PegarDosFechas` legacy.** Funcionalidad nunca usada en producción, eliminada al refactorizar.
- **`PegadoEspecial` aislado.** Vive con su propio lock global y un Sleep de drenado para no contaminar la cola del batch cuando se usan ambos en simultáneo.
- **TDD con asserts custom + runner.ps1.** Suite completa en < 2s; el runner falla loud si un test crashea (no espera exit code).

---

## Cosas a tener en cuenta cuando editás un schema

- **`tabsAfter` del último slot se ignora** (el batch no manda Tab final).
- **`expectedFn` sin `expectedDeps`** funciona pero perdés el breakdown visual — siempre declarálos juntos.
- Los **índices de `expectedDeps`/`ValidarSumaTol` son 1-based** y absolutos respecto al schema. Si reordenás campos, actualizalos.
- **`skipPaste=true` igual respeta `tabsAfter`**, así que para un campo de lupa con Tab simple después, va `(name, ..., 1, true)`.
- Para un campo que **siempre es egreso** (como Past payments), envolvé el cleaner: `clean := (raw) => { x := LimpiarComoPegadoEspecial(raw); return (x="") ? "" : ForzarNegativo(x) }` o usá el helper local `CleanPasoPegadoForzandoNegativo` que ya existe en el schema actual.
