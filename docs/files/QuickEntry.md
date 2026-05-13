---
file: QuickEntry.ahk
last_review: 2026-05-12
status: active  # active | deprecated | to-delete
---

# `QuickEntry.ahk`

## Propósito

Entry point de la aplicación. Declara los dos singletons globales (`engine`, `hud`), arma los hotkeys de teclado, registra el listener `OnClipboardChange`, y provee las funciones top-level `Do*()` que conectan hotkeys y botones del HUD con la lógica de `CaptureEngine` y `MainHud`.

## API pública

### Clases

_(Este archivo no define clases propias; instancia `CaptureEngine` y `MainHud`.)_

### Funciones libres

- **`DoPegadoEspecial(interactive := false) → (void)`** — Wrapper de `PegadoEspecial()` con soporte de modo interactivo: si `interactive=true`, espera que el usuario haga clic en el campo destino antes de pegar (evita que el foco quede atrapado en el HUD).
  - Llamado desde: `QuickEntry.ahk:76` (`^+v::`)
  - Llama a: `PegadoEspecial()` (de `Lib/PegadoEspecial.ahk`)

- **`HandlerCaptura(tipoData) → (void)`** — Callback de `OnClipboardChange`. Descarta datos no-texto o capturas en curso (`pegadoEnCurso`), llama a `engine.PushRaw()`, y muestra tooltip de error si el valor no pasa validación.
  - Llamado desde: runtime AHK vía `OnClipboardChange HandlerCaptura` (`QuickEntry.ahk:98`)
  - Llama a: `engine.PushRaw()`, `TooltipError()`, `TooltipConError()`, `RefrescarTooltip()`

- **`RefrescarTooltip() → (void)`** — Actualiza el HUD después de cada push/skip/undo. Delega en `hud.Update()`.
  - Llamado desde: `QuickEntry.ahk:89` (en `HandlerCaptura`), `QuickEntry.ahk:131` (en `DoArmOrSkip`), `QuickEntry.ahk:231` (en `DoUndo`)
  - Llama a: `hud.Update()`

- **`DoArmOrSkip() → (void)`** — Hotkey `^+a`. Si la GUI está oculta/minimizada, la restaura. Si la captura está activa y la cola no está completa, llama `engine.SkipCurrent()`. Si no hay captura activa, llama `engine.Arm()` y muestra el HUD.
  - Llamado desde: `QuickEntry.ahk:128` (`^+a::`), `Lib/MainHud.ahk:308` (botón HUD)
  - Llama a: `engine.isCapturing`, `engine.IsComplete`, `engine.SkipCurrent()`, `engine.Arm()`, `engine.SetExtraTabsAfter()`, `hud.Show()`, `hud.Update()`, `RefrescarTooltip()`

- **`DoSoltar(interactive := false) → (void)`** — Hotkey `^+s`. Ejecuta el paste batch de la cola capturada. Modo interactivo espera clic del usuario en el form antes de pegar. Aplica `KeyWait` en modificadores, llama `engine.PasteBatch()`, y en el bloque `finally` hace auto-rearm.
  - Llamado desde: `QuickEntry.ahk:175` (`^+s::`), `Lib/MainHud.ahk:311` (botón HUD)
  - Llama a: `engine.PasteBatch()`, `engine.Reset()`, `engine.Arm()`, `engine.SetExtraTabsAfter()`, `hud.SaveLastPaste()`, `hud.ClearAllPendingInvalid()`, `hud.Update()`

- **`DoReset() → (void)`** — Hotkey `^+r`. Aborta cualquier batch/scan en curso y resetea el engine; oculta el HUD.
  - Llamado desde: `QuickEntry.ahk:232` (`^+r::`), `Lib/MainHud.ahk:312` (botón HUD)
  - Llama a: `engine.Abort()`, `engine.Reset()`, `hud.ClearAllPendingInvalid()`, `hud.Hide()`

- **`DoUndo() → (void)`** — Hotkey `^+u`. Deshace el último slot capturado si hay captura activa.
  - Llamado desde: `QuickEntry.ahk:248` (`^+u::`), `Lib/MainHud.ahk:313` (botón HUD)
  - Llama a: `engine.Undo()`, `RefrescarTooltip()`

- **`DoHeaderScan(interactive := false) → (void)`** — Hotkey `^+h`. Lee los campos actuales del form (vía `engine.Scan()`) y pre-popula la cola. Modo interactivo espera clic en el selector "Type" del form antes de escanear. Restaura el clipboard desde `backup` en el bloque `finally`.
  - Llamado desde: `QuickEntry.ahk:279` (`^+h::`), `Lib/MainHud.ahk:310` (botón HUD)
  - Llama a: `engine.SetExtraTabsAfter()`, `engine.Scan()`, `hud.Show()`, `hud.Update()`

## Dependencias

- **#Include directos**: `Lib\Cleaners.ahk`, `Lib\Validators.ahk`, `Lib\Schema.ahk`, `Lib\CaptureEngine.ahk`, `Lib\TooltipFormatter.ahk`, `Lib\PegadoEspecial.ahk`, `Schemas\AsignetHeaderV1.ahk`, `Lib\MainHud.ahk`
- **Incluido por**: nadie (es el entry point)
- **Globales que define**:
  - `AUTO_CALCULAR_TOTALES_OMITIDOS := true` — si `true`, al omitir un slot con `expectedFn`, el valor calculado se pushea en vez de `""`
  - `HOTKEY_OMITIR := "^+a"` — cadena mostrada en el tooltip de error para guiar al usuario; debe mantenerse sincronizada con el binding `^+a::` del mismo archivo
  - `engine := CaptureEngine(...)` — singleton de captura batch (instanciado en `:35`)
  - `hud := MainHud(engine)` — singleton de la GUI principal (instanciado en `:36`)
- **Globales que usa (leídas)**:
  - `pegadoEnCurso` (definida en `Lib/PegadoEspecial.ahk:18`): leída en `HandlerCaptura` (`:103`), `DoSoltar` (`:180, 203, 226`), `DoHeaderScan` (`:284, 308, 331`)
- **Símbolos externos invocados**:
  - `CaptureEngine()` (de `Lib/CaptureEngine.ahk`)
  - `CrearAsignetHeaderV1()` (de `Schemas/AsignetHeaderV1.ahk`)
  - `MainHud()` (de `Lib/MainHud.ahk`)
  - `PegadoEspecial()` (de `Lib/PegadoEspecial.ahk`)
  - `TooltipError()`, `TooltipConError()` (de `Lib/TooltipFormatter.ahk`)

## Notas técnicas (WHY no-obvio)

- **`Sleep 30` antes de `engine.PasteBatch()` / `engine.Scan()`** (en `DoSoltar` y `DoHeaderScan`): permite que los modificadores físicos (Ctrl/Shift del hotkey) se asienten como "sueltos" a nivel del OS luego del `SendInput "{Blind}...up"`. Sin este sleep, las aplicaciones destino pueden recibir los Tabs como Ctrl+Shift+Tab en vez de Tab simple.

- **`Sleep 150` + `{Escape}` en `DoHeaderScan`**: el `Escape` cierra cualquier dropdown o autocomplete que haya quedado abierto de un scan anterior. Sin esto, los Tabs del scan interactúan con el widget abierto y el cursor se desfasa respecto del schema.

- **`Sleep 250` en modos interactivos** (`DoPegadoEspecial`, `DoSoltar`, `DoHeaderScan`): después del clic del usuario en el form, se espera 250 ms para que el OS transfiera el foco al campo destino antes de ejecutar `SendInput`. El valor fue calibrado empíricamente; valores menores (<150 ms) causaban race conditions con aplicaciones Chromium-based.

- **Patrón `KeyWait("LButton") + KeyWait("LButton","D")`** en los modos interactivos: el primer `KeyWait` espera a que se suelte el clic actual (sobre el botón del HUD) para que no sea inmediatamente consumido como el "siguiente clic". El segundo `KeyWait "D"` espera el siguiente click-down real del usuario (el que posiciona el cursor en el form).

- **`try/finally` en `DoSoltar` y `DoHeaderScan`**: garantiza que `pegadoEnCurso` vuelva a `false` y el clipboard se restaure incluso si `PasteBatch()`/`Scan()` lanzan una excepción. Sin esto, el handler `HandlerCaptura` quedaría bloqueado indefinidamente.

- **Auto-rearm en el `finally` de `DoSoltar`**: después de cada paste batch, el engine se rearma automáticamente con `engine.Arm()` para que el siguiente copy sea capturado sin requerir que el operador presione "Iniciar". Este es el "modo continuo" de QuickEntry; `^+r` (DoReset) es la pausa explícita.

- **Acoplamiento bidireccional `QuickEntry.ahk` ↔ `Lib/MainHud.ahk`**: `MainHud` invoca las funciones `DoArmOrSkip()`, `DoHeaderScan(true)`, `DoSoltar(true)`, `DoReset()`, `DoUndo()` definidas en este entry point. Esta dependencia no es visible en el grafo de `#Include` (se resuelve en runtime porque AHK v2 carga todo en el mismo scope al incluirse desde el entry point). Está documentada en `docs/files/INDEX.md` sección "Cross-file callers/callees".

- **`{Blind}` en `SendInput`**: preserva el estado actual de modificadores (Shift, Ctrl, etc.) para que la secuencia de keystrokes no sea interpretada con modificadores no deseados. Es un gotcha de AHK v2: sin `{Blind}`, las combinaciones compuestas pueden ser interceptadas por el OS con modificadores colgados.

- **`OnClipboardChange HandlerCaptura`** (no-función, callback): en AHK v2, `OnClipboardChange` requiere una función o referencia de función. Aquí se pasa el nombre directamente, lo cual es válido en v2 (la función es global).

## Bitácora de cleanup

### Fase 1 — m720
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - `QuickEntry.ahk:46-71` (pre-cleanup) — borrados handlers `XButton1::`, `XButton2::`, `WheelRight::`, `WheelLeft::` + banner "MAPEOS DE BOTONES DE MOUSE". Razón: mapping personal de un mouse Logitech M720; el plan de producción no incluye periféricos no estándar. `PegadoEspecial()` queda accesible vía `^+v::DoPegadoEspecial()`.
  - Sintaxis post-edit validada con `AutoHotkey64.exe /validate` (exit 0).
  - Archivo redujo de 334 → 308 líneas (26 borradas).

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - `QuickEntry.ahk:24` — borrado: `; --- Configuracion ---` — razón: banner decorativo
  - `QuickEntry.ahk:34` — borrado: `; --- Singletons ---` — razón: banner decorativo
  - `QuickEntry.ahk:100` — borrado: `; --- ^+a: armar / omitir ---` — razón: redundante (repite el hotkey y nombre de función de la línea siguiente)
  - `QuickEntry.ahk:147` — borrado: `; --- ^+s: soltar (paste batch) ---` — razón: redundante (repite el hotkey y nombre de función de la línea siguiente)
  - `QuickEntry.ahk:183` — borrado: `; Libera modificadores fisicos del hotkey antes del paste.` — razón: explica QUÉ, no WHY; el WHY (sin esto Tabs son Ctrl+Shift+Tab) ya está documentado en el bloque análogo de DoHeaderScan (líneas 281-283) y en las Notas técnicas del .md
  - `QuickEntry.ahk:204` — borrado: `; --- ^+r: reset ---` — razón: redundante (repite el hotkey y nombre de función de la línea siguiente)
  - `QuickEntry.ahk:220` — borrado: `; --- ^+u: undo ---` — razón: redundante (repite el hotkey y nombre de función de la línea siguiente)
  - `QuickEntry.ahk:242` — borrado: `; --- ^+e: entrada manual (toggle GUI) ---` — razón: redundante (repite el hotkey y nombre de función de la línea siguiente)
  - Sintaxis post-edit validada con `AutoHotkey64.exe /validate` (exit 0).
  - Archivo redujo de 308 → 300 líneas (8 borradas).

### Fase 3 — dead code
- [x] Auditado 2026-05-12

#### Borrados

Ninguno. Auditoría conservadora completada: todos los símbolos definidos en `QuickEntry.ahk` tienen al menos un caller legítimo o son registrados en runtime. No se borró ninguna definición.

Resumen de clasificación:
| Símbolo | Clasificación | Razón |
|---|---|---|
| `AUTO_CALCULAR_TOTALES_OMITIDOS` | USADO | Leído en línea 33 (arg de `CaptureEngine()`) |
| `HOTKEY_OMITIR` | USADO | Leído en líneas 73, 86 (tooltip de error) |
| `engine` | USADO | Singleton; ~25 referencias internas + MainHud.ahk |
| `hud` | USADO | Singleton; ~25 referencias internas + MainHud.ahk |
| `DoPegadoEspecial(interactive)` | USADO | Caller: `^+v::` (línea 47) |
| `HandlerCaptura(tipoData)` | USADO | Registrado vía `OnClipboardChange` (runtime) |
| `RefrescarTooltip()` | USADO | 3 callers internos: líneas 89, 131, 231 |
| `DoArmOrSkip()` | USADO | Callers: `^+a::` (línea 98) + `MainHud.ahk:293` |
| `DoSoltar(interactive)` | USADO | Callers: `^+s::` (línea 144) + `MainHud.ahk:296` con `true` |
| `DoReset()` | USADO | Callers: `^+r::` (línea 199) + `MainHud.ahk:297` |
| `DoUndo()` | USADO | Callers: `^+u::` (línea 214) + `MainHud.ahk:298` |
| `DoHeaderScan(interactive)` | USADO | Callers: `^+h::` (línea 244) + `MainHud.ahk:295` con `true` |
| `^+v`, `^+a`, `^+s`, `^+r`, `^+u`, `^+e`, `^+h` | USADO | Hotkeys activos; no tocar |
| `OnClipboardChange HandlerCaptura` | USADO | Registro de callback en runtime |

#### Candidatos para review senior

1. **`DoPegadoEspecial` — parámetro `interactive := false`**: el `interactive=true` nunca se pasa desde el exterior (INDEX.md línea 204 confirma "El HUD no tiene botón para PegadoEspecial"). El bloque `if interactive { ... }` es código muerto en el estado actual. No borrado: el comentario inline documenta la intención de agregarlo en el futuro, y la remoción requeriría también borrar el comentario explicativo en las líneas 49-52. Decisión arquitectónica, no trivial.


### Fase 5 — simplificación
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - `QuickEntry.ahk:92` — RefrescarTooltip: firma simplificada de `(res, accion := "")` a `()`. El cuerpo solo invocaba `hud.Update()`; los 2 parámetros + la global `engine` eran vestigios de una versión anterior del tooltip. 3 callsites actualizados.
  - `QuickEntry.ahk:89` — HandlerCaptura: `RefrescarTooltip(res, "")` → `RefrescarTooltip()`.
  - `QuickEntry.ahk:131` (original) — DoArmOrSkip: borrada asignación `accion := (s["value"] = "") ? "omitido" : "auto-calc " s["value"]` (solo se usaba como arg de RefrescarTooltip). `RefrescarTooltip(Map(...), accion)` → `RefrescarTooltip()`.
  - `QuickEntry.ahk:232` (original) — DoUndo: `RefrescarTooltip(Map("label", u["label"], "value", "", "slot", u["slot"]), "descartado")` → `RefrescarTooltip()`. Map construido inline solo para este callsite; eliminado junto al call.

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados: trailing newline faltante al final del archivo (1 cambio). Sin trailing whitespace, sin tabs, sin líneas en blanco consecutivas (3+) — archivo ya estaba en estado óptimo en esos aspectos.

## Ideas de simplificación pendientes (input para plan posterior)

- `RefrescarTooltip()` es hoy un wrapper de una sola línea (`hud.Update()`); se podría inlinear en cada callsite y eliminar la función intermedia. Riesgo bajo — requiere verificar que no existan callers dinámicos ni tests que la nombren.
