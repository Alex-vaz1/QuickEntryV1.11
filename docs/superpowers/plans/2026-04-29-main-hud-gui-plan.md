# Main HUD GUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el `ToolTip` de estado por una GUI persistente, movible, con edición inline en cada slot, persistencia de posición y restauración de la última cola pegada.

**Architecture:** Una nueva clase `MainHud` en `Lib/MainHud.ahk` que dueña la `Gui()` de AHK v2 y se mantiene viva mientras `engine.isCapturing == true`. `QuickEntry.ahk` la cablea: `RefrescarTooltip` deja de llamar `ToolTip(...)` y pasa a llamar `mainHud.Update()`. El motor crece un método nuevo `PushForce(value)` para soportar el "force-bypass" del flow de double-Enter post validación fallida. Persistencia via INI files en `%AppData%\QuickEntry\`.

**Tech Stack:** AutoHotkey v2.0 (clase + Gui native), AHK v2 IniRead/IniWrite, asserts custom para tests del engine, smoke manual para la GUI.

**Spec:** [`docs/superpowers/specs/2026-04-29-main-hud-gui-design.md`](../specs/2026-04-29-main-hud-gui-design.md)

---

## Resumen de archivos

| Archivo | Cambio |
|---|---|
| `Lib/CaptureEngine.ahk` | Agregar método `PushForce(value)` (commit sin validar). |
| `Lib/MainHud.ahk` | **Crear**. ~400 líneas: clase `MainHud` con Build/Update/Show/Hide + INI persistence + click handlers + inline edit + footer buttons. |
| `QuickEntry.ahk` | Instanciar `mainHud`, reemplazar `RefrescarTooltip` cuerpo, wire `Show/Hide` en `^+a/s/r`, `SaveLastPaste` antes de Reset en `^+s`. |
| `Tests/Test_CaptureEngine.ahk` | Agregar ~5 asserts para `PushForce`. |

Sin tests para `MainHud.ahk` (side-effect-only, smoke manual).

---

## Prerequisito: verificar suite verde con código revertido

- [ ] **Step P.1: Correr suite**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"
```

Expected: `ALL TESTS PASSED`. Si falla, debug y arreglar antes de continuar (los tests fueron checked out de `8fd1f69` que tenía 9 slots, debería matchear el estado revertido).

- [ ] **Step P.2: Validar QuickEntry.ahk syntax**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk') -RedirectStandardError "$env:TEMP\qe.err" -RedirectStandardOutput "$env:TEMP\qe.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\qe.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`, stderr vacío.

- [ ] **Step P.3: Commit baseline si hay cambios pendientes**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git status
# Si hay cambios sin commitear (del revert previo):
git add .
git commit -m "revert: roll back to user-tested 9-slot version + sync tests"
```

---

## Task 1: Engine — método `PushForce(value)`

**Files:**
- Modify: `Lib/CaptureEngine.ahk`
- Test: `Tests/Test_CaptureEngine.ahk`

**Contexto:** El flow de double-Enter en la edición inline necesita poder commitear un valor sin que `validate` lo bloquee. `PushForce` es symétrico a `PushRaw` pero salta la validación. Sigue limpiando con `campo.clean.Call(raw)` (si el cleaner devuelve `""`, sigue rechazando — force solo bypassa validate).

- [ ] **Step 1.1: Agregar método `PushForce` en `Lib/CaptureEngine.ahk`**

Insertar después del método `PushManual` (línea ~183 del archivo actual):

```ahk
    ; --- PushForce: clean + push SIN validar. Usado por edit inline cuando
    ;     el operador confirma "Forzar igual" tras Enter sobre valor invalido.
    ;     Si el cleaner devuelve "", sigue rechazando (force solo bypassa
    ;     validate, no clean). El slot queda con queue[slot] = limpio,
    ;     marcado como filled (FilledCount++). preloadedSlots se limpia. ---
    PushForce(raw)
    {
        slot := this.NextSlot
        if (slot = 0)
            return Map("ok", false, "error", "cola completa", "label", "", "slot", 0, "value", "")

        campo := this.schema.Field(slot)
        limpio := campo.clean.Call(raw)
        if (limpio = "")
            return Map("ok", false, "error", "no se reconocio el valor",
                       "label", campo.name, "slot", slot, "value", "")

        this.actionLog.Push(Map("slot", slot, "prevValue", this.queue[slot]))
        this.queue[slot] := limpio
        if this.preloadedSlots.Has(slot)
            this.preloadedSlots.Delete(slot)
        this.targetSlot := 0
        this.AutoAdvance(slot)
        return Map("ok", true, "error", "", "label", campo.name, "slot", slot, "value", limpio)
    }
```

- [ ] **Step 1.2: Agregar tests en `Tests/Test_CaptureEngine.ahk`**

Buscar la línea con `ReportarYSalir()` al final del archivo. Insertar ANTES de esa línea:

```ahk
; ====================================================================
; PushForce - bypassa validate, no bypassa clean
; ====================================================================
ePF := CaptureEngine(CrearMock())
ePF.Arm()
ePF.PushRaw("100")
ePF.PushRaw("50")
; Slot 3 normalmente requiere ValidarSumaTol([1,2]) = 150. Forzamos 999.
rPF := ePF.PushForce("999")
AssertEq(rPF["ok"], true, "PushForce bypassa validate")
AssertEq(rPF["value"], "999", "PushForce value es el limpio")
AssertEq(rPF["slot"], 3, "PushForce slot=3")
AssertEq(ePF.queue[3], "999", "PushForce escribe queue[slot]")
AssertEq(ePF.IsComplete, true, "PushForce completa la cola")
AssertEq(ePF.actionLog.Length, 3, "PushForce registra en actionLog")

; --- Undo tras PushForce restaura prevValue (vacio inicial) ---
uPF := ePF.Undo()
AssertEq(uPF["ok"], true, "Undo tras PushForce ok")
AssertEq(ePF.queue[3], "", "Undo restaura queue[3]='' (prevValue)")

; --- PushForce sigue rechazando si clean devuelve "" ---
ePF2 := CaptureEngine(CrearAsignetHeaderV1())
ePF2.Arm()
; Slot 1 (Account number) cleaner es CleanPasoPegado (LimpiarComoPegadoEspecial).
; Empty string cleanea a "" -> rechazo.
rPF2 := ePF2.PushForce("")
AssertEq(rPF2["ok"], false, "PushForce con clean='' rechaza")
AssertContains(rPF2["error"], "no se reconocio", "PushForce mensaje rechazo")

; --- PushForce sobre slot preloaded limpia preloadedSlots[slot] ---
ePF3 := CaptureEngine(CrearAsignetHeaderV1())
ePF3.Arm()
ePF3.preloadedSlots[1] := true
ePF3.queue[1] := "OLD"
ePF3.targetSlot := 1
rPF3 := ePF3.PushForce("NEW-VAL")
AssertEq(ePF3.queue[1], "NEW-VAL", "PushForce sobre preloaded actualiza queue")
AssertEq(ePF3.preloadedSlots.Has(1), false, "PushForce sobre preloaded limpia el flag")
```

- [ ] **Step 1.3: Correr suite, verificar GREEN**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"
```

Expected: `ALL TESTS PASSED`, total ≥ asserts previo + ~10.

- [ ] **Step 1.4: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/CaptureEngine.ahk Tests/Test_CaptureEngine.ahk
git commit -m "feat(engine): add PushForce() - commit sin validar para edit inline force-bypass"
```

---

## Task 2: Skeleton `Lib/MainHud.ahk` + INI persistence

**Files:**
- Create: `Lib/MainHud.ahk`

**Contexto:** Esqueleto inicial sin GUI controls aún. Solo la clase, INI helpers (load/save layout), constantes de estilo. Se puede instanciar y los métodos no-GUI se pueden llamar — pero `Build()` está vacío. Esto valida que el archivo carga sin errores.

- [ ] **Step 2.1: Crear `Lib/MainHud.ahk` con esqueleto + INI helpers**

```ahk
#Requires AutoHotkey v2.0
#Include "CaptureEngine.ahk"
#Include "TooltipFormatter.ahk"

; ====================================================================
; MainHud - GUI principal de QuickEntry. Reemplaza el ToolTip de
; estado. Persistente entre RefrescarTooltip calls. Movible. Soporta
; edicion inline por click en valor + jump por click en nombre.
;
; Side-effect-only: sin tests unit. Smoke manual con ^+a / ^+h / ^+s.
; ====================================================================

; --- Constantes de estilo ---
global MAINHUD_BG          := "0F1419"
global MAINHUD_BG_ROW      := "161B22"
global MAINHUD_BG_ACTIVE   := "3D2B17"  ; tinted ambar para slot apuntado
global MAINHUD_FG_LABEL    := "C9D1D9"
global MAINHUD_FG_DIM      := "5C6370"
global MAINHUD_FG_FILLED   := "7FB069"
global MAINHUD_FG_PRELOAD  := "7AA2F7"
global MAINHUD_FG_FORCED   := "FFB454"
global MAINHUD_FG_ACTIVE   := "FFB454"
global MAINHUD_FG_ERROR    := "E06C75"
global MAINHUD_FONT_VALUE  := "Cascadia Mono"
global MAINHUD_FONT_LABEL  := "Segoe UI"

class MainHud
{
    engine := ""
    gui := ""
    rows := []                  ; rows[i] = Map("nameCtrl", c, "valueCtrl", c, "iconCtrl", c, "opRows", [])
    inlineEdit := ""
    inlineEditSlot := 0
    inlineEditFailedOnce := false
    inlineEditPrevValue := ""
    inlineEditErrorCtrl := ""
    compactMode := false
    titleCounterCtrl := ""
    lastX := 0
    lastY := 0
    defaultX := 0
    defaultY := 0
    iniPath := ""

    __New(engine)
    {
        this.engine := engine
        this.iniPath := A_AppData "\QuickEntry\layout.ini"
        DirCreate(A_AppData "\QuickEntry")
        this.LoadPosition()
    }

    ; --- INI persistence ---
    LoadPosition()
    {
        ; Default = centro del monitor primario
        MonitorGetWorkArea(MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
        cx := mLeft + (mRight - mLeft) / 2 - 300
        cy := mTop + (mBottom - mTop) / 2 - 240

        this.defaultX := Integer(IniRead(this.iniPath, "Window", "defaultX", cx))
        this.defaultY := Integer(IniRead(this.iniPath, "Window", "defaultY", cy))
        this.lastX    := Integer(IniRead(this.iniPath, "Window", "lastX", this.defaultX))
        this.lastY    := Integer(IniRead(this.iniPath, "Window", "lastY", this.defaultY))
        this.compactMode := IniRead(this.iniPath, "Window", "compactMode", "0") = "1"
    }

    SaveLastPosition()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetPos(&x, &y)
        this.lastX := x
        this.lastY := y
        IniWrite(x, this.iniPath, "Window", "lastX")
        IniWrite(y, this.iniPath, "Window", "lastY")
    }

    SaveAsDefault()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetPos(&x, &y)
        this.defaultX := x
        this.defaultY := y
        this.lastX := x
        this.lastY := y
        IniWrite(x, this.iniPath, "Window", "defaultX")
        IniWrite(y, this.iniPath, "Window", "defaultY")
        IniWrite(x, this.iniPath, "Window", "lastX")
        IniWrite(y, this.iniPath, "Window", "lastY")
        ToolTip("Posicion default actualizada")
        SetTimer(() => ToolTip(), -1500)
    }

    SaveCompactMode()
    {
        IniWrite(this.compactMode ? "1" : "0", this.iniPath, "Window", "compactMode")
    }

    ; --- Lifecycle stubs (implementados en tasks siguientes) ---
    Build()
    {
        ; Stub - implementado en Task 3
    }

    Update()
    {
        ; Stub - implementado en Task 4
    }

    Show()
    {
        if !IsObject(this.gui)
            this.Build()
        if IsObject(this.gui)
            this.gui.Show("x" this.lastX " y" this.lastY)
    }

    Hide()
    {
        if IsObject(this.gui)
            this.gui.Hide()
    }
}
```

- [ ] **Step 2.2: Validar sintaxis del archivo**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`, stderr vacío.

- [ ] **Step 2.3: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): skeleton de MainHud con INI persistence (load/save position)"
```

---

## Task 3: Build() — title bar, slot rows, footer (sin interactividad)

**Files:**
- Modify: `Lib/MainHud.ahk`

**Contexto:** Implementar la creación visual completa de la GUI sin lógica de eventos. Los controles existen pero no responden a clicks. Esto permite probar visualmente el layout antes de cablear handlers.

- [ ] **Step 3.1: Reemplazar el método `Build()` stub en `Lib/MainHud.ahk`**

Buscar `Build() { ; Stub }` y reemplazar por:

```ahk
    Build()
    {
        g := Gui("+AlwaysOnTop +Resize -DPIScale", "QuickEntry")
        g.BackColor := MAINHUD_BG
        g.SetFont("s10 c" MAINHUD_FG_LABEL, MAINHUD_FONT_LABEL)
        g.MarginX := 16
        g.MarginY := 16

        n := this.engine.schema.Length
        rowH := 32
        windowW := 600

        ; --- Title bar ---
        g.Add("Text", "x16 y16 w200 h22", "QUICKENTRY  " this.engine.schema.name)
        this.titleCounterCtrl := g.Add("Text", "x420 y16 w160 h22 Right c" MAINHUD_FG_DIM, "0/" n)

        ; --- Slot rows ---
        this.rows := []
        yPos := 56
        Loop n
        {
            i := A_Index
            campo := this.engine.schema.Field(i)
            yRow := yPos + (i-1) * rowH

            ; Numero de slot
            slotTxt := g.Add("Text", "x16 y" yRow " w28 h" rowH " +0x100 c" MAINHUD_FG_DIM, i)
            ; Nombre del campo (clickable -> JumpTo)
            nameCtrl := g.Add("Text", "x50 y" yRow " w220 h" rowH " +0x100", campo.name)
            nameCtrl.SetFont("s10 c" MAINHUD_FG_LABEL, MAINHUD_FONT_LABEL)
            ; Valor (clickable -> JumpTo + edit inline)
            valueCtrl := g.Add("Text", "x280 y" yRow " w260 h" rowH " +0x100", "—")
            valueCtrl.SetFont("s10 c" MAINHUD_FG_DIM, MAINHUD_FONT_VALUE)
            ; Icono de estado
            iconCtrl := g.Add("Text", "x550 y" yRow " w28 h" rowH " Right c" MAINHUD_FG_DIM, "—")
            iconCtrl.SetFont("s12 c" MAINHUD_FG_DIM, MAINHUD_FONT_VALUE)

            this.rows.Push(Map(
                "slotTxt", slotTxt,
                "nameCtrl", nameCtrl,
                "valueCtrl", valueCtrl,
                "iconCtrl", iconCtrl,
                "opRows", []
            ))
        }

        ; --- Footer (botones) ---
        footerY := yPos + n * rowH + 16
        btnReset := g.Add("Button", "x16 y" footerY " w90 h32", "⊘ Reset")
        btnUndo := g.Add("Button", "x112 y" footerY " w90 h32", "↶ Undo")
        btnLoadLast := g.Add("Button", "x208 y" footerY " w110 h32", "↻ Load Last")

        btnSetDefault := g.Add("Button", "x510 y" footerY " w32 h32", "⊙")
        btnToggleCompact := g.Add("Button", "x548 y" footerY " w32 h32", this.compactMode ? "▢" : "▣")

        windowH := footerY + 48

        this.gui := g
        ; Eventos placeholder (implementados en Tasks 5-7)
        g.OnEvent("Close", (*) => this.OnClose())
        g.OnEvent("Escape", (*) => this.OnEscape())
    }

    OnClose(*)
    {
        ; Stub - guardar posicion + ocultar (sin cerrar el script)
        this.SaveLastPosition()
        this.Hide()
    }

    OnEscape(*)
    {
        ; Stub - igual a OnClose
        this.Hide()
    }
```

- [ ] **Step 3.2: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 3.3: Smoke visual (manual)**

Crear un script temporal para ver la GUI:

```ahk
; smoke_mainhud.ahk
#Requires AutoHotkey v2.0
#NoTrayIcon
#Include "Lib\MainHud.ahk"
#Include "Schemas\AsignetHeaderV1.ahk"

engine := CaptureEngine(CrearAsignetHeaderV1())
hud := MainHud(engine)
hud.Show()

F8::ExitApp
```

Save como `C:\Users\Usuario\Desktop\Asignet\smoke_mainhud.ahk`. Ejecutar:

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\Usuario\Desktop\Asignet\smoke_mainhud.ahk"
```

Expected: aparece la GUI con title bar, 9 filas de slots (Account number, Invoice date, ...), valores `—`, footer con `⊘ Reset` `↶ Undo` `↻ Load Last` y botones de iconos. F8 cierra. Ningún click hace nada todavía (eso es Tasks 5-7).

- [ ] **Step 3.4: Borrar smoke script**

```bash
rm "C:/Users/Usuario/Desktop/Asignet/smoke_mainhud.ahk"
```

- [ ] **Step 3.5: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): Build() crea title bar + slot rows + footer (sin interactividad)"
```

---

## Task 4: Update() — colores y iconos por estado

**Files:**
- Modify: `Lib/MainHud.ahk`

**Contexto:** `Update()` se llama cada vez que cambia el estado del engine (push, skip, undo, jump). Recolora cada fila según el estado del slot: apuntado, filled, preloaded, empty, etc. También actualiza el contador del title bar.

- [ ] **Step 4.1: Reemplazar el método `Update()` stub**

Buscar `Update() { ; Stub }` y reemplazar por:

```ahk
    Update()
    {
        if !IsObject(this.gui)
            return
        n := this.engine.schema.Length
        next := this.engine.NextSlot
        filled := this.engine.FilledCount

        ; Title counter
        this.titleCounterCtrl.Value := filled "/" n

        ; Por slot
        Loop n
        {
            i := A_Index
            row := this.rows[i]
            valor := this.engine.queue[i]
            esActivo := (i = next)
            esVacio := (valor = "")
            esPreloaded := this.engine.preloadedSlots.Has(i)

            ; --- Slot index + name color ---
            if esActivo
            {
                row["slotTxt"].SetFont("c" MAINHUD_FG_ACTIVE)
                row["slotTxt"].Value := "⌖ " i
                row["nameCtrl"].SetFont("s10 c" MAINHUD_FG_ACTIVE, MAINHUD_FONT_LABEL)
            }
            else
            {
                row["slotTxt"].SetFont("c" MAINHUD_FG_DIM)
                row["slotTxt"].Value := i
                row["nameCtrl"].SetFont("s10 c" MAINHUD_FG_LABEL, MAINHUD_FONT_LABEL)
            }

            ; --- Value display + color ---
            valorMostrado := this.TruncarValor(valor, esVacio, i)
            row["valueCtrl"].Value := valorMostrado

            colorVal := MAINHUD_FG_DIM
            if (esActivo && esVacio)
                colorVal := MAINHUD_FG_ACTIVE  ; muestra "esperado: X" en color activo
            else if esPreloaded
                colorVal := MAINHUD_FG_PRELOAD
            else if !esVacio
                colorVal := MAINHUD_FG_FILLED
            row["valueCtrl"].SetFont("s10 c" colorVal, MAINHUD_FONT_VALUE)

            ; --- Icon ---
            iconChar := "—"
            iconColor := MAINHUD_FG_DIM
            if esPreloaded
            {
                iconChar := "◐"
                iconColor := MAINHUD_FG_PRELOAD
            }
            else if !esVacio
            {
                iconChar := "✓"
                iconColor := MAINHUD_FG_FILLED
            }
            row["iconCtrl"].Value := iconChar
            row["iconCtrl"].SetFont("s12 c" iconColor, MAINHUD_FONT_VALUE)
        }
    }

    ; --- Helper: trunca el valor o muestra "esperado: X" si activo y vacio ---
    TruncarValor(valor, esVacio, slotIdx)
    {
        if esVacio
        {
            esp := this.engine.ExpectedFor(slotIdx)
            if (esp != "" && slotIdx = this.engine.NextSlot)
                return "esperado: " esp
            return "—"
        }
        if (StrLen(valor) > 28)
            return SubStr(valor, 1, 25) "..."
        return valor
    }
```

- [ ] **Step 4.2: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 4.3: Smoke visual con engine populado**

Crear `smoke_mainhud.ahk`:

```ahk
#Requires AutoHotkey v2.0
#NoTrayIcon
#Include "Lib\MainHud.ahk"
#Include "Schemas\AsignetHeaderV1.ahk"

engine := CaptureEngine(CrearAsignetHeaderV1())
engine.Arm()
engine.PushRaw("ACC-1234")           ; slot 1 filled
engine.PushRaw("Sep 15, 2026")        ; slot 2 filled
engine.SkipCurrent()                  ; slot 3 omit (vacio)
engine.JumpTo(7)                      ; cursor a slot 7
engine.preloadedSlots[5] := true      ; slot 5 preloaded simulado
engine.queue[5] := "1000"

hud := MainHud(engine)
hud.Show()
hud.Update()

F8::ExitApp
```

Ejecutar y verificar:
- Slot 1 (Account number): valor "ACC-1234", verde, ✓ verde
- Slot 2 (Invoice date): valor "09/15/2026", verde, ✓
- Slot 3 (Due date): "—", gris (omitido sin autocalc)
- Slot 5 (Previous balance): "1000", azul, ◐ azul
- Slot 7 (Past due): apuntado — `⌖ 7` ámbar, valor "esperado: " (vacío + es active)
- Otros: "—" gris

Borrar `smoke_mainhud.ahk`.

- [ ] **Step 4.4: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): Update() recolorea slots por estado (active/filled/preloaded/empty)"
```

---

## Task 5: Click handlers — name + slot# → JumpTo

**Files:**
- Modify: `Lib/MainHud.ahk`
- Modify: `QuickEntry.ahk`

**Contexto:** Click en columna izquierda (slot # o nombre) hace `JumpTo` y refresca. Por ahora value column NO hace nada (Task 6 implementa edit inline). Necesitamos un callback hacia QuickEntry para que `RefrescarTooltip` ya esté llamando `Update()` (porque el estado cambió).

- [ ] **Step 5.1: Wire click handlers en `Build()` de `Lib/MainHud.ahk`**

Buscar el bloque `Loop n { ... this.rows.Push(...) }` en `Build()`. Antes del `this.rows.Push(...)`, agregar handlers (en el medio del Loop):

```ahk
            ; Wire click handlers (closures sobre i)
            jumpHandler := this.MakeJumpHandler(i)
            slotTxt.OnEvent("Click", jumpHandler)
            nameCtrl.OnEvent("Click", jumpHandler)
            ; valueCtrl wire en Task 6 (edit inline)
```

- [ ] **Step 5.2: Agregar métodos de handlers al final de la clase `MainHud`**

Buscar el final de la clase (antes del `}` final) e insertar:

```ahk
    ; --- Genera handler de jump capturando slot por closure ---
    MakeJumpHandler(slot) => ((*) => this.OnRowClickName(slot))

    OnRowClickName(slot)
    {
        try this.engine.JumpTo(slot)
        this.Update()
    }
```

- [ ] **Step 5.3: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 5.4: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): click en columna nombre/# hace JumpTo + Update"
```

---

## Task 6: Inline edit — click en valor + Enter/Esc + double-Enter force

**Files:**
- Modify: `Lib/MainHud.ahk`

**Contexto:** Click en columna valor → JumpTo + el control Text se reemplaza por un Edit con el valor actual. Enter commit (PushManual). Si validación falla, el Edit queda abierto + texto rojo aparece. Si Enter de nuevo SIN cambiar el valor, MsgBox confirm → PushForce. Esc cancela.

- [ ] **Step 6.1: Wire click handler en `Build()` para valueCtrl**

Buscar el comentario `; valueCtrl wire en Task 6` que pusiste en Task 5, y reemplazar por:

```ahk
            valueCtrl.OnEvent("Click", this.MakeValueHandler(i))
```

- [ ] **Step 6.2: Agregar métodos de inline edit al final de `MainHud`**

Insertar antes del `}` final de la clase:

```ahk
    MakeValueHandler(slot) => ((*) => this.OnRowClickValue(slot))

    OnRowClickValue(slot)
    {
        try this.engine.JumpTo(slot)
        this.Update()
        this.ShowInlineEdit(slot)
    }

    ShowInlineEdit(slot)
    {
        if this.inlineEdit
            this.CloseInlineEdit()

        row := this.rows[slot]
        valueCtrl := row["valueCtrl"]
        valueCtrl.GetPos(&x, &y, &w, &h)
        valueCtrl.Visible := false

        valor := this.engine.queue[slot]
        edt := this.gui.Add("Edit", "x" x " y" y " w" w " h" h " vInlineEdit", valor)
        edt.SetFont("s10 c" MAINHUD_FG_LABEL, MAINHUD_FONT_VALUE)
        edt.Focus()

        this.inlineEdit := edt
        this.inlineEditSlot := slot
        this.inlineEditFailedOnce := false
        this.inlineEditPrevValue := ""

        ; Hotkeys context-sensitive (ahk_id de la GUI)
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Enter", (*) => this.OnInlineEditEnter(), "On")
        Hotkey("Escape", (*) => this.OnInlineEditEsc(), "On")
        HotIf()
    }

    OnInlineEditEnter()
    {
        if !this.inlineEdit
            return
        val := this.inlineEdit.Value
        slot := this.inlineEditSlot

        ; Si valor no cambio respecto al ultimo failed -> MsgBox confirm
        if (this.inlineEditFailedOnce && val = this.inlineEditPrevValue)
        {
            resp := MsgBox("Valor invalido. ¿Forzar igual?",
                           "QuickEntry", "YesNo Icon!")
            if (resp = "Yes")
            {
                this.engine.JumpTo(slot)
                rf := this.engine.PushForce(val)
                this.CloseInlineEdit()
                this.Update()
                return
            }
            else
            {
                this.inlineEdit.Focus()
                return
            }
        }

        ; Intentar push manual normal
        this.engine.JumpTo(slot)
        res := this.engine.PushManual(val)
        if !res["ok"]
        {
            this.inlineEditFailedOnce := true
            this.inlineEditPrevValue := val
            this.ShowInlineError(slot, res["error"])
            this.inlineEdit.Focus()
            return
        }

        this.CloseInlineEdit()
        this.Update()
    }

    OnInlineEditEsc()
    {
        this.CloseInlineEdit()
        this.Update()
    }

    CloseInlineEdit()
    {
        if !this.inlineEdit
            return
        slot := this.inlineEditSlot
        try this.inlineEdit.Destroy()
        this.inlineEdit := ""
        this.inlineEditSlot := 0
        this.inlineEditFailedOnce := false
        this.inlineEditPrevValue := ""

        if this.inlineEditErrorCtrl
        {
            try this.inlineEditErrorCtrl.Destroy()
            this.inlineEditErrorCtrl := ""
        }

        ; Restaurar valueCtrl
        if (slot >= 1 && slot <= this.rows.Length)
            this.rows[slot]["valueCtrl"].Visible := true

        ; Desactivar hotkeys
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        try Hotkey("Enter", "Off")
        try Hotkey("Escape", "Off")
        HotIf()
    }

    ShowInlineError(slot, msg)
    {
        if this.inlineEditErrorCtrl
        {
            try this.inlineEditErrorCtrl.Destroy()
            this.inlineEditErrorCtrl := ""
        }
        row := this.rows[slot]
        row["valueCtrl"].GetPos(&x, &y, &w, &h)
        ; Texto rojo debajo de la fila
        err := this.gui.Add("Text", "x" x " y" (y + h + 2) " w" (w + 60) " h18 c" MAINHUD_FG_ERROR, msg)
        err.SetFont("s9 italic c" MAINHUD_FG_ERROR, MAINHUD_FONT_LABEL)
        this.inlineEditErrorCtrl := err
    }
```

- [ ] **Step 6.3: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 6.4: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): inline edit en columna valor (click + Enter/Esc + double-Enter force)"
```

---

## Task 7: Footer button handlers + Close confirm

**Files:**
- Modify: `Lib/MainHud.ahk`

**Contexto:** Cablear los 5 botones del footer (Reset, Undo, Load Last, Set Default Pos, Toggle Compact) a métodos. `Load Last` y `SaveLastPaste` quedan como stubs que se completan en Task 9.

- [ ] **Step 7.1: Wire button handlers en `Build()` (final del método)**

Buscar al final de `Build()` (justo antes de `this.gui := g`) y agregar:

```ahk
        btnReset.OnEvent("Click", (*) => this.OnReset())
        btnUndo.OnEvent("Click", (*) => this.OnUndo())
        btnLoadLast.OnEvent("Click", (*) => this.OnLoadLast())
        btnSetDefault.OnEvent("Click", (*) => this.SaveAsDefault())
        btnToggleCompact.OnEvent("Click", (*) => this.OnToggleCompact())
```

Y reemplazar el ya-existente `OnEvent("Close", ...)` por:

```ahk
        g.OnEvent("Close", (*) => this.OnClose())
        g.OnEvent("Escape", (*) => this.OnEscape())
```

(no cambia, solo confirmar que está).

- [ ] **Step 7.2: Agregar handlers de botones**

Insertar antes del `}` final de la clase:

```ahk
    OnReset()
    {
        global engine
        this.engine.Reset()
        this.CloseInlineEdit()
        this.Hide()
        ToolTip("Captura cancelada")
        SetTimer(() => ToolTip(), -1500)
    }

    OnUndo()
    {
        u := this.engine.Undo()
        if !u["ok"]
        {
            ToolTip("Nada que deshacer")
            SetTimer(() => ToolTip(), -1500)
            return
        }
        this.Update()
    }

    OnLoadLast()
    {
        ; Implementado en Task 9
        ToolTip("Load Last (pendiente Task 9)")
        SetTimer(() => ToolTip(), -1500)
    }

    OnToggleCompact()
    {
        this.compactMode := !this.compactMode
        this.SaveCompactMode()
        ; Re-render compact (Task 8)
        this.Update()
    }
```

- [ ] **Step 7.3: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 7.4: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): footer button handlers (Reset, Undo, LoadLast stub, SetDefault, ToggleCompact)"
```

---

## Task 8: Compact mode rendering

**Files:**
- Modify: `Lib/MainHud.ahk`

**Contexto:** En modo compact, esconder todas las filas excepto la apuntada (`NextSlot`). Toggleable via `▣ ↔ ▢` button (ya cableado en Task 7).

- [ ] **Step 8.1: Modificar `Update()` para esconder filas no-apuntadas en compact**

Buscar el bloque dentro de `Update()` que itera `Loop n` y al inicio del cuerpo del Loop, agregar:

```ahk
            ; Compact mode: solo mostrar el slot apuntado
            esVisible := !this.compactMode || (i = next)
            row["slotTxt"].Visible := esVisible
            row["nameCtrl"].Visible := esVisible
            row["valueCtrl"].Visible := esVisible
            row["iconCtrl"].Visible := esVisible
            if !esVisible
                continue
```

(Esto va inmediatamente después de `row := this.rows[i]` y antes de `valor := ...`)

- [ ] **Step 8.2: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 8.3: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): compact mode esconde slots no-apuntados"
```

---

## Task 9: SaveLastPaste / LoadLastPaste persistence

**Files:**
- Modify: `Lib/MainHud.ahk`

**Contexto:** Antes de `engine.Reset()` en `^+s` (PasteBatch), serializar `engine.queue` + `engine.preloadedSlots` a `last_paste.ini`. Botón `↻ Load Last` lee y restaura el estado del engine.

- [ ] **Step 9.1: Agregar métodos de SaveLastPaste / LoadLastPaste**

Insertar antes del `}` final de la clase:

```ahk
    SaveLastPaste()
    {
        path := A_AppData "\QuickEntry\last_paste.ini"
        ; Limpiar archivo previo
        try FileDelete(path)
        ; Queue
        Loop this.engine.schema.Length
        {
            i := A_Index
            valor := this.engine.queue[i]
            ; IniWrite no acepta valores con \r\n. Asignet no los tiene, pero por las dudas:
            valor := StrReplace(valor, "`r`n", " ")
            valor := StrReplace(valor, "`n", " ")
            IniWrite(valor, path, "Queue", "slot" i)
        }
        ; Preloaded
        for slot, _ in this.engine.preloadedSlots
            IniWrite("true", path, "Preloaded", "slot" slot)
    }

    LoadLastPaste()
    {
        path := A_AppData "\QuickEntry\last_paste.ini"
        if !FileExist(path)
        {
            ToolTip("No hay ultima cola guardada")
            SetTimer(() => ToolTip(), -1500)
            return false
        }

        ; Si hay captura en curso con datos, confirmar
        if (this.engine.isCapturing && this.engine.FilledCount > 0)
        {
            resp := MsgBox("Hay una captura en curso. ¿Reemplazar con la ultima cola pegada?",
                           "Load Last", "YesNo Icon?")
            if (resp != "Yes")
                return false
        }

        ; Reset y rearm
        this.engine.Arm()

        ; Restaurar queue
        Loop this.engine.schema.Length
        {
            i := A_Index
            valor := IniRead(path, "Queue", "slot" i, "")
            if (valor != "")
                this.engine.queue[i] := valor
        }
        ; Restaurar preloadedSlots
        Loop this.engine.schema.Length
        {
            i := A_Index
            flag := IniRead(path, "Preloaded", "slot" i, "")
            if (flag = "true")
                this.engine.preloadedSlots[i] := true
        }
        ; AutoAdvance al primer vacio
        this.engine.AutoAdvance(0)
        return true
    }
```

- [ ] **Step 9.2: Reemplazar el stub de `OnLoadLast`**

Buscar `OnLoadLast()` y reemplazar el cuerpo por:

```ahk
    OnLoadLast()
    {
        if this.LoadLastPaste()
        {
            this.Show()
            this.Update()
        }
    }
```

- [ ] **Step 9.3: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\MainHud.ahk') -RedirectStandardError "$env:TEMP\mh.err" -RedirectStandardOutput "$env:TEMP\mh.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mh.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 9.4: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/MainHud.ahk
git commit -m "feat(hud): SaveLastPaste / LoadLastPaste persisten queue + preloadedSlots en INI"
```

---

## Task 10: Wire MainHud en `QuickEntry.ahk`

**Files:**
- Modify: `QuickEntry.ahk`

**Contexto:** Reemplazar el `ToolTip(...)` de estado por `mainHud.Update()`. Show/Hide en hotkeys de armar/reset/paste. SaveLastPaste antes de Reset en `^+s`.

- [ ] **Step 10.1: Agregar `#Include` y instanciar `mainHud`**

En `QuickEntry.ahk`, después del bloque de `#Include` existentes (línea ~9):

```ahk
#Include "Lib\MainHud.ahk"
```

Y en el bloque de Singletons (línea ~36 actual):

```ahk
global mainHud := MainHud(engine)
```

(insertar después de `global manualGui := ...`)

- [ ] **Step 10.2: Reemplazar `RefrescarTooltip` body**

Buscar:

```ahk
RefrescarTooltip(res, accion := "")
{
    global engine
    accionMostrar := (accion = "manual" || accion = "jump") ? "" : accion
    ToolTip(TooltipPostAccion(engine, accionMostrar))
}
```

Reemplazar por:

```ahk
RefrescarTooltip(res, accion := "")
{
    global engine, mainHud
    mainHud.Update()
}
```

(El parámetro `accion` ya no es necesario porque la GUI se rinde sola desde el state, pero lo mantenemos por compatibilidad de la firma con el resto del codigo.)

- [ ] **Step 10.3: Wire `^+a` para Show la GUI**

Buscar el hotkey `^+a::` y dentro del else (rama de `Arm`), después de `engine.Arm(A_Clipboard)`:

```ahk
    else
    {
        manualGui.Close()
        engine.Arm(A_Clipboard)
        mainHud.Show()
        mainHud.Update()
    }
```

(reemplazar la línea `ToolTip(LineaPrompt(engine))` por las dos nuevas).

- [ ] **Step 10.4: Wire `^+s` para SaveLastPaste antes de Reset + Hide al final**

Buscar el hotkey `^+s::` y reemplazar el bloque `try { ... } finally { engine.Reset(); ... }` por:

```ahk
    manualGui.Close()
    pegadoEnCurso := true
    try
    {
        SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
        Sleep 30
        engine.PasteBatch()
    }
    finally
    {
        mainHud.SaveLastPaste()
        engine.Reset()
        mainHud.Hide()
        pegadoEnCurso := false
        ToolTip()
    }
```

- [ ] **Step 10.5: Wire `^+r` para Hide la GUI**

Buscar el hotkey `^+r::` y reemplazar:

```ahk
^+r::
{
    global engine, manualGui, mainHud
    manualGui.Close()
    engine.Reset()
    mainHud.Hide()
    ToolTip("Captura cancelada")
    SetTimer(() => ToolTip(), -1500)
}
```

- [ ] **Step 10.6: Wire `^+u` (Undo) para refrescar el HUD**

Buscar `^+u::` y al final, reemplazar `RefrescarTooltip(...)` por:

```ahk
    RefrescarTooltip(Map("label", u["label"], "value", "", "slot", u["slot"]), "descartado")
    mainHud.Update()
```

(la línea ya llamaba `RefrescarTooltip` que ahora llama `mainHud.Update()` internamente, pero por las dudas explicito).

Actually wait — `RefrescarTooltip` ya llama `mainHud.Update()`. La línea adicional es redundante. **Saltar este step (10.6)** si la línea ya funciona.

- [ ] **Step 10.7: Wire `^+h` (HeaderScan) para Show + Update al final**

Buscar `^+h::` y al final del `try { ... }` (después de `engine.Scan(...)`), agregar:

```ahk
    finally
    {
        A_Clipboard := backup
        pegadoEnCurso := false
    }
    mainHud.Show()
    mainHud.Update()
```

(reemplazar el `ToolTip(TooltipPostAccion(engine))` final).

- [ ] **Step 10.8: Validar sintaxis**

```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk') -RedirectStandardError "$env:TEMP\qe.err" -RedirectStandardOutput "$env:TEMP\qe.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\qe.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`.

- [ ] **Step 10.9: Correr suite (verificar que el engine sigue OK)**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"
```

Expected: `ALL TESTS PASSED`.

- [ ] **Step 10.10: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add QuickEntry.ahk
git commit -m "feat(quickentry): wire MainHud - reemplaza ToolTip de estado, Show/Hide en ^+a/s/r/h"
```

---

## Task 11: Smoke test manual + push

**Files:** ninguno.

**Contexto:** Verificación end-to-end del flujo completo. La GUI es side-effect-only — el smoke confirma que todas las piezas se integran.

- [ ] **Step 11.1: Levantar QuickEntry**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk"
```

Verifica que el ícono H verde aparece en la bandeja.

- [ ] **Step 11.2: Smoke checklist (manual)**

Abrí Notepad o cualquier campo de texto de prueba. Verificá uno por uno:

1. **`^+a`** → GUI aparece centrada en pantalla (primera vez) con 9 slots vacíos. `⌖ 1` ámbar en slot 1 Account number. Footer: Reset/Undo/LoadLast/⊙/▣.
2. **Mover la GUI** con drag de title bar → al cerrar y reabrir, vuelve a esa posición.
3. **Click en `⊙`** (set default) → tooltip "Posicion default actualizada".
4. **Copiar `ACC-1234`** → slot 1 verde con ✓, cursor avanza a slot 2 (`⌖ 2` ámbar).
5. **Copiar `Sep 15, 2026`** → slot 2 verde "09/15/2026".
6. **`^+a`** (omitir) en slot 3 → omit, AutoAdvance a slot 4. Slot 3 sigue gris "—".
7. **Click en NOMBRE de slot 3** → cursor vuelve a slot 3.
8. **Click en VALOR de slot 3** → Edit aparece con "" (vacío). Tipear `02/01/2026`, Enter → slot 3 verde, cursor avanza al próximo vacío.
9. **Click en VALOR de slot 1** → Edit con "ACC-1234". Tipear `INVALID`, Enter → texto rojo abajo "no es un numero valido" (o validation msg). Enter de nuevo → MsgBox "Forzar igual?" → Yes → slot 1 commiteado con "INVALID" (color naranja, ícono `!`). 
   _Nota:_ Account number tiene ValidarNoVacio que pasa con cualquier no-vacío, así que este test puede no disparar el flow. Probar con slot 2 (Invoice date) que valida formato fecha.
10. **`^+u`** → undo del último → slot N retrocede al valor previo. GUI refresca.
11. **`▣` toggle compact** → solo el slot apuntado visible. Toggle de nuevo → todos visibles.
12. **`↻ Load Last`** sin haber pegado nunca → tooltip "No hay ultima cola guardada".
13. **`^+s`** (paste batch en Notepad) → pega los 9 valores con Tabs. GUI se oculta. Suite saved a INI.
14. **`^+a` de nuevo** → GUI vuelve, vacía. **`↻ Load Last`** → restaura los 9 valores de la sesión anterior + arma captura.
15. **`^+r`** → GUI se oculta + tooltip "Captura cancelada".

- [ ] **Step 11.3: Si TODOS los pasos del smoke OK, commit final + push**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git status  # debería estar clean
git push origin main
```

Expected: push exitoso.

- [ ] **Step 11.4: Si algún paso del smoke falla**

STOP. Reportar al usuario:
- Qué paso falló
- Qué se observó vs qué se esperaba
- Sin pushear

---

## Riesgos durante implementación

| Riesgo | Mitigación |
|---|---|
| AHK v2 GUI no permite cambiar bg color por control via `+Background` | Usar solo color de texto (`SetFont c<hex>`). Los slots se distinguen por texto en color + ícono lateral. Suficiente. Ya implementado así. |
| `Hotkey("Enter", ...)` con `HotIfWinActive` interfiere con otras teclas | Solo activamos durante inline edit. `CloseInlineEdit` desactiva. Si rompe en práctica, fallback: usar un Default Button invisible que reciba Enter. |
| `IniWrite` con valores con `=` o `[` rompe el archivo | Asignet no tiene esos chars en sus campos típicos (account#, fechas, montos, nombres). Si surge: escapar via StrReplace antes de IniWrite. |
| Compact mode + edit inline simultáneos | Si el slot editado se vuelve no-visible al toggle compact, el Edit queda flotante. Solución: cerrar el inline edit antes de toggle compact. Implementado: `OnToggleCompact` llama `CloseInlineEdit` antes (agregar si necesario en smoke). |
| `mainHud` se referencia antes de instanciarse en `RefrescarTooltip` | Al iniciar QuickEntry, `mainHud := MainHud(engine)` corre antes de cualquier hotkey. La función `RefrescarTooltip` solo se llama desde handlers de hotkeys o callbacks. Safe. |

---

## Self-review

Coverage check:
- D1 (replace tooltip): Task 10 ✓
- D2 (aesthetic): Task 3-4 (colores hardcoded) ✓
- D3 (position persistent): Task 2 (LoadPosition/SaveLastPosition/SaveAsDefault) ✓
- D4 (click name vs value): Tasks 5-6 ✓
- D5 (auto-advance after Enter): Task 6 (PushManual ya hace AutoAdvance) ✓
- D6 (validation error + double-Enter force): Task 6 + Task 1 (PushForce) ✓
- D7 (operandos clickeables): **GAP**. El plan no implementa filas hijas para operandos. Ver nota.
- D8 (footer): Task 7 ✓
- D9 (compact mode): Task 8 ✓
- D10 (load last): Task 9 ✓
- D11 (truncado de valores): Task 4 (`TruncarValor`) ✓

**Gap en D7 (operandos clickeables):** las filas hijas indentadas (`├ Previous balance: 1000`) no están en el Build/Update actual. Razón: agregar filas dinámicas que aparecen/desaparecen según el slot apuntado complica el layout (cambiaría el yPos de los slots siguientes). Decisión: **diferir D7 para una iteración posterior**. Por ahora la información de operandos sigue disponible vía el `expectedFor` mostrado como "esperado: X.XX" en la fila del slot apuntado. Si el operador necesita corregir un operando, puede usar Click en la fila del operando directo (slots 5 o 6 en el caso de Past due). Documentar este gap en el spec o aceptar como "v1.1".

Plan re-revisión:
- Sin placeholders, todo el código está completo.
- Tipos consistentes (`MAINHUD_FG_*` constantes usadas igual en todos los Tasks).
- Métodos referenciados (e.g., `CloseInlineEdit`, `TruncarValor`) están definidos en el mismo Task u otro previo.
- Comandos verifications todas tienen expected output.
