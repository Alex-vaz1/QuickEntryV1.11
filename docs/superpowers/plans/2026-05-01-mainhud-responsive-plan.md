# MainHud Responsive Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two-mode (Normal/Compact) responsive layout to QuickEntry's MainHud, with auto-switch by window width breakpoint, MinSize bloqueado, and W+H persistence in INI.

**Architecture:** Pure module `Lib/HudLayout.ahk` holds breakpoint logic + label/symbol lookup tables. `MainHud.ahk` consumes it: tracks `currentMode`, listens to `Size` event, re-renders texts and column widths when mode changes. INI gains 4 keys (`defaultW/H`, `lastW/H`).

**Tech Stack:** AutoHotkey v2.0, custom assert helpers, smoke launch + manual visual test for GUI.

**Spec:** `docs/superpowers/specs/2026-05-01-mainhud-responsive-design.md`

**ClautoHotkey reference**: ANTES de cada Task que toque GUI (`Tasks 5-10`), consultar `ClautoHotkey/Modules/Module_GUI.md` (resize, control move, ListView/TreeView no aplica acá pero patrones sí). Para Task 1-4 (módulo puro) basta con `Module_Instructions.md`.

---

## File Structure (final state)

```
Asignet/
├── Lib/
│   ├── HudLayout.ahk        ← NUEVO: módulo puro con breakpoint + tablas
│   └── MainHud.ahk          ← MODIFICADO: consume HudLayout
├── Tests/
│   └── Test_HudLayout.ahk   ← NUEVO: ~17 asserts
└── (resto sin cambios)
```

**Key design points:**
- Pure module testable: `IsCompact`, `LabelForSlot`, `LabelForButton`, `NameColWidth`. Sin estado, sin GUI.
- `MainHud` track `currentMode` y re-renderiza solo si cambia (idempotencia).
- `buttonsById` Map en MainHud asocia hwnd-stable IDs a controles. Eso desacopla el ID lógico ("start", "release") del texto mostrado.
- Re-renderizar significa: cambiar `.Text` de slots+botones, mover X de controles según `nameColWidth`. NO destruimos ni recreamos controles.

---

## Task 1: `HudLayout.IsCompact` (TDD pure)

**Files:**
- Create: `Lib/HudLayout.ahk`
- Create: `Tests/Test_HudLayout.ahk`

- [ ] **Step 1.1: Write failing test**

Create `Tests/Test_HudLayout.ahk`:

```autohotkey
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\HudLayout.ahk"
#Include "_AssertHelpers.ahk"

; --- IsCompact: breakpoint = 540, exclusive ---
AssertEq(HudLayout.IsCompact(539) ? 1 : 0, 1, "compact at 539")
AssertEq(HudLayout.IsCompact(540) ? 1 : 0, 0, "normal at exactly 540")
AssertEq(HudLayout.IsCompact(541) ? 1 : 0, 0, "normal at 541")
AssertEq(HudLayout.IsCompact(800) ? 1 : 0, 0, "normal at 800")
AssertEq(HudLayout.IsCompact(0) ? 1 : 0, 1, "compact at 0 (degenerate)")

ReportarYSalir()
```

- [ ] **Step 1.2: Run test — verify FAIL (file missing)**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"
```

Expected: `FAIL Test_HudLayout.ahk` with CRASH (HudLayout.ahk not found).

- [ ] **Step 1.3: Implement minimal `HudLayout.ahk`**

```autohotkey
#Requires AutoHotkey v2.0
; ====================================================================
; HudLayout.ahk - Layout decisions del MainHud (modulo PURO).
; Sin estado. Sin GUI. Lookup tables + funciones de decision por breakpoint.
;
; Modos:
;   Normal:  ancho >= 540px. Layout actual (nameCol 240, full labels).
;   Compact: ancho < 540px.  Slots abreviados + botones solo simbolo.
; ====================================================================

class HudLayout
{
    static breakpoint := 540

    static IsCompact(width)
    {
        return width < this.breakpoint
    }
}
```

- [ ] **Step 1.4: Run test — verify PASS**

Expected: `Test_HudLayout.ahk === 5 tests, 0 failures ===`.

- [ ] **Step 1.5: Commit**

```powershell
cd "C:\Users\Usuario\Desktop\Asignet"
git add Lib/HudLayout.ahk Tests/Test_HudLayout.ahk
git commit -m "feat(layout): HudLayout.IsCompact con breakpoint 540"
```

---

## Task 2: `HudLayout.LabelForSlot` (TDD pure)

**Files:**
- Modify: `Lib/HudLayout.ahk`
- Modify: `Tests/Test_HudLayout.ahk`

- [ ] **Step 2.1: Append failing tests**

Append to `Tests/Test_HudLayout.ahk` BEFORE `ReportarYSalir()`:

```autohotkey
; --- LabelForSlot: full vs abreviado segun isCompact ---
AssertEq(HudLayout.LabelForSlot(1, false), "Account number", "slot 1 normal")
AssertEq(HudLayout.LabelForSlot(1, true),  "Acct #",         "slot 1 compact")
AssertEq(HudLayout.LabelForSlot(4, false), "Corp name",      "slot 4 normal")
AssertEq(HudLayout.LabelForSlot(4, true),  "Corp",           "slot 4 compact")
AssertEq(HudLayout.LabelForSlot(9, false), "Invoice Total Including PastDue", "slot 9 normal")
AssertEq(HudLayout.LabelForSlot(9, true),  "Total + PD",     "slot 9 compact")
; Slot fuera de rango -> retorna "" (degenerate)
AssertEq(HudLayout.LabelForSlot(99, true), "",               "slot 99 returns empty")
```

- [ ] **Step 2.2: Run — FAIL (LabelForSlot undefined)**

Expected new failure on the 6 new asserts.

- [ ] **Step 2.3: Implement `LabelForSlot` in `HudLayout.ahk`**

Append inside `class HudLayout`:

```autohotkey
    ; --- Tabla privada: nombres por slot, full vs compact ---
    static slotLabels := Map(
        1, Map("full", "Account number",                 "compact", "Acct #"),
        2, Map("full", "Invoice date",                   "compact", "Inv date"),
        3, Map("full", "Due date",                       "compact", "Due date"),
        4, Map("full", "Corp name",                      "compact", "Corp"),
        5, Map("full", "Previous balance",               "compact", "Prev bal"),
        6, Map("full", "Past Total Payments",            "compact", "Payments"),
        7, Map("full", "Past due",                       "compact", "Past due"),
        8, Map("full", "Total ($)",                      "compact", "Total"),
        9, Map("full", "Invoice Total Including PastDue","compact", "Total + PD")
    )

    static LabelForSlot(idx, isCompact)
    {
        if !this.slotLabels.Has(idx)
            return ""
        return this.slotLabels[idx][isCompact ? "compact" : "full"]
    }
```

- [ ] **Step 2.4: Run — verify PASS**

Expected: `Test_HudLayout.ahk === 12 tests, 0 failures ===`.

- [ ] **Step 2.5: Commit**

```powershell
git add Lib/HudLayout.ahk Tests/Test_HudLayout.ahk
git commit -m "feat(layout): LabelForSlot con tabla full/compact (slots 1-9)"
```

---

## Task 3: `HudLayout.LabelForButton` (TDD pure)

**Files:**
- Modify: `Lib/HudLayout.ahk`
- Modify: `Tests/Test_HudLayout.ahk`

- [ ] **Step 3.1: Append failing tests**

```autohotkey
; --- LabelForButton: texto vs simbolo segun isCompact ---
AssertEq(HudLayout.LabelForButton("start", false),       "▶ Iniciar",      "start normal")
AssertEq(HudLayout.LabelForButton("start", true),        "▶",              "start compact")
AssertEq(HudLayout.LabelForButton("skip", false),        "⏭ Omitir",       "skip normal")
AssertEq(HudLayout.LabelForButton("skip", true),         "⏭",              "skip compact")
AssertEq(HudLayout.LabelForButton("templateOn", false),  "☑ Template",     "templateOn normal")
AssertEq(HudLayout.LabelForButton("templateOn", true),   "☑",              "templateOn compact")
AssertEq(HudLayout.LabelForButton("templateOff", false), "☐ Template",     "templateOff normal")
AssertEq(HudLayout.LabelForButton("templateOff", true),  "☐",              "templateOff compact")
AssertEq(HudLayout.LabelForButton("scan", false),        "⇣ Scan",         "scan normal")
AssertEq(HudLayout.LabelForButton("scan", true),         "⇣",              "scan compact")
AssertEq(HudLayout.LabelForButton("release", false),     "▶▶ Soltar",      "release normal")
AssertEq(HudLayout.LabelForButton("release", true),      "▶▶",             "release compact")
AssertEq(HudLayout.LabelForButton("reset", false),       "⊘ Reset",        "reset normal")
AssertEq(HudLayout.LabelForButton("reset", true),        "⊘",              "reset compact")
AssertEq(HudLayout.LabelForButton("undo", false),        "↶ Undo",         "undo normal")
AssertEq(HudLayout.LabelForButton("undo", true),         "↶",              "undo compact")
AssertEq(HudLayout.LabelForButton("loadLast", false),    "↻ Load Last",    "loadLast normal")
AssertEq(HudLayout.LabelForButton("loadLast", true),     "↻",              "loadLast compact")
AssertEq(HudLayout.LabelForButton("manual", false),      "⌨ Editar",       "manual normal")
AssertEq(HudLayout.LabelForButton("manual", true),       "⌨",              "manual compact")
AssertEq(HudLayout.LabelForButton("pegEsp", false),      "📋 Pegar limpio", "pegEsp normal")
AssertEq(HudLayout.LabelForButton("pegEsp", true),       "📋",              "pegEsp compact")
AssertEq(HudLayout.LabelForButton("autocalc", false),    "Σ Calc",         "autocalc normal")
AssertEq(HudLayout.LabelForButton("autocalc", true),     "Σ",              "autocalc compact")
AssertEq(HudLayout.LabelForButton("setDefault", false),  "⊙",              "setDefault normal (already symbol)")
AssertEq(HudLayout.LabelForButton("setDefault", true),   "⊙",              "setDefault compact (same)")
AssertEq(HudLayout.LabelForButton("nonexistent", true),  "?",              "unknown id returns ?")
```

- [ ] **Step 3.2: Run — FAIL (LabelForButton undefined)**

Expected: 27 new failing asserts.

- [ ] **Step 3.3: Implement `LabelForButton`**

Append inside `class HudLayout`:

```autohotkey
    static buttonLabels := Map(
        "start",       Map("full", "▶ Iniciar",      "compact", "▶"),
        "skip",        Map("full", "⏭ Omitir",       "compact", "⏭"),
        "templateOn",  Map("full", "☑ Template",     "compact", "☑"),
        "templateOff", Map("full", "☐ Template",     "compact", "☐"),
        "scan",        Map("full", "⇣ Scan",         "compact", "⇣"),
        "release",     Map("full", "▶▶ Soltar",      "compact", "▶▶"),
        "reset",       Map("full", "⊘ Reset",        "compact", "⊘"),
        "undo",        Map("full", "↶ Undo",         "compact", "↶"),
        "loadLast",    Map("full", "↻ Load Last",    "compact", "↻"),
        "manual",      Map("full", "⌨ Editar",       "compact", "⌨"),
        "pegEsp",      Map("full", "📋 Pegar limpio", "compact", "📋"),
        "autocalc",    Map("full", "Σ Calc",         "compact", "Σ"),
        "setDefault",  Map("full", "⊙",              "compact", "⊙")
    )

    static LabelForButton(buttonId, isCompact)
    {
        if !this.buttonLabels.Has(buttonId)
            return "?"
        return this.buttonLabels[buttonId][isCompact ? "compact" : "full"]
    }
```

- [ ] **Step 3.4: Run — PASS**

Expected: `Test_HudLayout.ahk === 39 tests, 0 failures ===`.

- [ ] **Step 3.5: Commit**

```powershell
git add Lib/HudLayout.ahk Tests/Test_HudLayout.ahk
git commit -m "feat(layout): LabelForButton con 13 button IDs y simbolos compactos"
```

---

## Task 4: `HudLayout.NameColWidth` (TDD pure)

**Files:**
- Modify: `Lib/HudLayout.ahk`
- Modify: `Tests/Test_HudLayout.ahk`

- [ ] **Step 4.1: Append failing tests**

```autohotkey
; --- NameColWidth: 240 normal, 100 compact ---
AssertEq(HudLayout.NameColWidth(false), 240, "nameCol normal")
AssertEq(HudLayout.NameColWidth(true),  100, "nameCol compact")
```

- [ ] **Step 4.2: Run — FAIL**

Expected: 2 new failing asserts.

- [ ] **Step 4.3: Implement `NameColWidth`**

Append inside `class HudLayout`:

```autohotkey
    static NameColWidth(isCompact)
    {
        return isCompact ? 100 : 240
    }
```

- [ ] **Step 4.4: Run — PASS**

Expected: `Test_HudLayout.ahk === 41 tests, 0 failures ===`.

- [ ] **Step 4.5: Commit**

```powershell
git add Lib/HudLayout.ahk Tests/Test_HudLayout.ahk
git commit -m "feat(layout): NameColWidth (240/100)"
```

---

## Task 5: MainHud — `buttonsById` Map + Build refactor (no behavior change yet)

**Files:**
- Modify: `Lib/MainHud.ahk`

This task introduces the `buttonsById` Map but DOES NOT yet read from `HudLayout`. Goal: make sure the existing UI keeps working with the new infrastructure in place. No visible change.

- [ ] **Step 5.1: Add `buttonsById` field declaration**

In `class MainHud`, near the existing field declarations (near `btnArm := ""`), add:

```autohotkey
    buttonsById := Map()
```

- [ ] **Step 5.2: Populate `buttonsById` in `Build()` after wiring**

After the line that currently says `btnSetDefault.OnEvent("Click", (*) => this.SaveAsDefault())`, add:

```autohotkey
        ; Map button IDs -> control refs (for HudLayout-driven re-render).
        ; IDs match HudLayout.LabelForButton lookup keys.
        this.buttonsById := Map(
            "start", btnArm,           ; texto cambia entre start/skip dinamicamente
            "templateOff", btnTemplateToggle,  ; idem entre on/off
            "scan", btnScan,
            "release", btnSoltar,
            "reset", btnReset,
            "undo", btnUndo,
            "loadLast", btnLoadLast,
            "manual", btnManual,
            "pegEsp", btnPegEsp,
            "autocalc", btnCalc,
            "setDefault", btnSetDefault
        )
```

- [ ] **Step 5.3: Validate**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk"
echo "ExitCode: $LASTEXITCODE"
```

Expected: `ExitCode: 0`.

- [ ] **Step 5.4: Smoke launch — verify still works**

```powershell
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: `OK`. Visual: GUI looks identical to before (no responsive yet).

- [ ] **Step 5.5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"
```

Expected: 742 asserts (701 + 41), ALL TESTS PASSED.

- [ ] **Step 5.6: Commit**

```powershell
git add Lib/MainHud.ahk
git commit -m "refactor(hud): buttonsById Map (sin cambio visible aun)"
```

---

## Task 6: MainHud — `+Resize +MinSize480x400` + Size event hook (skeleton)

**Files:**
- Modify: `Lib/MainHud.ahk`

- [ ] **Step 6.1: Add MinSize to Gui constructor**

In `Build()`, find the line:
```autohotkey
        g := Gui("+AlwaysOnTop +Resize -DPIScale", "QuickEntry")
```

Replace with:
```autohotkey
        g := Gui("+AlwaysOnTop +Resize +MinSize480x400 -DPIScale", "QuickEntry")
```

If `+MinSize480x400` syntax fails validation in AHK v2 (some versions require `Opt()` instead), use:
```autohotkey
        g := Gui("+AlwaysOnTop +Resize -DPIScale", "QuickEntry")
        g.Opt("+MinSize480x400")
```

- [ ] **Step 6.2: Add `currentMode` field**

Add field near `buttonsById`:
```autohotkey
    currentMode := "normal"  ; "normal" | "compact"
```

- [ ] **Step 6.3: Wire Size event (handler stub)**

In `Build()`, after the existing `g.OnEvent("ContextMenu", ...)`, add:

```autohotkey
        g.OnEvent("Size", (*) => this.OnResize())
```

- [ ] **Step 6.4: Implement `OnResize` STUB**

Add new method to `MainHud` class:

```autohotkey
    ; Stub: reads width and would re-render mode if changed.
    ; Full implementation in Task 7.
    OnResize()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetClientPos(, , &w)
        newMode := HudLayout.IsCompact(w) ? "compact" : "normal"
        if (newMode = this.currentMode)
            return
        this.currentMode := newMode
        ; TODO Task 7: this.RenderMode(newMode)
    }
```

- [ ] **Step 6.5: Add include for `HudLayout` at top of MainHud.ahk**

Find the existing `#Include` lines at the top. Add:
```autohotkey
#Include "HudLayout.ahk"
```

- [ ] **Step 6.6: Validate + smoke**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: `ExitCode: 0`, `OK`. Manual visual: try drag-resize the window — it should NOT shrink below 480x400. Below that, the OS resize stops.

If MinSize doesn't work with `+MinSize480x400` in options (no error but still shrinkable), fall back to `g.Opt("+MinSize480x400")` after `g := Gui(...)`.

- [ ] **Step 6.7: Run full test suite**

Expected: 742 asserts, ALL PASSED.

- [ ] **Step 6.8: Commit**

```powershell
git add Lib/MainHud.ahk
git commit -m "feat(hud): MinSize 480x400 + Size event hook + currentMode tracking"
```

---

## Task 7: MainHud — `RenderMode` aplica labels (sin reposicionar todavía)

**Files:**
- Modify: `Lib/MainHud.ahk`

- [ ] **Step 7.1: Implement `RenderMode` (labels only)**

Add new method to `MainHud`:

```autohotkey
    ; Aplica el modo (normal/compact) a los textos de slots y botones.
    ; NO reposiciona controles ni cambia anchos (eso es Task 8).
    RenderMode(mode)
    {
        isCompact := (mode = "compact")

        ; --- Slot labels ---
        for i, row in this.rows
        {
            label := HudLayout.LabelForSlot(i, isCompact)
            if (label != "")
                row["nameCtrl"].Text := label
        }

        ; --- Footer button labels ---
        ; btnArm: texto depende del estado (esActivo o no) Y del modo.
        ; Como Update() ya recalcula btnArm.Text en cada call basado en el estado,
        ; no lo seteamos aca; en vez, dejamos que Update() use HudLayout cuando se
        ; refresque (Task 9).

        ; btnTemplateToggle: similar, depende de this.templateMode.
        ; Lo seteamos directo aca porque no cambia frecuente:
        if this.buttonsById.Has("templateOff")
        {
            id := this.templateMode ? "templateOn" : "templateOff"
            this.buttonsById["templateOff"].Text := HudLayout.LabelForButton(id, isCompact)
        }

        ; Botones simples (texto fijo independiente de estado):
        for id, ctrl in this.buttonsById
        {
            if (id = "templateOff")  ; ya se manejo arriba
                continue
            if (id = "start")  ; lo maneja Update() con esActivo
                continue
            ctrl.Text := HudLayout.LabelForButton(id, isCompact)
        }
    }
```

- [ ] **Step 7.2: Llamar `RenderMode` desde `OnResize`**

Replace the `OnResize` stub:

```autohotkey
    OnResize()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetClientPos(, , &w)
        newMode := HudLayout.IsCompact(w) ? "compact" : "normal"
        if (newMode = this.currentMode)
            return
        this.currentMode := newMode
        this.RenderMode(newMode)
    }
```

- [ ] **Step 7.3: Llamar `RenderMode` al inicio de `Show`**

Find `Show()` method. Right after `g.Show("AutoSize")` or similar, add:

```autohotkey
        ; Aplicar modo inicial segun ancho actual
        this.gui.GetClientPos(, , &w)
        this.currentMode := HudLayout.IsCompact(w) ? "compact" : "normal"
        this.RenderMode(this.currentMode)
```

(If the exact location is hard to find, place it as the LAST line of `Show()` before the method end.)

- [ ] **Step 7.4: Update `Update()` para usar HudLayout en btnArm**

Find where `Update()` sets `this.btnArm.Text`. The current code sets it to `"⏭ Omitir"` or `"▶ Iniciar"` based on state. Replace with:

```autohotkey
        ; btnArm label: depende de esActivo Y del modo actual
        isCompact := (this.currentMode = "compact")
        this.btnArm.Text := HudLayout.LabelForButton(esActivo ? "skip" : "start", isCompact)
```

(Preserve the surrounding logic that determines `esActivo`.)

- [ ] **Step 7.5: Validate + smoke + manual visual test**

Validate. Smoke launch. **Manual visual test:**
1. Arranca QuickEntry. La GUI aparece en modo normal (640x algo).
2. Arrastra el borde derecho hacia la izquierda lentamente.
3. Cuando crucés bajo 540px de ancho: TODOS los nombres de slots cambian a versión corta ("Account number" → "Acct #") + botones del footer cambian a símbolo.
4. Arrastra de vuelta a 600px: vuelven los nombres completos.
5. Posiciones de los controles están **mal** (overlapping) en compact — eso lo arregla Task 8. No es bug, es WIP.

- [ ] **Step 7.6: Run full test suite**

Expected: 742 asserts, ALL PASSED.

- [ ] **Step 7.7: Commit**

```powershell
git add Lib/MainHud.ahk
git commit -m "feat(hud): RenderMode actualiza textos de slots+botones segun modo"
```

---

## Task 8: MainHud — `RenderMode` reposiciona controles según `nameColWidth`

**Files:**
- Modify: `Lib/MainHud.ahk`

- [ ] **Step 8.1: Extend `RenderMode` con reposicionamiento**

Append to `RenderMode(mode)` method (BEFORE its closing `}`):

```autohotkey
        ; --- Reposicionar controles de slot rows segun nameColWidth ---
        nameW := HudLayout.NameColWidth(isCompact)
        ; Anchos fijos:
        ;   slotTxt: x16 w28
        ;   nameCtrl: x50 w<nameW>
        ;   valueCtrl: x<50+nameW+10> w<260 normal / 240 compact>
        ;   iconCtrl: x<50+nameW+10+valueW+10> w28
        ;   forceBtn: x<iconCtrl.x - 32>
        valueW := isCompact ? 240 : 260
        nameX := 50
        valueX := nameX + nameW + 10
        iconX := valueX + valueW + 10
        forceX := iconX - 32

        for row in this.rows
        {
            row["nameCtrl"].Move(nameX, , nameW)
            row["valueCtrl"].Move(valueX, , valueW)
            row["iconCtrl"].Move(iconX)
            row["forceBtn"].Move(forceX)
            ; bgUnderlay: ancho total -24 desde x12 (depende del ancho de la ventana)
            this.gui.GetClientPos(, , &winW)
            row["bgUnderlay"].Move(, , winW - 24)
        }

        ; --- Footer botones: en compact, los achicamos para que sean cuadraditos ---
        ; Definimos anchos de botones por modo. En compact, todos ~36px (cuadrados).
        ; En normal, dejamos los anchos originales (no tocamos).
        if isCompact
        {
            footerWidths := Map(
                "start", 36, "templateOff", 36, "scan", 36, "release", 36,
                "reset", 36, "undo", 36, "loadLast", 36, "manual", 36,
                "pegEsp", 36, "autocalc", 36, "setDefault", 32
            )
            ; Posiciones X consecutivas en footer Row 1
            x1 := 16
            for id in ["start", "templateOff", "scan", "release", "reset", "undo"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x1, , w)
                x1 += w + 4
            }
            ; Footer Row 2
            x2 := 16
            for id in ["loadLast", "manual", "pegEsp", "autocalc"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x2, , w)
                x2 += w + 4
            }
            ; setDefault va al final de Row 2
            this.buttonsById["setDefault"].Move(x2, , footerWidths["setDefault"])
        }
        else
        {
            ; Normal mode: restaurar X y W originales
            normalLayout := Map(
                "start",       Map("x", 16,  "w", 90),
                "templateOff", Map("x", 110, "w", 110),
                "scan",        Map("x", 224, "w", 80),
                "release",     Map("x", 308, "w", 90),
                "reset",       Map("x", 402, "w", 62),
                "undo",        Map("x", 468, "w", 62),
                "loadLast",    Map("x", 16,  "w", 110),
                "manual",      Map("x", 132, "w", 100),
                "pegEsp",      Map("x", 238, "w", 130),
                "autocalc",    Map("x", 374, "w", 80),
                "setDefault",  Map("x", 548, "w", 32)
            )
            for id, pos in normalLayout
                this.buttonsById[id].Move(pos["x"], , pos["w"])
        }
```

**Nota:** las coordenadas Y no cambian (footerY/footerY2 son fijas). Solo X y W se ajustan.

- [ ] **Step 8.2: Hook `OnResize` también para refrescar bgUnderlay cuando ANCHO cambia (no solo modo)**

Modify `OnResize` to ALSO update bgUnderlay incluso si modo no cambió:

```autohotkey
    OnResize()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetClientPos(, , &w)
        newMode := HudLayout.IsCompact(w) ? "compact" : "normal"
        if (newMode != this.currentMode)
        {
            this.currentMode := newMode
            this.RenderMode(newMode)
        }
        else
        {
            ; Mismo modo: solo actualizar bgUnderlay para que cubra todo el ancho
            for row in this.rows
                row["bgUnderlay"].Move(, , w - 24)
        }
    }
```

- [ ] **Step 8.3: Validate + smoke + manual visual test**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: `ExitCode: 0`, `OK`. **Manual visual test:**
1. Arranca QuickEntry. Arrastra borde a < 540px.
2. **Compact mode**: nombres cortos, botones cuadrados con símbolo, todo entra en el ancho reducido. No hay overlap.
3. Arrastra a > 540px: vuelve a normal. Botones largos, nombres largos, posiciones originales.
4. Toggle entre los modos varias veces — los controles deben quedar correctos siempre.

- [ ] **Step 8.4: Run test suite**

Expected: 742 asserts, ALL PASSED.

- [ ] **Step 8.5: Commit**

```powershell
git add Lib/MainHud.ahk
git commit -m "feat(hud): RenderMode reposiciona controles segun modo (compact/normal)"
```

---

## Task 9: MainHud — INI persiste W+H (load/save/setDefault)

**Files:**
- Modify: `Lib/MainHud.ahk`

- [ ] **Step 9.1: Add `lastW`, `lastH`, `defaultW`, `defaultH` fields**

Near the existing position fields (`lastX`, `lastY`, `defaultX`, `defaultY`), add:

```autohotkey
    lastW := 0
    lastH := 0
    defaultW := 0
    defaultH := 0
```

- [ ] **Step 9.2: Modify `LoadPosition` to load W/H**

In `LoadPosition()`, after the existing IniRead calls for X/Y, add:

```autohotkey
        this.defaultW := Integer(IniRead(this.iniPath, "Window", "defaultW", 540))
        this.defaultH := Integer(IniRead(this.iniPath, "Window", "defaultH", 460))
        this.lastW    := Integer(IniRead(this.iniPath, "Window", "lastW", this.defaultW))
        this.lastH    := Integer(IniRead(this.iniPath, "Window", "lastH", this.defaultH))
```

- [ ] **Step 9.3: Modify `SaveLastPosition` to save W/H**

In `SaveLastPosition()`, replace the body with:

```autohotkey
        if !IsObject(this.gui)
            return
        this.gui.GetPos(&x, &y, &w, &h)
        this.lastX := x
        this.lastY := y
        this.lastW := w
        this.lastH := h
        IniWrite(x, this.iniPath, "Window", "lastX")
        IniWrite(y, this.iniPath, "Window", "lastY")
        IniWrite(w, this.iniPath, "Window", "lastW")
        IniWrite(h, this.iniPath, "Window", "lastH")
```

- [ ] **Step 9.4: Modify `SaveAsDefault` to save W/H**

Replace `SaveAsDefault()` body with:

```autohotkey
        if !IsObject(this.gui)
            return
        this.gui.GetPos(&x, &y, &w, &h)
        this.defaultX := x
        this.defaultY := y
        this.defaultW := w
        this.defaultH := h
        this.lastX := x
        this.lastY := y
        this.lastW := w
        this.lastH := h
        IniWrite(x, this.iniPath, "Window", "defaultX")
        IniWrite(y, this.iniPath, "Window", "defaultY")
        IniWrite(w, this.iniPath, "Window", "defaultW")
        IniWrite(h, this.iniPath, "Window", "defaultH")
        IniWrite(x, this.iniPath, "Window", "lastX")
        IniWrite(y, this.iniPath, "Window", "lastY")
        IniWrite(w, this.iniPath, "Window", "lastW")
        IniWrite(h, this.iniPath, "Window", "lastH")
        ToolTip("Posicion + tamanio default actualizados")
        SetTimer(() => ToolTip(), -1500)
```

- [ ] **Step 9.5: Modify `Show` para usar lastW/lastH al mostrar**

Find the `Show()` method, line that calls `g.Show(...)`. If it currently says something like `g.Show("AutoSize")`, replace with:

```autohotkey
        ; Usar tamanio guardado en INI
        showOpts := "x" this.lastX " y" this.lastY " w" this.lastW " h" this.lastH
        this.gui.Show(showOpts)
```

(Si el método actual no usa explicit W/H, agregalos. La idea: la ventana se abre con el tamaño persistido.)

- [ ] **Step 9.6: Validate + smoke + manual test**

Validate. Smoke launch. **Manual:**
1. Arranca, arrastra a un tamaño chico, hide (Escape) → reabrí (Ctrl+Shift+B o lo que sea) → debe abrir al tamaño que dejaste.
2. Click "⊙ Marcar default" → cierra y reabre → debe abrir con ese tamaño.
3. Verifica `%AppData%\QuickEntry\layout.ini` — debe tener `lastW`, `lastH`, `defaultW`, `defaultH`.

- [ ] **Step 9.7: Run test suite**

Expected: 742 asserts, ALL PASSED.

- [ ] **Step 9.8: Commit**

```powershell
git add Lib/MainHud.ahk
git commit -m "feat(hud): INI persiste W+H, Show usa tamanio guardado"
```

---

## Task 10: Final integration + manual smoke

**Files:**
- Modify: `Lib/MainHud.ahk` (si surgen ajustes en manual test)

- [ ] **Step 10.1: Run validate + smoke + tests**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"
```

Expected: validate `0`, smoke `OK`, tests `742 asserts ALL PASSED`.

- [ ] **Step 10.2: Manual smoke checklist**

Checklist visual completo (correr QuickEntry y probar):

- [ ] GUI arranca con tamaño persistido (no autoSize random)
- [ ] Arrastrar borde a < 540px → modo compact (slots cortos, botones cuadrados con símbolo)
- [ ] Arrastrar a > 540px → modo normal (slots completos, botones con texto)
- [ ] No se puede achicar la ventana abajo de 480x400 (MinSize)
- [ ] Hover sobre botón en compact muestra tooltip con descripción completa
- [ ] btnArm cambia entre `▶`/`⏭` (compact) o `▶ Iniciar`/`⏭ Omitir` (normal) según estado
- [ ] btnTemplateToggle cambia entre `☐`/`☑` (compact) o `☐ Template`/`☑ Template` (normal) según toggle
- [ ] Click "⊙" → tooltip "Posicion + tamanio default actualizados"
- [ ] Inline edit (`Ctrl+Shift+E`) sigue funcionando en ambos modos
- [ ] Force button (✓ verde) aparece en posición correcta a la izq del icon en ambos modos

- [ ] **Step 10.3: Si surge bug, agregar fix + commit**

Si un item falla, hacer fix mínimo y commit con mensaje descriptivo.

- [ ] **Step 10.4: Final commit (si todo OK, este step se puede saltar)**

Si la checklist pasa sin fixes, no hace falta commit. Si hubo fixes:

```powershell
git add Lib/MainHud.ahk
git commit -m "fix(hud): ajustes finales del manual smoke"
```

---

## Self-Review Checklist (run before declaring plan done)

After all 10 tasks:

- [ ] **Spec coverage:** every section in `2026-05-01-mainhud-responsive-design.md` maps to a task. ✓
  - Sec 3 modos → Tasks 1, 7
  - Sec 4 breakpoint → Task 1
  - Sec 5 INI persistence → Task 9
  - Sec 6.1 slot abreviaciones → Task 2
  - Sec 6.2 button símbolos → Task 3
  - Sec 7 anchos columna → Tasks 4, 8
  - Sec 8 arquitectura HudLayout + MainHud → Tasks 1-9
  - Sec 9 tests → Tasks 1-4
  - Sec 11 riesgos: MinSize syntax → Task 6 con fallback Opt(); flapping → no se implementa histéresis a menos que aparezca; underlay paint → Task 8
- [ ] **No placeholders:** todos los Tasks tienen código completo. ✓
- [ ] **Type consistency:** `HudLayout.IsCompact`, `LabelForSlot`, `LabelForButton`, `NameColWidth` usados consistentes en Tasks 5-9. ✓
- [ ] **All tests pass:** final state 742 asserts (701 base + 41 nuevos), ALL TESTS PASSED. ✓
- [ ] **Smoke launch works:** GUI arranca, resize entre modos funciona. ✓

## Final assert tally

| Test file | Asserts |
|---|---|
| Test_HudLayout (NUEVO) | 41 |
| Tests existentes (sin cambios) | 701 |
| **Total** | **742** |

## Out of scope (explícito)

- Histéresis del breakpoint (sec 11 spec). Se agrega solo si testing visual muestra flapping.
- Botones con tooltips inmediatos en hover (delay nativo de Windows aceptado).
- Símbolos vs íconos imagen (solo Unicode chars).
- Persistencia del estado del Process Timer durante resize (no aplica acá).
- Retroceder a "modo manual" (toggle compact/full button como antes — eso quedó out of scope cuando lo borramos en `44618b2`).

## Riesgos identificados durante el plan

- **Step 6.1**: si `+MinSize480x400` no es sintaxis válida en AHK v2 (algunas versiones requieren `Opt()`), usar fallback documentado. Si AHK v2 no soporta MinSize directo, hay que hookear `WM_GETMINMAXINFO` (más complejo) — paramos y reportamos antes de hackear.
- **Task 8 reposicionamiento**: las coordenadas X de los botones del footer en modo compact son consecutivas con `x += w + 4`. Si en algún caso visualmente se ven mal apretados, ajustar el `+ 4` a `+ 6` o `+ 8`.
- **Task 9 Show with explicit w/h**: si el método `Show()` actual usa AutoSize y los nuevos w/h no acomodan todos los controles (ej. ventana muy chica al primer arranque sin INI), podría haber overlap. Default `defaultH := 460` debería ser suficiente para 9 slots + 2 footer rows, pero verificar en manual test.
