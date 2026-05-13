# quickestEntry UI cleanup + small fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aplicar cinco cambios solicitados sobre quickestEntry: quitar header, reorganizar footer a 3 filas con renombre/remoción de botones, INI con default-position recovery, fix de inline-edit empty-commit, fix de Scan empty-value.

**Architecture:** Cambios distribuidos entre `Lib/MainHud.ahk` (GUI: header, footer, LoadPosition, OnInlineEditCommit), `Lib/CaptureEngine.ahk` (ClearSlot + Scan empty branch), `Lib/HudLayout.ahk` (rename "Soltar"→"Pegar" + nuevo helper `IsRectVisibleAgainst`). Pure modules con TDD; GUI changes con smoke + manual.

**Tech Stack:** AutoHotkey v2.0, asserts custom, PowerShell runner. Path AHK: `C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe`.

**Spec:** `docs/superpowers/specs/2026-05-10-quickestEntry-ui-cleanup-design.md`

**Baseline asserts:** 742 pasando hoy. Target final: **756** (= 742 + 14 nuevos).

**Git:** quickestEntry **NO es git repo**. Cada Task documenta el commit como reference pero el agente que ejecuta puede saltear el commit o init repo según prefiera. La numeración de hashes en el plan es solo placeholder narrativo.

---

## File Structure (final state)

```
QuickEntry-quickestEntry/
├── Lib/
│   ├── MainHud.ahk            ← MOD: header removido, footer 3 rows, LoadPosition recovery, OnInlineEditCommit empty
│   ├── CaptureEngine.ahk      ← MOD: nuevo ClearSlot, Scan empty val sobrescribe
│   └── HudLayout.ahk          ← MOD: rename "Soltar"→"Pegar", nuevo IsRectVisibleAgainst
├── Tests/
│   ├── Test_HudLayout.ahk     ← MOD: 2 asserts existentes "release" actualizados + 6 nuevos IsRectVisibleAgainst
│   └── Test_CaptureEngine.ahk ← MOD: +5 ClearSlot + +3 Scan empty
└── docs/superpowers/
    ├── specs/2026-05-10-quickestEntry-ui-cleanup-design.md  ← (ya escrito)
    └── plans/2026-05-10-quickestEntry-ui-cleanup-plan.md    ← este archivo
```

---

## Task 1: `HudLayout.LabelForButton` rename "Soltar" → "Pegar"

**Files:**
- Modify: `Lib/HudLayout.ahk`
- Modify: `Tests/Test_HudLayout.ahk` (2 asserts existentes)

- [ ] **Step 1.1: Cambiar tabla en HudLayout**

En `Lib/HudLayout.ahk`, encontrar la línea:
```autohotkey
        "release",     Map("full", "▶▶ Soltar",      "compact", "▶▶"),
```
Reemplazar por:
```autohotkey
        "release",     Map("full", "▶▶ Pegar",       "compact", "▶▶"),
```

- [ ] **Step 1.2: Actualizar tests existentes**

En `Tests/Test_HudLayout.ahk`, encontrar:
```autohotkey
AssertEq(HudLayout.LabelForButton("release", false),     "▶▶ Soltar",      "release normal")
```
Reemplazar por:
```autohotkey
AssertEq(HudLayout.LabelForButton("release", false),     "▶▶ Pegar",       "release normal")
```

(El assert para compact (`"▶▶"`) NO cambia.)

- [ ] **Step 1.3: Run test suite**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
```

Expected: `Test_HudLayout.ahk === 41 tests, 0 failures ===`. Total `742 asserts ALL PASSED`.

---

## Task 2: `CaptureEngine.ClearSlot` (TDD pure)

**Files:**
- Modify: `Lib/CaptureEngine.ahk` (agrega método)
- Modify: `Tests/Test_CaptureEngine.ahk` (agrega 5 asserts)

- [ ] **Step 2.1: Write failing tests**

En `Tests/Test_CaptureEngine.ahk`, **APPENDEÁ** antes de `ReportarYSalir()`:

```autohotkey
; ====================================================================
; ClearSlot - limpia un slot a "", soporta Undo via actionLog
; ====================================================================
e := CaptureEngine(CrearMock())
e.PushRaw("A1")             ; queue[1] = "A1"
e.PushRaw("42")             ; queue[2] = "42"
e.ClearSlot(1)
AssertEq(e.queue[1], "", "ClearSlot deja slot vacio")
AssertEq(e.queue[2], "42", "ClearSlot no toca otros slots")

; Undo debe restaurar el valor anterior del clear
e.Undo()
AssertEq(e.queue[1], "A1", "Undo de ClearSlot restaura prev value")

; ClearSlot fuera de rango es noop (no crash, no log)
e2 := CaptureEngine(CrearMock())
prevLen := e2.actionLog.Length
e2.ClearSlot(99)
AssertEq(e2.actionLog.Length, prevLen, "ClearSlot OOR no toca actionLog")

; ClearSlot quita el slot de preloadedSlots
e3 := CaptureEngine(CrearMock())
e3.queue[1] := "preloaded-val"
e3.preloadedSlots[1] := true
e3.ClearSlot(1)
AssertEq(e3.preloadedSlots.Has(1) ? 1 : 0, 0, "ClearSlot elimina preloaded")
```

- [ ] **Step 2.2: Run — verify FAIL**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
```

Expected: `Test_CaptureEngine.ahk FAIL/CRASH` (método `ClearSlot` no existe).

- [ ] **Step 2.3: Implementar `ClearSlot`**

En `Lib/CaptureEngine.ahk`, después del método `Undo()` (alrededor de línea 265, antes de `ExpectedFor`), agregá:

```autohotkey
    ; --- ClearSlot: borra el valor de un slot y lo quita de preloadedSlots.
    ;     Push al actionLog para soportar Undo. Usado por inline edit cuando
    ;     el usuario borra el contenido del Edit y commitea con Enter o
    ;     pierde foco. Validador (ej. ValidarNoVacio) NO se ejecuta — es un
    ;     clear explicito, no un "push de empty".
    ClearSlot(slot)
    {
        if (slot < 1 || slot > this.schema.Length)
            return
        this.actionLog.Push(Map("slot", slot, "prevValue", this.queue[slot]))
        this.queue[slot] := ""
        if this.preloadedSlots.Has(slot)
            this.preloadedSlots.Delete(slot)
    }
```

- [ ] **Step 2.4: Run — verify PASS**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
```

Expected: `Test_CaptureEngine.ahk === 215 tests, 0 failures ===` (210 base + 5 nuevos). Total `747 asserts ALL PASSED`.

---

## Task 3: `CaptureEngine.Scan` empty val sobrescribe (TDD pure)

**Files:**
- Modify: `Lib/CaptureEngine.ahk` (cambia branch del Scan loop)
- Modify: `Tests/Test_CaptureEngine.ahk` (+3 asserts)

- [ ] **Step 3.1: Write failing tests**

En `Tests/Test_CaptureEngine.ahk`, **APPENDEÁ** antes de `ReportarYSalir()`:

```autohotkey
; ====================================================================
; Scan empty val: si el campo del form esta vacio (captureFieldFn
; retorna ""), el slot queda VACIO en queue (NO mantiene valor anterior).
; ====================================================================
e := CaptureEngine(CrearMock())
e.queue[1] := "PREV"        ; valor previo en slot 1 (ej. de un load last)
e.queue[2] := "OTRO"        ; otro slot con valor que no debe cambiar

; Mock: captureFieldFn retorna "" siempre (form vacio)
emptyFn := () => ""
nopSend := (s) => 0
nopSleep := (ms) => 0
e.Scan(emptyFn, nopSend, nopSleep, "")

AssertEq(e.queue[1], "", "Scan empty borra slot 1 (no mantiene PREV)")
AssertEq(e.preloadedSlots.Has(1) ? 1 : 0, 0, "Scan empty no deja slot 1 en preloaded")

; Mock: captureFieldFn retorna un valor para slot 2 pero vacio para 1
calls := 0
mixedFn := () => (++calls, calls = 1 ? "" : "captured-val")
e2 := CaptureEngine(CrearMock())
e2.queue[1] := "OLD1"
e2.queue[2] := "OLD2"
e2.Scan(mixedFn, nopSend, nopSleep, "")
AssertEq(e2.queue[1], "", "Scan slot 1 vacio borra")
```

- [ ] **Step 3.2: Run — verify FAIL**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
```

Expected: los nuevos asserts fallan (queue[1] sigue siendo "PREV" / "OLD1" porque el código actual hace skip cuando val="").

- [ ] **Step 3.3: Modificar Scan loop**

En `Lib/CaptureEngine.ahk`, encontrar el bloque dentro de `Scan()`:

```autohotkey
            if (!campo.skipPaste)
            {
                val := captureFieldFn.Call()
                limpio := (val = "") ? "" : campo.clean.Call(val)
                if (limpio != "")
                {
                    this.queue[slot] := limpio
                    this.preloadedSlots[slot] := true
                }
            }
```

Reemplazar el bloque interno con:

```autohotkey
            if (!campo.skipPaste)
            {
                val := captureFieldFn.Call()
                if (val = "")
                {
                    ; Campo vacio en el form: SOBREESCRIBIR slot a "".
                    ; (Antes hacia skip y dejaba valor anterior — bug del clipboard "fantasma".)
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
                    ; Si val tenia algo pero cleaner lo rechazo (limpio = ""):
                    ; NO sobreescribimos (preservamos el valor previo del slot).
                }
            }
```

- [ ] **Step 3.4: Run — verify PASS**

Expected: `Test_CaptureEngine.ahk === 218 tests, 0 failures ===`. Total `750 asserts ALL PASSED`.

---

## Task 4: `HudLayout.IsRectVisibleAgainst` (TDD pure)

**Files:**
- Modify: `Lib/HudLayout.ahk` (agrega método estático)
- Modify: `Tests/Test_HudLayout.ahk` (+6 asserts)

Helper puro que recibe lista de monitores como Maps con keys `l, t, r, b`. Más fácil de testear que llamar `MonitorGetWorkArea` directo.

- [ ] **Step 4.1: Write failing tests**

En `Tests/Test_HudLayout.ahk`, **APPENDEÁ** antes de `ReportarYSalir()`:

```autohotkey
; ====================================================================
; IsRectVisibleAgainst(x, y, w, h, monitorsArray)
; Retorna true si al menos 100x100 del rect interseca algun monitor.
; ====================================================================
mons1 := [Map("l", 0, "t", 0, "r", 1920, "b", 1080)]   ; un monitor 1920x1080

; Rect totalmente dentro
AssertEq(HudLayout.IsRectVisibleAgainst(100, 100, 540, 460, mons1) ? 1 : 0, 1, "rect dentro de monitor")
; Rect totalmente fuera (a la derecha)
AssertEq(HudLayout.IsRectVisibleAgainst(2000, 100, 540, 460, mons1) ? 1 : 0, 0, "rect a la derecha del monitor")
; Rect que asoma solo 50px adentro (insuficiente — necesita 100)
AssertEq(HudLayout.IsRectVisibleAgainst(-490, 100, 540, 460, mons1) ? 1 : 0, 0, "rect con solo 50px visibles")
; Rect parcialmente visible con > 100x100
AssertEq(HudLayout.IsRectVisibleAgainst(-400, 100, 540, 460, mons1) ? 1 : 0, 1, "rect con 140px visibles cuenta")

; Multi-monitor
mons2 := [
    Map("l", 0,    "t", 0, "r", 1920, "b", 1080),
    Map("l", 1920, "t", 0, "r", 3840, "b", 1080)
]
AssertEq(HudLayout.IsRectVisibleAgainst(2500, 200, 540, 460, mons2) ? 1 : 0, 1, "rect en segundo monitor")

; Edge: sin monitores
AssertEq(HudLayout.IsRectVisibleAgainst(0, 0, 540, 460, []) ? 1 : 0, 0, "sin monitores retorna false")
```

- [ ] **Step 4.2: Run — verify FAIL**

Expected: 6 asserts fallan (método no existe).

- [ ] **Step 4.3: Implementar `IsRectVisibleAgainst`**

En `Lib/HudLayout.ahk`, dentro de `class HudLayout`, después de `NameColWidth()`, agregá:

```autohotkey
    ; --- IsRectVisibleAgainst: chequea si al menos 100x100 del rectangulo
    ;     (x, y, w, h) interseca alguno de los monitores en `monitorsArray`.
    ;     monitorsArray = Array<Map>, cada Map con keys "l", "t", "r", "b"
    ;     (left/top/right/bottom de la work area).
    ;     Modulo PURO: no llama a MonitorGetWorkArea — el caller le pasa
    ;     los rectangulos. Asi se puede testear sin tocar Windows API.
    static IsRectVisibleAgainst(x, y, w, h, monitorsArray)
    {
        minVisible := 100
        for mon in monitorsArray
        {
            ix := Max(x, mon["l"])
            iy := Max(y, mon["t"])
            ir := Min(x + w, mon["r"])
            ib := Min(y + h, mon["b"])
            if (ir - ix >= minVisible && ib - iy >= minVisible)
                return true
        }
        return false
    }
```

- [ ] **Step 4.4: Run — verify PASS**

Expected: `Test_HudLayout.ahk === 47 tests, 0 failures ===`. Total `756 asserts ALL PASSED`.

---

## Task 5: `MainHud.LoadPosition` con default-position recovery

**Files:**
- Modify: `Lib/MainHud.ahk` (reemplaza body de LoadPosition + agrega helper EnumMonitorsForLayout)

GUI smoke only (LoadPosition se prueba al arrancar la app).

- [ ] **Step 5.1: Agregar helper que recolecta monitores**

En `Lib/MainHud.ahk`, dentro de `class MainHud`, antes de `LoadPosition()`, agregá:

```autohotkey
    ; --- EnumMonitorsForLayout: itera todos los monitores activos y devuelve
    ;     un Array<Map> con sus work areas. Es la fuente real que LoadPosition
    ;     pasa a HudLayout.IsRectVisibleAgainst (modulo puro).
    EnumMonitorsForLayout()
    {
        out := []
        try
        {
            MonitorGetCount(&count)
            Loop count
            {
                MonitorGetWorkArea(A_Index, &mL, &mT, &mR, &mB)
                out.Push(Map("l", mL, "t", mT, "r", mR, "b", mB))
            }
        }
        catch
        {
            ; Defensivo: si MonitorGetCount/WorkArea fallan, devolver vacio.
            ; IsRectVisibleAgainst con [] retorna false -> caera a centrar.
        }
        return out
    }
```

- [ ] **Step 5.2: Reemplazar `LoadPosition`**

En `Lib/MainHud.ahk`, reemplazar el cuerpo entero de `LoadPosition()`:

```autohotkey
    LoadPosition()
    {
        ; --- Tamanio: respetar lo guardado en INI (defaults si no existe) ---
        this.defaultW := Integer(IniRead(this.iniPath, "Window", "defaultW", 540))
        this.defaultH := Integer(IniRead(this.iniPath, "Window", "defaultH", 460))
        this.lastW    := Integer(IniRead(this.iniPath, "Window", "lastW", this.defaultW))
        this.lastH    := Integer(IniRead(this.iniPath, "Window", "lastH", this.defaultH))

        ; --- Posicion: respetar INI si la ventana es visible en algun monitor;
        ;     sino caer a centrado en monitor primario. ---
        MonitorGetWorkArea(MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
        centerX := mLeft + ((mRight - mLeft) - this.lastW) // 2
        centerY := mTop  + ((mBottom - mTop) - this.lastH) // 2

        monitors := this.EnumMonitorsForLayout()

        ; lastX/Y
        savedLastX := IniRead(this.iniPath, "Window", "lastX", "")
        savedLastY := IniRead(this.iniPath, "Window", "lastY", "")
        if (savedLastX = "" || savedLastY = "")
        {
            this.lastX := centerX
            this.lastY := centerY
        }
        else
        {
            sx := Integer(savedLastX)
            sy := Integer(savedLastY)
            if HudLayout.IsRectVisibleAgainst(sx, sy, this.lastW, this.lastH, monitors)
            {
                this.lastX := sx
                this.lastY := sy
            }
            else
            {
                ; Fallback: el monitor donde estaba guardada la ventana ya
                ; no existe o cambio de tamanio. Centrar en primario.
                this.lastX := centerX
                this.lastY := centerY
            }
        }

        ; defaultX/Y (con misma logica)
        savedDefX := IniRead(this.iniPath, "Window", "defaultX", "")
        savedDefY := IniRead(this.iniPath, "Window", "defaultY", "")
        defCenterX := mLeft + ((mRight - mLeft) - this.defaultW) // 2
        defCenterY := mTop  + ((mBottom - mTop) - this.defaultH) // 2
        if (savedDefX = "" || savedDefY = "")
        {
            this.defaultX := defCenterX
            this.defaultY := defCenterY
        }
        else
        {
            dx := Integer(savedDefX)
            dy := Integer(savedDefY)
            if HudLayout.IsRectVisibleAgainst(dx, dy, this.defaultW, this.defaultH, monitors)
            {
                this.defaultX := dx
                this.defaultY := dy
            }
            else
            {
                this.defaultX := defCenterX
                this.defaultY := defCenterY
            }
        }

        this.templateMode := IniRead(this.iniPath, "Window", "templateMode", "0") = "1"
    }
```

- [ ] **Step 5.3: Validate + smoke**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: validate exit 0, smoke OK. Tests siguen pasando 756.

**Manual test (opcional)**: editar `%AppData%\QuickEntry\layout.ini` poniendo `lastX=-5000` y `lastY=-5000`. Arrancar QuickEntry. La ventana debe aparecer centrada en el monitor primario (no fuera de pantalla).

---

## Task 6: Header — quitar título y counter

**Files:**
- Modify: `Lib/MainHud.ahk` (Build + Update)

- [ ] **Step 6.1: Quitar creación de controles en Build**

En `Lib/MainHud.ahk`, encontrar las líneas en `Build()`:

```autohotkey
        ; --- Title bar ---
        titleLbl := g.Add("Text", "x16 y12 w300 h26", "QUICKENTRY  " this.engine.schema.name)
        titleLbl.SetFont("s11 Bold c" MAINHUD_FG_LABEL, MAINHUD_FONT_LABEL)
        this.titleCounterCtrl := g.Add("Text", "x420 y14 w160 h22 Right c" MAINHUD_FG_DIM, "0/" n)
```

Reemplazar por:

```autohotkey
        ; --- Title bar removido para ganar espacio vertical (Task 6 del plan
        ;     2026-05-10). this.titleCounterCtrl queda como "" (sin control).
        ;     Update() chequea IsObject(this.titleCounterCtrl) antes de usarlo.
```

- [ ] **Step 6.2: Adjustar yPos inicial**

En la misma `Build()`, encontrar:
```autohotkey
        this.rows := []
        yPos := 64
```

Reemplazar por:
```autohotkey
        this.rows := []
        yPos := 12
```

- [ ] **Step 6.3: Guard en Update**

En `Lib/MainHud.ahk` Update(), encontrar (alrededor de línea 470):

```autohotkey
        this.titleCounterCtrl.Value := filled "/" n
```

Reemplazar por:

```autohotkey
        if IsObject(this.titleCounterCtrl)
            this.titleCounterCtrl.Value := filled "/" n
```

- [ ] **Step 6.4: Validate + smoke + tests**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
```

Expected: validate 0, smoke OK, tests 756 ALL PASSED.

**Manual**: arrancar QuickEntry. NO debe verse el texto "QUICKENTRY" arriba ni el "0/9". El slot 1 ("Account number") debe estar a ~12px del top.

---

## Task 7: Footer reorganizado a 3 filas + remoción de Editar/Pegar limpio

**Files:**
- Modify: `Lib/MainHud.ahk` (Build + buttonsById + btnTooltips + RenderMode compact-grid)

Cambio grande pero localizado. **Se hace en pasos chicos**.

- [ ] **Step 7.1: Reescribir bloque de footer en Build**

En `Lib/MainHud.ahk`, encontrar este bloque (footer rows actuales):

```autohotkey
        ; --- Footer Row 1: acciones primarias de captura ---
        footerY := yPos + n * rowH + 16
        btnArm := g.Add("Button", "x16 y" footerY " w90 h32", "▶ Iniciar")
        ; Template toggle: ☐ off / ☑ on. Cuando ON, agrega 1 Tab extra entre
        ; Account # e Invoice date para skipear el campo Template del form.
        templateLbl := this.templateMode ? "☑ Template" : "☐ Template"
        btnTemplateToggle := g.Add("Button", "x110 y" footerY " w110 h32", templateLbl)
        btnScan := g.Add("Button", "x224 y" footerY " w80 h32", "⇣ Scan")
        btnSoltar := g.Add("Button", "x308 y" footerY " w90 h32", "▶▶ Soltar")
        btnReset := g.Add("Button", "x402 y" footerY " w62 h32", "⊘ Reset")
        btnUndo := g.Add("Button", "x468 y" footerY " w62 h32", "↶ Undo")

        ; --- Footer Row 2: secundarios + config icons ---
        footerY2 := footerY + 40
        btnLoadLast := g.Add("Button", "x16 y" footerY2 " w110 h32", "↻ Load Last")
        btnManual := g.Add("Button", "x132 y" footerY2 " w100 h32", "⌨ Editar")
        btnPegEsp := g.Add("Button", "x238 y" footerY2 " w130 h32", "📋 Pegar limpio")
        btnCalc := g.Add("Button", "x374 y" footerY2 " w80 h32", "Σ Calc")

        btnSetDefault := g.Add("Button", "x548 y" footerY2 " w32 h32", "⊙")

        windowH := footerY2 + 48
```

Reemplazar por:

```autohotkey
        ; --- Footer rows (3 filas) ---
        ;   Row 1: Template | Scan | Pegar
        ;   Row 2: Iniciar/Omitir | Undo | Reset
        ;   Row 3: ⊙ default | Load Last | Σ Calc
        ; Botones removidos: ⌨ Editar y 📋 Pegar limpio (los hotkeys ^+e y ^+v
        ; siguen funcionando desde QuickEntry.ahk).
        footerY  := yPos + n * rowH + 16              ; Row 1
        footerY2 := footerY + 40                       ; Row 2
        footerY3 := footerY2 + 40                      ; Row 3

        ; Row 1
        templateLbl := this.templateMode ? "☑ Template" : "☐ Template"
        btnTemplateToggle := g.Add("Button", "x16 y" footerY " w110 h32", templateLbl)
        btnScan           := g.Add("Button", "x130 y" footerY " w90 h32",  "⇣ Scan")
        btnSoltar         := g.Add("Button", "x224 y" footerY " w90 h32",  "▶▶ Pegar")

        ; Row 2
        btnArm   := g.Add("Button", "x16 y" footerY2 " w90 h32",  "▶ Iniciar")
        btnUndo  := g.Add("Button", "x110 y" footerY2 " w90 h32", "↶ Undo")
        btnReset := g.Add("Button", "x204 y" footerY2 " w90 h32", "⊘ Reset")

        ; Row 3
        btnSetDefault := g.Add("Button", "x16 y" footerY3 " w32 h32",  "⊙")
        btnLoadLast   := g.Add("Button", "x52 y" footerY3 " w110 h32", "↻ Load Last")
        btnCalc       := g.Add("Button", "x166 y" footerY3 " w80 h32", "Σ Calc")

        windowH := footerY3 + 48
```

- [ ] **Step 7.2: Eliminar wirings de Manual y PegEsp**

En el mismo Build, encontrar:

```autohotkey
        btnManual.OnEvent("Click", (*) => this.OpenInlineEditOnCurrentSlot())
        btnPegEsp.OnEvent("Click", (*) => DoPegadoEspecial(true))
```

Eliminar estas 2 líneas (los hotkeys `^+e` y `^+v` en `QuickEntry.ahk` siguen vivos, así que la funcionalidad sigue accesible).

- [ ] **Step 7.3: Actualizar `buttonsById` Map**

Encontrar:

```autohotkey
        this.buttonsById := Map(
            "start", btnArm,
            "templateOff", btnTemplateToggle,
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

Reemplazar por:

```autohotkey
        this.buttonsById := Map(
            "start", btnArm,
            "templateOff", btnTemplateToggle,
            "scan", btnScan,
            "release", btnSoltar,
            "reset", btnReset,
            "undo", btnUndo,
            "loadLast", btnLoadLast,
            "autocalc", btnCalc,
            "setDefault", btnSetDefault
        )
```

(Removidos: `"manual"` y `"pegEsp"`.)

- [ ] **Step 7.4: Actualizar `btnTooltips` Map**

Encontrar el bloque:

```autohotkey
        this.btnTooltips := Map(
            btnArm.Hwnd, "Iniciar captura / Omitir slot actual (^+a)",
            btnTemplateToggle.Hwnd, "Toggle: si Asignet muestra el campo 'Template' entre Account # e Invoice date, activa esto. Persiste entre sesiones.",
            btnScan.Hwnd, "HeaderScan: pide click en selector de Type, pregunta por template, lee form (^+h sin prompt)",
            btnSoltar.Hwnd, "Soltar: pide click en form, despues pega todos los valores (^+s sin prompt)",
            btnReset.Hwnd, "Cancelar captura / Freno paste/scan en curso (^+r)",
            btnUndo.Hwnd, "Descartar el ultimo valor cargado (^+u)",
            btnLoadLast.Hwnd, "Cargar la ultima cola pegada",
            btnManual.Hwnd, "Editar inline el slot actual (mismo que click en el valor) (^+e)",
            btnPegEsp.Hwnd, "Pegado especial: limpia + pega clipboard actual (^+v)",
            btnCalc.Hwnd, "AutoCalculator: pega numeros y muestra suma",
            btnSetDefault.Hwnd, "Marcar posicion actual como default"
        )
```

Reemplazar por:

```autohotkey
        this.btnTooltips := Map(
            btnArm.Hwnd, "Iniciar captura / Omitir slot actual (^+a)",
            btnTemplateToggle.Hwnd, "Toggle: si Asignet muestra el campo 'Template' entre Account # e Invoice date, activa esto. Persiste entre sesiones.",
            btnScan.Hwnd, "HeaderScan: pide click en selector de Type, pregunta por template, lee form (^+h sin prompt)",
            btnSoltar.Hwnd, "Pegar: pide click en form, despues pega todos los valores (^+s sin prompt)",
            btnReset.Hwnd, "Cancelar captura / Freno paste/scan en curso (^+r)",
            btnUndo.Hwnd, "Descartar el ultimo valor cargado (^+u)",
            btnLoadLast.Hwnd, "Cargar la ultima cola pegada",
            btnCalc.Hwnd, "AutoCalculator: pega numeros y muestra suma",
            btnSetDefault.Hwnd, "Marcar posicion actual como default"
        )
```

(Removidas las 2 entradas de `btnManual` y `btnPegEsp`. Texto del tooltip de `btnSoltar` actualizado: "Soltar" → "Pegar".)

- [ ] **Step 7.5: Actualizar compact-grid en RenderMode**

En `Lib/MainHud.ahk`, encontrar el bloque dentro de `RenderMode(mode)` que itera los IDs para compact (alrededor de línea 365-395). Hay un `footerWidths` Map con 11 entries y dos loops (`for id in [..]`) que asumen las dos rows con esos IDs. Hay que actualizarlos para 3 rows y 9 botones.

Encontrar:

```autohotkey
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

Reemplazar TODO ese bloque por:

```autohotkey
        if isCompact
        {
            footerWidths := Map(
                "templateOff", 36, "scan", 36, "release", 36,
                "start", 36, "undo", 36, "reset", 36,
                "setDefault", 32, "loadLast", 36, "autocalc", 36
            )
            ; Row 1 compact: Template | Scan | Pegar
            x1 := 16
            for id in ["templateOff", "scan", "release"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x1, , w)
                x1 += w + 4
            }
            ; Row 2 compact: Iniciar/Omitir | Undo | Reset
            x2 := 16
            for id in ["start", "undo", "reset"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x2, , w)
                x2 += w + 4
            }
            ; Row 3 compact: ⊙ default | Load Last | Σ Calc
            x3 := 16
            for id in ["setDefault", "loadLast", "autocalc"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x3, , w)
                x3 += w + 4
            }
        }
        else
        {
            ; Normal mode: posiciones originales de las 3 filas (Task 7).
            normalLayout := Map(
                "templateOff", Map("x", 16,  "w", 110),
                "scan",        Map("x", 130, "w", 90),
                "release",     Map("x", 224, "w", 90),
                "start",       Map("x", 16,  "w", 90),
                "undo",        Map("x", 110, "w", 90),
                "reset",       Map("x", 204, "w", 90),
                "setDefault",  Map("x", 16,  "w", 32),
                "loadLast",    Map("x", 52,  "w", 110),
                "autocalc",    Map("x", 166, "w", 80)
            )
            for id, pos in normalLayout
                this.buttonsById[id].Move(pos["x"], , pos["w"])
        }
```

- [ ] **Step 7.6: Validate + smoke + tests**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
```

Expected: validate 0, smoke OK, tests 756 ALL PASSED.

**Manual**:
- Arrancar QuickEntry: ver 3 filas de botones, sin "Editar" ni "Pegar limpio", `⊙` abajo a la izquierda en Row 3, "Soltar" renombrado a "Pegar".
- `Ctrl+Shift+E` debe abrir inline edit (hotkey sigue).
- `Ctrl+Shift+V` debe disparar pegado especial (hotkey sigue).

---

## Task 8: Inline edit empty-commit → ClearSlot

**Files:**
- Modify: `Lib/MainHud.ahk` (OnInlineEditCommit branch)

- [ ] **Step 8.1: Modificar `OnInlineEditCommit`**

En `Lib/MainHud.ahk`, encontrar el método `OnInlineEditCommit()`. La sección crítica:

```autohotkey
        this.inlineEditCommitting := true
        try
        {
            val := this.inlineEditCtrl.Value
            slot := this.inlineEditSlot

            this.engine.JumpTo(slot)
            res := this.engine.PushManual(val)

            this.CloseInlineEdit()

            if !res["ok"]
            {
                ; Valor rechazado por validacion: NO descartamos. Guardamos
                ; el typed value en pendingInvalidValue del row. Update() lo
                ; renderiza en amber + muestra "!" rojo + boton ✓ a la izquierda
                ; del iconCtrl para que el usuario pueda forzar el commit.
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := val
                this.Update()
            }
            else
            {
                ; Push valido: limpiar pendingInvalidValue del slot si lo tenia.
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := ""
                this.Update()
            }
        }
        finally
        {
            this.inlineEditCommitting := false
        }
```

Reemplazar por:

```autohotkey
        this.inlineEditCommitting := true
        try
        {
            val := this.inlineEditCtrl.Value
            slot := this.inlineEditSlot

            ; Caso especial: usuario borro el contenido y commitea (Enter /
            ; LoseFocus / click afuera). Tratamos como "clear slot" — NO
            ; pasamos por PushManual (que dispararia ValidarNoVacio y mostraria
            ; el "!" rojo). El slot queda vacio limpio.
            if (Trim(val) = "")
            {
                this.engine.ClearSlot(slot)
                this.CloseInlineEdit()
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := ""
                this.Update()
                return
            }

            this.engine.JumpTo(slot)
            res := this.engine.PushManual(val)

            this.CloseInlineEdit()

            if !res["ok"]
            {
                ; Valor rechazado por validacion: NO descartamos. Guardamos
                ; el typed value en pendingInvalidValue del row. Update() lo
                ; renderiza en amber + muestra "!" rojo + boton ✓ a la izquierda
                ; del iconCtrl para que el usuario pueda forzar el commit.
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := val
                this.Update()
            }
            else
            {
                ; Push valido: limpiar pendingInvalidValue del slot si lo tenia.
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := ""
                this.Update()
            }
        }
        finally
        {
            this.inlineEditCommitting := false
        }
```

- [ ] **Step 8.2: Validate + smoke + tests**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
```

Expected: validate 0, smoke OK, tests 756 ALL PASSED.

**Manual**:
1. Arrancar QuickEntry. Cargar (vía Scan o tipear) un valor en slot 1.
2. Click en el valor del slot 1 → abre inline edit.
3. Borrar todo (Ctrl+A, Delete). El Edit queda vacío.
4. Presionar Enter → el slot 1 queda vacío visualmente, sin `!` rojo, sin pendingInvalid.
5. Repetir: click en valor, borrar, click EN OTRO SLOT (afuera del Edit) → mismo resultado.
6. Repetir: click en valor, borrar, click FUERA de la ventana de QuickEntry → mismo resultado.
7. Probar `Ctrl+Shift+U` (Undo) después de clear → debe restaurar el valor anterior.

---

## Task 9: Final integration smoke

**Files:** ninguno (solo verificación)

- [ ] **Step 9.1: Run full pipeline**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk"
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\Tests\runner.ps1"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Fing\QuickEntry-quickestEntry\QuickEntry-quickestEntry\QuickEntry.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: validate 0, tests 756 ALL PASSED, smoke OK.

- [ ] **Step 9.2: Checklist manual**

Arrancar QuickEntry (no matar el proceso esta vez). Probar:

- [ ] NO se ve "QUICKENTRY Asignet 0/9" arriba (Task 6).
- [ ] Slot 1 ("Account number") está a ~12px del top.
- [ ] Footer tiene **3 filas** (Task 7):
  - Row 1: Template | Scan | Pegar
  - Row 2: Iniciar (o Omitir) | Undo | Reset
  - Row 3: ⊙ | Load Last | Σ Calc
- [ ] NO existen botones "Editar" ni "Pegar limpio" en el footer.
- [ ] El botón "Soltar" se llama "Pegar".
- [ ] Hover en "Pegar" muestra tooltip "Pegar: pide click en form...".
- [ ] `Ctrl+Shift+E` abre inline edit (hotkey sigue activo).
- [ ] `Ctrl+Shift+V` dispara pegado especial (hotkey sigue activo).
- [ ] Click en cualquier valor → abre inline edit. Borrar todo el contenido → presionar Enter → el slot queda **vacío sin `!` rojo** (Task 8).
- [ ] Hacer Scan sobre un form con campos vacíos → los slots correspondientes quedan **vacíos en el GUI**, no muestran el "último del clipboard" (Task 3).
- [ ] Arrastrar la ventana a una posición rara, cerrar (X). Borrar/editar `%AppData%\QuickEntry\layout.ini` poniendo `lastX=-9999`. Reabrir QuickEntry → la ventana aparece centrada (no off-screen) (Task 5).
- [ ] Click en `⊙` (Row 3, esquina inferior izquierda) → tooltip "Posicion + tamanio default actualizados".

---

## Final assert tally

| Test file | Asserts antes | Asserts después | Delta |
|---|---|---|---|
| Test_HudLayout | 41 | 47 | +6 (IsRectVisibleAgainst) |
| Test_CaptureEngine | 210 | 218 | +8 (5 ClearSlot + 3 Scan empty) |
| Test_AsignetHeader | 140 | 140 | 0 |
| Test_Cleaners | 184 | 184 | 0 |
| Test_Schema | 35 | 35 | 0 |
| Test_TooltipFormatter | 77 | 77 | 0 |
| Test_Validators | 55 | 55 | 0 |
| **Total** | **742** | **756** | **+14** |

---

## Self-Review

### Spec coverage

| Sección spec | Task |
|---|---|
| 2.1 Header removal | Task 6 |
| 2.2 Footer 3 filas + remoción Editar/PegEsp + rename "Soltar"→"Pegar" | Tasks 1, 7 |
| 2.3 Default-position recovery | Tasks 4 (helper), 5 (LoadPosition) |
| 2.4 Inline edit empty-commit | Tasks 2 (ClearSlot), 8 (OnInlineEditCommit) |
| 2.5 Scan empty val | Task 3 |

Cobertura completa.

### Placeholders

- No hay TBD, TODO, "fill in", "implement later" en el plan.
- `; TODO` que aparece en código generado son **anchors intencionales** (no aplica acá: ninguno usado).

### Type consistency

- `IsRectVisibleAgainst(x, y, w, h, monitorsArray)` definida en Task 4, usada en Task 5. ✓
- `EnumMonitorsForLayout()` definida en Task 5.1, usada en Task 5.2. ✓
- `ClearSlot(slot)` definida en Task 2, usada en Task 8. ✓
- `buttonsById` Map IDs (sin `manual`, `pegEsp`) consistentes entre Task 7 (Build), Task 7.5 (RenderMode compact-grid), Task 7.5 (RenderMode normal).
- `HudLayout.LabelForButton("release", ...)` retorna "▶▶ Pegar"/"▶▶" (Task 1). Compatible con btnSoltar mostrado por Build inicial ("▶▶ Pegar") y por RenderMode al cambiar de modo.

### Orden de Tasks (por qué este orden)

1. Task 1 (HudLayout rename) — primero porque cambia label canónica que el resto usa.
2. Tasks 2, 3 (CaptureEngine ClearSlot + Scan empty) — módulos puros, TDD seguro antes de tocar GUI.
3. Task 4 (HudLayout IsRectVisibleAgainst) — helper puro requerido por Task 5.
4. Task 5 (LoadPosition) — depende de Task 4. GUI smoke.
5. Task 6 (Header removal) — independiente del resto, hace antes que Task 7 para tener la y=12 disponible.
6. Task 7 (Footer 3 filas) — el cambio más invasivo, después de que header esté limpio.
7. Task 8 (OnInlineEditCommit empty) — depende de Task 2 (ClearSlot).
8. Task 9 — checklist final.

### Riesgos finales

- **Task 7.5 RenderMode**: el `normalLayout` Map nuevo usa anchos de 90 para los 3 botones del Row 2. Si quedan visualmente cortados en compact, ajustar (Task 7.6 manual visual).
- **Task 5**: `MonitorGetCount(&count)` y `MonitorGetWorkArea(idx, ...)` pueden tirar en setups muy raros. El try/catch en `EnumMonitorsForLayout` lo protege devolviendo `[]`, que cae a centrar. ✓
- **Task 8 `Trim(val) = ""`**: si el usuario tipea solo espacios y commitea, también limpia. Eso es razonable: la validación lo rechazaría igualmente.
- **Task 3 caso `val != "" && limpio = ""`** (cleaner descarta): NO sobrescribimos slot. Documentado en spec sec 2.5 y en el snippet.
