# Main HUD GUI — Design

**Fecha:** 2026-04-29
**Reemplaza:** sistema actual de `ToolTip` flotante de Windows
**Estado:** aprobado para writing-plans

---

## Goal

Reemplazar el `ToolTip` actual por una GUI persistente, movible, redimensionable y rica en interacción. La GUI muestra el schema completo en cualquier momento, resalta visualmente el slot apuntado, permite jump y edición inline en cada slot, persiste su posición entre sesiones, y soporta restaurar la última cola pegada.

---

## Contexto

El sistema actual usa `ToolTip()` de AHK:
- Aparece en el cursor (hard-coded posición)
- Texto plano (limitado styling, sin colores per-slot, sin íconos)
- Solo display — no permite click/edit en slots
- Desaparece al hacer click fuera
- No persistente — se redibuja en cada `RefrescarTooltip` call

Limitaciones reales para el flujo del operador:
- Para editar un slot ya cargado debe abrir `^+e` (ManualInputGui), buscar el slot en la lista, click, escribir
- Para volver a un slot omitido idem (ManualInputGui o `^+u` repetidos)
- No hay forma de revisar todos los slots de un vistazo cuando hay muchos preloaded
- Si el operador mueve el ratón el tooltip lo persigue, ocluye el form

La GUI nueva (`MainHud`) resuelve estas tres cosas.

---

## Decisiones aprobadas

| ID | Decisión | Alternativas descartadas |
|---|---|---|
| **D1** | **Reemplaza el tooltip de ESTADO** (el persistente de `RefrescarTooltip`). ~~La GUI siempre visible cuando `engine.isCapturing == true`: aparece en `^+a` (armar), se oculta en `^+r` (reset) y al final de `^+s` (paste batch).~~ **⚠️ SUPERSEDED 2026-05-12**: la GUI se muestra al **startup** del script (no al armar) y permanece visible permanentemente; `^+s` **no oculta el HUD** sino que dispara auto-rearm (modo captura continua, ver MANUAL §5.1). `^+r` sí oculta el HUD. **Mantener los `ToolTip(...)` transientes** (1.5s) para mensajes one-shot como "Captura cancelada", "Nada que deshacer", "No hay última cola guardada". Esos no compiten con la GUI. | Coexistir status tooltip + GUI (UI fragmentada). |
| **D2** | **Aesthetic: "Operator Console"** dark theme. BG `#0F1419`, mono font (`Cascadia Mono`) para valores, sans (`Segoe UI Variable Display` semi-bold) para labels, accent ámbar `#FFB454` para slot apuntado, verde `#7FB069` filled, azul `#7AA2F7` preloaded, gris `#5C6370` empty, rojo `#E06C75` error. Iconos Unicode (no emojis). | Light editorial, brutalist (descartados por fatiga visual o agresividad). |
| **D3** | **Posición persistente.** Default = centro del monitor primario. Al moverse, guarda nueva posición en `%AppData%\QuickEntry\layout.ini` (`lastX/lastY`). Botón `⊙` "Marcar default" copia `lastX/Y` → `defaultX/Y`. Default se usa solo en primera ejecución o cuando no hay last. | Posición fija (no movible — limitante). |
| **D4** | **Click en columna NOMBRE** (slot # + label) → `engine.JumpTo(slot)`. Sin edit. **Click en columna VALOR** → `engine.JumpTo(slot)` + `Text` se reemplaza por `Edit` precargado con el valor actual. Enter commit, Esc cancel. | Doble-click para editar (más fricción). |
| **D5** | **Tras Enter exitoso en edit inline**, cursor auto-avanza al próximo slot vacío (mismo `AutoAdvance` que push normal). | Quedarse en el slot editado (más explicit pero menos fluido). |
| **D6** | **Validación falla en edit inline:** Edit queda abierto + texto rojo debajo de la fila con el mensaje del validator. **Si el operador presiona Enter de nuevo sin cambiar el valor**, MsgBox `"Valor inválido. ¿Forzar igual?"` Yes/No. Yes → `engine.PushForce(value)` (commit sin validar). No → vuelve al Edit. | Solo permitir valores válidos (bloquea casos edge donde el form acepta lo que el validator rechaza). |
| **D7** | **Operandos clickeables.** Para slots derivados (Past due, Invoice Total) que tienen `expectedDeps`, las filas hijas indentadas (`├ └`) son clickeables. Click → `JumpTo(slotOperando)` (ej. click en `├ Previous balance: 171.86` debajo de Past due → JumpTo(5)). | Solo display (más simple pero menos potente). |
| **D8** | **Footer botones:** `[⊘ Reset]` `[↶ Undo]` `[↻ Load Last]` (botones con texto, izquierda) + íconos chicos `⊙` (marcar default) `▣/▢` (toggle compact/full) a la derecha. **NO botones para Manual/Scan/Paste** — esos siguen siendo hotkey-only (`^+e`, `^+h`, `^+s`). | Botones para todo (UI inflada). |
| **D9** | **Compact mode (toggle ▣/▢).** Compact muestra solo el slot apuntado + sus operandos (si hay). Full muestra los N slots. Default: Full. Persistido en `layout.ini`. | Solo full (menos útil en pantallas chicas). |
| **D10** | **Load Last:** al disparar `^+s` (PasteBatch), antes de `engine.Reset()`, guarda snapshot `{queue, preloadedSlots}` en `%AppData%\QuickEntry\last_paste.ini`. Botón `[↻ Load Last]` lee y restaura (sobrescribe estado actual del engine + arma la captura). Disponible incluso post-Reset / post-arrancar el script. | Sin persistencia (operador no puede recuperar tras un cierre accidental). |
| **D11** | **Truncado de valores** para evitar overflow horizontal: si `StrLen(valor) > 28`, se muestra `SubStr(valor, 1, 25) "..."`. Hover sobre el valor truncado → tooltip nativo Windows con el valor completo. | Sin truncado (overflow visual). |

---

## Layout

```
┌──────────────────────────────────────────────────────────────┐
│  ⌖ QUICKENTRY      Asignet Header v1      7/9            ─×│ ← title bar
├──────────────────────────────────────────────────────────────┤
│                                                              │
│      1   Account number              ACC-99999          ✓   │
│      2   Invoice date                09/15/2026         ✓   │
│      3   Due date                    09/30/2026         ✓   │
│      4   Corp name                   Sagenet 3210...    ✓   │ ← truncated
│   ▶  5   Previous balance            171.86             ◐   │ ← previo (last action)
│      6   Past Total Payments         -171.86            ✓   │
│   ⌖  7   Past due                    esperado: 0.00         │ ← apuntado (accent fill)
│            ├ Previous balance        171.86                  │ ← operando (clickable)
│            └ Past Total Payments     -171.86                 │
│      8   Total ($)                   —                       │
│      9   Invoice Total Including PastDue   —                 │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│  [⊘ Reset]  [↶ Undo]  [↻ Load Last]              ⊙    ▣     │ ← footer
└──────────────────────────────────────────────────────────────┘
```

### Dimensiones aproximadas (px)
- Ventana: 600 × 480 (full mode, 9 slots), 600 × 200 (compact)
- Title bar: 32px alto
- Slot row: 32px alto
- Operando row: 24px alto, indent +20px
- Footer: 48px alto
- Padding lateral: 16px

### Convenciones de estado por fila

| Estado | Indicador izquierda | Color valor | Ícono derecha |
|---|---|---|---|
| **Apuntado** (`NextSlot`) | `⌖` (cross-hair, accent ámbar) + bg row tinted | accent ámbar | esperado del campo si tiene `expectedFn` |
| **Filled** (push normal) | (vacío) | verde `#7FB069` | `✓` verde |
| **Preloaded** (HeaderScan) | (vacío) | azul `#7AA2F7` | `◐` azul |
| **Autocalc** (skip+autoCalc) | (vacío) | verde italic | `✓` |
| **Forced** (PushForce, post bypass) | (vacío) | naranja `#FFB454` | `!` naranja |
| **Empty** | (vacío) | gris `#5C6370` | `—` gris |

**Si el slot apuntado coincide con un slot lleno** (ej. operador hizo `Undo` y el cursor volvió a un slot que ya tiene valor anterior), prevalece el estado **Apuntado**: `⌖` + accent fill. El valor sigue mostrándose con su color de filled/preloaded como referencia.

No se usa el `▶` para "previo / última acción" — el `actionLog` ya no se renderiza en la GUI; el operador puede ver qué hizo último mirando el `⌖` (se mueve solo) y los colores de los slots. Si se necesita "qué fue lo último que cambié", el `Undo` lo dice implícitamente al apretar `^+u`.

### Title bar
- Izquierda: `⌖ QUICKENTRY` + nombre del schema (`engine.schema.name`)
- Centro: contador `FilledCount/Length` (live update)
- Derecha: `─` minimizar, `×` cerrar (cierra el script entero — pregunta confirm)

---

## Estado interno (`MainHud` class)

```ahk
class MainHud
{
    engine := ""               ; ref al CaptureEngine
    gui := ""                  ; Gui object
    rows := []                 ; Array<Map>: {bgPanel, slotTxt, nameTxt, valueCtrl, iconTxt, opRows}
    inlineEdit := ""           ; Edit control activo (null si no hay edit)
    inlineEditSlot := 0        ; slot que el inline-edit está editando (0 si none)
    inlineEditFailedOnce := false  ; primer Enter fallo, segundo dispara MsgBox
    compactMode := false       ; persiste en layout.ini
    lastX := 0
    lastY := 0
    defaultX := 0
    defaultY := 0
}
```

**Layout INI** (`%AppData%\QuickEntry\layout.ini`):
```ini
[Window]
lastX=400
lastY=300
defaultX=400
defaultY=300
compactMode=0
```

**Last paste INI** (`%AppData%\QuickEntry\last_paste.ini`):
```ini
[Queue]
slot1=ACC-1234
slot2=09/15/2026
...
slot9=
[Preloaded]
slot1=true
slot4=true
```

---

## Cambios por archivo

### `Lib/MainHud.ahk` (nuevo)
Implementa la clase `MainHud`. ~350 líneas estimadas. Métodos:
- `__New(engine)` — instancia, lee layout.ini
- `Build()` — crea Gui + controles (title bar, rows, footer)
- `Show()` / `Hide()` — control de visibilidad
- `Update()` — re-renderiza estado: colors, valores, ícono por slot. Llamado desde `RefrescarTooltip` en QuickEntry.
- `OnRowClickName(slot)` — JumpTo + Update
- `OnRowClickValue(slot)` — JumpTo + ShowInlineEdit
- `OnOperandoClick(slot)` — JumpTo + Update
- `ShowInlineEdit(slot)` — reemplaza Text con Edit, focus
- `OnInlineEditEnter()` — PushManual; si fail, mostrar error rojo + flag failedOnce; si segundo Enter sin cambio, MsgBox confirm → PushForce
- `OnInlineEditEsc()` — destruye Edit, restaura Text
- `OnReset()` / `OnUndo()` / `OnLoadLast()` — handlers de footer buttons
- `OnSetDefaultPos()` — `defaultX := lastX, defaultY := lastY` + write INI
- `OnToggleCompact()` — cambia compactMode + redibuja
- `OnMove()` — llamado en cada movimiento, debounced (Sleep 500ms timer) → write `lastX/Y`
- `SaveLastPaste()` — serializa engine state a `last_paste.ini`
- `LoadLastPaste()` — lee y restaura

### `Lib/CaptureEngine.ahk` (modificar)
- Agregar método `PushForce(value)`: idéntico a `PushRaw` pero sin llamar `campo.validate.Call`. Toda la otra lógica igual (clean, actionLog, queue write, AutoAdvance, preloadedSlots clear). Si el clean devuelve `""`, sigue rechazando (force solo bypassa validate, no clean).

### `QuickEntry.ahk` (modificar)
- Inicializar `mainHud := MainHud(engine)` en singletons.
- `RefrescarTooltip(res, accion)` ahora llama `mainHud.Update()` en lugar de `ToolTip(...)`.
- En `^+a` (armar): `mainHud.Show()` después de `engine.Arm()`.
- En `^+s` (PasteBatch): `mainHud.SaveLastPaste()` ANTES de `engine.Reset()`. `mainHud.Hide()` al terminar.
- En `^+r` (reset): `mainHud.Hide()`.
- Eliminar `ToolTip(...)` calls reemplazados (mantener los de `^+r`/transient messages como "Captura cancelada" — esos quedan como ToolTip de 1.5s).

### `Lib/ManualInputGui.ahk` (sin cambios funcionales)
- Sigue existiendo para `^+e`. Pero la mayoría de los flujos manuales pasan ahora por la GUI principal (click directo en valor). `^+e` sigue siendo la alternativa "abrir en una ventanita aparte" para quien la prefiera.
- Considerar: ¿deprecate `ManualInputGui` en favor del MainHud + edit inline? Por ahora **mantener**, no es prioridad eliminarlo.

### `Lib/TooltipFormatter.ahk` (sin cambios)
- Las funciones `LineaPrompt`, `LineaPrevio`, `LineasOperandos`, `TooltipError` siguen siendo útiles — `MainHud.Update()` las consume para armar los strings (esperado, mensajes de error, etc.).

### Tests
- `Tests/Test_MainHud.ahk` — **no se crea**. La GUI es side-effect-only; el approach es smoke-test manual + unit tests de `engine.PushForce` en `Test_CaptureEngine.ahk`.
- Agregar tests de `PushForce` en `Test_CaptureEngine.ahk` (~5 asserts: ok=true sin validar, queue actualizado, actionLog crece, AutoAdvance funciona, slot preloaded se limpia).

---

## Edge cases

| # | Caso | Comportamiento |
|---|---|---|
| 1 | `^+a` con cola ya cargada (estado raro tras Load Last) | `mainHud.Show()`. Si `engine.IsComplete`, tooltip dice "Listo n/n - ^+s para pegar, ^+e para revisar". |
| 2 | Click en slot con la cola completa (`IsComplete`) | JumpTo igual funciona — el slot se vuelve `NextSlot` y el operador puede editar. Tras editar, AutoAdvance no encuentra vacíos → `IsComplete` again. |
| 3 | Esc durante inline edit con valor inválido y `failedOnce=true` | Cancela el edit, restaura Text con el valor previo (no commitea). `failedOnce` se resetea. |
| 4 | Click en otro slot mientras hay un inline edit abierto | Cancela el edit actual (igual que Esc) + JumpTo al nuevo slot + abre edit en el nuevo. |
| 5 | Move event durante un inline edit | Edit se mueve junto con la GUI (es child control). Sin issues. |
| 6 | Load Last con `last_paste.ini` inexistente (primera ejecución) | Mensaje `ToolTip("No hay última cola guardada")` 1.5s. No abre la GUI ni cambia estado. |
| 7 | Load Last cuando hay una captura en curso con datos sin pegar | MsgBox confirm: `"Hay una captura en curso. ¿Reemplazar con la última cola pegada?"` Yes/No. Yes → reemplaza. No → cancela. |
| 8 | Cerrar la GUI con `×` | ~~Confirm `"¿Cerrar QuickEntry?"`. Si Yes, ExitApp (cierra script entero).~~ **⚠️ SUPERSEDED 2026-05-12**: en producción, × **oculta** la GUI sin confirmar (el operador puede accidentalmente clickear ×; cerrar el script entero sin warning es peligroso). El hotkey de escape sigue siendo `Ctrl+Shift+R` para reset. Para cerrar QuickEntry: System Tray. |
| 9 | GUI tapa el form al moverse el operador | El operador la mueve. Posición persiste en `lastX/Y`. |
| 10 | Schema cambia (otra empresa) entre ejecuciones | `defaultX/Y` y `lastX/Y` no son schema-specific. Se reusan. OK porque la GUI siempre se muestra en la misma área de la pantalla. |

---

## Out of scope (esta iteración)

- Animaciones / fade-in. AHK GUI no las soporta nativas; agregar via timers es ruidoso. Cambios visuales son instantáneos.
- Resize manual de la GUI por el usuario. El tamaño es fijo según schema length + compact mode.
- Themes user-configurable. Solo el dark "Operator Console" hard-coded.
- Persistencia de la GUI entre slot drag-drop reordering (no aplica — slots son fijos por schema).
- Drag-and-drop entre slots (mover valor de un slot a otro).

---

## Riesgos

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| AHK v2 GUI no permite cambio de bg color por control individual de forma confiable | Media | Test temprano: probar `ctrl.Opt("+Background" color)`. Si falla, fallback a `Picture` controls como backgrounds o text con `c<color>` solamente (sin bg fill). |
| Inline edit (Edit control reemplazando Text dinámicamente) introduce flickering | Media | Usar `g.Opt("+LastFound") + WinSetRedraw(false/true)` durante el swap. Si flickering inevitable, aceptarlo (cambio rápido, no es deal-breaker). |
| Persistencia INI requiere directory creation | Baja | `DirCreate("%AppData%\QuickEntry")` idempotente al iniciar el script. |
| `PushForce` agrega complejidad al engine API | Baja | Es un método pequeño, parallel a `PushRaw`. Documentado. Tests cubren. |
| MainHud + ManualInputGui co-existen → confusión sobre cuál usar | Baja | Documentar en MANUAL_USUARIO: "el método principal es la GUI; `^+e` abre la entrada manual estilo dialog para quien la prefiera". |

---

## Plan de prerequisito

Antes de implementar:
1. **Verificar suite verde** con el código revertido a 9 slots (último revert del usuario). Si tests fallan → fixear o adaptar tests para que reflejen el estado actual del schema.
2. **Validar AHK GUI capabilities**: hacer un proof-of-concept rápido (~30 líneas) que confirme que se puede hacer bg color por control + text color por control + replace Text con Edit dinámicamente sin crash.

---

## Próximo paso

Pasar a `superpowers:writing-plans` para producir el plan de implementación bite-sized en `docs/superpowers/plans/2026-04-29-main-hud-gui-plan.md`.
