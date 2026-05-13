# Botonera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the **Botonera** sibling app to QuickEntry — a launcher GUI with three section-tabs (Wayfast / Web / Tools) under `Botonera/`, designed as an extensible scaffold for the parser role.

**Architecture:** Sections-as-classes (each section is one class implementing a `Section` contract). Tab3 control hosts the three sections. Pure modules (Cleaners, formatters, INI persistence) are testable in isolation. GUI classes are smoke-tested only. INI single-file persistence (`botonera.ini`).

**Tech Stack:** AutoHotkey v2.0, INI file persistence, custom assert helpers, PowerShell test runner.

**Spec:** `docs/superpowers/specs/2026-05-01-botonera-design.md`

---

## File Structure (final state)

```
C:\Users\Usuario\Desktop\Asignet\
├── (existing files unchanged)
└── Botonera\
    ├── Botonera.ahk                ← entry point (~80 LOC: wiring + global hotkey)
    ├── botonera.ini                ← created at runtime (gitignored)
    ├── Lib\
    │   ├── Cleaners.ahk            ← snapshot copy of ../../Lib/Cleaners.ahk
    │   ├── IniPersist.ahk          ← Window position load/save helper
    │   ├── MainGui.ahk             ← Tab3 host, mounts sections
    │   ├── Section.ahk             ← abstract base contract
    │   ├── SectionWayfast.ahk      ← scaffold + user-defined buttons
    │   ├── SectionWeb.ahk          ← Launch QuickEntry + URLs
    │   ├── SectionTools.ahk        ← 5 utility buttons → widgets
    │   └── Widgets\
    │       ├── SnippetsManager.ahk
    │       ├── RegexTester.ahk
    │       ├── JsonPretty.ahk
    │       └── ProcessTimer.ahk
    └── Tests\
        ├── _AssertHelpers.ahk      ← snapshot copy of ../../Tests/_AssertHelpers.ahk
        ├── runner.ps1              ← snapshot copy of ../../Tests/runner.ps1
        ├── Test_IniPersist.ahk
        ├── Test_JsonPretty.ahk
        ├── Test_RegexTester.ahk
        ├── Test_ProcessTimer.ahk
        ├── Test_SnippetsManager.ahk
        └── Test_WayfastUserButtons.ahk
```

**Key conventions:**
- Pure modules (testable): `IniPersist`, `JsonPretty.FormatLogic`, `RegexTester.EvalLogic`, `ProcessTimer.HistoryLogic`, `SnippetsManager.StoreLogic`, `WayfastUserButtons` (storage layer).
- GUI classes (smoke-only): `MainGui`, `SectionXxx`, popups in `Widgets/`.
- Each Widget exports a tiny pure logic module **AND** a GUI class. Tests target the pure module; the GUI just calls into it.

---

## Task 0: Bootstrap folder structure + snapshot copies + smoke-test runner

**Files:**
- Create dir: `Botonera/`
- Create dir: `Botonera/Lib/`
- Create dir: `Botonera/Lib/Widgets/`
- Create dir: `Botonera/Tests/`
- Create: `Botonera/Lib/Cleaners.ahk` (snapshot of `Lib/Cleaners.ahk`)
- Create: `Botonera/Tests/_AssertHelpers.ahk` (snapshot of `Tests/_AssertHelpers.ahk`)
- Create: `Botonera/Tests/runner.ps1` (snapshot of `Tests/runner.ps1`)
- Create: `Botonera/.gitignore`

- [ ] **Step 0.1: Create directory tree**

```powershell
New-Item -ItemType Directory -Path "C:\Users\Usuario\Desktop\Asignet\Botonera\Lib\Widgets" -Force
New-Item -ItemType Directory -Path "C:\Users\Usuario\Desktop\Asignet\Botonera\Tests" -Force
```

Expected: directories exist, no errors.

- [ ] **Step 0.2: Snapshot-copy `Cleaners.ahk` with origin marker**

Read `C:\Users\Usuario\Desktop\Asignet\Lib\Cleaners.ahk` and write to `Botonera/Lib/Cleaners.ahk`, prepending this header right after `#Requires AutoHotkey v2.0`:

```autohotkey
; ====================================================================
; SNAPSHOT COPY from ../../Lib/Cleaners.ahk on 2026-05-01.
; This file is intentionally INDEPENDENT of the parent QuickEntry version.
; Edits here do NOT affect QuickEntry. To re-sync, copy from origin manually.
; ====================================================================
```

- [ ] **Step 0.3: Snapshot-copy `_AssertHelpers.ahk`**

Copy `Tests/_AssertHelpers.ahk` → `Botonera/Tests/_AssertHelpers.ahk` verbatim (no header changes — it's tiny and identical use case).

- [ ] **Step 0.4: Snapshot-copy `runner.ps1`**

Copy `Tests/runner.ps1` → `Botonera/Tests/runner.ps1` verbatim. Same script works because it uses `$PSScriptRoot` to find tests.

- [ ] **Step 0.5: Add `.gitignore` for runtime files**

Write `Botonera/.gitignore`:

```
botonera.ini
botonera.log
```

- [ ] **Step 0.6: Smoke-validate the runner sees no tests yet (and exits clean)**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Botonera\Tests\runner.ps1"
```

Expected output:
```

Total asserts: 0
ALL TESTS PASSED
```
Exit code: 0.

- [ ] **Step 0.7: Commit**

```powershell
cd "C:\Users\Usuario\Desktop\Asignet"
git add Botonera/
git commit -m "feat(botonera): bootstrap folder + snapshot copies of Cleaners/runner/asserts"
```

---

## Task 1: `IniPersist.ahk` — load/save window position (PURE, TDD)

**Files:**
- Create: `Botonera/Lib/IniPersist.ahk`
- Create: `Botonera/Tests/Test_IniPersist.ahk`

This task validates the testing infrastructure works with a real pure module.

- [ ] **Step 1.1: Write failing test**

Create `Botonera/Tests/Test_IniPersist.ahk`:

```autohotkey
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\IniPersist.ahk"
#Include "_AssertHelpers.ahk"

; Use a temp INI under TEMP so we never touch the real botonera.ini
testIni := A_Temp "\botonera_test_" A_TickCount ".ini"

; --- Default fallback when key missing ---
AssertEq(IniPersist.LoadInt(testIni, "Window", "x", 100), 100, "default x when missing")
AssertEq(IniPersist.LoadInt(testIni, "Window", "y", 200), 200, "default y when missing")

; --- Save then load roundtrip ---
IniPersist.SaveInt(testIni, "Window", "x", 555)
IniPersist.SaveInt(testIni, "Window", "y", 777)
AssertEq(IniPersist.LoadInt(testIni, "Window", "x", 0), 555, "loaded x")
AssertEq(IniPersist.LoadInt(testIni, "Window", "y", 0), 777, "loaded y")

; --- Overwrite ---
IniPersist.SaveInt(testIni, "Window", "x", 999)
AssertEq(IniPersist.LoadInt(testIni, "Window", "x", 0), 999, "overwritten x")

; --- Cleanup test file ---
try FileDelete(testIni)

ReportarYSalir()
```

- [ ] **Step 1.2: Run test — verify it FAILS (no IniPersist.ahk yet)**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Botonera\Tests\runner.ps1"
```

Expected: `FAIL Test_IniPersist.ahk` with CRASH (file not found / IniPersist undefined).

- [ ] **Step 1.3: Implement minimal `IniPersist.ahk`**

Create `Botonera/Lib/IniPersist.ahk`:

```autohotkey
#Requires AutoHotkey v2.0
; ====================================================================
; IniPersist.ahk - Wrapper estatico sobre IniRead/IniWrite con defaults.
; Modulo PURO (sin estado, sin GUI). Escribe/lee enteros con fallback
; a default cuando la clave no existe o el archivo no existe todavia.
; ====================================================================

class IniPersist
{
    static LoadInt(path, section, key, default := 0)
    {
        try
        {
            v := IniRead(path, section, key, default)
            return Integer(v)
        }
        catch
        {
            return default
        }
    }

    static SaveInt(path, section, key, value)
    {
        IniWrite(Integer(value), path, section, key)
    }

    static LoadStr(path, section, key, default := "")
    {
        try
            return IniRead(path, section, key, default)
        catch
            return default
    }

    static SaveStr(path, section, key, value)
    {
        IniWrite(value, path, section, key)
    }
}
```

- [ ] **Step 1.4: Run test — verify it PASSES**

Expected:
```
PASS  Test_IniPersist.ahk             === 5 tests, 0 failures ===

Total asserts: 5
ALL TESTS PASSED
```

- [ ] **Step 1.5: Commit**

```powershell
git add Botonera/Lib/IniPersist.ahk Botonera/Tests/Test_IniPersist.ahk
git commit -m "feat(botonera): IniPersist with int/str load/save + default fallback"
```

---

## Task 2: `Botonera.ahk` entry point with empty MainGui + global hotkey

**Files:**
- Create: `Botonera/Lib/MainGui.ahk`
- Create: `Botonera/Botonera.ahk`

GUI tasks are smoke-tested only (no automated tests). Validation = `/validate` exit 0 + smoke launch starts and shuts cleanly.

- [ ] **Step 2.1: Create `Lib/MainGui.ahk` (empty Tab3 with three tabs)**

```autohotkey
#Requires AutoHotkey v2.0
#Include "IniPersist.ahk"

; ====================================================================
; MainGui - Ventana raiz con Tab3 de tres pestanias.
; No conoce que hay en cada seccion: las recibe en el constructor y las
; monta en su tab respectivo via Section.Build(tabCtrl, tabIndex).
; ====================================================================

class MainGui
{
    gui := ""
    tab := ""
    sections := []
    iniPath := ""
    visible := false

    __New(sections, iniPath)
    {
        this.sections := sections
        this.iniPath := iniPath
    }

    Build()
    {
        g := Gui("+AlwaysOnTop -DPIScale", "Botonera")
        g.BackColor := "F8FAFC"
        g.SetFont("s10 c1F2937", "Segoe UI")
        g.MarginX := 12
        g.MarginY := 12

        names := []
        for s in this.sections
            names.Push(s.title)

        this.tab := g.Add("Tab3", "x12 y12 w480 h360", names)

        for i, s in this.sections
        {
            this.tab.UseTab(i)
            s.Build(this.tab, i)
        }
        this.tab.UseTab()  ; reset

        g.OnEvent("Close", (*) => this.Hide())
        g.OnEvent("Escape", (*) => this.Hide())

        this.gui := g
    }

    Show()
    {
        if !IsObject(this.gui)
            this.Build()

        x := IniPersist.LoadInt(this.iniPath, "Window", "x", 100)
        y := IniPersist.LoadInt(this.iniPath, "Window", "y", 100)
        this.gui.Show("x" x " y" y " w504 h396")
        this.visible := true

        for s in this.sections
            if s.HasMethod("OnShow")
                s.OnShow()
    }

    Hide()
    {
        if !IsObject(this.gui) || !this.visible
            return
        ; Save current pos before hiding
        this.gui.GetPos(&x, &y)
        IniPersist.SaveInt(this.iniPath, "Window", "x", x)
        IniPersist.SaveInt(this.iniPath, "Window", "y", y)
        this.gui.Hide()
        this.visible := false
    }

    Toggle()
    {
        if this.visible
            this.Hide()
        else
            this.Show()
    }
}
```

- [ ] **Step 2.2: Create `Botonera.ahk` entry with three placeholder sections + global hotkey**

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "Lib\MainGui.ahk"

; --- Stub sections so MainGui can mount; real ones replace these later ---
class StubSection
{
    title := ""
    __New(title) { this.title := title }
    Build(tab, idx) { tab.UseTab(idx); tab.Parent.Add("Text", "x24 y48", "(" this.title " - vacio por ahora)") }
}

global g_iniPath := A_ScriptDir "\botonera.ini"
global g_mainGui := MainGui([
    StubSection("Wayfast"),
    StubSection("Web"),
    StubSection("Tools")
], g_iniPath)

g_mainGui.Show()  ; visible al startup

^+b::g_mainGui.Toggle()
```

- [ ] **Step 2.3: Validate AHK syntax**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk"
echo "ExitCode: $LASTEXITCODE"
```

Expected: `ExitCode: 0`.

- [ ] **Step 2.4: Smoke launch**

```powershell
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK (alive)" } else { "FAIL (exited $($proc.ExitCode))" }
```

Expected: `OK (alive)`.

- [ ] **Step 2.5: Run test suite (still passes)**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Botonera\Tests\runner.ps1"
```

Expected: `ALL TESTS PASSED`, 5 asserts.

- [ ] **Step 2.6: Commit**

```powershell
git add Botonera/Botonera.ahk Botonera/Lib/MainGui.ahk
git commit -m "feat(botonera): entry point + MainGui with empty Tab3 + Ctrl+Shift+B toggle"
```

---

## Task 3: `Section.ahk` abstract contract (documentation-as-code)

**Files:**
- Create: `Botonera/Lib/Section.ahk`

This is a documented base class. It defines the interface that all real sections implement. No tests (it's an interface), but it standardizes the API so future sections plug in identically.

- [ ] **Step 3.1: Create `Section.ahk`**

```autohotkey
#Requires AutoHotkey v2.0

; ====================================================================
; Section.ahk - Base contract para las secciones de Botonera.
;
; Cada seccion (Wayfast, Web, Tools, ...futuras) hereda de Section y
; sobreescribe Build(). Los demas metodos son opcionales (default noop).
;
; Punto de extension: para agregar una seccion nueva al programa,
;   1. Crear Lib/SectionXxx.ahk que extends Section
;   2. Sobreescribir Build(tabCtrl, tabIndex)
;   3. Registrar la instancia en Botonera.ahk
; ====================================================================

class Section
{
    title := "(unnamed)"

    Build(tabCtrl, tabIndex)
    {
        ; Subclases agregan controles al tabCtrl despues de tabCtrl.UseTab(tabIndex).
        throw Error("Section.Build() must be overridden by " this.__Class)
    }

    RegisterHotkeys()
    {
        ; Override si la seccion necesita hotkeys propios. Default: noop.
    }

    OnShow()
    {
        ; Override si la seccion debe refrescarse al mostrar la ventana.
    }
}
```

- [ ] **Step 3.2: Validate**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Lib\Section.ahk"
echo "ExitCode: $LASTEXITCODE"
```

Expected: `ExitCode: 0`.

- [ ] **Step 3.3: Commit**

```powershell
git add Botonera/Lib/Section.ahk
git commit -m "feat(botonera): Section abstract contract (Build/RegisterHotkeys/OnShow)"
```

---

## Task 4: `SectionWeb.ahk` — Launch QuickEntry + Asignet URL

**Files:**
- Create: `Botonera/Lib/SectionWeb.ahk`
- Modify: `Botonera/Botonera.ahk` (replace Web stub)

- [ ] **Step 4.1: Create `SectionWeb.ahk`**

```autohotkey
#Requires AutoHotkey v2.0
#Include "Section.ahk"

class SectionWeb extends Section
{
    title := "Web"

    Build(tab, idx)
    {
        g := tab.Parent
        tab.UseTab(idx)

        g.Add("Text", "x24 y48 w430 h20", "Lanzadores web y atajos al flujo de carga manual.")

        btnQE := g.Add("Button", "x24 y76 w220 h36", "🚀 Launch QuickEntry")
        btnQE.OnEvent("Click", (*) => this.LaunchQuickEntry())

        btnWeb := g.Add("Button", "x24 y120 w220 h36", "🌐 Asignet web")
        btnWeb.OnEvent("Click", (*) => this.OpenAsignetWeb())
    }

    LaunchQuickEntry()
    {
        ; Buscar instancia previa por titulo conocido del MainHud
        if WinExist("QuickEntry ahk_class AutoHotkeyGUI")
        {
            WinActivate("QuickEntry ahk_class AutoHotkeyGUI")
            ToolTip("QuickEntry ya estaba corriendo")
            SetTimer(() => ToolTip(), -1500)
            return
        }
        try
        {
            Run('"' A_ScriptDir '\..\QuickEntry.ahk"')
            ToolTip("QuickEntry iniciado")
            SetTimer(() => ToolTip(), -1500)
        }
        catch as e
        {
            ToolTip("Error al lanzar: " e.Message)
            SetTimer(() => ToolTip(), -2500)
        }
    }

    OpenAsignetWeb()
    {
        ; URL real la define el operador editando esta funcion (o INI a futuro).
        Run("https://asignet.com/")
    }
}
```

- [ ] **Step 4.2: Wire into `Botonera.ahk`**

Replace `Botonera.ahk` content:

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "Lib\MainGui.ahk"
#Include "Lib\SectionWeb.ahk"

class StubSection extends Section
{
    title := ""
    __New(title) { this.title := title }
    Build(tab, idx) { tab.UseTab(idx); tab.Parent.Add("Text", "x24 y48", "(" this.title " - placeholder)") }
}

global g_iniPath := A_ScriptDir "\botonera.ini"
global g_mainGui := MainGui([
    StubSection("Wayfast"),
    SectionWeb(),
    StubSection("Tools")
], g_iniPath)

g_mainGui.Show()

^+b::g_mainGui.Toggle()
```

Add `#Include "Section.ahk"` line at the top of `Lib/MainGui.ahk` so `Section` is available for `StubSection extends Section`:

```autohotkey
#Include "IniPersist.ahk"
#Include "Section.ahk"
```

- [ ] **Step 4.3: Validate + smoke launch**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: validate `ExitCode: 0`, smoke `OK`.

- [ ] **Step 4.4: Commit**

```powershell
git add Botonera/
git commit -m "feat(botonera): SectionWeb with Launch QuickEntry + Asignet URL"
```

---

## Task 5: `SnippetsManager` — pure storage layer (TDD)

**Files:**
- Create: `Botonera/Lib/Widgets/SnippetsManager.ahk` (pure module, no GUI yet)
- Create: `Botonera/Tests/Test_SnippetsManager.ahk`

The popup GUI comes in Task 6. Here we write the storage layer pure and TDD it.

- [ ] **Step 5.1: Write failing test**

```autohotkey
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\Widgets\SnippetsManager.ahk"
#Include "_AssertHelpers.ahk"

testIni := A_Temp "\snippets_test_" A_TickCount ".ini"

; Empty file: zero snippets
AssertEq(SnippetsStore.LoadAll(testIni).Length, 0, "empty list when no INI")

; Add one snippet
SnippetsStore.Add(testIni, "Saludo", "Hola, como estas?")
list := SnippetsStore.LoadAll(testIni)
AssertEq(list.Length, 1, "one snippet after Add")
AssertEq(list[1].label, "Saludo", "loaded label")
AssertEq(list[1].text, "Hola, como estas?", "loaded text")

; Add a second
SnippetsStore.Add(testIni, "Firma", "Saludos cordiales,`r`nAle")
AssertEq(SnippetsStore.LoadAll(testIni).Length, 2, "two snippets after second Add")

; Remove first
SnippetsStore.RemoveAt(testIni, 1)
list := SnippetsStore.LoadAll(testIni)
AssertEq(list.Length, 1, "one snippet after Remove")
AssertEq(list[1].label, "Firma", "remaining is Firma")

; Cleanup
try FileDelete(testIni)

ReportarYSalir()
```

- [ ] **Step 5.2: Run test — verify it FAILS**

Run runner. Expected: `FAIL Test_SnippetsManager.ahk` (CRASH, no module).

- [ ] **Step 5.3: Implement `SnippetsStore` in `Lib/Widgets/SnippetsManager.ahk`**

```autohotkey
#Requires AutoHotkey v2.0

; ====================================================================
; SnippetsManager.ahk
;   - SnippetsStore: capa de persistencia PURA (testeable sin GUI)
;   - SnippetsManager: popup GUI (clase agregada en task posterior)
; Storage en INI section [Snippets] con claves N.label / N.text donde
; N es el indice 1-based.
; ====================================================================

class SnippetsStore
{
    static LoadAll(iniPath)
    {
        out := []
        i := 1
        loop
        {
            label := IniRead(iniPath, "Snippets", i ".label", "")
            if (label = "")
                break
            text := IniRead(iniPath, "Snippets", i ".text", "")
            out.Push({label: label, text: text})
            i++
        }
        return out
    }

    static Add(iniPath, label, text)
    {
        existing := this.LoadAll(iniPath)
        idx := existing.Length + 1
        IniWrite(label, iniPath, "Snippets", idx ".label")
        IniWrite(text, iniPath, "Snippets", idx ".text")
    }

    static RemoveAt(iniPath, index)
    {
        existing := this.LoadAll(iniPath)
        if (index < 1 || index > existing.Length)
            return
        ; Reescribir todo: borrar la seccion y volcar los demas
        try IniDelete(iniPath, "Snippets")
        newIdx := 1
        for i, snip in existing
        {
            if (i = index)
                continue
            IniWrite(snip.label, iniPath, "Snippets", newIdx ".label")
            IniWrite(snip.text, iniPath, "Snippets", newIdx ".text")
            newIdx++
        }
    }
}
```

- [ ] **Step 5.4: Run test — verify it PASSES**

Expected: `Test_SnippetsManager.ahk === 6 tests, 0 failures ===`.

- [ ] **Step 5.5: Commit**

```powershell
git add Botonera/Lib/Widgets/SnippetsManager.ahk Botonera/Tests/Test_SnippetsManager.ahk
git commit -m "feat(botonera): SnippetsStore (pure load/add/remove with INI persistence)"
```

---

## Task 6: `SnippetsManager` GUI popup (smoke only)

**Files:**
- Modify: `Botonera/Lib/Widgets/SnippetsManager.ahk` (append GUI class)

- [ ] **Step 6.1: Append GUI class to `SnippetsManager.ahk`**

Append (after `SnippetsStore`):

```autohotkey
class SnippetsManager
{
    iniPath := ""
    gui := ""
    list := ""
    edLabel := ""
    edText := ""

    __New(iniPath)
    {
        this.iniPath := iniPath
    }

    Show()
    {
        if IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)
        {
            this.gui.Show()
            return
        }
        this.Build()
    }

    Build()
    {
        g := Gui("+AlwaysOnTop -DPIScale", "Snippets")
        g.BackColor := "F8FAFC"
        g.SetFont("s10 c1F2937", "Segoe UI")
        g.MarginX := 12
        g.MarginY := 12

        g.Add("Text", "x12 y10 w400 h18", "Doble-click para copiar al clipboard:")
        this.list := g.Add("ListView", "x12 y32 w400 h160 -Multi", ["Etiqueta", "Texto (preview)"])
        this.list.OnEvent("DoubleClick", (*) => this.CopySelected())

        g.Add("Text", "x12 y200 w120 h20", "Nueva etiqueta:")
        this.edLabel := g.Add("Edit", "x140 y198 w272 h22")
        g.Add("Text", "x12 y228 w120 h20", "Nuevo texto:")
        this.edText := g.Add("Edit", "x140 y226 w272 h60 +Multi")

        btnAdd := g.Add("Button", "x12 y296 w120 h28", "+ Agregar")
        btnAdd.OnEvent("Click", (*) => this.OnAdd())
        btnDel := g.Add("Button", "x140 y296 w120 h28", "− Eliminar")
        btnDel.OnEvent("Click", (*) => this.OnDelete())
        btnClose := g.Add("Button", "x300 y296 w112 h28", "Cerrar")
        btnClose.OnEvent("Click", (*) => g.Hide())

        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())

        this.gui := g
        this.RefreshList()
        g.Show("AutoSize")
    }

    RefreshList()
    {
        this.list.Delete()
        for snip in SnippetsStore.LoadAll(this.iniPath)
        {
            preview := SubStr(snip.text, 1, 50)
            if (StrLen(snip.text) > 50)
                preview .= "..."
            this.list.Add(, snip.label, preview)
        }
        this.list.ModifyCol(1, 120)
        this.list.ModifyCol(2, 270)
    }

    OnAdd()
    {
        label := Trim(this.edLabel.Value)
        text := this.edText.Value
        if (label = "" || text = "")
        {
            ToolTip("Etiqueta y texto no pueden estar vacios")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        SnippetsStore.Add(this.iniPath, label, text)
        this.edLabel.Value := ""
        this.edText.Value := ""
        this.RefreshList()
    }

    OnDelete()
    {
        idx := this.list.GetNext(0)
        if (idx = 0)
            return
        SnippetsStore.RemoveAt(this.iniPath, idx)
        this.RefreshList()
    }

    CopySelected()
    {
        idx := this.list.GetNext(0)
        if (idx = 0)
            return
        snippets := SnippetsStore.LoadAll(this.iniPath)
        if (idx > snippets.Length)
            return
        A_Clipboard := snippets[idx].text
        ToolTip("Copiado: " snippets[idx].label)
        SetTimer(() => ToolTip(), -1500)
    }
}
```

- [ ] **Step 6.2: Validate**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Lib\Widgets\SnippetsManager.ahk"
echo "ExitCode: $LASTEXITCODE"
```

Expected: `ExitCode: 0`.

- [ ] **Step 6.3: Run test suite (storage tests still pass)**

Expected: ALL TESTS PASSED, 11 asserts.

- [ ] **Step 6.4: Commit**

```powershell
git add Botonera/Lib/Widgets/SnippetsManager.ahk
git commit -m "feat(botonera): SnippetsManager GUI popup (ListView + add/delete/copy)"
```

---

## Task 7: `JsonPretty` — pure format logic (TDD)

**Files:**
- Create: `Botonera/Lib/Widgets/JsonPretty.ahk` (pure module first)
- Create: `Botonera/Tests/Test_JsonPretty.ahk`

- [ ] **Step 7.1: Write failing test**

```autohotkey
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\Widgets\JsonPretty.ahk"
#Include "_AssertHelpers.ahk"

; Empty/whitespace input
AssertEq(JsonPrettyLogic.Format(""), "", "empty string")
AssertEq(JsonPrettyLogic.Format("   "), "", "whitespace only")

; Trivial object/array (empty containers stay on one line)
AssertEq(JsonPrettyLogic.Format("{}"), "{}", "empty object")
AssertEq(JsonPrettyLogic.Format("[]"), "[]", "empty array")
AssertEq(JsonPrettyLogic.Format("{ }"), "{}", "empty object with whitespace inside")

; Object with one key, indent 2 spaces
expected := "{`r`n  ""a"": 1`r`n}"
AssertEq(JsonPrettyLogic.Format("{""a"":1}"), expected, "single key object")

; Nested
expected2 := "{`r`n  ""a"": {`r`n    ""b"": 2`r`n  }`r`n}"
AssertEq(JsonPrettyLogic.Format("{""a"":{""b"":2}}"), expected2, "nested object")

; Array
expected3 := "[`r`n  1,`r`n  2,`r`n  3`r`n]"
AssertEq(JsonPrettyLogic.Format("[1,2,3]"), expected3, "simple array")

; String containing special chars stays intact
AssertContains(JsonPrettyLogic.Format("{""s"":""hi {there}""}"), """hi {there}""", "string with braces preserved")

; Invalid JSON returns empty + sets error message
JsonPrettyLogic.lastError := ""
res := JsonPrettyLogic.Format("{not json")
AssertEq(res, "", "invalid returns empty")
AssertContains(JsonPrettyLogic.lastError, "Invalid", "lastError set on invalid")

ReportarYSalir()
```

- [ ] **Step 7.2: Run test — FAILS**

Expected: CRASH (file not found).

- [ ] **Step 7.3: Implement `JsonPrettyLogic` in `Lib/Widgets/JsonPretty.ahk`**

```autohotkey
#Requires AutoHotkey v2.0

; ====================================================================
; JsonPretty.ahk
;   - JsonPrettyLogic: indenta una cadena JSON. Modulo PURO.
;   - JsonPretty: GUI popup (clase agregada despues).
;
; Implementacion: caracter por caracter. Tracking de nivel de anidacion.
; Respeta strings (no toca contenido entre comillas). Indenta con 2 espacios.
; Si la cadena no es JSON valido (mismatched braces/quotes), devuelve "" y
; popula JsonPrettyLogic.lastError.
; ====================================================================

class JsonPrettyLogic
{
    static lastError := ""

    static Format(input)
    {
        this.lastError := ""
        s := Trim(input)
        if (s = "")
            return ""

        out := ""
        depth := 0
        inString := false
        prev := ""
        i := 1
        len := StrLen(s)

        while (i <= len)
        {
            c := SubStr(s, i, 1)

            if inString
            {
                out .= c
                if (c = '"' && prev != "\")
                    inString := false
                prev := c
                i++
                continue
            }

            switch c
            {
                case '"':
                    inString := true
                    out .= c
                case "{", "[":
                    closer := (c = "{") ? "}" : "]"
                    ; Mirar adelante: si lo siguiente no-whitespace es el closer, emitir vacio
                    nextNonWs := this._PeekNextNonWs(s, i + 1)
                    if (nextNonWs = closer)
                    {
                        out .= c closer
                        ; consumir hasta el closer inclusive
                        i := this._FindNextNonWs(s, i + 1) + 1
                        prev := closer
                        continue
                    }
                    out .= c
                    depth++
                    out .= "`r`n" this._Indent(depth)
                case "}", "]":
                    depth--
                    if (depth < 0)
                    {
                        this.lastError := "Invalid JSON: unmatched closing bracket"
                        return ""
                    }
                    out .= "`r`n" this._Indent(depth) c
                case ",":
                    out .= c "`r`n" this._Indent(depth)
                case ":":
                    out .= ": "
                case " ", "`t", "`r", "`n":
                    ; skip whitespace outside strings
                default:
                    out .= c
            }
            prev := c
            i++
        }

        if inString
        {
            this.lastError := "Invalid JSON: unterminated string"
            return ""
        }
        if (depth != 0)
        {
            this.lastError := "Invalid JSON: unmatched opening bracket"
            return ""
        }
        return out
    }

    static _Indent(level)
    {
        out := ""
        loop level
            out .= "  "
        return out
    }

    static _PeekNextNonWs(s, startPos)
    {
        len := StrLen(s)
        i := startPos
        while (i <= len)
        {
            c := SubStr(s, i, 1)
            if (c != " " && c != "`t" && c != "`r" && c != "`n")
                return c
            i++
        }
        return ""
    }

    static _FindNextNonWs(s, startPos)
    {
        len := StrLen(s)
        i := startPos
        while (i <= len)
        {
            c := SubStr(s, i, 1)
            if (c != " " && c != "`t" && c != "`r" && c != "`n")
                return i
            i++
        }
        return len
    }
}
```

- [ ] **Step 7.4: Run test — verify PASSES**

Expected: `Test_JsonPretty.ahk === 11 tests, 0 failures ===`.

- [ ] **Step 7.5: Commit**

```powershell
git add Botonera/Lib/Widgets/JsonPretty.ahk Botonera/Tests/Test_JsonPretty.ahk
git commit -m "feat(botonera): JsonPrettyLogic with 2-space indent + invalid detection"
```

---

## Task 8: `JsonPretty` GUI popup (smoke only)

**Files:**
- Modify: `Botonera/Lib/Widgets/JsonPretty.ahk`

- [ ] **Step 8.1: Append GUI class**

```autohotkey
class JsonPretty
{
    gui := ""
    edIn := ""
    edOut := ""
    lblErr := ""

    Show()
    {
        if IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)
        {
            this.gui.Show()
            return
        }
        this.Build()
    }

    Build()
    {
        g := Gui("+AlwaysOnTop -DPIScale", "JSON Pretty")
        g.BackColor := "F8FAFC"
        g.SetFont("s10 c1F2937", "Segoe UI")
        g.MarginX := 12
        g.MarginY := 12

        g.Add("Text", "x12 y10 w250 h18", "Input:")
        this.edIn := g.Add("Edit", "x12 y32 w560 h120 +Multi -Wrap")
        this.edIn.SetFont("s10", "Cascadia Mono")

        btnFmt := g.Add("Button", "x12 y160 w120 h28", "Format")
        btnFmt.OnEvent("Click", (*) => this.OnFormat())
        btnPasteIn := g.Add("Button", "x140 y160 w160 h28", "📋 Pegar input")
        btnPasteIn.OnEvent("Click", (*) => (this.edIn.Value := A_Clipboard))
        btnCopyOut := g.Add("Button", "x308 y160 w160 h28", "📋 Copiar output")
        btnCopyOut.OnEvent("Click", (*) => this.CopyOutput())
        btnClose := g.Add("Button", "x476 y160 w96 h28", "Cerrar")
        btnClose.OnEvent("Click", (*) => g.Hide())

        this.lblErr := g.Add("Text", "x12 y196 w560 h18 cDC2626", "")

        g.Add("Text", "x12 y220 w250 h18", "Output:")
        this.edOut := g.Add("Edit", "x12 y242 w560 h160 +Multi -Wrap +ReadOnly")
        this.edOut.SetFont("s10 c15803D", "Cascadia Mono")

        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())

        this.gui := g
        g.Show("AutoSize")
    }

    OnFormat()
    {
        result := JsonPrettyLogic.Format(this.edIn.Value)
        if (result = "" && this.edIn.Value != "")
            this.lblErr.Value := JsonPrettyLogic.lastError
        else
            this.lblErr.Value := ""
        this.edOut.Value := result
    }

    CopyOutput()
    {
        if (this.edOut.Value = "")
            return
        A_Clipboard := this.edOut.Value
        ToolTip("Output copiado")
        SetTimer(() => ToolTip(), -1500)
    }
}
```

- [ ] **Step 8.2: Validate**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Lib\Widgets\JsonPretty.ahk"
```

Expected: `ExitCode: 0`.

- [ ] **Step 8.3: Commit**

```powershell
git add Botonera/Lib/Widgets/JsonPretty.ahk
git commit -m "feat(botonera): JsonPretty GUI popup (input/format/output panels)"
```

---

## Task 9: `RegexTester` — pure logic + GUI

**Files:**
- Create: `Botonera/Lib/Widgets/RegexTester.ahk`
- Create: `Botonera/Tests/Test_RegexTester.ahk`

- [ ] **Step 9.1: Write failing test**

```autohotkey
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\Widgets\RegexTester.ahk"
#Include "_AssertHelpers.ahk"

; No matches
AssertEq(RegexTesterLogic.FindAll("abc", "x").Length, 0, "no matches")

; Single literal match
res := RegexTesterLogic.FindAll("hello world", "world")
AssertEq(res.Length, 1, "one match")
AssertEq(res[1].text, "world", "match text")
AssertEq(res[1].pos, 7, "match pos")

; Multiple matches with regex
res := RegexTesterLogic.FindAll("a1 b22 c333", "\d+")
AssertEq(res.Length, 3, "three matches")
AssertEq(res[1].text, "1", "match 1")
AssertEq(res[2].text, "22", "match 2")
AssertEq(res[3].text, "333", "match 3")

; Invalid regex
RegexTesterLogic.lastError := ""
res := RegexTesterLogic.FindAll("anything", "[unclosed")
AssertEq(res.Length, 0, "invalid pattern returns empty")
AssertContains(RegexTesterLogic.lastError, "Invalid", "lastError set")

; Case insensitive flag
res := RegexTesterLogic.FindAll("Hello hello HELLO", "i)hello")
AssertEq(res.Length, 3, "case insensitive matches all")

ReportarYSalir()
```

- [ ] **Step 9.2: Run test — FAILS**

Expected: CRASH.

- [ ] **Step 9.3: Implement `RegexTesterLogic` + GUI in single file**

```autohotkey
#Requires AutoHotkey v2.0

; ====================================================================
; RegexTester.ahk
;   - RegexTesterLogic: encuentra todos los matches de un patron en un
;     texto. Modulo PURO. Setea lastError si el patron es invalido.
;   - RegexTester: GUI popup con dos Edit y lista de matches.
; ====================================================================

class RegexTesterLogic
{
    static lastError := ""

    static FindAll(text, pattern)
    {
        this.lastError := ""
        out := []
        if (text = "" || pattern = "")
            return out
        try
        {
            pos := 1
            while (matchPos := RegExMatch(text, pattern, &m, pos))
            {
                out.Push({text: m[0], pos: matchPos, length: StrLen(m[0])})
                ; avanzar al menos 1 char para evitar loop con match vacio
                pos := matchPos + Max(1, StrLen(m[0]))
                if (pos > StrLen(text))
                    break
            }
        }
        catch as e
        {
            this.lastError := "Invalid regex: " e.Message
            return []
        }
        return out
    }
}

class RegexTester
{
    gui := ""
    edText := ""
    edPattern := ""
    lvMatches := ""
    lblErr := ""

    Show()
    {
        if IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)
        {
            this.gui.Show()
            return
        }
        this.Build()
    }

    Build()
    {
        g := Gui("+AlwaysOnTop -DPIScale", "Regex Tester")
        g.BackColor := "F8FAFC"
        g.SetFont("s10 c1F2937", "Segoe UI")
        g.MarginX := 12
        g.MarginY := 12

        g.Add("Text", "x12 y10 w400 h18", "Patron (PCRE, ej: i)\d+):")
        this.edPattern := g.Add("Edit", "x12 y32 w560 h22")
        this.edPattern.SetFont("s10", "Cascadia Mono")
        this.edPattern.OnEvent("Change", (*) => this.OnChange())

        g.Add("Text", "x12 y62 w400 h18", "Texto:")
        this.edText := g.Add("Edit", "x12 y84 w560 h120 +Multi -Wrap")
        this.edText.SetFont("s10", "Cascadia Mono")
        this.edText.OnEvent("Change", (*) => this.OnChange())

        this.lblErr := g.Add("Text", "x12 y210 w560 h18 cDC2626", "")

        g.Add("Text", "x12 y234 w400 h18", "Matches:")
        this.lvMatches := g.Add("ListView", "x12 y256 w560 h140 -Multi", ["#", "Pos", "Len", "Match"])

        btnClose := g.Add("Button", "x460 y404 w112 h28", "Cerrar")
        btnClose.OnEvent("Click", (*) => g.Hide())

        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())

        this.gui := g
        g.Show("AutoSize")
    }

    OnChange()
    {
        matches := RegexTesterLogic.FindAll(this.edText.Value, this.edPattern.Value)
        if (RegexTesterLogic.lastError != "")
            this.lblErr.Value := RegexTesterLogic.lastError
        else
            this.lblErr.Value := ""

        this.lvMatches.Delete()
        for i, m in matches
            this.lvMatches.Add(, i, m.pos, m.length, m.text)
        this.lvMatches.ModifyCol(1, 30)
        this.lvMatches.ModifyCol(2, 50)
        this.lvMatches.ModifyCol(3, 50)
        this.lvMatches.ModifyCol(4, 410)
    }
}
```

- [ ] **Step 9.4: Run test — verify PASSES**

Expected: `Test_RegexTester.ahk === 8 tests, 0 failures ===`.

- [ ] **Step 9.5: Validate GUI portion**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Lib\Widgets\RegexTester.ahk"
```

Expected: `ExitCode: 0`.

- [ ] **Step 9.6: Commit**

```powershell
git add Botonera/Lib/Widgets/RegexTester.ahk Botonera/Tests/Test_RegexTester.ahk
git commit -m "feat(botonera): RegexTester (pure FindAll + GUI with live re-eval)"
```

---

## Task 10: `ProcessTimer` — pure history layer (TDD)

**Files:**
- Create: `Botonera/Lib/Widgets/ProcessTimer.ahk`
- Create: `Botonera/Tests/Test_ProcessTimer.ahk`

- [ ] **Step 10.1: Write failing test**

```autohotkey
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\Widgets\ProcessTimer.ahk"
#Include "_AssertHelpers.ahk"

testIni := A_Temp "\timer_test_" A_TickCount ".ini"

; Empty: no history
AssertEq(TimerHistory.LoadAll(testIni).Length, 0, "empty history")

; Add one
TimerHistory.Add(testIni, "Carga factura X", 87, "2026-05-01T14:30:00")
list := TimerHistory.LoadAll(testIni)
AssertEq(list.Length, 1, "one entry")
AssertEq(list[1].task, "Carga factura X", "task name")
AssertEq(list[1].seconds, 87, "seconds")
AssertEq(list[1].timestamp, "2026-05-01T14:30:00", "timestamp")

; Add second, last 10 cap respected
TimerHistory.Add(testIni, "Tarea2", 50, "2026-05-01T14:35:00")
AssertEq(TimerHistory.LoadAll(testIni).Length, 2, "two entries")

; Add 12 more — only last 10 kept
loop 12
    TimerHistory.Add(testIni, "T" A_Index, A_Index * 10, "ts" A_Index)
list := TimerHistory.LoadAll(testIni)
AssertEq(list.Length, 10, "capped at 10")
; Most recent first (newest is the last added)
AssertEq(list[1].task, "T12", "newest first")
AssertEq(list[10].task, "T3", "oldest last (T1 and T2 were dropped along with the original 2)")

; Cleanup
try FileDelete(testIni)

ReportarYSalir()
```

- [ ] **Step 10.2: Run test — FAILS (no module yet)**

Expected: CRASH.

- [ ] **Step 10.3: Implement `TimerHistory` + GUI**

```autohotkey
#Requires AutoHotkey v2.0

; ====================================================================
; ProcessTimer.ahk
;   - TimerHistory: lectura/escritura del historial. Modulo PURO. Cap=10.
;   - ProcessTimer: GUI con Start/Stop + lista de los ultimos 10.
; ====================================================================

class TimerHistory
{
    static cap := 10

    static LoadAll(iniPath)
    {
        out := []
        i := 1
        loop
        {
            task := IniRead(iniPath, "Timer.History", i ".task", "")
            if (task = "")
                break
            secsStr := IniRead(iniPath, "Timer.History", i ".seconds", "0")
            ts := IniRead(iniPath, "Timer.History", i ".timestamp", "")
            out.Push({task: task, seconds: Integer(secsStr), timestamp: ts})
            i++
        }
        return out
    }

    static Add(iniPath, task, seconds, timestamp)
    {
        existing := this.LoadAll(iniPath)
        ; Insertar al frente (mas reciente primero)
        existing.InsertAt(1, {task: task, seconds: seconds, timestamp: timestamp})
        ; Cap
        while (existing.Length > this.cap)
            existing.Pop()
        ; Reescribir todo
        try IniDelete(iniPath, "Timer.History")
        for i, e in existing
        {
            IniWrite(e.task, iniPath, "Timer.History", i ".task")
            IniWrite(e.seconds, iniPath, "Timer.History", i ".seconds")
            IniWrite(e.timestamp, iniPath, "Timer.History", i ".timestamp")
        }
    }
}

class ProcessTimer
{
    iniPath := ""
    gui := ""
    edTask := ""
    txtElapsed := ""
    btnStart := ""
    btnStop := ""
    lvHistory := ""
    startTick := 0
    timerHandler := 0
    running := false

    __New(iniPath)
    {
        this.iniPath := iniPath
    }

    Show()
    {
        if IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)
        {
            this.gui.Show()
            this.RefreshList()
            return
        }
        this.Build()
    }

    Build()
    {
        g := Gui("+AlwaysOnTop -DPIScale", "Process Timer")
        g.BackColor := "F8FAFC"
        g.SetFont("s10 c1F2937", "Segoe UI")
        g.MarginX := 12
        g.MarginY := 12

        g.Add("Text", "x12 y10 w120 h22", "Tarea:")
        this.edTask := g.Add("Edit", "x140 y8 w380 h22")

        this.btnStart := g.Add("Button", "x12 y40 w120 h32", "▶ Start")
        this.btnStart.OnEvent("Click", (*) => this.OnStart())
        this.btnStop := g.Add("Button", "x140 y40 w120 h32 Disabled", "■ Stop")
        this.btnStop.OnEvent("Click", (*) => this.OnStop())

        this.txtElapsed := g.Add("Text", "x270 y46 w250 h22 c1E40AF", "0:00")
        this.txtElapsed.SetFont("s14 Bold", "Cascadia Mono")

        g.Add("Text", "x12 y84 w400 h18", "Historial (ultimos 10):")
        this.lvHistory := g.Add("ListView", "x12 y106 w508 h180 -Multi", ["Tarea", "Segundos", "Timestamp"])

        btnClose := g.Add("Button", "x408 y294 w112 h28", "Cerrar")
        btnClose.OnEvent("Click", (*) => this.OnClose())

        g.OnEvent("Close", (*) => this.OnClose())
        g.OnEvent("Escape", (*) => this.OnClose())

        this.gui := g
        this.RefreshList()
        g.Show("AutoSize")
    }

    OnStart()
    {
        if this.running
            return
        if (Trim(this.edTask.Value) = "")
        {
            ToolTip("Escribi un nombre de tarea primero")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        this.startTick := A_TickCount
        this.running := true
        this.btnStart.Enabled := false
        this.btnStop.Enabled := true
        this.timerHandler := ObjBindMethod(this, "Tick")
        SetTimer(this.timerHandler, 250)
    }

    Tick()
    {
        if !this.running
            return
        elapsed := (A_TickCount - this.startTick) // 1000
        mins := elapsed // 60
        secs := Mod(elapsed, 60)
        this.txtElapsed.Value := Format("{}:{:02d}", mins, secs)
    }

    OnStop()
    {
        if !this.running
            return
        elapsed := (A_TickCount - this.startTick) // 1000
        if (this.timerHandler)
        {
            SetTimer(this.timerHandler, 0)
            this.timerHandler := 0
        }
        this.running := false
        this.btnStart.Enabled := true
        this.btnStop.Enabled := false

        ts := FormatTime(, "yyyy-MM-ddTHH:mm:ss")
        TimerHistory.Add(this.iniPath, this.edTask.Value, elapsed, ts)
        this.edTask.Value := ""
        this.txtElapsed.Value := "0:00"
        this.RefreshList()
    }

    OnClose()
    {
        if this.running
            this.OnStop()
        this.gui.Hide()
    }

    RefreshList()
    {
        this.lvHistory.Delete()
        for e in TimerHistory.LoadAll(this.iniPath)
            this.lvHistory.Add(, e.task, e.seconds, e.timestamp)
        this.lvHistory.ModifyCol(1, 240)
        this.lvHistory.ModifyCol(2, 80)
        this.lvHistory.ModifyCol(3, 180)
    }
}
```

- [ ] **Step 10.4: Run test — verify PASSES**

Expected: `Test_ProcessTimer.ahk === 9 tests, 0 failures ===`.

- [ ] **Step 10.5: Validate GUI**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Lib\Widgets\ProcessTimer.ahk"
```

Expected: `ExitCode: 0`.

- [ ] **Step 10.6: Commit**

```powershell
git add Botonera/Lib/Widgets/ProcessTimer.ahk Botonera/Tests/Test_ProcessTimer.ahk
git commit -m "feat(botonera): ProcessTimer (Start/Stop + history capped at 10)"
```

---

## Task 11: `SectionTools` — wire the 5 buttons to widgets + Cleaner inline

**Files:**
- Create: `Botonera/Lib/SectionTools.ahk`
- Modify: `Botonera/Botonera.ahk` (replace Tools stub)

- [ ] **Step 11.1: Create `SectionTools.ahk`**

```autohotkey
#Requires AutoHotkey v2.0
#Include "Section.ahk"
#Include "Cleaners.ahk"
#Include "Widgets\SnippetsManager.ahk"
#Include "Widgets\RegexTester.ahk"
#Include "Widgets\JsonPretty.ahk"
#Include "Widgets\ProcessTimer.ahk"

; g_clipboardBusy se declara en Botonera.ahk (single source) — ver task 11.2

class SectionTools extends Section
{
    title := "Tools"
    iniPath := ""
    snippets := ""
    regex := ""
    jsonPretty := ""
    timer := ""

    __New(iniPath)
    {
        this.iniPath := iniPath
        this.snippets := SnippetsManager(iniPath)
        this.regex := RegexTester()
        this.jsonPretty := JsonPretty()
        this.timer := ProcessTimer(iniPath)
    }

    Build(tab, idx)
    {
        g := tab.Parent
        tab.UseTab(idx)

        g.Add("Text", "x24 y48 w430 h20", "Utilities transversales (no acopladas a un sistema concreto).")

        btnClean := g.Add("Button", "x24 y76 w220 h36", "🧹 Limpiar Clipboard")
        btnClean.OnEvent("Click", (*) => this.OnClean())

        btnSnip := g.Add("Button", "x254 y76 w220 h36", "📋 Snippets")
        btnSnip.OnEvent("Click", (*) => this.snippets.Show())

        btnRegex := g.Add("Button", "x24 y120 w220 h36", "🔍 Regex Tester")
        btnRegex.OnEvent("Click", (*) => this.regex.Show())

        btnJson := g.Add("Button", "x254 y120 w220 h36", "{ } JSON Pretty")
        btnJson.OnEvent("Click", (*) => this.jsonPretty.Show())

        btnTimer := g.Add("Button", "x24 y164 w220 h36", "⏱ Process Timer")
        btnTimer.OnEvent("Click", (*) => this.timer.Show())
    }

    OnClean()
    {
        global g_clipboardBusy
        if g_clipboardBusy
            return
        g_clipboardBusy := true
        try
        {
            raw := A_Clipboard
            if (raw = "")
            {
                ToolTip("Clipboard vacio")
                SetTimer(() => ToolTip(), -1500)
                return
            }
            cleaned := NormalizarPrecio(raw)
            if (cleaned = "")
            {
                ToolTip("No se pudo normalizar como precio. Clipboard intacto.")
                SetTimer(() => ToolTip(), -2000)
                return
            }
            A_Clipboard := cleaned
            ToolTip("Limpio: " cleaned)
            SetTimer(() => ToolTip(), -1500)
        }
        finally
        {
            g_clipboardBusy := false
        }
    }
}
```

- [ ] **Step 11.2: Wire in `Botonera.ahk`**

Replace `Botonera.ahk`:

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "Lib\MainGui.ahk"
#Include "Lib\SectionWeb.ahk"
#Include "Lib\SectionTools.ahk"

global g_clipboardBusy := false

class StubSection extends Section
{
    title := ""
    __New(title) { this.title := title }
    Build(tab, idx) { tab.UseTab(idx); tab.Parent.Add("Text", "x24 y48", "(" this.title " - placeholder)") }
}

global g_iniPath := A_ScriptDir "\botonera.ini"
global g_mainGui := MainGui([
    StubSection("Wayfast"),
    SectionWeb(),
    SectionTools(g_iniPath)
], g_iniPath)

g_mainGui.Show()

^+b::g_mainGui.Toggle()
```

- [ ] **Step 11.3: Validate + smoke launch**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1500
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: validate `ExitCode: 0`, smoke `OK`.

- [ ] **Step 11.4: Run full test suite**

Expected: ALL TESTS PASSED, 39 asserts (5 IniPersist + 6 Snippets + 11 Json + 8 Regex + 9 Timer).

- [ ] **Step 11.5: Commit**

```powershell
git add Botonera/Lib/SectionTools.ahk Botonera/Botonera.ahk
git commit -m "feat(botonera): SectionTools wires 5 buttons + clipboard cleaner inline"
```

---

## Task 12: `WayfastUserButtons` — pure storage layer (TDD)

**Files:**
- Create: `Botonera/Lib/WayfastUserButtons.ahk`
- Create: `Botonera/Tests/Test_WayfastUserButtons.ahk`

The user-defined buttons are persisted; the GUI comes in Task 13.

- [ ] **Step 12.1: Write failing test**

```autohotkey
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\WayfastUserButtons.ahk"
#Include "_AssertHelpers.ahk"

testIni := A_Temp "\wayfast_test_" A_TickCount ".ini"

; Empty
AssertEq(WayfastUserButtons.LoadAll(testIni).Length, 0, "empty list")

; Add URL button
WayfastUserButtons.Add(testIni, "Wayfast login", "url", "http://internal.wayfast/")
list := WayfastUserButtons.LoadAll(testIni)
AssertEq(list.Length, 1, "one button")
AssertEq(list[1].label, "Wayfast login", "label")
AssertEq(list[1].kind, "url", "kind")
AssertEq(list[1].action, "http://internal.wayfast/", "action")

; Add snippet button
WayfastUserButtons.Add(testIni, "Firma std", "snippet", "Saludos`r`nAle")
AssertEq(WayfastUserButtons.LoadAll(testIni).Length, 2, "two buttons")
AssertEq(WayfastUserButtons.LoadAll(testIni)[2].kind, "snippet", "second is snippet")

; Remove first
WayfastUserButtons.RemoveAt(testIni, 1)
list := WayfastUserButtons.LoadAll(testIni)
AssertEq(list.Length, 1, "one after remove")
AssertEq(list[1].label, "Firma std", "remaining is Firma")

; Cleanup
try FileDelete(testIni)

ReportarYSalir()
```

- [ ] **Step 12.2: Run test — FAILS**

Expected: CRASH.

- [ ] **Step 12.3: Implement `WayfastUserButtons`**

```autohotkey
#Requires AutoHotkey v2.0

; ====================================================================
; WayfastUserButtons.ahk - Persistencia de botones definidos por el
; usuario en la seccion Wayfast. Modulo PURO.
;
; Cada boton tiene:
;   label  - texto visible
;   kind   - "url" | "snippet" | "command"
;   action - segun kind:
;            url     -> URL completa (ej. "https://...")
;            snippet -> texto a copiar al clipboard al click
;            command -> comando a ejecutar via Run()
; ====================================================================

class WayfastUserButtons
{
    static LoadAll(iniPath)
    {
        out := []
        i := 1
        loop
        {
            label := IniRead(iniPath, "Wayfast.UserButtons", i ".label", "")
            if (label = "")
                break
            kind := IniRead(iniPath, "Wayfast.UserButtons", i ".kind", "url")
            action := IniRead(iniPath, "Wayfast.UserButtons", i ".action", "")
            out.Push({label: label, kind: kind, action: action})
            i++
        }
        return out
    }

    static Add(iniPath, label, kind, action)
    {
        existing := this.LoadAll(iniPath)
        idx := existing.Length + 1
        IniWrite(label, iniPath, "Wayfast.UserButtons", idx ".label")
        IniWrite(kind, iniPath, "Wayfast.UserButtons", idx ".kind")
        IniWrite(action, iniPath, "Wayfast.UserButtons", idx ".action")
    }

    static RemoveAt(iniPath, index)
    {
        existing := this.LoadAll(iniPath)
        if (index < 1 || index > existing.Length)
            return
        try IniDelete(iniPath, "Wayfast.UserButtons")
        newIdx := 1
        for i, b in existing
        {
            if (i = index)
                continue
            IniWrite(b.label, iniPath, "Wayfast.UserButtons", newIdx ".label")
            IniWrite(b.kind, iniPath, "Wayfast.UserButtons", newIdx ".kind")
            IniWrite(b.action, iniPath, "Wayfast.UserButtons", newIdx ".action")
            newIdx++
        }
    }
}
```

- [ ] **Step 12.4: Run test — verify PASSES**

Expected: `Test_WayfastUserButtons.ahk === 8 tests, 0 failures ===`.

- [ ] **Step 12.5: Commit**

```powershell
git add Botonera/Lib/WayfastUserButtons.ahk Botonera/Tests/Test_WayfastUserButtons.ahk
git commit -m "feat(botonera): WayfastUserButtons store (url/snippet/command persistence)"
```

---

## Task 13: `SectionWayfast` — scaffold UI + dynamic user buttons

**Files:**
- Create: `Botonera/Lib/SectionWayfast.ahk`
- Modify: `Botonera/Botonera.ahk` (remove last stub)

- [ ] **Step 13.1: Create `SectionWayfast.ahk`**

```autohotkey
#Requires AutoHotkey v2.0
#Include "Section.ahk"
#Include "WayfastUserButtons.ahk"

; ====================================================================
; SectionWayfast - Scaffold para el rol de parser.
;
; Inicio: solo un texto + un boton "Agregar...". Los botones que el
; operador define en runtime se persisten en INI y se rerenderizan al
; reabrir la app.
;
; PUNTO DE EXTENSION: cuando un patron se repita lo suficiente como
; para justificar codigo dedicado, agregalo como metodo de esta clase
; y un boton hardcoded en Build(). Los user buttons del INI son la
; primera iteracion experimental.
; ====================================================================

class SectionWayfast extends Section
{
    title := "Wayfast"
    iniPath := ""
    tab := ""
    tabIdx := 0
    addPopup := ""
    userButtons := []
    userButtonCtrls := []

    __New(iniPath)
    {
        this.iniPath := iniPath
    }

    Build(tab, idx)
    {
        this.tab := tab
        this.tabIdx := idx
        g := tab.Parent
        tab.UseTab(idx)

        g.Add("Text", "x24 y48 w430 h36",
            "Aca van atajos de Wayfast a medida que descubras patrones.`nUsa '+ Agregar' para sumar uno rapido.")

        btnAdd := g.Add("Button", "x24 y92 w160 h32", "+ Agregar nuevo boton")
        btnAdd.OnEvent("Click", (*) => this.ShowAddPopup())

        ; ; TODO: agregar mas botones especializados en codigo cuando los descubras.
        this.RenderUserButtons()
    }

    RenderUserButtons()
    {
        g := this.tab.Parent
        this.tab.UseTab(this.tabIdx)

        ; Limpiar render previo
        for c in this.userButtonCtrls
            try c.Visible := false
        this.userButtonCtrls := []

        this.userButtons := WayfastUserButtons.LoadAll(this.iniPath)
        baseY := 134
        for i, b in this.userButtons
        {
            row := i - 1
            x := 24 + (Mod(row, 2) * 230)
            y := baseY + ((row // 2) * 40)
            ctrl := g.Add("Button", "x" x " y" y " w220 h32", b.label)
            ctrl.OnEvent("Click", this.MakeHandler(i))
            this.userButtonCtrls.Push(ctrl)
        }
        this.tab.UseTab()
    }

    MakeHandler(index)
    {
        return ((*) => this.ExecuteButton(index))
    }

    ExecuteButton(index)
    {
        if (index > this.userButtons.Length)
            return
        b := this.userButtons[index]
        switch b.kind
        {
            case "url":
                Run(b.action)
            case "snippet":
                A_Clipboard := b.action
                ToolTip("Snippet copiado: " b.label)
                SetTimer(() => ToolTip(), -1500)
            case "command":
                try Run(b.action)
        }
    }

    ShowAddPopup()
    {
        if IsObject(this.addPopup) && WinExist("ahk_id " this.addPopup.Hwnd)
        {
            this.addPopup.Show()
            return
        }
        p := Gui("+AlwaysOnTop -DPIScale +Owner" this.tab.Parent.Hwnd, "Agregar boton Wayfast")
        p.BackColor := "F8FAFC"
        p.SetFont("s10 c1F2937", "Segoe UI")
        p.MarginX := 12
        p.MarginY := 12

        p.Add("Text", "x12 y12 w120 h22", "Etiqueta:")
        edLabel := p.Add("Edit", "x140 y10 w280 h22")

        p.Add("Text", "x12 y42 w120 h22", "Tipo:")
        ddKind := p.Add("DropDownList", "x140 y40 w160 h140 Choose1", ["url", "snippet", "command"])

        p.Add("Text", "x12 y72 w120 h22", "Accion:")
        edAction := p.Add("Edit", "x140 y70 w280 h60 +Multi")

        btnSave := p.Add("Button", "x140 y140 w120 h28", "Guardar")
        btnCancel := p.Add("Button", "x270 y140 w120 h28", "Cancelar")

        btnSave.OnEvent("Click", (*) => this.OnSavePopup(p, edLabel, ddKind, edAction))
        btnCancel.OnEvent("Click", (*) => p.Hide())
        p.OnEvent("Close", (*) => p.Hide())
        p.OnEvent("Escape", (*) => p.Hide())

        this.addPopup := p
        p.Show("AutoSize")
    }

    OnSavePopup(p, edLabel, ddKind, edAction)
    {
        label := Trim(edLabel.Value)
        kind := ddKind.Text
        action := edAction.Value
        if (label = "" || action = "")
        {
            ToolTip("Etiqueta y accion no pueden estar vacias")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        WayfastUserButtons.Add(this.iniPath, label, kind, action)
        edLabel.Value := ""
        edAction.Value := ""
        p.Hide()
        this.RenderUserButtons()
    }

    OnShow()
    {
        this.RenderUserButtons()
    }
}
```

- [ ] **Step 13.2: Wire in `Botonera.ahk`** (replace last stub)

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "Lib\MainGui.ahk"
#Include "Lib\SectionWayfast.ahk"
#Include "Lib\SectionWeb.ahk"
#Include "Lib\SectionTools.ahk"

global g_clipboardBusy := false

global g_iniPath := A_ScriptDir "\botonera.ini"
global g_mainGui := MainGui([
    SectionWayfast(g_iniPath),
    SectionWeb(),
    SectionTools(g_iniPath)
], g_iniPath)

g_mainGui.Show()

^+b::g_mainGui.Toggle()
```

(`StubSection` class deleted — no longer needed. `g_clipboardBusy` se mantiene de Task 11.)

- [ ] **Step 13.3: Validate + smoke launch**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate "C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk"
$proc = Start-Process -FilePath "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","C:\Users\Usuario\Desktop\Asignet\Botonera\Botonera.ahk" -NoNewWindow -PassThru
Start-Sleep -Milliseconds 1800
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "OK" } else { "FAIL ($($proc.ExitCode))" }
```

Expected: `ExitCode: 0`, `OK`.

- [ ] **Step 13.4: Run full test suite (final)**

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Botonera\Tests\runner.ps1"
```

Expected: ALL TESTS PASSED, 47 asserts.

- [ ] **Step 13.5: Commit**

```powershell
git add Botonera/Lib/SectionWayfast.ahk Botonera/Botonera.ahk
git commit -m "feat(botonera): SectionWayfast scaffold with INI-persisted user buttons"
```

---

## Task 14: README + extension docs (the "esqueleto" guide)

**Files:**
- Create: `Botonera/README.md`

This is the documentation that makes the "esqueleto para futuras automatizaciones" concrete. Without it, the extensibility is implicit and a future you (or somebody else) won't see how to plug in.

- [ ] **Step 14.1: Write `Botonera/README.md`**

```markdown
# Botonera

Launcher GUI hermana de QuickEntry. Tres secciones (Wayfast / Web / Tools) en un Tab3.

Disenada como **esqueleto extensible** para automatizar tareas del rol de parser.

## Como correr

```
AutoHotkey64.exe Botonera.ahk
```

`Ctrl+Shift+B` toggle show/hide.

## Tests

```powershell
powershell -ExecutionPolicy Bypass -File Tests\runner.ps1
```

## Extender la botonera (3 niveles)

### Nivel 1: Agregar un boton de usuario en runtime (sin codear)

Click en la seccion **Wayfast** > "+ Agregar nuevo boton". Tres tipos:
- **url**: abre una URL al click.
- **snippet**: copia un texto al clipboard al click.
- **command**: ejecuta un comando del sistema (cuidado).

Persiste en `botonera.ini` seccion `[Wayfast.UserButtons]`. Sobrevive reinicios.

### Nivel 2: Agregar un boton hardcoded a una seccion existente

Editar la clase de la seccion (ej. `Lib/SectionTools.ahk`):

```autohotkey
; en Build():
btnNuevo := g.Add("Button", "x24 y220 w220 h36", "Mi accion")
btnNuevo.OnEvent("Click", (*) => this.OnMiAccion())

; en otro lugar de la clase:
OnMiAccion()
{
    ; ...
}
```

3 lineas en `Build()` + el metodo. Recompilar = reiniciar el script.

### Nivel 3: Agregar una seccion entera

1. Crear `Lib/SectionMiNueva.ahk` que extienda `Section`:

```autohotkey
#Include "Section.ahk"

class SectionMiNueva extends Section
{
    title := "MiNueva"
    Build(tab, idx)
    {
        tab.UseTab(idx)
        ; ...
    }
}
```

2. Registrar en `Botonera.ahk`:

```autohotkey
#Include "Lib\SectionMiNueva.ahk"

global g_mainGui := MainGui([
    SectionWayfast(g_iniPath),
    SectionWeb(),
    SectionTools(g_iniPath),
    SectionMiNueva()  ; <-- nueva
], g_iniPath)
```

## Estructura

(Ver `docs/superpowers/specs/2026-05-01-botonera-design.md` para diseno completo.)

## Aislamiento de QuickEntry

`Botonera/Lib/Cleaners.ahk` es **snapshot copia** de `../Lib/Cleaners.ahk` (no `#Include` cross-folder). Cambios en uno no afectan al otro.
```

- [ ] **Step 14.2: Commit**

```powershell
git add Botonera/README.md
git commit -m "docs(botonera): README with 3-level extension guide"
```

---

## Self-Review Checklist (run before declaring plan done)

After all 14 tasks:

- [ ] **Spec coverage:** every section in `2026-05-01-botonera-design.md` maps to a task. ✓
  - Sec 3 architecture → Task 0–13
  - Sec 5.1 entry → Task 2
  - Sec 5.2 MainGui → Task 2
  - Sec 5.3 Section contract → Task 3
  - Sec 5.4 Wayfast → Task 12, 13
  - Sec 5.5 Web → Task 4
  - Sec 5.6 Tools 5 buttons → Task 5–11
  - Sec 6 Data flow → covered in Tasks 1, 5, 10, 11, 12
  - Sec 8 Testing → Tasks 1, 5, 7, 9, 10, 12 (pure modules)
  - Sec 9 Extension points → Task 14 (README)
  - Sec 10 Out-of-scope → respected (no OCR, no login, no diff, no validator tester)
- [ ] **No placeholders:** every step has actual code or commands. ✓
- [ ] **Type consistency:** `IniPersist.LoadInt`, `SnippetsStore.LoadAll`, `WayfastUserButtons.LoadAll`, `TimerHistory.LoadAll`, `JsonPrettyLogic.Format`, `RegexTesterLogic.FindAll` — names consistent across tasks. ✓
- [ ] **All tests pass:** final state should have 47 asserts, ALL TESTS PASSED. ✓
- [ ] **Smoke launch works:** Botonera arranca con tres secciones reales (no stubs). ✓

## Final assert tally

| Test file | Asserts |
|---|---|
| Test_IniPersist | 5 |
| Test_SnippetsManager | 6 |
| Test_JsonPretty | 11 |
| Test_RegexTester | 8 |
| Test_ProcessTimer | 9 |
| Test_WayfastUserButtons | 8 |
| **Total** | **47** |

## Out of scope (no se implementa en este plan)

- Edicion in-place de user buttons existentes (solo Add/Remove). Si surge la necesidad, sumar `WayfastUserButtons.UpdateAt` + UI.
- Hotkeys per-section (la API `Section.RegisterHotkeys()` existe pero no se usa todavia).
- Persistencia del estado del Process Timer (si el timer esta corriendo y cerras la app, se pierde). Spec dice "save state to INI so timers resume" — diferido a un futuro plan si se necesita.
- Migracion a Plugin Loader (Enfoque 2 de la spec). Refactor cuando una seccion crezca a 15+ botones.
