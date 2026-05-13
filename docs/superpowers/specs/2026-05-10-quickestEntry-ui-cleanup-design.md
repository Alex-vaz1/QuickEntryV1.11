# quickestEntry UI cleanup + small fixes — Design Spec

**Fecha:** 2026-05-10
**Estado:** Draft

---

## 1. Goal

Cinco cambios pequeños sobre el MainHud y CaptureEngine de quickestEntry:

1. Quitar el header "QUICKENTRY Asignet 0/9" (recupera espacio vertical).
2. Reorganizar el footer de 2 filas a 3 filas, con renombre "Soltar" → "Pegar" y remoción de los botones "Pegar limpio" y "Editar" del UI (los hotkeys siguen).
3. INI con default-position recovery: si la posición guardada queda fuera de los monitores activos, caer a centrado.
4. Inline edit empty-commit: borrar contenido del Edit + commit (Enter o pérdida de foco) deja el slot vacío en lugar de fallar la validación.
5. Scan: cuando un campo está vacío en el form, el slot se actualiza a vacío en el GUI (no se queda con el valor anterior).

## 2. Cambios — detalle

### 2.1 Header — quitar título y counter

Hoy `Build()` crea:
- `titleLbl` con "QUICKENTRY  <schema.name>" en x=16 y=12 w=300 h=26.
- `titleCounterCtrl` (referenciado por `Update()` para mostrar "N/9") en x=420 y=14 w=160 h=22.

Y los slot rows arrancan en `yPos := 64`.

**Cambio**: eliminar ambos controles. Mover `yPos` a 12 (margen top). La referencia `this.titleCounterCtrl` se mantiene como property pero queda en string vacío (o se setea a un control no-visible) para que `Update()` siga funcionando sin tocar.

Decisión más limpia: en `Update()`, donde se setea `this.titleCounterCtrl.Value`, condicionarlo a `if IsObject(this.titleCounterCtrl)`. Y en Build no crear el control. Property queda como `""`.

**Ganancia**: 52px verticales (de y=64 a y=12). Esos se ocupan con la 3era fila de footer.

### 2.2 Footer 3 filas

Layout actual (footerY = 64 + 9·32 + 16 = 368, footerY2 = 408):

```
Row 1 (368): [▶ Iniciar 90] [☐ Template 110] [⇣ Scan 80] [▶▶ Soltar 90] [⊘ Reset 62] [↶ Undo 62]
Row 2 (408): [↻ Load Last 110] [⌨ Editar 100] [📋 Pegar limpio 130] [Σ Calc 80] [⊙ 32 a x548]
```

Layout nuevo (con yPos=12, footerY base = 12 + 9·32 + 16 = 316):

```
Row 1 (316): [☐ Template] [⇣ Scan] [▶▶ Pegar]
Row 2 (356): [▶ Iniciar / ⏭ Omitir] [↶ Undo] [⊘ Reset]
Row 3 (396): [⊙] [↻ Load Last] [Σ Calc]
```

Anchos por columna fijos sin importar el modo (es decir, no aplico el grid 36px del compact, dejo anchos normales para que sea más legible. Para esta versión SIMPLIFICO: NO uso compact mode con grid de 36px en estas 3 filas — uso `HudLayout.LabelForButton` para texto/símbolo pero las posiciones X las define el layout normal de 3 filas).

**Wait — interacción con compact mode**. quickestEntry tiene compact mode (HudLayout.IsCompact, breakpoint 540) y RenderMode aplica grid de 36px en compact para footer. Con la nueva estructura 3-rows + setDefault en x=16, el grid de compact debe adaptarse:
- En compact mode, las 3 filas mantienen sus IDs pero usan grid de botones de ~40px.

Para simplificar y evitar romper el compact: la nueva estructura usa Y dinámica por row (3 rows) en AMBOS modos. La diferencia entre normal/compact sigue siendo: textos vs símbolos + anchos.

```
Row 1: Template, Scan, Pegar
Row 2: Arm (Iniciar/Omitir), Undo, Reset
Row 3: SetDefault, LoadLast, Calc
```

**Removidos del UI** (NO del wiring, NO de los hotkeys): `btnManual` (⌨ Editar) y `btnPegEsp` (📋 Pegar limpio). Sus hotkeys `Ctrl+Shift+E` y `Ctrl+Shift+V` siguen funcionando porque están definidos en `QuickEntry.ahk`, fuera de `Build()`.

**Tooltips**: el handler de hover (`OnMouseMoveHover`) usa `btnTooltips` Map. Las entradas de los botones removidos se quitan del Map. Las de los renombrados se actualizan ("Soltar" → "Pegar").

**buttonsById Map**: se actualiza para reflejar los botones existentes. Los IDs `manual` y `pegEsp` se eliminan. `setDefault` queda. `release` queda (aunque ahora el texto sea "Pegar").

**HudLayout.LabelForButton**: actualizar entrada `"release"` para que el texto normal sea `"▶▶ Pegar"` en vez de `"▶▶ Soltar"`. Compact símbolo queda igual (`▶▶`).

### 2.3 Default-position recovery en INI

Hoy `LoadPosition()` IGNORA `lastX/lastY/defaultX/defaultY` del INI y siempre centra. Eso es defensa contra "ventana desaparecida en otro monitor".

**Nuevo comportamiento**: respetar lo guardado en INI cuando es visible en algún monitor; si NO es visible (porque el rectángulo `(x,y,w,h)` no intersecta ningún work area con al menos 100px), caer a "centrar en monitor primario".

**Helper nuevo**: `IsRectVisible(x, y, w, h)` retorna `true` si al menos 100x100 del rectángulo está dentro de algún monitor activo. Iter monitores via `MonitorGetCount` + `MonitorGetWorkArea`.

**Storage del INI** (no cambia structure, solo se vuelve usado):
- `defaultX`, `defaultY`, `defaultW`, `defaultH` (escritos por `SaveAsDefault`)
- `lastX`, `lastY`, `lastW`, `lastH` (escritos por `SaveLastPosition`)

Lectura:
1. Leer todos los W/H (con defaults 540/460).
2. Leer `lastX/lastY`. Si están vacíos en INI o `IsRectVisible(lastX, lastY, lastW, lastH) = false` → centrar.
3. Leer `defaultX/defaultY`. Mismo manejo de fallback.

### 2.4 Inline edit empty commit

`OnInlineEditCommit()` actualmente hace `this.engine.PushManual(val)`. Si `val = ""`, `PushManual → PushRaw → validator (ValidarNoVacio)` rechaza → entra rama `!res["ok"]` → guarda `pendingInvalidValue := ""` → Update() muestra valor inválido con `!` y botón `✓`.

**Nuevo**: tratar `val = ""` como "clear slot" — NO ir por PushManual.

Implementación:
- Nuevo método en CaptureEngine: `ClearSlot(slot)` que hace `queue[slot] := ""`, `preloadedSlots.Delete(slot)`, `actionLog.Push({type: "clear", slot: slot, prev: <valor anterior>})` para soportar Undo.
- En `OnInlineEditCommit`, antes del `engine.PushManual`, chequear `Trim(val) = ""`. Si sí, llamar `engine.ClearSlot(slot)` + `CloseInlineEdit()` + `Update()`. Skip toda la rama de PushManual.

Trim() es para tratar "   " como vacío también.

`pendingInvalidValue` del row se limpia también al clear (no debe quedar "" como pending invalid).

### 2.5 Scan empty value sobrescribe slot

`Scan()` actual:
```ahk
val := captureFieldFn.Call()
limpio := (val = "") ? "" : campo.clean.Call(val)
if (limpio != "")
{
    this.queue[slot] := limpio
    this.preloadedSlots[slot] := true
}
```

Si `val = ""` (campo vacío en form): `limpio = ""` → if salta → `queue[slot]` queda con valor previo. Eso es el bug.

**Nuevo**:
```ahk
val := captureFieldFn.Call()
if (val = "")
{
    this.queue[slot] := ""
    if this.preloadedSlots.Has(slot)
        this.preloadedSlots.Delete(slot)
}
else
{
    limpio := campo.clean.Call(val)
    if (limpio != "")
    {
        this.queue[slot] := limpio
        this.preloadedSlots[slot] := true
    }
    else
    {
        ; val tenía algo pero clean lo descartó (ej. "OCR ilegible" → ""): 
        ; lo dejamos pendiente para el usuario, NO sobreescribimos
        ; el slot porque algo había escrito.
    }
}
```

Caso edge: si `val != "" && limpio = ""` (cleaner rechazó): NO sobreescribimos `queue[slot]` (queda como estaba). Eso es razonable: si OCR capturó basura, dejamos el último valor bueno. Solo el caso vacío real (`val = ""`) limpia.

## 3. Out of scope

- Anchoring derecho/inferior dinámico al resize (sigue pendiente, otro plan).
- Eliminar Botonera de carpeta `Botonera/` (no afecta a quickestEntry).
- Cambiar el confirm-removal de `DoSoltar`/`DoHeaderScan` en QuickEntry.ahk (queda como está en quickestEntry).
- Persistencia de preloadedSlots en SaveLastPaste (queda como está en quickestEntry).
- Borrar el control hidden `titleCounterCtrl` totalmente — basta con no crearlo y guardear contra IsObject en los callers.

## 4. Riesgos

| Riesgo | Mitigación |
|---|---|
| `Update()` accede a `this.titleCounterCtrl.Value` sin guarda → crash al quitar | Guarda `if IsObject(...)` antes de cada uso |
| Compact grid (RenderMode) hardcodea 11 botones — al quitar 2, el loop falla | Revisar RenderMode y quitar las entradas de `manual` y `pegEsp` del Map |
| `buttonsById["manual"]` o `["pegEsp"]` referenciados en algún tooltip / Update | Buscar en código y quitar |
| `IsRectVisible` con 0 monitores conectados (degenerate) | Retornar `false` siempre → fallback a centrar |
| ClearSlot rompe undo / loadLast | Implementar `ClearSlot` con `actionLog` para soportar Undo |
| Inline edit con `Trim(val) = ""` pero usuario quería literalmente espacio en blanco | Aceptable: no es un valor "real", y la validación lo rechazaría igualmente |
