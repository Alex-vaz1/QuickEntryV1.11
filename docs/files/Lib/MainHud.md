---
file: Lib/MainHud.ahk
last_review: 2026-05-12
last_cleanup: 2026-05-12
status: active
---

# `Lib/MainHud.ahk`

## Propósito

GUI principal persistente de QuickEntry. Reemplaza el ToolTip de estado por una ventana redimensionable (`+Resize`) siempre-encima (`+AlwaysOnTop`) que muestra en tiempo real el estado de cada slot del `CaptureEngine`: nombre, valor actual, icono de estado y highlight del slot activo. Soporta edición inline por click en el valor, jump de slot por click en el nombre, persistencia de posición/tamaño en INI, modo compacto/normal según ancho de ventana y un panel de botones que despacha los handlers `Do*` del entry point.

## API pública

### Globales que define (paleta y fuentes)

| Global | Valor | Propósito |
|---|---|---|
| `MAINHUD_BG` | `"F8FAFC"` | Fondo de ventana (gris-azulado casi blanco) |
| `MAINHUD_BG_ACTIVE` | `"DBEAFE"` | Tint azul claro del slot apuntado por `NextSlot` |
| `MAINHUD_FG_LABEL` | `"1F2937"` | Texto dark-gray para nombres de campo |
| `MAINHUD_FG_DIM` | `"9CA3AF"` | Gris medio: slots vacíos / inactivos |
| `MAINHUD_FG_FILLED` | `"15803D"` | Verde: slot con valor válido confirmado |
| `MAINHUD_FG_PRELOAD` | `"1D4ED8"` | Azul medio: slot preloaded (paste anterior) |
| `MAINHUD_FG_FORCED` | `"D97706"` | Ámbar: `pendingInvalidValue` pendiente de forzar |
| `MAINHUD_FG_ACTIVE` | `"1E40AF"` | Azul Asignet profundo: slot activo (`NextSlot`) |
| `MAINHUD_FG_ERROR` | `"DC2626"` | Rojo: icono `!` cuando hay `pendingInvalidValue` |
| `MAINHUD_FONT_VALUE` | `"Cascadia Mono"` | Fuente de valores numéricos |
| `MAINHUD_FONT_LABEL` | `"Segoe UI"` | Fuente de labels / nombres de campo |

### Clases

- **`MainHud(engine)`** — GUI principal de captura; recibe el singleton `CaptureEngine` en construcción.
  - **Propiedades**:
    - `engine` — referencia al `CaptureEngine` (inyectada en `__New`)
    - `gui` — instancia `Gui` de AHK v2; `""` hasta que `Build()` se llame
    - `rows` — `Array` de `Map`; `rows[i]` contiene `"bgUnderlay"`, `"slotTxt"`, `"nameCtrl"`, `"valueCtrl"`, `"iconCtrl"`, `"forceBtn"`, `"pendingInvalidValue"`, `"opRows"`
    - `inlineEditCtrl` — control `Edit` persistente (creado en `Build`, oculto hasta `ShowInlineEdit`)
    - `inlineEditDefaultBtn` — `Button` Default hidden (recibe Enter mientras `inlineEditCtrl` está visible)
    - `inlineEditActive` — `Boolean`; `true` cuando hay edición inline en curso
    - `inlineEditSlot` — `Integer`; índice del slot en edición (1-based), `0` si inactivo
    - `inlineEditCommitting` — `Boolean`; semáforo de re-entrada en `OnInlineEditCommit`
    - `autoCalc` — instancia lazy de `AutoCalculator`; `""` hasta primer `OnAutoCalc`
    - `btnTooltips` — `Map(hwnd → texto)` para hover-help sobre botones del footer
    - `mouseMoveRegistered` — `Boolean`; guard de `OnMessage(0x0200, ...)` único
    - `lastTooltipHwnd` — `Integer`; debounce de `OnMouseMoveHover`
    - `titleCounterCtrl` — `""` (barra de título removida; `Update()` lo chequea con `IsObject`)
    - `btnArm` — ref al botón "▶ Iniciar / ▷ Omitir"; label cambia según `engine.isCapturing`
    - `btnTemplateToggle` — ref al botón "☐/☑ Template"
    - `buttonsById` — `Map(id → ctrl)` con keys `"start"`, `"templateOff"`, `"scan"`, `"release"`, `"reset"`, `"undo"`, `"loadLast"`, `"autocalc"`, `"setDefault"`
    - `currentMode` — `"normal"` | `"compact"`; se recalcula en `OnResize`
    - `templateMode` — `Boolean`; persistido en INI; controla `SetExtraTabsAfter(1, 0|1)`
    - `lastX`, `lastY`, `lastW`, `lastH` — posición/tamaño de última sesión (leídos de INI)
    - `defaultX`, `defaultY`, `defaultW`, `defaultH` — posición/tamaño default guardado con `SaveAsDefault`
    - `iniPath` — `A_AppData "\QuickEntry\layout.ini"`

  - **Métodos**:

    - `__New(engine)` — inicializa `iniPath`, crea `DirCreate`, llama `LoadPosition()`
      - Llamado desde: `QuickEntry.ahk:36`
      - Llama a: `LoadPosition()`

    - `EnumMonitorsForLayout() → Array<Map>` — itera monitores con `MonitorGetCount` / `MonitorGetWorkArea`; retorna array de Maps `{l, t, r, b}` con work areas. Devuelve `[]` si falla (defensivo).
      - Llamado desde: `LoadPosition()`
      - Llama a: `MonitorGetCount()`, `MonitorGetWorkArea()`

    - `LoadPosition()` — lee `layout.ini` (sección `[Window]`) y valida que lastX/Y y defaultX/Y sean visibles en algún monitor via `HudLayout.IsRectVisibleAgainst`; si no, centra en monitor primario.
      - Llamado desde: `__New()`
      - Llama a: `IniRead()`, `MonitorGetWorkArea()`, `MonitorGetPrimary()`, `EnumMonitorsForLayout()`, `HudLayout.IsRectVisibleAgainst()`

    - `SaveLastPosition()` — lee posición actual de `this.gui` y persiste `lastX/Y/W/H` en INI.
      - Llamado desde: `OnClose()`
      - Llama a: `this.gui.GetPos()`, `IniWrite()`

    - `SaveAsDefault()` — persiste la posición actual como `defaultX/Y/W/H` y también como `lastX/Y/W/H` en INI. Muestra ToolTip de confirmación 1500 ms.
      - Llamado desde: handler del botón `btnSetDefault` (wired en `Build()`)
      - Llama a: `this.gui.GetPos()`, `IniWrite()`, `ToolTip()`, `SetTimer()`

    - `SaveTemplateMode()` — persiste `this.templateMode` como `"1"` / `"0"` en INI.
      - Llamado desde: `OnTemplateToggle()`
      - Llama a: `IniWrite()`

    - `Build()` — crea la ventana `Gui`, todos los controles (slot rows + footer buttons + inline edit controls), wires todos los handlers, registra `OnMessage(0x0200)` y los eventos `Close/Escape/ContextMenu/Size` del GUI.
      - Llamado desde: `Show()` (lazy, sólo si `!IsObject(this.gui)`)
      - Llama a: `Gui()`, `g.Add()`, `MakeJumpHandler()`, `MakeValueHandler()`, `MakeForceHandler()`, `OnMessage()`, `ObjBindMethod()`, `HudLayout.LabelForButton()`

    - `RenderMode(mode)` — aplica el modo `"normal"` | `"compact"` a labels de slot (vía `HudLayout.LabelForSlot`), labels de botones (vía `HudLayout.LabelForButton`), anchos de columnas de slot rows y posiciones/anchos de footer buttons.
      - Llamado desde: `Show()`, `OnResize()`
      - Llama a: `HudLayout.LabelForSlot()`, `HudLayout.LabelForButton()`, `HudLayout.NameColWidth()`, `ctrl.Move()`, `this.gui.GetClientPos()`

    - `OnResize()` — callback `g.OnEvent("Size", ...)`. Recalcula `currentMode` según ancho cliente; si cambia, llama `RenderMode`; si no, sólo actualiza `bgUnderlay` de cada fila.
      - Llamado desde: evento `Size` del GUI (wired en `Build()`)
      - Llama a: `this.gui.GetClientPos()`, `HudLayout.IsCompact()`, `RenderMode()`, `row["bgUnderlay"].Move()`

    - `OnClose(*)` — guarda posición y oculta sin cerrar el script.
      - Llamado desde: evento `Close` del GUI (wired en `Build()`)
      - Llama a: `SaveLastPosition()`, `Hide()`

    - `OnEscape(*)` — alias de `Hide()`.
      - Llamado desde: evento `Escape` del GUI (wired en `Build()`)
      - Llama a: `Hide()`

    - `Show()` — si `gui` no existe, llama `Build()`. Muestra con posición/tamaño del INI. Aplica `RenderMode` según ancho inicial.
      - Llamado desde: `QuickEntry.ahk:41, 146, 169, 333`; `OpenInlineEditOnCurrentSlot()`; `OnLoadLast()`
      - Llama a: `Build()`, `this.gui.Show()`, `this.gui.GetClientPos()`, `HudLayout.IsCompact()`, `RenderMode()`

    - `Hide()` — oculta la ventana si existe.
      - Llamado desde: `QuickEntry.ahk:242`; `OnClose()`; `OnEscape()`
      - Llama a: `this.gui.Hide()`

    - `Update()` — refresca TODOS los controles de la GUI con el estado actual del engine: label del `btnArm`, label del `btnTemplateToggle`, counter de título (stub), y por cada slot: background highlight (underlay + 4 controles), color y valor del `valueCtrl` (truncado a 28 chars; muestra `pendingInvalidValue` en ámbar si lo hay), ícono de estado y visibilidad del `forceBtn`.
      - Llamado desde: `QuickEntry.ahk:44, 124, 147, 170, 225, 334`; `OnRowClickName()`; `OnRowClickValue()`; `OnForceCommit()`; `OnInlineEditCommit()`; `OnInlineEditEsc()`; `OpenInlineEditOnCurrentSlot()`; `OnLoadLast()`
      - Llama a: `HudLayout.LabelForButton()`, `TruncarValor()`, `this.engine.*` (varios)

    - `TruncarValor(valor, esVacio, slotIdx) → String` — helper privado; si vacío y slot es `NextSlot`, retorna `"esperado: " + engine.ExpectedFor(slotIdx)`; si largo (> 28 chars), trunca a 25 + `"..."`; sino el valor tal cual.
      - Llamado desde: `Update()`
      - Llama a: `this.engine.ExpectedFor()`, `StrLen()`, `SubStr()`

    - `MakeJumpHandler(slot) → Closure` — factory de handler de click en `slotTxt` / `nameCtrl`.
      - Llamado desde: `Build()`
      - Llama a: (retorna closure que llama `OnRowClickName(slot)`)

    - `MakeValueHandler(slot) → Closure` — factory de handler de click en `valueCtrl`.
      - Llamado desde: `Build()`
      - Llama a: (retorna closure que llama `OnRowClickValue(slot)`)

    - `MakeForceHandler(slot) → Closure` — factory de handler de click en `forceBtn`.
      - Llamado desde: `Build()`
      - Llama a: (retorna closure que llama `OnForceCommit(slot)`)

    - `OpenInlineEditOnCurrentSlot()` — hotkey `^+e`: si no hay captura activa o cola llena, muestra ToolTip y retorna. Si `inlineEditActive`, hace commit previo. Luego `JumpTo(NextSlot)` + `ShowInlineEdit`.
      - Llamado desde: `QuickEntry.ahk:270`
      - Llama a: `Show()`, `OnInlineEditCommit()`, `this.engine.JumpTo()`, `Update()`, `ShowInlineEdit()`

    - `OnRowClickName(slot)` — click en nombre/número de slot: commit inline pendiente, luego `engine.JumpTo(slot)` y `Update()`.
      - Llamado desde: closure creada por `MakeJumpHandler()`
      - Llama a: `OnInlineEditCommit()`, `this.engine.JumpTo()`, `Update()`

    - `OnRowClickValue(slot)` — click en valor de slot: commit inline pendiente, `JumpTo`, `Update`, `ShowInlineEdit`.
      - Llamado desde: closure creada por `MakeValueHandler()`
      - Llama a: `OnInlineEditCommit()`, `this.engine.JumpTo()`, `Update()`, `ShowInlineEdit()`

    - `OnForceCommit(slot)` — click en botón `✓`: toma `pendingInvalidValue` del row, hace `JumpTo + PushForce`, limpia `pendingInvalidValue`, llama `Update()`.
      - Llamado desde: closure creada por `MakeForceHandler()`
      - Llama a: `this.engine.JumpTo()`, `this.engine.PushForce()`, `Update()`

    - `ShowInlineEdit(slot)` — posiciona y muestra `inlineEditCtrl` sobre el `valueCtrl` del slot; oculta `valueCtrl`; rellena con `pendingInvalidValue` si lo hay, sino con `engine.queue[slot]`; muestra `inlineEditDefaultBtn`; da foco; registra hotkey `Escape` scoped al HWND del GUI.
      - Llamado desde: `OpenInlineEditOnCurrentSlot()`; `OnRowClickValue()`
      - Llama a: `OnInlineEditCommit()`, `row["valueCtrl"].GetPos()`, `this.inlineEditCtrl.Move()`, `this.inlineEditCtrl.Focus()`, `HotIfWinActive()`, `Hotkey()`

    - `OnInlineEditCommit()` — semáforo `inlineEditCommitting` para evitar re-entrada (LoseFocus puede dispararse durante el commit). Si `Trim(val) = ""` → `engine.ClearSlot` (no pasa por `PushManual`). Si no → `engine.PushManual(val)`; si falla validación, guarda en `pendingInvalidValue`; si ok, limpia. Siempre llama `CloseInlineEdit()` + `Update()`.
      - Llamado desde: evento `LoseFocus` de `inlineEditCtrl`; click en `inlineEditDefaultBtn` (Enter); `OpenInlineEditOnCurrentSlot()`; `OnRowClickName()`; `OnRowClickValue()`; `ShowInlineEdit()`
      - Llama a: `this.engine.ClearSlot()`, `this.engine.JumpTo()`, `this.engine.PushManual()`, `CloseInlineEdit()`, `Update()`

    - `OnInlineEditEsc()` — Escape scoped al GUI: descarta edición sin commit y llama `Update()`.
      - Llamado desde: `Hotkey("Escape", ...)` registrado en `ShowInlineEdit()`
      - Llama a: `CloseInlineEdit()`, `Update()`

    - `CloseInlineEdit()` — oculta `inlineEditCtrl` + `inlineEditDefaultBtn`, restaura `valueCtrl`, limpia flags, desactiva hotkey Escape.
      - Llamado desde: `OnInlineEditCommit()`; `OnInlineEditEsc()`
      - Llama a: `HotIfWinActive()`, `Hotkey("Escape", "Off")`

    - `ClearAllPendingInvalid()` — limpia `pendingInvalidValue` de todos los rows; llamado tras Reset o PasteBatch para que los pending de la sesión anterior no sobrevivan.
      - Llamado desde: `QuickEntry.ahk:219, 241`
      - Llama a: (itera `this.rows` directo)

    - `OnLoadLast()` — llama `LoadLastPaste()`; si retorna `true`, llama `Show()` + `Update()`.
      - Llamado desde: handler del botón "↻ Load Last" (wired en `Build()`)
      - Llama a: `LoadLastPaste()`, `Show()`, `Update()`

    - `OnTemplateToggle()` — invierte `templateMode`, persiste en INI, sync inmediato con `engine.SetExtraTabsAfter` si hay captura activa, refresca label del botón.
      - Llamado desde: handler del botón "☐/☑ Template" (wired en `Build()`)
      - Llama a: `SaveTemplateMode()`, `this.engine.SetExtraTabsAfter()`, `HudLayout.LabelForButton()`

    - `OnAutoCalc()` — instancia lazy de `AutoCalculator`; llama `autoCalc.Show()`.
      - Llamado desde: handler del botón "Σ Calc" (wired en `Build()`)
      - Llama a: `AutoCalculator()`, `this.autoCalc.Show()`

    - `SaveLastPaste()` — vuelca `engine.queue[1..n]` al archivo `%AppData%\QuickEntry\last_paste.ini` (sección `[Queue]`, claves `slot1..slotN`). Sanitiza `\r\n` y `\n` antes de `IniWrite`.
      - Llamado desde: `QuickEntry.ahk:217`
      - Llama a: `FileDelete()`, `IniWrite()`, `StrReplace()`

    - `LoadLastPaste() → Boolean` — lee `last_paste.ini`; si no existe, ToolTip y `false`. Si hay captura en curso con datos, pide confirmación `MsgBox`. Hace `engine.Arm()`, restaura queue slot a slot, llama `engine.AutoAdvance(0)`. Retorna `true` si éxito.
      - Llamado desde: `OnLoadLast()`
      - Llama a: `FileExist()`, `IniRead()`, `this.engine.Arm()`, `this.engine.AutoAdvance()`, `MsgBox()`, `ToolTip()`, `SetTimer()`

    - `OnMouseMoveHover(wParam, lParam, msg, hwnd)` — callback de `WM_MOUSEMOVE (0x0200)`. Debounce por `lastTooltipHwnd`; muestra ToolTip del botón si `btnTooltips.Has(hwnd)`, o borra ToolTip al salir.
      - Llamado desde: `OnMessage(0x0200, ...)` registrado en `Build()`
      - Llama a: `ToolTip()`

## Dependencias

- **#Include directos**: `CaptureEngine.ahk`, `TooltipFormatter.ahk`, `AutoCalculator.ahk`, `HudLayout.ahk`
- **Incluido por**: `QuickEntry.ahk` (línea 9 del entry point)
- **Globales que define**: `MAINHUD_BG`, `MAINHUD_BG_ACTIVE`, `MAINHUD_FG_LABEL`, `MAINHUD_FG_DIM`, `MAINHUD_FG_FILLED`, `MAINHUD_FG_PRELOAD`, `MAINHUD_FG_FORCED`, `MAINHUD_FG_ACTIVE`, `MAINHUD_FG_ERROR`, `MAINHUD_FONT_VALUE`, `MAINHUD_FONT_LABEL` (paleta de colores y fuentes del HUD)
- **Globales que usa (leídas)**: todas las `MAINHUD_*` listadas arriba (definidas en el mismo archivo)
- **Símbolos externos invocados**:
  - `HudLayout.IsRectVisibleAgainst()` — `Lib/HudLayout.ahk`
  - `HudLayout.LabelForSlot()` — `Lib/HudLayout.ahk`
  - `HudLayout.LabelForButton()` — `Lib/HudLayout.ahk`
  - `HudLayout.NameColWidth()` — `Lib/HudLayout.ahk`
  - `HudLayout.IsCompact()` — `Lib/HudLayout.ahk`
  - `AutoCalculator()` — `Lib/AutoCalculator.ahk` (lazy, instanciado en `OnAutoCalc`)
  - `DoArmOrSkip()` — `QuickEntry.ahk` (referencia runtime, no por `#Include`)
  - `DoHeaderScan(true)` — `QuickEntry.ahk` (ídem)
  - `DoSoltar(true)` — `QuickEntry.ahk` (ídem)
  - `DoReset()` — `QuickEntry.ahk` (ídem)
  - `DoUndo()` — `QuickEntry.ahk` (ídem)

## Notas técnicas (WHY no-obvio)

- **Acoplamiento bidireccional entry-point ↔ HUD**: `MainHud` invoca `DoArmOrSkip`, `DoHeaderScan`, `DoSoltar`, `DoReset`, `DoUndo` — funciones top-level definidas en `QuickEntry.ahk`. Esto no es detectable por `#Include` y es la única dependencia "invertida" del grafo. El HUD actúa como si el entry point fuera un namespace global implícito. En un refactor, estos callbacks deberían inyectarse al constructor.

- **`inlineEditCommitting` semáforo de re-entrada**: `OnInlineEditCommit` puede ser disparado por `LoseFocus` mientras ya está ejecutándose (si el commit mismo provoca un cambio de foco). El flag corta la re-entrada antes de cualquier operación del engine, evitando doble-PushManual.

- **Persistent inline edit controls**: `inlineEditCtrl` y `inlineEditDefaultBtn` se crean una sola vez en `Build()` y se reusan en cada `ShowInlineEdit`/`CloseInlineEdit`. Crearlos y destruirlos en cada edición causaba flickering y pérdidas de foco en AHK v2. El Default button debe estar en posición visible (1x1 px) aunque hidden — si está off-screen puede no recibir el routing de Enter de forma confiable.

- **Click en controles Text no dispara LoseFocus en Edit**: cuando el usuario hace click en `nameCtrl` (un `Text`) mientras hay edición inline activa, AHK v2 no genera `LoseFocus` en el `Edit` porque los controles `Text` no toman foco. Por eso `OnRowClickName` y `OnRowClickValue` hacen `OnInlineEditCommit()` explícito antes de cualquier `JumpTo`.

- **`pendingInvalidValue` sobrevive a `CloseInlineEdit`**: a diferencia de canceling (Escape, que llama `CloseInlineEdit` sin tocar `pendingInvalidValue`), el flujo de validación fallida en `OnInlineEditCommit` guarda el valor rechazado en `rows[slot]["pendingInvalidValue"]` para que `Update()` lo muestre en ámbar con icono `!` y botón `✓`. La limpieza ocurre sólo en `ClearAllPendingInvalid()` (Reset/PasteBatch) o cuando un push posterior al mismo slot tiene éxito.

- **Background highlight continuo (underlay pattern)**: cada fila tiene un control `Text` transparente (`bgUnderlay`) que cubre toda la fila en z-order bajo, más 4 controles internos. Para lograr fondo continuo sin gaps, todos los 5 controles reciben la misma opción `+Background<COLOR>` o `+BackgroundTrans`, seguida de `Redraw()`. Sin el `Redraw()` explícito AHK v2 no invalida el área del control en algunos formularios.

- **INI de posición con validación multi-monitor**: `LoadPosition` usa `HudLayout.IsRectVisibleAgainst` contra el resultado de `EnumMonitorsForLayout()` para detectar si una posición guardada en una sesión anterior ya no es visible (monitor desconectado, resolución cambiada). Si no es visible, centra en el monitor primario. El fallback defensivo del `try/catch` en `EnumMonitorsForLayout` retorna `[]`, lo que fuerza el centrado.

- **Modo compacto/normal determinado por ancho de ventana**: `HudLayout.IsCompact(w)` define el umbral. `RenderMode` reposiciona controles con `Move()` — no reconstruye la ventana. Los anchos de botones en modo compact son ~36 px (cuadrados con sólo el ícono) vs los anchos del plan Task 7 en modo normal.

- **`OnMessage(0x0200)` registrado una sola vez**: el guard `mouseMoveRegistered` evita registrar el mismo handler múltiples veces si `Build()` fuera llamado más de una vez (aunque la lógica de `Show()` sólo llama `Build()` si `!IsObject(this.gui)`).

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (no aplica — MainHud.ahk no contiene handlers de mouse M720)

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:

**Borrados (redundantes / QUÉ obvio / narrativa histórica):**

- `Lib/MainHud.ahk:7-13` — borrado: banner original de 7 líneas con descripción narrativa — razón: reemplazado por banner de 6 líneas que dice WHY (redimensionable, inline-edit, INI) y no el QUÉ ("reemplaza el ToolTip de estado")
- `Lib/MainHud.ahk:15` — borrado: `; --- Constantes de estilo ---` — razón: banner decorativo sin información; reemplazado por `; --- Paleta de colores y fuentes (light theme) ---` que dice el contexto real
- `Lib/MainHud.ahk:67` — borrado: `; --- INI persistence ---` — razón: banner decorativo puro; reemplazado por sección `; ==== PERSISTENCE ====`
- `Lib/MainHud.ahk:68-70` — borrado: bloque narrativo de 3 líneas describiendo `EnumMonitorsForLayout` QUÉ ("itera todos los monitores activos...") — razón: reescrito en el docblock del método con WHY añadido (por qué devuelve `[]` y qué consecuencia tiene)
- `Lib/MainHud.ahk:85-87` — borrado: `; Defensivo: si MonitorGetCount/WorkArea fallan, devolver vacio. / IsRectVisibleAgainst con [] retorna false -> caera a centrar.` — razón: WHY real movido al docblock del método; el catch vacío ahora es intencional visible
- `Lib/MainHud.ahk:93` — borrado: `; --- Tamanio: respetar lo guardado en INI (defaults si no existe) ---` — razón: QUÉ obvio (IniRead con defaults)
- `Lib/MainHud.ahk:99-100` — borrado: `; --- Posicion: respetar INI si la ventana es visible en algun monitor; / ; sino caer a centrado en monitor primario. ---` — razón: WHY condensado como comentario inline en la variable `centerX/Y`
- `Lib/MainHud.ahk:107` — borrado: `; lastX/Y` — razón: label de variable obvio
- `Lib/MainHud.ahk:133` — borrado: `; defaultX/Y (con misma logica)` — razón: label de variable obvio
- `Lib/MainHud.ahk:207` — borrado: `; --- Lifecycle ---` — razón: banner decorativo; reemplazado por `; ==== BUILD ====`
- `Lib/MainHud.ahk:221-222` — borrado: `; --- Title bar removido para ganar espacio vertical (Task 6 del plan 2026-05-10). this.titleCounterCtrl queda como "" (sin control). / ; Update() chequea IsObject(this.titleCounterCtrl) antes de usarlo.` — razón: narrativa histórica (referencia a task de plan ya ejecutado)
- `Lib/MainHud.ahk:235` — borrado: comentario "Underlay: cubre toda la fila para pintar fondo continuo... Se agrega PRIMERO para que quede en z-order mas bajo" de 3 líneas — razón: condensado en comentario de 2 líneas manteniendo solo el WHY (z-order, controles encima)
- `Lib/MainHud.ahk:243` — borrado: `; Numero de slot` — razón: QUÉ obvio (el literal `i` en el control lo dice)
- `Lib/MainHud.ahk:241-247` — borrado: tres comentarios inline `; Nombre del campo (clickable -> JumpTo)`, `; Valor (clickable -> JumpTo + edit inline)`, `; Icono de estado` — razón: QUÉ obvio leído en los nombres de variables `nameCtrl`, `valueCtrl`, `iconCtrl`
- `Lib/MainHud.ahk:257` — borrado: `; Wire click handlers (closures sobre i)` — razón: QUÉ obvio (las 3 líneas siguientes son las closures)
- `Lib/MainHud.ahk:279-283` — borrado: comentario "Botones removidos: ⌨ Editar y 📋 Pegar limpio..." — razón: narrativa histórica; los hotkeys siguen en `QuickEntry.ahk`, no es información accionable aquí
- `Lib/MainHud.ahk:285-286` — borrado: `; Row 1 - botones +20% ancho (110->132, 90->108) con X reajustadas (gap=4). h28 (-15%).` — razón: narrativa de diseño (delta de tamaños); condensado a `; Anchos +20% vs diseño original (gap=4px entre botones).`
- `Lib/MainHud.ahk:291-296` — borrado: comentarios `; Row 2 - botones...` y `; Row 3 - botones...` con deltas de medidas — razón: misma razón; deltas de tamaño no son WHY
- `Lib/MainHud.ahk:303` — borrado: `; Save button refs - Update() refresca labels en cada call` — razón: condensado (el WHY "Update() refresca" ya se expresa en el comentario del bloque buttonsById)
- `Lib/MainHud.ahk:307` — borrado: `; Wire handlers` — razón: QUÉ obvio (las 9 líneas `.OnEvent` son evidentes)
- `Lib/MainHud.ahk:318-319` — borrado: `; Map button IDs -> control refs (for HudLayout-driven re-render). / ; IDs match HudLayout.LabelForButton lookup keys.` — razón: condensado a un comentario de una línea manteniendo el WHY (lookup keys)
- `Lib/MainHud.ahk:321-322` — borrado: comentarios `; texto cambia...` e `; idem entre on/off` en el Map literal — razón: QUÉ obvio por los nombres de key `"start"`, `"templateOff"`
- `Lib/MainHud.ahk:332` — borrado: `; --- Persistent inline edit controls (hidden until ShowInlineEdit) ---` — razón: reemplazado por banner de 2 líneas con WHY real (flickering en AHK v2)
- `Lib/MainHud.ahk:345` — borrado: `; Map button HWND -> tooltip text para hover help` — razón: QUÉ obvio (el Map se auto-documenta)
- `Lib/MainHud.ahk:357` — borrado: `; Registrar handler global de WM_MOUSEMOVE (0x0200) - solo una vez` — razón: WHY (una sola vez / guard) condensado en el bloque `if !this.mouseMoveRegistered`
- `Lib/MainHud.ahk:364` — borrado: `; Eventos placeholder (handlers reales en Tasks 5-7)` — razón: narrativa histórica (Tasks ya ejecutados)
- `Lib/MainHud.ahk:372-373` — borrado: `; Aplica el modo (normal/compact) a los textos de slots y botones. / ; NO reposiciona controles ni cambia anchos (eso es Task 8).` — razón: "Task 8" es narrativa histórica; lo que hace el método (incluyendo reposicionado) ahora se describe sin referencia a tasks
- `Lib/MainHud.ahk:387-390` — borrado: bloque de 4 líneas sobre `btnArm` y `btnTemplateToggle` en `RenderMode` explicando "Task 9" — razón: narrativa histórica; el comportamiento se documenta correctamente en el `continue` con comentario inline
- `Lib/MainHud.ahk:399-400` — borrado: `; Botones simples (texto fijo independiente de estado):` — razón: QUÉ parcial; el loop lo dice
- `Lib/MainHud.ahk:409-421` — reescrito: bloque de coordenadas de slot rows — razón: QUÉ → WHY; se conservan las coordenadas absolutas con sus nombres semánticos (`nameX`, `valueX`, `iconX`, `forceX`) y se explica la tabla de anchos por nombre de columna
- `Lib/MainHud.ahk:434-435` — borrado: `; --- Footer botones: en compact, los achicamos para que sean cuadraditos --- / ; Definimos anchos de botones por modo. En compact, todos ~36px (cuadrados).` — razón: condensado a una línea con WHY (cuadrados con sólo el ícono)
- `Lib/MainHud.ahk:444-448` — borrado: tres comentarios `; Row 1 compact: Template | Scan | Pegar` etc. — razón: QUÉ obvio; el array de IDs lo dice
- `Lib/MainHud.ahk:453-456`, `462-465` — borrado: `; Row 2 compact` y `; Row 3 compact` — razón: misma razón
- `Lib/MainHud.ahk:474-475` — borrado: `; Normal mode: posiciones de las 3 filas con botones +20% (Task 7 + DPI bump). / ; Coincidir con Build(): widths multiplicadas x1.2, X reajustadas (gap=4).` — razón: narrativa histórica (Task 7 / DPI bump); condensado a comentario sin referencia a tasks
- `Lib/MainHud.ahk:505-508` — borrado: `; Mismo modo: solo actualizar bgUnderlay para que cubra todo el ancho` — razón: QUÉ obvio; el código es una sola línea `Move(, , w - 24)`
- `Lib/MainHud.ahk:513-514` — borrado: `; Stub - guardar posicion + ocultar (sin cerrar el script)` — razón: "Stub" es narrativa histórica; el cuerpo del método es la documentación
- `Lib/MainHud.ahk:520-521` — borrado: `; Stub - igual a OnClose` — razón: misma razón; `OnEscape` llama `Hide()` directamente
- `Lib/MainHud.ahk:528` — borrado: `; Swap Arm button label segun si hay captura activa` — razón: QUÉ obvio
- `Lib/MainHud.ahk:536-537` — borrado: `; Refrescar label del template toggle (puede haber cambiado el flag)` — razón: QUÉ obvio
- `Lib/MainHud.ahk:546-547`, `551` — borrado: `; Title counter` y `; Por slot` — razón: QUÉ obvio
- `Lib/MainHud.ahk:575` — borrado: `; --- Slot index + name color ---` — razón: QUÉ obvio; el bloque if/else siguiente es explícito
- `Lib/MainHud.ahk:615-617` — borrado: `; --- Icon + Force button --- / ; Si hay pendingInvalidValue: "!" rojo persistente + boton ✓ visible. / ; Sino: icono normal de estado + boton ✓ oculto.` — razón: condensado a una línea con WHY (qué estados implica)
- `Lib/MainHud.ahk:645` — borrado: `; --- Helper: trunca el valor o muestra "esperado: X" si activo y vacio ---` — razón: QUÉ obvio; el nombre del método `TruncarValor` y sus parámetros son suficientes
- `Lib/MainHud.ahk:682` — borrado: `; --- Click handlers ---` — razón: banner decorativo; reemplazado por `; ==== CLICK HANDLERS ====`
- `Lib/MainHud.ahk:687-691` — borrado: bloque de 5 líneas narrativas de `OpenInlineEditOnCurrentSlot` describiendo Escape, minimizado, etc. — razón: condensado a 2 líneas con los casos de borde relevantes
- `Lib/MainHud.ahk:758` — borrado: `; --- Inline edit ---` — razón: banner decorativo; reemplazado por `; ==== INLINE EDIT ====`
- `Lib/MainHud.ahk:836-841` — borrado: comentario `; Push valido: limpiar pendingInvalidValue del slot si lo tenia.` — razón: QUÉ obvio (el `else` del `if !res["ok"]`)
- `Lib/MainHud.ahk:868-869`, `872-873` — borrado: `; Restaurar valueCtrl` y `; Desactivar hotkey de Esc` — razón: QUÉ obvio; el código es una línea cada uno
- `Lib/MainHud.ahk:993` — borrado: `; --- Mouse hover tooltip handler (WM_MOUSEMOVE callback) ---` — razón: banner decorativo; reemplazado por comentario inline con WHY (debounce)

**Reescritos (QUÉ → WHY):**

- `Lib/MainHud.ahk:71-74` — reescrito: docblock de `EnumMonitorsForLayout` — de "itera todos los monitores activos" a WHY explicando qué le pasa a `IsRectVisibleAgainst` con `[]` y qué consecuencia tiene para `LoadPosition`
- `Lib/MainHud.ahk:100-101` — reescrito: comentario de posición fallback — de descripción de lógica a WHY ("cuando la posición guardada ya no es visible")
- `Lib/MainHud.ahk:218-219` — reescrito: comentario de footer layout — eliminados deltas de tamaño históricos, conservada descripción semántica de las 3 filas
- `Lib/MainHud.ahk:237-239` — reescrito: comentario de `bgUnderlay` — de QUÉ ("Underlay: cubre toda la fila...") a WHY (z-order bajo necesario para que controles internos queden encima)
- `Lib/MainHud.ahk:258-260` — reescrito: comentario de `forceBtn` — condensado manteniendo WHY (visible SOLO cuando hay pendingInvalidValue)
- `Lib/MainHud.ahk:280-283` — reescrito: comentario de footer — eliminada narrativa de botones removidos; conservada tabla de 3 filas como referencia de layout
- `Lib/MainHud.ahk:298-300` — reescrito: comentario de `Update()` refresh — de "Save button refs" a WHY explícito
- `Lib/MainHud.ahk:308-309` — reescrito: comentario de contratos de callback — de `; Wire handlers` a `; Contratos de callback: estos nombres son funciones top-level en QuickEntry.ahk`
- `Lib/MainHud.ahk:319-320` — reescrito: comentario de `buttonsById` — de 2 líneas a 1 con WHY (IDs = lookup keys de HudLayout)
- `Lib/MainHud.ahk:333-335` — reescrito: banner de inline edit persistente — WHY explícito: flickering y pérdida de foco en AHK v2 si se crean/destruyen en cada edición
- `Lib/MainHud.ahk:360-362` — reescrito: comentario de `OnMessage` guard — WHY explícito (guard evita duplicados si Build se llamara más de una vez)
- `Lib/MainHud.ahk:407-414` — reescrito: tabla de coordenadas de slot rows — tabla anotada con nombres semánticos de columna en lugar de deltas numéricos crudos
- `Lib/MainHud.ahk:435` — reescrito: comentario de botones compact — de "Definimos anchos..." a WHY ("cuadrados con sólo el ícono")
- `Lib/MainHud.ahk:474` — reescrito: comentario de `normalLayout` — eliminada referencia a Task 7 + DPI bump; condensado a 1 línea con WHY (coinciden con `Build()`)
- `Lib/MainHud.ahk:558-564` — reescrito: comentario de background highlight — condensado a 2 líneas con WHY (fondo continuo sin gaps + Redraw obligatorio en AHK v2)
- `Lib/MainHud.ahk:594-596` — reescrito: comentario de `pendingInvalidValue` en Update — condensado manteniendo WHY (muestra lo que tipeo el usuario para decidir si forzar)
- `Lib/MainHud.ahk:625-627` — reescrito: comentario de icono/forceBtn — condensado a 2 líneas con estados
- `Lib/MainHud.ahk:680-681` — reescrito: comentario de `OpenInlineEditOnCurrentSlot` — condensado a 2 líneas con los casos de no-op
- `Lib/MainHud.ahk:762-764` — reescrito: safety comment de `ShowInlineEdit` — condensado a 1 línea con WHY (CloseInlineEdit sólo oculta, no guarda)
- `Lib/MainHud.ahk:774-777` — reescrito: comentario de pre-carga de `pendingInvalidValue` — condensado a WHY (usuario corrige sin re-tipear)
- `Lib/MainHud.ahk:809-812` — reescrito: caso de valor en blanco en `OnInlineEditCommit` — condensado manteniendo WHY (evita ValidarNoVacio / "!" rojo)
- `Lib/MainHud.ahk:828-831` — reescrito: validación fallida en `OnInlineEditCommit` — condensado a WHY (renderiza en ámbar + "!" + botón ✓)
- `Lib/MainHud.ahk:864-865` — reescrito: `CloseInlineEdit` hide comment — WHY explícito ("se reusan en el próximo ShowInlineEdit")
- `Lib/MainHud.ahk:891-893` — reescrito: `ClearAllPendingInvalid` docblock — WHY explícito (pending pertenecen a sesión anterior)
- `Lib/MainHud.ahk:948-950` — reescrito: `SaveLastPaste` IniWrite comment — WHY conservado (IniWrite no acepta newlines)
- `Lib/MainHud.ahk:971-974` — reescrito: `LoadLastPaste` preloadedSlots comment — WHY conservado (PasteBatch los SKIP; Load Last debe pegar todos)
- `Lib/MainHud.ahk:978-980` — reescrito: `OnMouseMoveHover` header — de banner decorativo a commentario inline con WHY (debounce por `lastTooltipHwnd`)

**Banners conservados (6 secciones reales):**

- `; ==== PERSISTENCE ====` — sección INI (EnumMonitorsForLayout, LoadPosition, Save*)
- `; ==== BUILD ====` — construcción de GUI y controles
- `; ==== RENDER ====` — RenderMode, OnResize
- `; ==== UPDATE ====` — Update, TruncarValor, Show, Hide
- `; ==== CLICK HANDLERS ====` — Make*Handler, OnRowClick*, OnForceCommit, OpenInlineEditOnCurrentSlot
- `; ==== INLINE EDIT ====` — ShowInlineEdit, OnInlineEditCommit, OnInlineEditEsc, CloseInlineEdit

**Nota de validación:** `AutoHotkey64.exe` no está instalado en la máquina de trabajo (`C:\Users\avazquez\...`; el ejecutable está en `C:\Users\Usuario\...` según CLAUDE.md). Validación sintáctica pendiente en el entorno objetivo. La revisión manual confirma: todas las llaves de clase/método están balanceadas (1 `class MainHud {` → 1 `}` al final), todos los métodos tienen su par de `{}`/`try`/`finally`, y no se modificó ningún identificador, string ni lógica.

### Fase 3 — dead code
- [x] Auditado 2026-05-12

**Veredictos de los 3 candidatos flagged:**

| Símbolo | Veredicto | Evidencia |
|---|---|---|
| `MAINHUD_BG_ROW` | NO USADO → ya ausente | `grep *.ahk`: 0 refs. No está en el archivo post-Fase-2. Confirmado por `grep BG_ROW Lib/MainHud.ahk` → sin match. |
| `OnReset()` | NO USADO → ya ausente | `grep *.ahk OnReset`: 0 refs en todo el repo. Wiring en `Build()` va a `DoReset()` global, no a `this.OnReset()`. El método no existe en el archivo actual (ausente post-Fase-2 o nunca llegó a producción). |
| `OnUndo()` | NO USADO → ya ausente | Ídem: `grep *.ahk OnUndo`: 0 refs. Wiring va a `DoUndo()` global. Ausente del archivo actual. |

**Procedimiento de verificación de wiring (criterio especial):**

Para `OnReset`/`OnUndo` se verificaron explícitamente los patterns `.Bind(`, `.OnEvent(`, `OnMessage(`, `OnNotify(` dentro de `Lib/MainHud.ahk`. Los resultados confirman:
- `btnReset.OnEvent("Click", (*) => DoReset())` — wired a global, NO a `this.OnReset()`
- `btnUndo.OnEvent("Click", (*) => DoUndo())` — wired a global, NO a `this.OnUndo()`
- Ningún `Bind` ni `ObjBindMethod` referencia `"OnReset"` o `"OnUndo"` en el archivo.

**Borrados en `.ahk`:** ninguno necesario — los tres símbolos ya estaban ausentes del archivo fuente al momento del audit (ya eliminados durante Fase 2 o nunca promovidos a producción).

**Actualizaciones en `.md`:**
- Tabla de globales: removida fila `MAINHUD_BG_ROW` (símbolo no existe en el archivo).
- Sección "Globales que define" en Dependencias: removido `MAINHUD_BG_ROW` del listado.
- Notas técnicas: conservada la nota sobre `MAINHUD_BG_ROW` como referencia histórica del WHY de su eliminación.

**Validación sintáctica:** `AutoHotkey64.exe /ErrorStdOut=utf-8 /validate Lib/MainHud.ahk` → exit 0, stderr vacío.

**Candidatos para review senior:** ninguno. Los tres candidatos están resueltos (todos ausentes). No se detectaron símbolos adicionales con < 90% confianza.

## Ideas de simplificación pendientes (input para plan posterior)

- **Inyectar callbacks `Do*` en el constructor en lugar de depender de funciones globales del entry point.** `MainHud` referencia `DoArmOrSkip`, `DoHeaderScan`, `DoSoltar`, `DoReset`, `DoUndo` como globals implícitas del entry point — la única dependencia "invertida" del grafo. Pasarlos como `Map("arm", DoArmOrSkip.Bind(), ...)` en `__New` eliminaría el acoplamiento, permitiría tests unitarios del HUD y alinea con el patrón `.Bind(this)` de Asignet.

- **Separar `Build()` en sub-métodos**: `Build()` tiene ~160 líneas que mezclan construcción de slot rows, construcción de footer buttons, wiring de handlers y registro de `OnMessage`. Extraer `_BuildSlotRows()`, `_BuildFooterButtons()`, `_WireEvents()` reduciría la carga cognitiva y facilitaría tests de cada subsección de la GUI.

- **`OnReset()` / `OnUndo()` ya eliminados (resuelto en Fase 3)**: los métodos estaban ausentes del archivo; el flujo de Reset/Undo se delega completamente a `DoReset()` / `DoUndo()` del entry point, wired directamente en `Build()`. No hay deuda pendiente.

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno necesario.

**Hallazgos del audit:**
- Trailing whitespace: 0 líneas afectadas.
- Bloques de 3+ líneas en blanco consecutivas: ninguno.
- Indentación: 4 espacios consistentes en todo el archivo. La única excepción es L894, continuation line alineada al paréntesis de apertura del `MsgBox` — patrón intencional, no un error de indentación.
- Trailing newline: presente y único.
- Comentarios huérfanos: ninguno. Los 85 comentarios no-banner del archivo son contextuales (WHY de quirks AHK v2, contratos de diseño, invariantes de runtime).
- Validación sintáctica: `AutoHotkey64.exe /ErrorStdOut=utf-8 /validate Lib/MainHud.ahk` → exit 0, stderr vacío.
