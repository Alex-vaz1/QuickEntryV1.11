# Captura UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor el motor de captura para soportar un picker que permite saltar a cualquier slot (vacío o lleno), con auto-avance al próximo vacío; tooltip de previo invertido (`▶ valor ◀ (Nombre)`); listo persistente con `cola llena - ^+e para revisar`; autocalc activado por default.

**Architecture:** `queue` se pre-aloca a `schema.Length` con `""` en `Arm`. Cada Push/Skip se registra en `actionLog` (con `prevValue`) para Undo reversible. `targetSlot` (0 = sequential) permite que el picker fuerce la posición. `AutoAdvance` busca cíclicamente el próximo `""` desde el slot recién actuado. `FilledCount` cuenta `queue[i] != ""` y reemplaza `queue.Length` en los displays `x/n`.

**Tech Stack:** AutoHotkey v2.0 (procedural + clases), tests via asserts custom + `runner.ps1` (PowerShell).

**Spec:** [`docs/superpowers/specs/2026-04-27-captura-ux-overhaul-design.md`](../specs/2026-04-27-captura-ux-overhaul-design.md)

---

## Resumen de archivos modificados

| Archivo | Cambio |
|---|---|
| `Lib/CaptureEngine.ahk` | Refactor estado: queue pre-alocada, actionLog, targetSlot. Métodos nuevos: JumpTo, AutoAdvance, FilledCount. |
| `Lib/TooltipFormatter.ahk` | LineaPrompt: cola-llena variant + FilledCount en `x/n`. LineaPrevio: formato C + lee actionLog. |
| `Lib/ManualInputGui.ahk` | Picker compacto con lista de slots vacíos + botón "Ver todos" + click-to-jump. |
| `QuickEntry.ahk` | Flip `AUTO_CALCULAR_TOTALES_OMITIDOS := true` + RefrescarTooltip maneja `accion="jump"`. |
| `Tests/Test_CaptureEngine.ahk` | Adaptar asserts existentes al nuevo modelo + tests nuevos para JumpTo/AutoAdvance/FilledCount/actionLog Undo. |
| `Tests/Test_TooltipFormatter.ahk` | Adaptar asserts a formato C + cola-llena + FilledCount. |
| `Tests/Test_AsignetHeader.ahk` | Tests nuevos: autocalc end-to-end de slot 7 y 9. |
| `docs/MANUAL_USUARIO.md` | Sección picker + autocalc + listo persistente. |
| `docs/GUIA_TECNICA.md` | Estado interno engine actualizado. |

Sin cambios: `Lib/Schema.ahk`, `Lib/Cleaners.ahk`, `Lib/Validators.ahk`, `Lib/PegadoEspecial.ahk`, `Schemas/*`, `docs/PERSONALIZACION_HOTKEYS.md`, `docs/AGREGAR_EMPRESA.md`.

---

## Task 1: Refactor del CaptureEngine — queue pre-alocada + actionLog + targetSlot

**Files:**
- Modify: `Lib/CaptureEngine.ahk`
- Test: `Tests/Test_CaptureEngine.ahk`

**Contexto:** Este refactor cambia la semántica de `queue` (de monotónica a fixed-length). Todos los call sites de `queue.Length` y `queue.Push()` se actualizan. Se agregan tres miembros nuevos (`actionLog`, `targetSlot`, `FilledCount`) y un método nuevo (`JumpTo`, `AutoAdvance`).

- [ ] **Step 1.1: Reemplazar el cuerpo entero de `Lib/CaptureEngine.ahk` con la versión nueva**

Mantener el header de comentarios actualizado (modelo nuevo). Body de la clase:

```ahk
#Requires AutoHotkey v2.0
#Include "Schema.ahk"

; ====================================================================
; CaptureEngine - motor de captura schema-driven.
;
; Estado interno:
;   schema        - InvoiceSchema (inmutable durante una captura)
;   queue         - Array<String>: pre-alocado a schema.Length, todos ""
;                   inicialmente. queue[i] != "" significa "slot i lleno".
;   actionLog     - Array<Map>: cada accion = {slot, prevValue}, para Undo.
;   targetSlot    - Integer: 0 = sequential (NextSlot escanea queue).
;                   != 0 = el picker o un Undo forzo cursor a ese slot.
;   isCapturing   - Boolean
;   clipBackup    - String
;   autoCalcFlag  - Boolean: si true, SkipCurrent en slot con expectedFn
;                   pushea el valor calculado en vez de "".
;
; Metodos puros (testeables sin runtime AHK):
;   Arm(snapshot)       - reset state, isCapturing=true
;   Reset()             - reset state, isCapturing=false
;   PushRaw(raw)        - clean+validate+push al slot NextSlot,
;                         registra accion, AutoAdvance al proximo vacio.
;                         Retorna Map(ok, error, label, slot, value)
;   PushManual(value)   - alias de PushRaw
;   SkipCurrent()       - push "" o expectedFn(queue) si autoCalc;
;                         registra accion, AutoAdvance.
;                         Retorna Map(value, slot, label)
;   Undo()              - pop del actionLog, restaura queue[slot] al
;                         prevValue, targetSlot := slot.
;                         Retorna Map(ok, slot, label)
;   JumpTo(slot)        - fuerza targetSlot. Throw si slot fuera de rango.
;                         Retorna Map(slot, label)
;   ExpectedFor(slot)   - delega a expectedFn del campo
;   NextSlot            - prop: targetSlot si != 0, sino primer "" en queue
;   IsComplete          - prop: NextSlot = 0
;   FilledCount         - prop: cuenta de slots con queue[i] != ""
;
; Helper privado:
;   AutoAdvance(slotJustActed) - busca proximo "" desde slot+1 en adelante;
;                                si no, desde 1 hasta slot-1. Si nada, 0.
;
; Metodo con side effects (cubierto en integracion manual):
;   PasteBatch(sendFn?, sleepFn?) - itera schema.ordenPegado, paste+Tabs.
; ====================================================================

class CaptureEngine
{
    schema := ""
    queue := []
    actionLog := []
    targetSlot := 0
    isCapturing := false
    clipBackup := ""
    autoCalcFlag := false

    __New(schema, autoCalcFlag := false)
    {
        this.schema := schema
        this.autoCalcFlag := autoCalcFlag
        this.ResetState()
    }

    ; --- Helper interno: limpia queue/actionLog/targetSlot, NO toca isCapturing/clipBackup ---
    ResetState()
    {
        this.queue := []
        Loop this.schema.Length
            this.queue.Push("")
        this.actionLog := []
        this.targetSlot := 0
    }

    NextSlot
    {
        get
        {
            if (this.targetSlot != 0)
                return this.targetSlot
            Loop this.schema.Length
                if (this.queue[A_Index] = "")
                    return A_Index
            return 0
        }
    }

    IsComplete => this.NextSlot = 0

    FilledCount
    {
        get
        {
            count := 0
            Loop this.schema.Length
                if (this.queue[A_Index] != "")
                    count++
            return count
        }
    }

    Arm(clipSnapshot := "")
    {
        this.ResetState()
        this.isCapturing := true
        this.clipBackup := clipSnapshot
    }

    Reset()
    {
        this.ResetState()
        this.isCapturing := false
        this.clipBackup := ""
    }

    JumpTo(slot)
    {
        if (slot < 1 || slot > this.schema.Length)
            throw ValueError("slot fuera de rango: " slot)
        this.targetSlot := slot
        return Map("slot", slot, "label", this.schema.Field(slot).name)
    }

    PushRaw(raw)
    {
        slot := this.NextSlot
        if (slot = 0)
            return Map("ok", false, "error", "cola completa", "label", "", "slot", 0, "value", "")

        campo := this.schema.Field(slot)
        limpio := campo.clean.Call(raw)
        if (limpio = "")
            return Map("ok", false, "error", "no se reconocio el valor",
                       "label", campo.name, "slot", slot, "value", "")

        err := campo.validate.Call(limpio, this.queue)
        if (err != "")
            return Map("ok", false, "error", err,
                       "label", campo.name, "slot", slot, "value", limpio)

        this.actionLog.Push(Map("slot", slot, "prevValue", this.queue[slot]))
        this.queue[slot] := limpio
        this.targetSlot := 0
        this.AutoAdvance(slot)
        return Map("ok", true, "error", "", "label", campo.name, "slot", slot, "value", limpio)
    }

    PushManual(value) => this.PushRaw(value)

    SkipCurrent()
    {
        slot := this.NextSlot
        if (slot = 0)
            return Map("value", "", "slot", 0, "label", "")

        campo := this.schema.Field(slot)
        valor := ""
        if (this.autoCalcFlag && IsObject(campo.expectedFn))
            valor := campo.expectedFn.Call(this.queue)

        this.actionLog.Push(Map("slot", slot, "prevValue", this.queue[slot]))
        this.queue[slot] := valor
        this.targetSlot := 0
        this.AutoAdvance(slot)
        return Map("value", valor, "slot", slot, "label", campo.name)
    }

    Undo()
    {
        if (this.actionLog.Length = 0)
            return Map("ok", false, "slot", 0, "label", "")
        accion := this.actionLog.Pop()
        slot := accion["slot"]
        this.queue[slot] := accion["prevValue"]
        this.targetSlot := slot
        return Map("ok", true, "slot", slot, "label", this.schema.Field(slot).name)
    }

    ExpectedFor(slot)
    {
        if (slot < 1 || slot > this.schema.Length)
            return ""
        campo := this.schema.Field(slot)
        if !IsObject(campo.expectedFn)
            return ""
        return campo.expectedFn.Call(this.queue)
    }

    ; --- Helper privado: setea targetSlot al proximo "" cyclico desde slotJustActed+1 ---
    AutoAdvance(slotJustActed)
    {
        i := slotJustActed + 1
        while (i <= this.schema.Length)
        {
            if (this.queue[i] = "")
            {
                this.targetSlot := i
                return
            }
            i++
        }
        i := 1
        while (i < slotJustActed)
        {
            if (this.queue[i] = "")
            {
                this.targetSlot := i
                return
            }
            i++
        }
        this.targetSlot := 0
    }

    PasteBatch(sendFn := unset, sleepFn := unset)
    {
        if !IsSet(sendFn)
            sendFn := (s) => SendInput(s)
        if !IsSet(sleepFn)
            sleepFn := (ms) => Sleep(ms)

        orden := this.schema.ordenPegado
        total := orden.Length

        for posicion, slot in orden
        {
            campo := this.schema.Field(slot)
            valor := this.queue[slot]
            isLast := (posicion = total)

            if (valor != "" && !campo.skipPaste)
            {
                A_Clipboard := ""
                A_Clipboard := valor
                if !ClipWait(0.5, 1)
                {
                    A_Clipboard := this.clipBackup
                    throw Error("Error al actualizar clipboard en slot " slot)
                }
                sendFn.Call("{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}")
                sleepFn.Call(20)
                sendFn.Call("^v")
                sleepFn.Call(150)
            }

            if !isLast
            {
                Loop campo.tabsAfter
                {
                    sendFn.Call("{Tab}")
                    sleepFn.Call(150)
                }
            }
        }
        A_Clipboard := this.clipBackup
    }
}
```

- [ ] **Step 1.2: Adaptar asserts existentes en `Tests/Test_CaptureEngine.ahk` al modelo nuevo**

Cambios mecánicos a aplicar a TODO el archivo:

| Patrón viejo | Patrón nuevo |
|---|---|
| `e.queue.Length, 0, "engine no armado: queue vacia"` | `e.queue.Length, 3, "engine no armado: queue pre-alocada a schema.Length"` |
| `e.NextSlot, 2, "PushRaw 1: NextSlot=2"` | (sin cambio — semántica preservada) |
| `e.queue.Length, 1, "PushRaw rechazo no muta queue"` | `e.FilledCount, 1, "PushRaw rechazo no muta cola"` |
| `e.queue[3], "", "Skip pushea vacio"` | (sin cambio — sigue válido) |
| `e.queue.Length=3 completo` | `e.FilledCount, 3, "FilledCount=3 completo"` |
| `e.queue.Length=3 PushRaw post-completo no muta queue` | `e.FilledCount, 3, "PushRaw post-completo no muta cola"` |
| `Undo x3 vacia queue` → `e.queue.Length=0` | `e.actionLog.Length, 0, "Undo x3 vacia actionLog"` (queue.Length sigue siendo 3) |

Adicionalmente, para los tests de Undo: el comportamiento es ahora "pop del actionLog". El primer Undo restaura `queue[3] := ""` y `targetSlot := 3`. Verificar esos invariants.

Reemplazos exactos a aplicar:

```ahk
; Linea ~30 (estado inicial)
AssertEq(e.queue.Length, 3, "engine no armado: queue pre-alocada a schema.Length")
; (asserts NextSlot, isCapturing, IsComplete sin cambio)

; Linea ~62 (PushRaw rechazo)
AssertEq(e.NextSlot, 2, "PushRaw rechazo no avanza")
AssertEq(e.FilledCount, 1, "PushRaw rechazo no muta cola")

; Linea ~92-93 (post-completo)
AssertEq(e.IsComplete, true, "IsComplete tras pushear los 3")
AssertEq(e.NextSlot, 0, "NextSlot=0 cuando completo")
AssertEq(e.FilledCount, 3, "FilledCount=3 completo")

; Linea ~102 (post-completo no muta)
AssertEq(e.FilledCount, 3, "PushRaw post-completo no muta cola")

; Bloque Undo (linea ~107+)
u := e.Undo()
AssertEq(u["ok"], true, "Undo ok")
AssertEq(u["slot"], 3, "Undo slot 3")
AssertEq(u["label"], "Suma", "Undo label Suma")
AssertEq(e.NextSlot, 3, "Undo: NextSlot=3 (targetSlot apunta al deshecho)")
AssertEq(e.IsComplete, false, "Undo: !IsComplete")
AssertEq(e.queue[3], "", "Undo restaura queue[3] = prevValue (vacio inicial)")

; --- Multi-undo ---
e.Undo()
e.Undo()
AssertEq(e.actionLog.Length, 0, "Undo x3 vacia actionLog")
AssertEq(e.NextSlot, 1, "Undo total: NextSlot=1 (targetSlot apunta al primero deshecho)")
AssertEq(e.FilledCount, 0, "Undo total: FilledCount=0")

; Undo cola vacia (actionLog vacio)
uVacio := e.Undo()
AssertEq(uVacio["ok"], false, "Undo actionLog vacio: ok=false")
```

- [ ] **Step 1.3: Agregar tests nuevos al final de `Tests/Test_CaptureEngine.ahk`, antes de `ReportarYSalir()`**

Insertar este bloque ANTES de `ReportarYSalir()`:

```ahk
; ====================================================================
; FilledCount - cuenta slots con queue[i] != ""
; ====================================================================
eFC := CaptureEngine(CrearMock())
AssertEq(eFC.FilledCount, 0, "FilledCount engine virgen = 0")
eFC.Arm()
AssertEq(eFC.FilledCount, 0, "FilledCount tras Arm = 0")
eFC.PushRaw("100")
AssertEq(eFC.FilledCount, 1, "FilledCount tras 1 push = 1")
eFC.SkipCurrent()  ; slot 2 sin autocalc -> ""
AssertEq(eFC.FilledCount, 1, "FilledCount Skip(no autocalc) NO suma")
eFC.PushRaw("999")  ; slot 3 (sin validacion suma porque slot 2 = "")
AssertEq(eFC.FilledCount, 2, "FilledCount tras push slot 3 = 2 (skipeado no cuenta)")

; --- FilledCount con autocalc cuenta ---
eFCa := CaptureEngine(CrearMock(), true)
eFCa.Arm()
eFCa.PushRaw("100")
eFCa.PushRaw("50")
eFCa.SkipCurrent()  ; slot 3 autocalc -> "150.00"
AssertEq(eFCa.FilledCount, 3, "FilledCount autocalc cuenta slot calculado")

; ====================================================================
; JumpTo - setea targetSlot, no muta queue
; ====================================================================
eJ := CaptureEngine(CrearMock())
eJ.Arm()
eJ.PushRaw("100")
AssertEq(eJ.NextSlot, 2, "Pre-jump NextSlot=2")
j := eJ.JumpTo(1)
AssertEq(j["slot"], 1, "JumpTo retorna slot")
AssertEq(j["label"], "A", "JumpTo retorna label")
AssertEq(eJ.targetSlot, 1, "JumpTo setea targetSlot")
AssertEq(eJ.NextSlot, 1, "JumpTo cambia NextSlot al target")
AssertEq(eJ.queue[1], "100", "JumpTo NO muta queue")
AssertEq(eJ.actionLog.Length, 1, "JumpTo NO toca actionLog")

; --- JumpTo fuera de rango lanza ---
threwLow := false
try eJ.JumpTo(0)
catch ValueError
    threwLow := true
AssertEq(threwLow, true, "JumpTo(0) throw ValueError")

threwHigh := false
try eJ.JumpTo(99)
catch ValueError
    threwHigh := true
AssertEq(threwHigh, true, "JumpTo(N+1) throw ValueError")

; ====================================================================
; Push tras JumpTo - reemplaza, registra accion, AutoAdvance
; ====================================================================
eJP := CaptureEngine(CrearMock())
eJP.Arm()
eJP.PushRaw("100")  ; slot 1
eJP.PushRaw("50")   ; slot 2
; queue = ["100", "50", ""]; NextSlot = 3
eJP.JumpTo(1)       ; targetSlot = 1
rOver := eJP.PushRaw("999")
AssertEq(rOver["ok"], true, "Push tras Jump ok")
AssertEq(rOver["slot"], 1, "Push tras Jump usa slot del jump")
AssertEq(eJP.queue[1], "999", "Push tras Jump reemplaza queue[1]")
AssertEq(eJP.targetSlot, 3, "Push tras Jump auto-advance a proximo vacio (slot 3)")
AssertEq(eJP.actionLog.Length, 3, "actionLog crece con push tras jump")
ultAccion := eJP.actionLog[3]
AssertEq(ultAccion["slot"], 1, "ultima accion: slot=1")
AssertEq(ultAccion["prevValue"], "100", "ultima accion: prevValue del slot 1 = 100")

; ====================================================================
; AutoAdvance ciclico - busca hacia adelante, despues hacia atras
; ====================================================================
eAA := CaptureEngine(CrearMock())
eAA.Arm()
eAA.PushRaw("100")     ; slot 1
eAA.SkipCurrent()      ; slot 2 -> ""
eAA.PushRaw("50")      ; slot 3 -> wait, validate suma falla porque slot2=""
                        ; Actually ValidarSumaTol skip si dep vacia, asi que pasa
; queue = ["100", "", "50"]; NextSlot deberia ser 2 (primer "")
AssertEq(eAA.NextSlot, 2, "Tras push 3 con slot 2 vacio: NextSlot=2 (cycle back)")

; --- Push slot 2: AutoAdvance no encuentra "" hacia adelante (slot 3 lleno),
;     vuelve al inicio (slot 1 lleno), termina con targetSlot=0 ---
eAA.PushRaw("60")
AssertEq(eAA.queue[2], "60", "queue[2] llenado")
AssertEq(eAA.targetSlot, 0, "AutoAdvance no encuentra vacio -> targetSlot=0")
AssertEq(eAA.IsComplete, true, "IsComplete tras llenar todo")
AssertEq(eAA.FilledCount, 3, "FilledCount=3")

; ====================================================================
; Undo restaura queue al prevValue + targetSlot = slot deshecho
; ====================================================================
eU := CaptureEngine(CrearMock())
eU.Arm()
eU.PushRaw("100")  ; slot 1, prev = ""
eU.PushRaw("50")   ; slot 2, prev = ""
eU.JumpTo(1)
eU.PushRaw("777")  ; slot 1, prev = "100"
; queue = ["777", "50", ""], actionLog 3 entries
u1 := eU.Undo()
AssertEq(u1["slot"], 1, "Undo retorna slot")
AssertEq(eU.queue[1], "100", "Undo restaura queue[1] al prevValue (100)")
AssertEq(eU.targetSlot, 1, "Undo setea targetSlot al deshecho")
AssertEq(eU.NextSlot, 1, "NextSlot = slot deshecho")
AssertEq(eU.actionLog.Length, 2, "actionLog -1")

; ====================================================================
; Reset limpia todo
; ====================================================================
eR := CaptureEngine(CrearMock())
eR.Arm("backup")
eR.PushRaw("100")
eR.JumpTo(2)
eR.Reset()
AssertEq(eR.isCapturing, false, "Reset: isCapturing=false")
AssertEq(eR.actionLog.Length, 0, "Reset: actionLog vacio")
AssertEq(eR.targetSlot, 0, "Reset: targetSlot=0")
AssertEq(eR.FilledCount, 0, "Reset: FilledCount=0")
AssertEq(eR.queue.Length, 3, "Reset: queue sigue pre-alocada a schema.Length")
AssertEq(eR.queue[1], "", "Reset: queue[1] = ''")
AssertEq(eR.clipBackup, "", "Reset: clipBackup vacio")
```

- [ ] **Step 1.4: Correr suite y verificar GREEN**

Run: `pwsh -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"`

Expected: `ALL TESTS PASSED`. Asserts esperados ≈ 545 (519 actuales − 1 reemplazado + ~27 nuevos). Si algún test de TooltipFormatter falla por usar `engine.queue.Length` para inferir previo: NO arreglar acá; eso lo cubre Task 2.

Nota: `Test_TooltipFormatter.ahk` usa `engine.queue.Length` indirectamente vía `LineaPrevio` que actualmente lee `engine.queue[engine.queue.Length]`. Como queue ahora es fixed-length, ese índice devolverá `""` (slot 9 vacío) en muchos tests. Ese roto es ESPERADO y se arregla en Task 2.

Si fallan SOLO tests de Test_TooltipFormatter: continuar a Task 2. Si fallan tests de Test_CaptureEngine: revisar adaptaciones del Step 1.2.

- [ ] **Step 1.5: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/CaptureEngine.ahk Tests/Test_CaptureEngine.ahk
git commit -m "refactor(engine): pre-allocated queue + actionLog + JumpTo/AutoAdvance

- queue se pre-aloca a schema.Length con \"\" en Arm/Reset/__New.
- actionLog: Array<Map> registra cada Push/Skip con prevValue para Undo reversible.
- targetSlot: Integer (0 = sequential, sino cursor forzado).
- NextSlot escanea queue por primer \"\"; usa targetSlot si != 0.
- IsComplete = NextSlot = 0.
- FilledCount: prop getter para slots con queue[i] != \"\".
- JumpTo(slot): setea targetSlot. Throw ValueError fuera de rango.
- AutoAdvance(slot): busca proximo \"\" desde slot+1, sino desde 1, sino 0.
- Undo: pop actionLog, restaura queue[slot] = prevValue, targetSlot = slot.

Tests adaptados (queue.Length -> FilledCount donde semantica cambio).
Tests nuevos: JumpTo, FilledCount, AutoAdvance ciclico, Undo restaura prevValue."
```

---

## Task 2: TooltipFormatter — formato C, cola-llena, FilledCount

**Files:**
- Modify: `Lib/TooltipFormatter.ahk`
- Test: `Tests/Test_TooltipFormatter.ahk`

- [ ] **Step 2.1: Reemplazar `LineaPrompt` y `LineaPrevio` en `Lib/TooltipFormatter.ahk`**

Localizar las dos funciones y reemplazar enteras. Las demás funciones (`EnNegrita`, `LineasOperandos`, `TooltipPostAccion`, `TooltipError`, `LineaInputInvalido`, `TooltipConError`) quedan intactas.

```ahk
; --- Linea 1: prompt del proximo slot (o "Listo" si completo) ---
LineaPrompt(engine)
{
    if (engine.IsComplete)
        return "Listo " engine.FilledCount "/" engine.schema.Length
            . " - cola llena - ^+s para pegar, ^+e para revisar"

    slot := engine.NextSlot
    nombre := engine.schema.Field(slot).name
    base := 'Busca "' nombre '" (' engine.FilledCount "/" engine.schema.Length ")"

    esperado := engine.ExpectedFor(slot)
    if (esperado != "")
        base .= " - esperado: " esperado
    return base
}

; --- Linea 2: feedback del slot recien actuado (vacio si actionLog vacio) ---
;     Formato C: "<prefijo>▶ valor ◀ (NombreCampo)" - valor primero, nombre entre parentesis.
LineaPrevio(engine, accion := "", valorOverride := "")
{
    if (engine.actionLog.Length = 0)
        return ""

    prevAccion := engine.actionLog[engine.actionLog.Length]
    prevSlot := prevAccion["slot"]
    prevNombre := engine.schema.Field(prevSlot).name
    prevValor := (valorOverride != "") ? valorOverride : engine.queue[prevSlot]

    if (prevValor = "")
        prevValor := "(vacio)"

    prefijo := (accion != "") ? accion ": " : ""
    return prefijo EnNegrita(prevValor) " (" prevNombre ")"
}
```

- [ ] **Step 2.2: Adaptar asserts existentes en `Tests/Test_TooltipFormatter.ahk`**

Los asserts del formato viejo `Nombre: ▶ valor ◀` deben pasar a `▶ valor ◀ (Nombre)`. Aplicar reemplazos exactos:

| Buscar | Reemplazar con |
|---|---|
| `"Account number: " NEGRITA_OPEN "ACC-99999" NEGRITA_CLOSE` | `NEGRITA_OPEN "ACC-99999" NEGRITA_CLOSE " (Account number)"` |
| `"Account number:"` (sin negrita, en otro tooltip) | `" (Account number)"` (ojo: revisar contexto, puede ser AssertContains) |
| `"Previous balance: " NEGRITA_OPEN "1000" NEGRITA_CLOSE` | `NEGRITA_OPEN "1000" NEGRITA_CLOSE " (Previous balance)"` |
| `"omitido: Previous balance: " NEGRITA_OPEN "1000" NEGRITA_CLOSE` | `"omitido: " NEGRITA_OPEN "1000" NEGRITA_CLOSE " (Previous balance)"` |
| `"descartado: Previous balance:"` | `"descartado: "` (verificar contexto — el assert era AssertContains buscando substring) |
| `"Invoice Total Including PastDue: " NEGRITA_OPEN "3000" NEGRITA_CLOSE` | `NEGRITA_OPEN "3000" NEGRITA_CLOSE " (Invoice Total Including PastDue)"` |
| `"Account number: " NEGRITA_OPEN "(vacio)" NEGRITA_CLOSE` | `NEGRITA_OPEN "(vacio)" NEGRITA_CLOSE " (Account number)"` |

Asserts del prompt `(slot/9)` deben pasar a `(filledCount/9)`. Esto es donde aparece `'Busca "X" (N/9)'`:

| Buscar | Reemplazar con |
|---|---|
| `'Busca "Past Total Payments" (6/9)'` | `'Busca "Past Total Payments" (5/9)'` (5 llenos: ACC + Sep15 + Oct15 + Logitech + 1000) |
| `'Busca "Past due" (7/9) - esperado: 500.00'` | `'Busca "Past due" (6/9) - esperado: 500.00'` (6 llenos, +Past pay) |
| `'Busca "Invoice Total Including PastDue" (9/9) - esperado: 3000.00'` | `'Busca "Invoice Total Including PastDue" (8/9) - esperado: 3000.00'` (8 llenos) |
| `'Busca "Invoice date" (2/9)'` | `'Busca "Invoice date" (1/9)'` (1 lleno: ACC-99999) |
| `'Busca "Invoice date" (2/9)'` (otra occurrence en ConError) | idem |

Y los asserts de "Listo" cambian de formato:

| Buscar | Reemplazar con |
|---|---|
| `AssertContains(tFin, "Listo 9/9", "T fin: listo")` | `AssertContains(tFin, "Listo 9/9 - cola llena", "T fin: listo con cola llena")` |
| `AssertContains(tFin, "- ^+s para pegar", "T fin: hint hotkey")` | `AssertContains(tFin, "^+s para pegar, ^+e para revisar", "T fin: hint hotkeys completos")` |

Asserts de slot omitido `(vacio)` siguen válidos en su contenido pero el formato C cambia:

| Buscar | Reemplazar con |
|---|---|
| `'Busca "Invoice date" (2/9)'` (en bloque de slot omitido) | `'Busca "Invoice date" (1/9)'` (omitido NO cuenta como lleno) |

- [ ] **Step 2.3: Agregar tests nuevos al final, antes de `ReportarYSalir()`**

```ahk
; ====================================================================
; LineaPrompt - cola llena con cola-llena lema y hint persistente
; ====================================================================
eFin := CaptureEngine(CrearAsignetHeaderV1())
eFin.Arm()
inputs := ["ACC", "01/01/2026", "02/01/2026", "Corp", "1000", "-500", "500", "2500", "3000"]
Loop 9
    eFin.PushRaw(inputs[A_Index])

pFin := LineaPrompt(eFin)
AssertContains(pFin, "Listo 9/9", "Listo: x/n con FilledCount")
AssertContains(pFin, "cola llena", "Listo: lema cola llena")
AssertContains(pFin, "^+s para pegar", "Listo: hint paste")
AssertContains(pFin, "^+e para revisar", "Listo: hint review SIEMPRE presente")

; --- Listo con omits: x < n pero IsComplete porque AutoAdvance no encuentra "" ---
;     (NO aplica porque IsComplete = NextSlot=0 = no hay vacios. Si hay vacios, no esta complete.)
;     Skip omitido NO completa la cola en el sentido nuevo.
eOmCompl := CaptureEngine(CrearAsignetHeaderV1(), false)  ; autoCalc OFF
eOmCompl.Arm()
Loop 9
    eOmCompl.SkipCurrent()  ; todos vacios sin autocalc
AssertEq(eOmCompl.FilledCount, 0, "Skip x9 sin autocalc: FilledCount=0")
; AutoAdvance: tras skip slot 9, busca "" desde slot 10 (no), desde 1: encuentra slot 1.
; targetSlot = 1, NextSlot = 1, IsComplete = false. Listo NO aparece.
AssertEq(eOmCompl.IsComplete, false, "Skip todo sin autocalc: NO IsComplete (hay vacios)")

; ====================================================================
; LineaPrevio - usa actionLog (no queue.Length), formato C
; ====================================================================
eLP := CaptureEngine(CrearAsignetHeaderV1())
eLP.Arm()
eLP.PushRaw("ACC-1234")
prevDirecto := LineaPrevio(eLP)
AssertContains(prevDirecto, NEGRITA_OPEN "ACC-1234" NEGRITA_CLOSE, "LineaPrevio formato C: valor con flechas")
AssertContains(prevDirecto, "(Account number)", "LineaPrevio formato C: nombre entre parentesis")
AssertEq(InStr(prevDirecto, "Account number:"), 0, "LineaPrevio formato C: NO usa 'Nombre: valor'")

; --- Tras Jump+Push, previo refleja el slot que se acaba de pushear ---
eLP.PushRaw("01/01/2026")  ; slot 2
eLP.PushRaw("02/01/2026")  ; slot 3
eLP.JumpTo(1)
eLP.PushRaw("ACC-9999")    ; reemplaza slot 1
prevTrasJump := LineaPrevio(eLP)
AssertContains(prevTrasJump, NEGRITA_OPEN "ACC-9999" NEGRITA_CLOSE, "Previo tras Jump+Push: valor nuevo")
AssertContains(prevTrasJump, "(Account number)", "Previo tras Jump+Push: nombre del slot reemplazado")

; --- Previo con accion (omitido / descartado) ---
eOm := CaptureEngine(CrearAsignetHeaderV1())
eOm.Arm()
eOm.PushRaw("ACC")
eOm.SkipCurrent()  ; slot 2 -> "", actionLog crece
prevOm := LineaPrevio(eOm, "omitido")
AssertContains(prevOm, "omitido: " NEGRITA_OPEN "(vacio)" NEGRITA_CLOSE " (Invoice date)", "Previo omitido formato C")
```

- [ ] **Step 2.4: Correr suite y verificar GREEN**

Run: `pwsh -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"`

Expected: `ALL TESTS PASSED`. Asserts esperados ≈ 555.

- [ ] **Step 2.5: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/TooltipFormatter.ahk Tests/Test_TooltipFormatter.ahk
git commit -m "feat(tooltip): formato C, cola-llena lema, FilledCount en x/n

- LineaPrompt cola llena: 'Listo x/n - cola llena - ^+s para pegar, ^+e para revisar'
  persistente, hint ^+e siempre visible.
- LineaPrompt durante captura: x/n usa FilledCount (no slot index).
- LineaPrevio formato C: '▶ valor ◀ (NombreCampo)' - valor primero,
  nombre entre parentesis para que el operador no lea el nombre primero
  y termine 'buscando dos veces' el campo previo.
- LineaPrevio fuente: actionLog (no queue.Length) - tras Jump+Push refleja
  el slot recien actuado, no 'el ultimo de la cola'."
```

---

## Task 3: ManualInputGui — picker compacto

**Files:**
- Modify: `Lib/ManualInputGui.ahk`

**Contexto:** No hay tests unit (side-effect-only). Verificación: `/Validate` syntax + smoke manual al final del plan.

- [ ] **Step 3.1: Reemplazar el cuerpo de `Lib/ManualInputGui.ahk`**

```ahk
#Requires AutoHotkey v2.0
#Include "CaptureEngine.ahk"
#Include "TooltipFormatter.ahk"

; ====================================================================
; ManualInputGui - GUI flotante: input manual + picker de slots.
;
; Toggle: Open() abre, Close() cierra (sin guardar). Toggle() alterna.
;
; Layout:
;   - Input box arriba bound al slot NextSlot al momento de Open.
;     Submit (Enter o boton) -> engine.PushManual(texto).
;   - Lista de slots abajo. Default: solo vacios. Boton "Ver todos"
;     toggle a la lista completa con valores actuales. Click en fila
;     -> engine.JumpTo(slot), cierra GUI, callback "jump".
;   - Si engine.IsComplete: input deshabilitado, mensaje "Cola llena".
;
; Side effect-only - no tests unit (probar manualmente con ^+e).
; ====================================================================

class ManualInputGui
{
    engine := ""
    onAfterPush := ""
    gui := ""
    showAll := false  ; toggle: false = solo vacios, true = todos

    __New(engine, onAfterPush)
    {
        this.engine := engine
        this.onAfterPush := onAfterPush
    }

    IsOpen => IsObject(this.gui)

    Toggle()
    {
        if this.IsOpen
            this.Close()
        else
            this.Open()
    }

    Open()
    {
        if !this.engine.isCapturing
        {
            ToolTip("No hay captura activa - usa ^+a primero")
            SetTimer(() => ToolTip(), -1500)
            return
        }

        this.showAll := false
        this.Render()
    }

    Render()
    {
        ; Si esta abierto, cerrar y reconstruir
        if this.IsOpen
        {
            try this.gui.Destroy()
            this.gui := ""
        }

        completo := this.engine.IsComplete
        slot := this.engine.NextSlot  ; 0 si completo
        n := this.engine.schema.Length
        filled := this.engine.FilledCount

        if (completo)
            titulo := "Picker - cola llena (" filled "/" n ")"
        else
            titulo := "Entrada manual / Picker - slot " slot " (" filled "/" n ")"

        g := Gui("+AlwaysOnTop +ToolWindow", titulo)
        g.SetFont("s10", "Segoe UI")
        g.MarginX := 10
        g.MarginY := 10

        ; --- Input box (deshabilitado si completo) ---
        if (completo)
        {
            g.Add("Text", "x10 y10 w400", "Cola llena. Click en un slot para editar.")
            edt := g.Add("Edit", "x10 y34 w400 h26 vTexto Disabled", "")
        }
        else
        {
            nombre := this.engine.schema.Field(slot).name
            g.Add("Text", "x10 y10 w400", 'Escribi el valor para "' nombre '" y dale Enter:')
            edt := g.Add("Edit", "x10 y34 w400 h26 vTexto")
        }

        btnOk := g.Add("Button", "x244 y68 w80 h28 Default", "Aceptar")
        btnCancel := g.Add("Button", "x330 y68 w80 h28", "Cancelar")
        btnOk.OnEvent("Click", (*) => this.Confirm())
        btnCancel.OnEvent("Click", (*) => this.Close())
        if (completo)
            btnOk.Enabled := false

        ; --- Toggle Ver todos / Solo vacios ---
        toggleLabel := this.showAll ? "Ocultar llenos" : "Ver todos los slots"
        btnToggle := g.Add("Button", "x10 y68 w160 h28", toggleLabel)
        btnToggle.OnEvent("Click", (*) => this.ToggleVista())

        ; --- Lista de slots ---
        g.Add("Text", "x10 y108 w400", this.showAll ? "Todos los slots:" : "Slots vacios:")

        yPos := 132
        nada := true
        Loop n
        {
            i := A_Index
            valor := this.engine.queue[i]
            esVacio := (valor = "")
            if (!this.showAll && !esVacio)
                continue
            nada := false

            display := i ".  " this.engine.schema.Field(i).name
            valorDisplay := esVacio ? "(vacio)" : valor
            arrow := (i = slot) ? "→ " : "   "

            ; +0x100 = SS_NOTIFY: hace que los Text controls disparen Click events en AHK v2
            txt := g.Add("Text", "x10 y" yPos " w50 h22 +0x100", arrow i ".")
            nameTxt := g.Add("Text", "x60 y" yPos " w180 h22 +0x100", this.engine.schema.Field(i).name)
            valTxt := g.Add("Text", "x244 y" yPos " w166 h22 +0x100", valorDisplay)

            ; Click en cualquiera de los 3 controles del row -> JumpTo
            handler := this.MakeJumpHandler(i)
            txt.OnEvent("Click", handler)
            nameTxt.OnEvent("Click", handler)
            valTxt.OnEvent("Click", handler)

            yPos += 22
        }

        if (nada)
        {
            g.Add("Text", "x10 y" yPos " w400", "Sin slots vacios. Usa 'Ver todos' para editar.")
            yPos += 22
        }

        this.gui := g
        g.OnEvent("Escape", (*) => this.Close())
        g.OnEvent("Close", (*) => this.Close())
        g.Show("AutoSize")
        if (!completo)
            edt.Focus()
    }

    ; --- Genera un handler que captura el slot por closure ---
    MakeJumpHandler(slot)
    {
        return ((*) => this.JumpTo(slot))
    }

    JumpTo(slot)
    {
        if !this.IsOpen
            return
        res := this.engine.JumpTo(slot)
        this.Close()
        ; Refresca tooltip via callback con accion "jump"
        this.onAfterPush.Call(
            Map("slot", res["slot"], "label", res["label"], "value", this.engine.queue[res["slot"]]),
            "jump"
        )
    }

    ToggleVista()
    {
        this.showAll := !this.showAll
        this.Render()
    }

    Confirm()
    {
        if !this.IsOpen
            return
        if this.engine.IsComplete
        {
            ToolTip("Cola llena - usa los slots de abajo para editar")
            SetTimer(() => ToolTip(), -1500)
            return
        }
        saved := this.gui.Submit(false)
        res := this.engine.PushManual(saved.Texto)
        if !res["ok"]
        {
            ToolTip(TooltipError(res["label"], res["error"]) "`nrecorregi o ^+e para cancelar")
            SetTimer(() => ToolTip(), -2500)
            return
        }
        this.Close()
        this.onAfterPush.Call(res, "manual")
    }

    Close()
    {
        if this.IsOpen
        {
            try this.gui.Destroy()
            this.gui := ""
        }
    }
}
```

- [ ] **Step 3.2: Validar sintaxis del archivo**

Run:
```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\Lib\ManualInputGui.ahk') -RedirectStandardError "$env:TEMP\mig.err" -RedirectStandardOutput "$env:TEMP\mig.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\mig.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`, stderr vacío.

- [ ] **Step 3.3: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Lib/ManualInputGui.ahk
git commit -m "feat(gui): picker compacto con slot list + Ver todos toggle

- Open: input box bound a NextSlot + lista de slots vacios.
- Boton 'Ver todos los slots' toggle a vista completa con valores.
- Click en cualquier columna de un row -> engine.JumpTo(slot), cierra GUI,
  callback 'jump' para refrescar tooltip.
- Cola llena: input deshabilitado, mensaje 'Click en un slot para editar'.
- Boton Cancelar y Esc cierran sin accion.
- Renderizador unificado (Render) - re-construye GUI al togglear vista."
```

---

## Task 4: QuickEntry — flip autoCalc + handle "jump" accion

**Files:**
- Modify: `QuickEntry.ahk`

- [ ] **Step 4.1: Aplicar dos edits a `QuickEntry.ahk`**

Edit 1: la línea de configuración del autoCalc.

Buscar:
```ahk
global AUTO_CALCULAR_TOTALES_OMITIDOS := false
```
Reemplazar con:
```ahk
; Si true, omitir un slot con expectedFn (Past due, Invoice Total)
; pushea el valor calculado en vez de "". Por default ON: el operador
; suele querer que el calculo automatico llene el slot omitido.
global AUTO_CALCULAR_TOTALES_OMITIDOS := true
```

Edit 2: `RefrescarTooltip` debe tratar `accion = "jump"` igual que `"manual"` (sin prefijo).

Buscar:
```ahk
RefrescarTooltip(res, accion := "")
{
    global engine
    ; "manual" no muestra prefijo: el previo se ve igual que un push normal.
    accionMostrar := (accion = "manual") ? "" : accion
    ToolTip(TooltipPostAccion(engine, accionMostrar))
}
```
Reemplazar con:
```ahk
RefrescarTooltip(res, accion := "")
{
    global engine
    ; "manual" y "jump" no muestran prefijo: el previo se ve natural
    ; (manual = push tipeado; jump = solo movio cursor, no hubo accion).
    accionMostrar := (accion = "manual" || accion = "jump") ? "" : accion
    ToolTip(TooltipPostAccion(engine, accionMostrar))
}
```

- [ ] **Step 4.2: Validar sintaxis del entry point**

Run:
```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk') -RedirectStandardError "$env:TEMP\qe.err" -RedirectStandardOutput "$env:TEMP\qe.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\qe.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`, stderr vacío.

- [ ] **Step 4.3: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add QuickEntry.ahk
git commit -m "feat(quickentry): autoCalc por default ON + jump action no-prefijo

- AUTO_CALCULAR_TOTALES_OMITIDOS = true: omitir Past due o Invoice Total
  pushea el calculo (Previous + Past payments / Total + Past due).
  El operador puede revisar el valor antes de pegar.
- RefrescarTooltip ahora tambien trata accion='jump' como sin prefijo
  (el picker no hizo una mutacion, solo movio cursor)."
```

---

## Task 5: Tests Asignet end-to-end de autocalc

**Files:**
- Modify: `Tests/Test_AsignetHeader.ahk`

- [ ] **Step 5.1: Agregar bloque de tests al final, antes de `ReportarYSalir()`**

```ahk
; ====================================================================
; AutoCalc end-to-end con schema Asignet real - slot 7 y slot 9 en cadena
; ====================================================================

; --- AutoCalc slot 7 (Past due) ---
ea := CaptureEngine(CrearAsignetHeaderV1(), true)  ; autoCalc ON
ea.Arm()
inputsHappy := ["ACC", "01/01/2026", "02/01/2026", "Corp", "1000.00", "-500.00"]
Loop 6
    ea.PushRaw(inputsHappy[A_Index])
AssertEq(ea.NextSlot, 7, "Asignet pre-skip: NextSlot=7")
AssertEq(ea.ExpectedFor(7), "500.00", "Asignet ExpectedFor(7) con cola completa hasta 6 = 500.00")

skP7 := ea.SkipCurrent()
AssertEq(skP7["value"], "500.00", "Asignet Skip(7) autocalc value")
AssertEq(ea.queue[7], "500.00", "Asignet queue[7] = autocalc")
AssertEq(ea.FilledCount, 7, "Asignet FilledCount tras autocalc slot 7 = 7 (cuenta)")

; --- AutoCalc slot 9 - usa el slot 7 autocalc'd como dependencia ---
ea.PushRaw("2500.00")  ; slot 8
AssertEq(ea.NextSlot, 9, "Asignet pre-skip 9: NextSlot=9")
AssertEq(ea.ExpectedFor(9), "3000.00", "Asignet ExpectedFor(9) = 2500 + 500 (autocalc'd) = 3000.00")

skP9 := ea.SkipCurrent()
AssertEq(skP9["value"], "3000.00", "Asignet Skip(9) autocalc value")
AssertEq(ea.queue[9], "3000.00", "Asignet queue[9] = autocalc")
AssertEq(ea.IsComplete, true, "Asignet IsComplete tras autocalc slot 9")
AssertEq(ea.FilledCount, 9, "Asignet FilledCount=9 con dos autocalc")

; --- AutoCalc con dep incompleta retorna "" (no rompe) ---
eaPartial := CaptureEngine(CrearAsignetHeaderV1(), true)
eaPartial.Arm()
eaPartial.PushRaw("ACC")
eaPartial.PushRaw("01/01/2026")
eaPartial.PushRaw("02/01/2026")
eaPartial.PushRaw("Corp")
; queue = [ACC, 01/01, 02/01, Corp, "", "", "", "", ""]; NextSlot = 5
eaPartial.JumpTo(7)  ; salta directo a Past due sin haber llenado 5 y 6
skBad := eaPartial.SkipCurrent()
AssertEq(skBad["value"], "", "Asignet Skip(7) con dep5,6 vacios: autocalc retorna ''")
AssertEq(eaPartial.queue[7], "", "Asignet queue[7] queda '' (no se rompe)")
```

- [ ] **Step 5.2: Correr suite y verificar GREEN**

Run: `pwsh -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"`

Expected: `ALL TESTS PASSED`. Asserts esperados ≈ 568.

- [ ] **Step 5.3: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add Tests/Test_AsignetHeader.ahk
git commit -m "test(asignet): autocalc end-to-end slot 7 y 9 en cadena

- Slot 7 autocalc usa Previous + Past payments (1000 + (-500) = 500.00).
- Slot 9 autocalc usa Total + Past due autocalc'd (2500 + 500 = 3000.00).
- FilledCount cuenta slots autocalc'd (queue[i] != '').
- Dep incompleta: autocalc retorna '' sin romper (queue[i] queda '')."
```

---

## Task 6: Actualizar docs

**Files:**
- Modify: `docs/MANUAL_USUARIO.md`
- Modify: `docs/GUIA_TECNICA.md`

- [ ] **Step 6.1: Actualizar `docs/MANUAL_USUARIO.md` — sección "Cuando algo sale mal"**

Buscar la fila de la tabla con "Quisiste copiar pero el OCR falló":
```markdown
| El valor existe pero el OCR lo lee mal y no podés corregirlo desde la fuente | `Ctrl+Shift+E` abre una ventanita. Tipeás el valor a mano, Enter, listo. Para cancelar sin guardar: `Ctrl+Shift+E` de nuevo o Esc. |
```

Reemplazar con:
```markdown
| El valor existe pero el OCR lo lee mal y no podés corregirlo desde la fuente | `Ctrl+Shift+E` abre el **picker** (lista de slots vacíos + input manual). Tipeás el valor del slot actual + Enter. Para cancelar sin guardar: `Ctrl+Shift+E` de nuevo, Esc, o click en Cancelar. |
| Querés volver a un slot que omitiste o cargar uno fuera de orden | `Ctrl+Shift+E` → click en la fila del slot que querés (en la lista de vacíos). El picker cierra y el flujo de captura te posiciona en ese slot. Tras llenarlo, auto-avanza al **próximo vacío** (no al siguiente sequential). |
| Querés editar un slot ya lleno | `Ctrl+Shift+E` → "Ver todos los slots" → click en la fila del slot lleno. El próximo push (copy o manual) **reemplaza** el valor anterior. |
```

Buscar la sección "Pegar en el formulario" — el paso 5:
```markdown
### 5. Pegar en el formulario
Cuando el tooltip diga `Listo 9/9 - Ctrl+Shift+S para pegar`:
```

Reemplazar con:
```markdown
### 5. Pegar en el formulario
Cuando el tooltip diga `Listo 9/9 - cola llena - Ctrl+Shift+S para pegar, Ctrl+Shift+E para revisar`:
```

Buscar la sección "Mejores prácticas" y agregar al final:
```markdown
- **Past due e Invoice Total se autocalculan al omitir.** Si los omitís con `Ctrl+Shift+A`, QuickEntry les pone la suma de los slots que dependen (Past due = Previous + Past payments; Invoice Total = Total + Past due). Verificá el `esperado: X.XX` que muestra el tooltip antes de omitir.
```

- [ ] **Step 6.2: Actualizar `docs/GUIA_TECNICA.md` — sección "Lib/CaptureEngine.ahk"**

Buscar el bloque que empieza con "### 4. `Lib/CaptureEngine.ahk` — el motor" y reemplazar TODA la sección hasta antes de "### 5." con:

```markdown
### 4. `Lib/CaptureEngine.ahk` — el motor
Estado y lógica de la cola. **Casi todo es testeable sin runtime AHK real** porque inyectamos cleaner/validator/sendFn.

Estado interno:
- `schema` (InvoiceSchema, inmutable durante una captura)
- `queue: Array<String>` — **pre-alocada a `schema.Length`** con `""` en `Arm`. `queue[i] != ""` significa "slot i lleno". Length es siempre `schema.Length`.
- `actionLog: Array<Map>` — cada `Push`/`Skip` registra `{slot, prevValue}`. `Undo` hace pop y restaura.
- `targetSlot: Integer` — `0` = sequential (`NextSlot` escanea queue por primer `""`). `!= 0` = el picker o un Undo forzó cursor a ese slot.
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

Método con side effects (probado en integración manual):
- `PasteBatch(sendFn?, sleepFn?)` — itera `schema.ordenPegado`, pone valor en clipboard, manda `^v`, luego `tabsAfter` Tabs. **No manda Tabs después del último slot.** Restaura `clipBackup` al final. `sendFn`/`sleepFn` son inyectables para tests.
```

- [ ] **Step 6.3: Actualizar `docs/GUIA_TECNICA.md` — sección "Lib/TooltipFormatter.ahk"**

Buscar el bloque "### 5. `Lib/TooltipFormatter.ahk`" y reemplazar la lista de funciones con:

```markdown
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
```

- [ ] **Step 6.4: Actualizar `docs/GUIA_TECNICA.md` — sección "Lib/ManualInputGui.ahk"**

Buscar el bloque "### 7. `Lib/ManualInputGui.ahk`" y reemplazar con:

```markdown
### 7. `Lib/ManualInputGui.ahk` — picker compacto
Toggle (`^+e`). Layout:
- **Input box arriba** bound a `engine.NextSlot` al momento de Open. Submit (Enter o botón Aceptar) → `engine.PushManual(texto)`. Si valida, cierra y refresca tooltip. Si error, deja GUI abierta y muestra `TooltipError`.
- **Lista de slots abajo.** Default: solo slots vacíos (compacto). Botón `Ver todos los slots` toggle a la lista completa con valores actuales (marcando el slot actual con `→`). Click en cualquier columna de una fila → `engine.JumpTo(slot)`, cierra GUI, callback `"jump"` para refrescar tooltip.
- **Cola llena:** input deshabilitado con mensaje `Click en un slot para editar`. La lista (con "Ver todos") permite re-editar slots ya cargados.

Side effect-only — no tests unit. Smoke test manual.
```

- [ ] **Step 6.5: Commit**

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git add docs/MANUAL_USUARIO.md docs/GUIA_TECNICA.md
git commit -m "docs: picker compacto + autocalc por default + estado engine nuevo

- MANUAL_USUARIO: 3 filas nuevas en 'Cuando algo sale mal' para picker
  (manual input, jump a vacio, edit slot lleno). Listo persistente con
  hint '^+e para revisar'. Past due/Invoice Total autocalc explicado.
- GUIA_TECNICA: CaptureEngine refleja queue pre-alocada + actionLog +
  targetSlot + JumpTo + AutoAdvance + FilledCount. TooltipFormatter
  refleja formato C + cola-llena + actionLog. ManualInputGui describe
  el picker compacto con toggle Ver todos."
```

---

## Task 7: Verificación final

**Files:** ninguno (solo verificaciones).

- [ ] **Step 7.1: Correr la suite completa de tests**

Run: `pwsh -ExecutionPolicy Bypass -File "C:\Users\Usuario\Desktop\Asignet\Tests\runner.ps1"`

Expected: `ALL TESTS PASSED`. Total asserts ≥ 565. Si algo falla, volver al task que corresponda.

- [ ] **Step 7.2: Validar sintaxis del entry point**

Run:
```powershell
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$p = Start-Process -FilePath $ahk -ArgumentList @('/Validate','/ErrorStdOut=utf-8','C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk') -RedirectStandardError "$env:TEMP\qe.err" -RedirectStandardOutput "$env:TEMP\qe.out" -PassThru -Wait -NoNewWindow
"exit=$($p.ExitCode)"
Get-Content "$env:TEMP\qe.err" -ErrorAction SilentlyContinue
```

Expected: `exit=0`, stderr vacío.

- [ ] **Step 7.3: Smoke check manual (instrucciones para el usuario)**

Levantar QuickEntry:
```
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\Usuario\Desktop\Asignet\QuickEntry.ahk"
```

Checklist en Notepad o Asignet form:

1. `Ctrl+Shift+A` → tooltip `Busca "Account number" (0/9)`. ✓ formato C, FilledCount=0.
2. `Ctrl+C` sobre `ACC-1234` → tooltip avanza, previo `▶ ACC-1234 ◀ (Account number)`. ✓
3. `Ctrl+Shift+A` para omitir slot 2 → tooltip avanza a slot 3, previo `omitido: ▶ (vacio) ◀ (Invoice date)`. ✓
4. Cargar 3, 4, 5, 6 (precios y fechas válidos). En slot 7 verificar tooltip muestra `esperado: 500.00` + breakdown de operandos. ✓
5. `Ctrl+Shift+A` en slot 7 (autocalc) → tooltip avanza, previo `omitido: auto-calc 500.00: ▶ 500.00 ◀ (Past due)`. Validar que FilledCount sumó. ✓
6. `Ctrl+Shift+E` → picker abre. Lista debería mostrar SOLO slot 2 (omitido) y los aún no llenados. ✓
7. Click en slot 2 (Invoice date) → picker cierra, tooltip vuelve `Busca "Invoice date" (X/9)`. ✓
8. `Ctrl+C` `01/15/2026` → tooltip avanza al **próximo vacío** (no al slot 3 que ya está lleno), debería ir a 8 o 9 según qué falte. ✓
9. Llenar el resto. Cuando todo esté lleno: tooltip `Listo 9/9 - cola llena - ^+s para pegar, ^+e para revisar`. ✓
10. `Ctrl+Shift+E` con cola llena → picker abre con input deshabilitado y mensaje "Click en un slot para editar". Botón "Ver todos" muestra la lista completa. Click en un slot lleno → cierra picker, tooltip vuelve a `Busca "X" (...)`. ✓
11. `Ctrl+Shift+R` resetea. ✓
12. `Ctrl+Shift+V` (PegadoEspecial) sigue funcionando standalone. ✓

Si todo OK: implementación completa.

- [ ] **Step 7.4: Commit final (si hubo ajustes durante smoke)**

Solo si el smoke detectó algún ajuste menor. Si no hubo cambios, omitir.

```bash
cd "C:/Users/Usuario/Desktop/Asignet"
git status
# Si hay cambios:
git add <archivos>
git commit -m "fix(<area>): <ajuste detectado en smoke>"
```

---

## Riesgos durante la implementación

| Riesgo | Mitigación |
|---|---|
| Test_TooltipFormatter rompe en Task 1 (depende del formato viejo). | Esperado. El runner muestra qué archivo crashea — esos tests se arreglan en Task 2. No correr suite "all green" entre Task 1 y Task 2. |
| GUI del picker no actualiza live cuando llega un `Ctrl+C` con la GUI abierta. | Out of scope per spec. Operador cierra y reabre. |
| `AutoAdvance` ciclo infinito si toda la queue está vacía y no hay `targetSlot` claro. | El loop decrementa naturalmente: arranca en `slotJustActed+1`, va hasta `schema.Length`, después de 1 hasta `slotJustActed-1`. Siempre termina; en el peor caso retorna `targetSlot := 0`. Cubierto por test "AutoAdvance ciclico". |
| `AutoCalc` con `expectedFn` que retorna `""` (deps incompletas) genera slot vacío. AutoAdvance lo encuentra y vuelve. | Comportamiento intencional. Cubierto por test "Asignet Skip(7) con dep5,6 vacios". |
| Click en filas de la GUI en AHK v2: `Text` controls no tienen `OnEvent("Click")` por default. Verificar que funciona. | Si no funciona, fallback: usar controles `Link` o un `ListView` con `OnEvent("Click")` o `DoubleClick`. Detección en Step 3.2 (`/Validate` no captura issues runtime). Si en smoke (Step 7.3) los clicks no responden, refactor a ListView con doble-click. |
