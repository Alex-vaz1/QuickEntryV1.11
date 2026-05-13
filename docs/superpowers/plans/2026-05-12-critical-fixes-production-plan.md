# Critical fixes para producción multi-operador — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (en sesión, secuencial). Steps usan checkbox (`- [ ]`).

**Goal:** Resolver los 6 Critical detectados por el senior review previo. Convertir el código de "demo del autor" a "deployable a un piloto controlado de 2-3 operadores". Después del piloto, sumar los Important del senior review en un próximo plan.

**Architecture:** 8 tasks secuenciales. Crea 2 módulos nuevos chicos (`Lib/Logger.ahk`, `Lib/PasteMutex.ahk`). Modifica `QuickEntry.ahk` (entry point, varios cambios coordinados) y `Lib/PegadoEspecial.ahk` (refactor de mutex). Cambio mínimo en `Lib/MainHud.ahk` (1 cambio en title del HUD). Tests nuevos para Logger + PasteMutex.

**Tech Stack:** AutoHotkey v2.0, runner.ps1 portable, asserts custom. Path AHK64: `C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe`.

**Baseline asserts:** 757 (post-Fase-6).
**Target post-Fase-7:** 757 + N (N≈10-15 nuevos de Logger + PasteMutex). Target específico: **770**.

**Senior review original:** ver [`2026-05-12-cleanup-quickentry-final.md`](2026-05-12-cleanup-quickentry-final.md) §Fase 5 y la review previa en transcripto.

**Backup:** crear `_archive/2026-05-12-post-fase6.zip` antes de empezar (Task 0).

---

## Los 6 Critical del senior review (recap)

| C | Critical issue | Fix tactic |
|---|---|---|
| C1 | Falta `#SingleInstance Force` → doble instancia corrompe cola | 1 línea en `QuickEntry.ahk:1` |
| C2 | `try/finally` sin `catch` en `DoSoltar`/`DoHeaderScan` → stacktrace al operador | Agregar `catch (e)` con tooltip + log + cleanup |
| C3 | Cero logging productivo → soporte multi-operador imposible | Nuevo `Lib/Logger.ahk` con file logging + rotación |
| C4 | Schema hardcoded `CrearAsignetHeaderV1()` → multi-empresa requiere editar fuente | Registry + INI `[General]\Schema=` |
| C5 | Captura continua opt-out invisible → operador nuevo confunde | Title del HUD muestra "CAPTURA ACTIVA" cuando arm |
| C6 | `pegadoEnCurso` global cross-file no encapsulada → bomba para próximo dev | Nuevo `Lib/PasteMutex.ahk` (clase con static methods) |

---

## File Structure (estado final post-Fase-7)

```
QuickEntry-quickestEntryV1.11/
├── QuickEntry.ahk                  ← MOD: #SingleInstance, schema registry, try/catch+log, PasteMutex
├── Lib/
│   ├── Logger.ahk                  ← NEW: file logging + rotación
│   ├── PasteMutex.ahk              ← NEW: encapsula pegadoEnCurso como clase
│   ├── PegadoEspecial.ahk          ← MOD: usa PasteMutex en vez de global
│   ├── MainHud.ahk                 ← MOD: title bar refleja CAPTURA ACTIVA
│   └── (resto sin cambios)
└── Tests/
    ├── Test_Logger.ahk             ← NEW: ~7 asserts (write, rotation, no-crash si folder missing)
    ├── Test_PasteMutex.ahk         ← NEW: ~6 asserts (acquire, release, idempotencia, no-recursive)
    └── (resto sin cambios)
```

---

## Task 0: Backup

**Files:**
- Create: `_archive/2026-05-12-post-fase6.zip`

- [ ] **Step 0.1: Crear backup zip del estado post-Fase-6**

```powershell
$exclude = @('_archive', '.git')
$items = Get-ChildItem -Path . | Where-Object { $_.Name -notin $exclude }
Compress-Archive -Path $items -DestinationPath _archive/2026-05-12-post-fase6.zip -CompressionLevel Optimal -Force
$z = Get-Item _archive/2026-05-12-post-fase6.zip
"Backup: $($z.Name) ($($z.Length) bytes)"
if ($z.Length -lt 100000) { throw "Zip demasiado chico" } else { "OK" }
```
Expected: size > 100KB, OK.

---

## Task 1 (C1): `#SingleInstance Force`

**Files:**
- Modify: `QuickEntry.ahk:1-2`

- [ ] **Step 1.1: Agregar la directiva al tope**

Reemplazar la línea 1 actual (`#Requires AutoHotkey v2.0`) por:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
```

Razón: sin esta directiva, una segunda instancia accidental (Auto-launch + double-click, dos shortcuts, etc.) registra DOS `OnClipboardChange HandlerCaptura`. Cada `Ctrl+C` dispara `engine.PushRaw` sobre dos engines distintos → cola corrupta. `Force` mata la instancia vieja y lanza la nueva (vs. `Ignore` que mantiene la vieja). `Force` es más seguro para el operador (siempre tiene la instancia más reciente, sin estado raro).

- [ ] **Step 1.2: Validar sintaxis**

```powershell
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","/validate","QuickEntry.ahk" -Wait -PassThru -NoNewWindow
```
Expected: exit 0.

- [ ] **Step 1.3: Test gate**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 2>&1 | Select-Object -Last 3
```
Expected: `Total asserts: 757`, `ALL TESTS PASSED`, exit 0.

---

## Task 2 (C3 — Logger module primero, antes de C2)

**Files:**
- Create: `Lib/Logger.ahk`
- Create: `Tests/Test_Logger.ahk`

- [ ] **Step 2.1: Crear `Lib/Logger.ahk`**

Crear el archivo con el contenido exacto:

```ahk
#Requires AutoHotkey v2.0

; Logger.ahk — file logging simple para diagnostico multi-operador.
;
; Output: %APPDATA%\QuickEntry\events.log
; Format: [YYYY-MM-DD HH:mm:ss] LEVEL EVENT=name kv1=val1 kv2=val2 ...
; Rotation: cuando events.log > 1 MB, rename a events.log.old (1 backup).

class Logger
{
    static MAX_BYTES := 1048576  ; 1 MB
    static _initialized := false
    static _logPath := ""

    static _Init()
    {
        if Logger._initialized
            return
        dir := A_AppData "\QuickEntry"
        if !DirExist(dir)
            DirCreate(dir)
        Logger._logPath := dir "\events.log"
        Logger._initialized := true
    }

    ; Path actual del log. Util para tests / soporte ("mandame events.log").
    static Path
    {
        get {
            Logger._Init()
            return Logger._logPath
        }
    }

    ; Escribe una linea estructurada. Rota si el archivo excede MAX_BYTES.
    ; level: "INFO" | "WARN" | "ERROR"
    ; event: nombre corto (ej "paste_batch")
    ; kvMap: Map de pares clave-valor opcionales
    static Log(level, event, kvMap := "")
    {
        Logger._Init()
        try {
            if FileExist(Logger._logPath) {
                size := FileGetSize(Logger._logPath)
                if (size > Logger.MAX_BYTES)
                    Logger._Rotate()
            }
            ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            line := "[" ts "] " level " EVENT=" event
            if IsObject(kvMap) {
                for k, v in kvMap
                    line .= " " k "=" Logger._EscapeValue(v)
            }
            FileAppend(line "`n", Logger._logPath, "UTF-8")
        } catch (e) {
            ; Log silencioso si falla escritura (disco lleno, permisos): no propagar.
            ; El operador ya tiene problemas mas grandes que un log roto.
        }
    }

    static Info(event, kvMap := "")  => Logger.Log("INFO", event, kvMap)
    static Warn(event, kvMap := "")  => Logger.Log("WARN", event, kvMap)
    static Error(event, kvMap := "") => Logger.Log("ERROR", event, kvMap)

    static _Rotate()
    {
        oldPath := Logger._logPath ".old"
        if FileExist(oldPath)
            FileDelete(oldPath)
        FileMove(Logger._logPath, oldPath)
    }

    ; Espacios y `=` en values rompen el grep; reemplazarlos.
    static _EscapeValue(v)
    {
        s := String(v)
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, " ", "_")
        return s
    }
}
```

- [ ] **Step 2.2: Crear `Tests/Test_Logger.ahk`**

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Off

#Include "..\Lib\Logger.ahk"
#Include "_AssertHelpers.ahk"

; Setup: redirigir log a un path temp para no contaminar APPDATA del operador.
testDir := A_Temp "\QuickEntry_Test_Logger"
if DirExist(testDir)
    DirDelete(testDir, true)
DirCreate(testDir)
Logger._logPath := testDir "\events.log"
Logger._initialized := true

; --- 1. Log.Info crea el archivo y escribe una linea bien formada
Logger.Info("test_event", Map("slot", 3, "value", "ok"))
AssertEq(FileExist(Logger._logPath) ? 1 : 0, 1, "Info crea el archivo")
content := FileRead(Logger._logPath)
AssertContains(content, "INFO EVENT=test_event", "linea contiene INFO + event name")
AssertContains(content, "slot=3", "kv slot serializado")
AssertContains(content, "value=ok", "kv value serializado")

; --- 2. Niveles distintos
Logger.Warn("test_warn")
Logger.Error("test_error", Map("err", "x"))
content := FileRead(Logger._logPath)
AssertContains(content, "WARN EVENT=test_warn", "Warn escribe WARN")
AssertContains(content, "ERROR EVENT=test_error", "Error escribe ERROR")

; --- 3. Escape de valores con espacios
Logger.Info("escape_test", Map("msg", "hello world"))
content := FileRead(Logger._logPath)
AssertContains(content, "msg=hello_world", "espacios reemplazados por _")

; --- 4. Rotación cuando supera MAX_BYTES
; Forzamos MAX_BYTES bajo para no escribir 1MB en el test.
Logger.MAX_BYTES := 200
loop 20 {
    Logger.Info("fill", Map("i", A_Index, "data", "aaaaaaaaaaaaaaaaaaaa"))
}
oldPath := Logger._logPath ".old"
AssertEq(FileExist(oldPath) ? 1 : 0, 1, "rotacion crea .old")

; Cleanup
DirDelete(testDir, true)

ReportarYSalir()
```

- [ ] **Step 2.3: Correr test del Logger aislado**

```powershell
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 Tests/Test_Logger.ahk
```
Expected: salida termina con `=== 8 tests, 0 failures ===`, exit 0.

- [ ] **Step 2.4: Test gate full**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 2>&1 | Select-Object -Last 12
```
Expected: nuevo file `Test_Logger.ahk` aparece, `Total asserts: 765` (757 + 8), `ALL TESTS PASSED`.

---

## Task 3 (C6): PasteMutex module

**Files:**
- Create: `Lib/PasteMutex.ahk`
- Create: `Tests/Test_PasteMutex.ahk`

- [ ] **Step 3.1: Crear `Lib/PasteMutex.ahk`**

```ahk
#Requires AutoHotkey v2.0

; PasteMutex.ahk — encapsula el lock que coordina:
;   - PegadoEspecial (^+v): paste con limpieza standalone
;   - HandlerCaptura (OnClipboardChange): captura batch al engine
;   - DoSoltar / DoHeaderScan: batch paste / scan del form
;
; Antes de Fase-7 esto era una global `pegadoEnCurso` cross-file. Esta clase
; centraliza la convencion para que un tercer flujo no pueda olvidar tomar el lock.

class PasteMutex
{
    static _locked := false

    ; readonly property — true si algun flujo tiene el lock tomado.
    static IsLocked
    {
        get => PasteMutex._locked
    }

    ; Intenta adquirir el lock. Retorna true si lo tomó, false si ya estaba tomado.
    ; Caller debe `if !PasteMutex.Acquire() return` o equivalente.
    static Acquire()
    {
        if PasteMutex._locked
            return false
        PasteMutex._locked := true
        return true
    }

    ; Libera el lock. Idempotente: si ya esta liberado, no hace nada.
    static Release()
    {
        PasteMutex._locked := false
    }
}
```

- [ ] **Step 3.2: Crear `Tests/Test_PasteMutex.ahk`**

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Off

#Include "..\Lib\PasteMutex.ahk"
#Include "_AssertHelpers.ahk"

; Estado inicial limpio en cada test
PasteMutex.Release()

; --- 1. Estado inicial: no locked
AssertEq(PasteMutex.IsLocked, false, "estado inicial: IsLocked=false")

; --- 2. Acquire toma el lock
ok := PasteMutex.Acquire()
AssertEq(ok, true, "primer Acquire retorna true")
AssertEq(PasteMutex.IsLocked, true, "tras Acquire: IsLocked=true")

; --- 3. Acquire mientras lockeado retorna false (no-recursive)
ok2 := PasteMutex.Acquire()
AssertEq(ok2, false, "segundo Acquire retorna false")
AssertEq(PasteMutex.IsLocked, true, "sigue locked despues del segundo Acquire fallido")

; --- 4. Release libera
PasteMutex.Release()
AssertEq(PasteMutex.IsLocked, false, "tras Release: IsLocked=false")

; --- 5. Release idempotente
PasteMutex.Release()
AssertEq(PasteMutex.IsLocked, false, "Release doble no rompe nada")

; --- 6. Acquire post-Release funciona
ok3 := PasteMutex.Acquire()
AssertEq(ok3, true, "Acquire despues de Release funciona")
PasteMutex.Release()

ReportarYSalir()
```

- [ ] **Step 3.3: Correr Test_PasteMutex aislado**

```powershell
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 Tests/Test_PasteMutex.ahk
```
Expected: `=== 7 tests, 0 failures ===`, exit 0.

- [ ] **Step 3.4: Test gate full**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 2>&1 | Select-Object -Last 12
```
Expected: `Total asserts: 772` (765 + 7), `ALL TESTS PASSED`.

---

## Task 4 (C6 wire): refactorizar `pegadoEnCurso` a `PasteMutex` en producción

**Files:**
- Modify: `Lib/PegadoEspecial.ahk` (remueve `global pegadoEnCurso`, usa PasteMutex)
- Modify: `QuickEntry.ahk` (remueve `pegadoEnCurso` de declaraciones globales en funciones)

- [ ] **Step 4.1: Editar `Lib/PegadoEspecial.ahk`**

Read el archivo. Localizar la línea `global pegadoEnCurso := false` (aprox línea 25). Reemplazarla por:

```ahk
; pegadoEnCurso migrado a PasteMutex (Lib/PasteMutex.ahk) en Fase-7
; para encapsular el lock cross-file y evitar que un nuevo flujo
; olvide tomarlo. Mantenemos las llamadas en PegadoEspecial via PasteMutex.
```

(Borrar la declaración global; el comentario explica por qué.)

Luego en el cuerpo de `PegadoEspecial()`, reemplazar el bloque del lock antiguo:

```ahk
if (pegadoEnCurso)
    return
pegadoEnCurso := true
```

Por:

```ahk
if !PasteMutex.Acquire()
    return
```

Y reemplazar el `pegadoEnCurso := false` en el `finally` por:

```ahk
PasteMutex.Release()
```

Quitar también el `global pegadoEnCurso` que esté dentro del cuerpo de la función.

- [ ] **Step 4.2: Editar `QuickEntry.ahk` para usar PasteMutex**

Read el archivo. En cada función que usa `pegadoEnCurso`:

`HandlerCaptura(tipoData)` (línea ~71):
- Quitar `pegadoEnCurso` del `global engine, pegadoEnCurso, HOTKEY_OMITIR` → dejar `global engine, HOTKEY_OMITIR`.
- Reemplazar `if (!engine.isCapturing || pegadoEnCurso)` por `if (!engine.isCapturing || PasteMutex.IsLocked)`.

`DoSoltar(interactive := false)` (línea ~146):
- Quitar `pegadoEnCurso` del `global engine, pegadoEnCurso, hud` → `global engine, hud`.
- Reemplazar `if (pegadoEnCurso) return` por `if (PasteMutex.IsLocked) return`.
- Reemplazar `pegadoEnCurso := true` por `PasteMutex.Acquire()`.
- Reemplazar `pegadoEnCurso := false` (en el `finally`) por `PasteMutex.Release()`.

`DoHeaderScan(interactive := false)` (línea ~244):
- Mismo refactor: quitar `pegadoEnCurso` de las globals, reemplazar set/clear por `PasteMutex.Acquire()` / `PasteMutex.Release()`, reemplazar reads por `PasteMutex.IsLocked`.

- [ ] **Step 4.3: Agregar `#Include "Lib\PasteMutex.ahk"` al tope de QuickEntry.ahk**

Justo después de los `#Include` existentes (entre `#Include "Lib\Cleaners.ahk"` y los demás), agregar:

```ahk
#Include "Lib\PasteMutex.ahk"
```

- [ ] **Step 4.4: Validar sintaxis productivos**

```powershell
$ahk = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
foreach ($f in @('QuickEntry.ahk','Lib/PegadoEspecial.ahk','Lib/PasteMutex.ahk')) {
  $p = Start-Process $ahk -ArgumentList "/ErrorStdOut=utf-8","/validate",$f -Wait -PassThru -NoNewWindow -RedirectStandardError "$env:TEMP\v.err" -RedirectStandardOutput "$env:TEMP\v.out"
  if ($p.ExitCode -ne 0) { throw "$f fail" } else { "OK $f" }
}
```
Expected: 3 OK lines.

- [ ] **Step 4.5: Test gate**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 2>&1 | Select-Object -Last 12
```
Expected: `Total asserts: 772`, `ALL TESTS PASSED`.

---

## Task 5 (C2 + C3 wire): try/catch + log en `DoSoltar` y `DoHeaderScan`

**Files:**
- Modify: `QuickEntry.ahk` (las dos funciones)

- [ ] **Step 5.1: Agregar `#Include "Lib\Logger.ahk"` al tope de QuickEntry.ahk**

Después del Include de PasteMutex (Step 4.3):

```ahk
#Include "Lib\Logger.ahk"
```

- [ ] **Step 5.2: Editar `DoSoltar` para agregar catch + log**

Localizar el bloque `try { ... engine.PasteBatch() ... }` en `DoSoltar`. Reemplazar la estructura actual:

```ahk
    try
    {
        SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
        Sleep 30
        engine.PasteBatch()
    }
    finally
    {
        hud.SaveLastPaste()
        engine.Reset()
        hud.ClearAllPendingInvalid()
        engine.Arm(A_Clipboard)
        engine.SetExtraTabsAfter(1, hud.templateMode ? 1 : 0)
        hud.Update()
        PasteMutex.Release()
        ToolTip()
    }
```

Por:

```ahk
    Logger.Info("paste_batch_start", Map("filled", engine.FilledCount, "total", engine.schema.Length))
    try
    {
        SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
        Sleep 30
        engine.PasteBatch()
        Logger.Info("paste_batch_done", Map("filled", engine.FilledCount))
    }
    catch (e)
    {
        Logger.Error("paste_batch_failed", Map("msg", e.Message))
        ToolTip("Pegado interrumpido: " e.Message ". Revisa el form y usa ^+r para resetear.")
        SetTimer(() => ToolTip(), -4000)
    }
    finally
    {
        hud.SaveLastPaste()
        engine.Reset()
        hud.ClearAllPendingInvalid()
        engine.Arm(A_Clipboard)
        engine.SetExtraTabsAfter(1, hud.templateMode ? 1 : 0)
        hud.Update()
        PasteMutex.Release()
        if !A_EventInfo  ; no pisar el tooltip de error
            ToolTip()
    }
```

(Asume que Step 4.2 ya cambió el set/clear de mutex a PasteMutex.Acquire/Release.)

- [ ] **Step 5.3: Editar `DoHeaderScan` análogamente**

Localizar el bloque `try { ... engine.Scan(, , , backup) ... }` en `DoHeaderScan`. Aplicar el mismo patrón: agregar `Logger.Info("scan_start")` antes del try, `Logger.Info("scan_done")` al final del try, `catch (e) { Logger.Error("scan_failed", ...); ToolTip(...); SetTimer(...) }`, y mantener el finally igual (con PasteMutex.Release).

Exacto:

```ahk
    Logger.Info("scan_start", Map())
    try
    {
        SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
        Sleep 30
        SendInput "{Escape}"
        Sleep 150
        engine.Scan(, , , backup)
        Logger.Info("scan_done", Map("filled", engine.FilledCount))
    }
    catch (e)
    {
        Logger.Error("scan_failed", Map("msg", e.Message))
        ToolTip("Scan interrumpido: " e.Message ". Cursor puede estar desfasado, usa ^+r y reintenta.")
        SetTimer(() => ToolTip(), -4000)
    }
    finally
    {
        A_Clipboard := backup
        PasteMutex.Release()
    }
```

- [ ] **Step 5.4: Agregar logs en otros eventos clave**

En `DoReset` (después de `engine.Abort()` etc.):
```ahk
    Logger.Info("reset", Map())
```

En `DoUndo` después del `u := engine.Undo()` (solo si `u["ok"]`):
```ahk
    Logger.Info("undo", Map("slot", u["slot"]))
```

En `DoArmOrSkip` cuando arma (en la rama `else` del fondo):
```ahk
    Logger.Info("arm", Map())
```

- [ ] **Step 5.5: Validar sintaxis**

```powershell
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","/validate","QuickEntry.ahk" -Wait -PassThru -NoNewWindow
```
Expected: exit 0.

- [ ] **Step 5.6: Test gate**

Expected: `Total asserts: 772`, `ALL TESTS PASSED`.

---

## Task 6 (C4): Schema runtime selection via INI

**Files:**
- Modify: `QuickEntry.ahk` (la línea de instanciación de `engine`)

- [ ] **Step 6.1: Agregar registry + INI lookup antes de instanciar engine**

Localizar la línea actual:

```ahk
global engine := CaptureEngine(CrearAsignetHeaderV1(), AUTO_CALCULAR_TOTALES_OMITIDOS)
```

Reemplazar el bloque (esa línea + el comentario inmediato anterior) por:

```ahk
; --- Schema registry ---
; Para agregar una empresa nueva: crear `Schemas/EmpresaXHeaderV1.ahk` con su
; constructor `CrearEmpresaXHeaderV1()`, agregar `#Include` arriba, y agregar
; una entrada acá. El operador elige cuál usar con
; `%APPDATA%\QuickEntry\config.ini`:
;   [General]
;   Schema=AsignetHeaderV1
global SCHEMA_REGISTRY := Map(
    "AsignetHeaderV1", CrearAsignetHeaderV1
)

configPath := A_AppData "\QuickEntry\config.ini"
schemaName := IniRead(configPath, "General", "Schema", "AsignetHeaderV1")
if !SCHEMA_REGISTRY.Has(schemaName) {
    Logger.Warn("schema_unknown", Map("requested", schemaName, "fallback", "AsignetHeaderV1"))
    MsgBox "Schema desconocido en config.ini: '" schemaName "'.`n`nUsando AsignetHeaderV1 por default.", "QuickEntry", 48
    schemaName := "AsignetHeaderV1"
}
Logger.Info("startup", Map("schema", schemaName))
factory := SCHEMA_REGISTRY[schemaName]
global engine := CaptureEngine(factory(), AUTO_CALCULAR_TOTALES_OMITIDOS)
```

- [ ] **Step 6.2: Actualizar `docs/AGREGAR_EMPRESA.md` para mencionar el registry**

Read `docs/AGREGAR_EMPRESA.md`. Localizar el "Paso 6" o equivalente que dice "agregar al QuickEntry.ahk la línea X". Reemplazar la instrucción por algo como:

```markdown
## Paso 6: Registrar la empresa en QuickEntry.ahk

Abrí `QuickEntry.ahk`. Localizá el bloque `global SCHEMA_REGISTRY := Map(...)` y agregá una nueva entrada:

```ahk
global SCHEMA_REGISTRY := Map(
    "AsignetHeaderV1", CrearAsignetHeaderV1,
    "EmpresaXHeaderV1", CrearEmpresaXHeaderV1  ; ← tu empresa nueva
)
```

Agregá también el `#Include` correspondiente arriba:

```ahk
#Include "Schemas\EmpresaXHeaderV1.ahk"
```

## Paso 7: Activar la empresa nueva

El operador elige qué schema usar editando `%APPDATA%\QuickEntry\config.ini`:

```ini
[General]
Schema=EmpresaXHeaderV1
```

Sin INI o con un nombre desconocido, QuickEntry usa `AsignetHeaderV1` por default (con un warning visible).
```

(Renumerar los pasos siguientes si quedan.)

- [ ] **Step 6.3: Validar sintaxis**

Expected: exit 0.

- [ ] **Step 6.4: Test gate**

Expected: `Total asserts: 772`, `ALL TESTS PASSED`.

---

## Task 7 (C5): visible cue "CAPTURA ACTIVA" en title del HUD

**Files:**
- Modify: `Lib/MainHud.ahk` (Build + Update)

- [ ] **Step 7.1: Read `Lib/MainHud.ahk:208`** y localizar la creación del Gui

Ver el código actual:
```ahk
g := Gui("+AlwaysOnTop +Resize +MinSize380x340 -DPIScale", "QuickEntry")
```

- [ ] **Step 7.2: Editar `Update()` para que setee el title según `engine.isCapturing`**

Localizar el método `Update(*)` en `Lib/MainHud.ahk`. Al **inicio** del método (antes de cualquier render de slots), agregar:

```ahk
        if this.engine.isCapturing
            this.gui.Title := "QuickEntry — CAPTURA ACTIVA (Ctrl+C guarda al slot)"
        else
            this.gui.Title := "QuickEntry — pausado (Ctrl+Shift+A para armar)"
```

Esto se ejecuta en cada `hud.Update()` (que el entry point llama tras cada arm/skip/paste/reset/undo), así el title refleja el estado real.

- [ ] **Step 7.3: Validar sintaxis**

```powershell
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","/validate","Lib/MainHud.ahk" -Wait -PassThru -NoNewWindow
```
Expected: exit 0.

- [ ] **Step 7.4: Test gate**

Expected: `Total asserts: 772`, `ALL TESTS PASSED`.

---

## Task 8: Verificación final + INDEX update

**Files:**
- Modify: `docs/files/INDEX.md` (Fase 7 entry)

- [ ] **Step 8.1: Validar sintaxis de todos los productivos + nuevos módulos**

```powershell
$ahk = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$files = @('QuickEntry.ahk',
           'Lib/AutoCalculator.ahk','Lib/CaptureEngine.ahk','Lib/Cleaners.ahk',
           'Lib/HudLayout.ahk','Lib/Logger.ahk','Lib/MainHud.ahk','Lib/PasteMutex.ahk',
           'Lib/PegadoEspecial.ahk','Lib/Schema.ahk','Lib/TooltipFormatter.ahk','Lib/Validators.ahk',
           'Schemas/AsignetHeaderV1.ahk','Schemas/_Plantilla_NuevaEmpresa.ahk')
$failures = @()
foreach ($f in $files) {
  $p = Start-Process $ahk -ArgumentList "/ErrorStdOut=utf-8","/validate",$f -Wait -PassThru -NoNewWindow -RedirectStandardError "$env:TEMP\v.err" -RedirectStandardOutput "$env:TEMP\v.out"
  if ($p.ExitCode -ne 0) { $failures += $f }
}
if ($failures) { throw "Sintaxis fallo: $($failures -join ', ')" }
"OK: 14 archivos validados"
```
Expected: `OK: 14 archivos validados`.

- [ ] **Step 8.2: Test gate final completo**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 2>&1
"exit: $LASTEXITCODE"
```
Expected:
- Listado de 9 archivos PASS (los 7 antiguos + Test_Logger + Test_PasteMutex).
- `Total asserts: 772` (757 + 8 Logger + 7 PasteMutex).
- `ALL TESTS PASSED`, exit 0.

- [ ] **Step 8.3: Smoke test manual mínimo (instrucción para humano)**

```
1. Lanzá QuickEntry.ahk con doble-click.
2. Verificá:
   a. El HUD muestra en title: "QuickEntry — CAPTURA ACTIVA (Ctrl+C guarda al slot)".
   b. Hacé un copy de cualquier texto: el slot 1 se llena (o tooltip de error si el cleaner rechaza).
   c. Apretá ^+r: el title cambia a "QuickEntry — pausado (Ctrl+Shift+A para armar)".
   d. Hacé un copy: nada pasa (captura pausada).
   e. Apretá ^+a: el title vuelve a CAPTURA ACTIVA.
3. Verificá que `%APPDATA%\QuickEntry\events.log` exists y tiene líneas de los pasos anteriores.
4. Lanzá una segunda instancia de QuickEntry.ahk. Verificá que la primera muere y la segunda toma su lugar (no quedan dos engines).
5. Si todo OK, reportar al humano: smoke test PASSED.
```

- [ ] **Step 8.4: Update INDEX.md con Fase 7**

En `docs/files/INDEX.md`, agregar a la tabla "Estado por fase":

```markdown
| 7 | Critical fixes para producción multi-operador (post senior review) | 🟢 completa |
```

Y agregar al final de la sección "Resumen de cleanup":

```markdown
**Fase 7 — Critical fixes para producción multi-operador (2026-05-12).** Plan: [`2026-05-12-critical-fixes-production-plan.md`](../superpowers/plans/2026-05-12-critical-fixes-production-plan.md). Backup: `_archive/2026-05-12-post-fase6.zip`.

- **C1**: `#SingleInstance Force` agregado en `QuickEntry.ahk:2`. Doble instancia ya no corrompe la cola.
- **C2**: try/catch agregado en `DoSoltar` y `DoHeaderScan`. Errores muestran tooltip + log en lugar de stacktrace AHK.
- **C3**: Nuevo `Lib/Logger.ahk` (file logging + rotación a 1 MB). Output a `%APPDATA%\QuickEntry\events.log`. Wireado en arm/skip/paste/scan/reset/undo + errores. **Tests**: +8 asserts (`Test_Logger.ahk`).
- **C4**: Schema selection runtime via INI (`%APPDATA%\QuickEntry\config.ini` `[General]\Schema=`). Registry `SCHEMA_REGISTRY` en `QuickEntry.ahk` permite multi-empresa sin editar código.
- **C5**: Title del HUD ahora muestra "CAPTURA ACTIVA" o "pausado" según `engine.isCapturing`. Operador nuevo ve el estado de un vistazo.
- **C6**: Nuevo `Lib/PasteMutex.ahk` encapsula el lock antes-global `pegadoEnCurso`. `PegadoEspecial`, `HandlerCaptura`, `DoSoltar`, `DoHeaderScan` usan `PasteMutex.IsLocked` / `Acquire()` / `Release()`. **Tests**: +7 asserts (`Test_PasteMutex.ahk`).
- **Asserts**: 757 → **772** ✅. Sintaxis: 14 archivos validados (+2 nuevos módulos).
```

- [ ] **Step 8.5: Cerrar la fase**

Reportar al humano:
- Fase 7 cerrada con 772/772 asserts pasando.
- Los 6 Critical del senior review están resueltos.
- Pendiente para próximo ciclo (no en este plan): los 11 Important del senior (callback injection MainHud, Build() split, magic numbers en CaptureEngine, INSTALL.md, versionado visible, last_paste.ini opt-out, etc).

---

## Self-review checklist

1. **Spec coverage** (los 6 Critical del senior):
   - ✅ C1 → Task 1
   - ✅ C2 → Task 5 (catch + tooltip)
   - ✅ C3 → Tasks 2 (módulo) + 5 (wire en handlers)
   - ✅ C4 → Task 6 (registry + INI)
   - ✅ C5 → Task 7 (HUD title)
   - ✅ C6 → Tasks 3 (módulo) + 4 (refactor producción)
   - ✅ Backup → Task 0
   - ✅ Verificación → Task 8

2. **Placeholder scan:** ningún TBD. Cada step muestra código exacto o comando ejecutable.

3. **Type consistency:** `PasteMutex.IsLocked` / `Acquire()` / `Release()` consistente entre Lib/PasteMutex.ahk, Test_PasteMutex.ahk, Lib/PegadoEspecial.ahk refactor, QuickEntry.ahk refactor. `Logger.Info/Warn/Error` consistente. `SCHEMA_REGISTRY` nombrado igual en todos lados. Conteo target: 757 → 765 (Logger) → 772 (PasteMutex) → 772 final.

---

## Notas operativas

- **AHK path**: `C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` (esta máquina). Tests/runner.ps1 ya tiene discovery portable post-Fase-0.2.
- **`#SingleInstance Force`** en QuickEntry.ahk **no afecta los tests** porque cada `Test_*.ahk` declara su propio `#SingleInstance Off`.
- **Order matters**: Task 3 (PasteMutex module) antes de Task 4 (refactor productivo). Task 2 (Logger) antes de Task 5 (catch+log) y Task 6 (Logger.Warn en schema lookup).
- **Logs van a APPDATA del USER que corre QuickEntry**, no al folder del repo. Confidencial-ish (incluye timestamps + lifecycle events sin valores). Mencionar en docs/MANUAL si hace falta.
- **Rollback**: si algo se rompe a medio camino, restaurar desde `_archive/2026-05-12-post-fase6.zip`.
- **No es git repo**. Mismo workflow zip-based que las fases anteriores.

---

## Próximos pasos sugeridos (NO en este plan)

Los **Important del senior review** quedan para un próximo plan, en orden de impacto:

1. MainHud callback injection (romper dependencia invertida HUD → entry).
2. `MainHud.Build()` split (≥150 líneas → ~40 cada sub-método).
3. Magic numbers en `CaptureEngine.ahk` (los 7 sitios de `Sleep 150`).
4. `INSTALL.md` con paquete + verificación post-install (para IT corporativo).
5. Versionado visible (`QUICKENTRY_VERSION` constante + title bar).
6. `last_paste.ini` opt-out o borrado en `OnExit` (data sensible).
7. Tests de GUI mínimos (smoke headless de MainHud Build).

Estos 7 son trabajo de un próximo ciclo de ~1 día. Recomendable después de un piloto controlado con 2-3 operadores ejecutando el código post-Fase-7.
