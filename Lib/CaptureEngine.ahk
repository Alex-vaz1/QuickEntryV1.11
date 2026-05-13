#Requires AutoHotkey v2.0
#Include "Schema.ahk"

; ====================================================================
; CaptureEngine - motor de captura schema-driven.
;
; Estado interno:
;   schema          - InvoiceSchema (inmutable durante una captura)
;   queue           - Array<String>: pre-alocado a schema.Length, todos ""
;                     inicialmente. queue[i] != "" significa "slot i lleno".
;   actionLog       - Array<Map>: cada accion = {slot, prevValue}, para Undo.
;   targetSlot      - Integer: 0 = sequential (NextSlot escanea queue).
;                     != 0 = el picker o un Undo forzo cursor a ese slot.
;   preloadedSlots  - Map<Integer, true>: slots cargados via Scan() (lectura
;                     del form). PasteBatch los SKIP (no re-pega), solo manda
;                     Tabs. Push/Skip sobre uno de estos slots lo elimina
;                     del map (override manual = ya no es preloaded).
;   isCapturing     - Boolean
;   clipBackup      - String
;   autoCalcFlag    - Boolean: si true, SkipCurrent en slot con expectedFn
;                     pushea el valor calculado en vez de "".
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
;   PreloadedCount      - prop: cuenta de slots en preloadedSlots
;
; Helper privado:
;   AutoAdvance(slotJustActed) - busca proximo "" desde slot+1 en adelante;
;                                si no, desde 1 hasta slot-1. Si nada, 0.
;
; Metodos con side effects (cubiertos en integracion manual):
;   Scan(captureFieldFn?, sendFn?, sleepFn?, clipSnapshot?)
;       - corre prePasteSteps + lee cada slot via Ctrl+A/Ctrl+C +
;         pre-popula queue/preloadedSlots con valores del form actual.
;         AutoAdvance(0) tras el loop = cursor al primer vacio.
;   PasteBatch(sendFn?, sleepFn?) - itera schema.ordenPegado, paste+Tabs.
;     Skip paste para slots en preloadedSlots (solo manda Tabs).
; ====================================================================

; Sleep 80ms tras Ctrl+A: debouncing de forms web retrasa la seleccion.
; ClipWait 0.5s: margen al OS para serializar eventos clipboard.
DefaultCaptureField()
{
    A_Clipboard := ""
    Sleep 30
    SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}"
    Sleep 20
    SendInput "^a"
    Sleep 80
    SendInput "^c"
    if !ClipWait(0.5, 1)
        return ""
    return A_Clipboard
}

class CaptureEngine
{
    schema := ""
    queue := []
    actionLog := []
    targetSlot := 0
    preloadedSlots := Map()
    isCapturing := false
    clipBackup := ""
    autoCalcFlag := false
    abortFlag := false           ; set true por Abort() para interrumpir PasteBatch/Scan loops
    extraTabsAfterSlot := Map()  ; Map<slot, extraTabs> para casos como template field opcional

    __New(schema, autoCalcFlag := false)
    {
        this.schema := schema
        this.autoCalcFlag := autoCalcFlag
        this.ResetState()
    }

    ResetState()
    {
        this.queue := []
        Loop this.schema.Length
            this.queue.Push("")
        this.actionLog := []
        this.targetSlot := 0
        this.preloadedSlots := Map()
        this.abortFlag := false
        this.extraTabsAfterSlot := Map()
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

    PreloadedCount => this.preloadedSlots.Count

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

    ; Solo setea flag; los loops hacen break en el proximo ciclo.
    ; NO toca queue/state — eso lo hace Reset() despues. Idempotente.
    Abort()
    {
        this.abortFlag := true
    }

    ; Para forms con campos opcionales intercalados (ej. template field entre Account e Invoice date).
    ; count=0 elimina la entrada del map.
    SetExtraTabsAfter(slot, count)
    {
        if (count > 0)
            this.extraTabsAfterSlot[slot] := count
        else if this.extraTabsAfterSlot.Has(slot)
            this.extraTabsAfterSlot.Delete(slot)
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
        if this.preloadedSlots.Has(slot)
            this.preloadedSlots.Delete(slot)
        this.targetSlot := 0
        this.AutoAdvance(slot)
        return Map("ok", true, "error", "", "label", campo.name, "slot", slot, "value", limpio)
    }

    PushManual(value) => this.PushRaw(value)

    ; Bypassa validate, no clean: si cleaner devuelve "" sigue rechazando.
    ; Usado cuando el operador confirma "Forzar igual" tras valor invalido.
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
        if this.preloadedSlots.Has(slot)
            this.preloadedSlots.Delete(slot)
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

    ; Validador NO se ejecuta: es clear explicito del operador, no un push de empty.
    ClearSlot(slot)
    {
        if (slot < 1 || slot > this.schema.Length)
            return
        this.actionLog.Push(Map("type", "clear", "slot", slot, "prevValue", this.queue[slot]))
        this.queue[slot] := ""
        if this.preloadedSlots.Has(slot)
            this.preloadedSlots.Delete(slot)
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

    ; Liberacion de modificadores fisicos es concern del call site (QuickEntry), no del engine.
    EjecutarPrePasteSteps(sendFn, sleepFn)
    {
        for paso in this.schema.prePasteSteps
        {
            if (this.abortFlag)
                return
            sendFn.Call(paso)
            sleepFn.Call(150)
        }
    }

    ; usarStepsAfter=true en PasteBatch (form vacio, stepsAfter p.ej. dropdown);
    ; false en Scan (form lleno, no se necesitan interacciones extra).
    EmitirTabsTrasSlot(campo, isLast, sendFn, sleepFn, usarStepsAfter := false)
    {
        if isLast
            return
        if (usarStepsAfter && campo.stepsAfter.Length > 0)
        {
            for paso in campo.stepsAfter
            {
                if (this.abortFlag)
                    return
                if IsNumber(paso)
                    sleepFn.Call(paso)
                else
                {
                    sendFn.Call(paso)
                    sleepFn.Call(150)
                }
            }
        }
        else
        {
            Loop campo.tabsAfter
            {
                if (this.abortFlag)
                    break
                sendFn.Call("{Tab}")
                sleepFn.Call(150)
            }
        }
    }

    EjecutarPreScanSteps(sendFn, sleepFn)
    {
        steps := (this.schema.preScanSteps.Length > 0)
            ? this.schema.preScanSteps
            : this.schema.prePasteSteps
        for paso in steps
        {
            if (this.abortFlag)
                return
            sendFn.Call(paso)
            sleepFn.Call(150)
        }
    }

    ; PRECONDICION: cursor al tope del form (mismo punto de partida que ^+s).
    ; Tras Scan el cursor queda al final; el operador vuelve al tope antes de ^+s.
    Scan(captureFieldFn := unset, sendFn := unset, sleepFn := unset, clipSnapshot := "")
    {
        if !IsSet(captureFieldFn)
            captureFieldFn := DefaultCaptureField
        if !IsSet(sendFn)
            sendFn := (s) => SendInput(s)
        if !IsSet(sleepFn)
            sleepFn := (ms) => Sleep(ms)

        ; Preservar extraTabsAfterSlot a traves del ResetState. El caller
        ; (DoHeaderScan) configura los tabs extra ANTES de llamar Scan,
        ; pero ResetState los limpia - asi que los re-aplicamos despues.
        extraTabsBackup := this.extraTabsAfterSlot.Clone()
        this.ResetState()
        this.extraTabsAfterSlot := extraTabsBackup
        this.isCapturing := true
        this.clipBackup := clipSnapshot

        this.EjecutarPreScanSteps(sendFn, sleepFn)

        orden := this.schema.ordenPegado
        total := orden.Length

        for posicion, slot in orden
        {
            if (this.abortFlag)
                break
            campo := this.schema.Field(slot)
            isLast := (posicion = total)

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

            this.EmitirTabsTrasSlot(campo, isLast, sendFn, sleepFn)

            ; Mismo bloque que PasteBatch: mantiene alineacion de cursor con ordenPegado.
            if (!isLast && this.extraTabsAfterSlot.Has(slot))
            {
                Loop this.extraTabsAfterSlot[slot]
                {
                    if (this.abortFlag)
                        break
                    sendFn.Call("{Tab}")
                    sleepFn.Call(150)
                }
            }
        }

        this.AutoAdvance(0)
        A_Clipboard := this.clipBackup
    }

    PasteBatch(sendFn := unset, sleepFn := unset)
    {
        if !IsSet(sendFn)
            sendFn := (s) => SendInput(s)
        if !IsSet(sleepFn)
            sleepFn := (ms) => Sleep(ms)

        this.EjecutarPrePasteSteps(sendFn, sleepFn)

        orden := this.schema.ordenPegado
        total := orden.Length

        for posicion, slot in orden
        {
            if (this.abortFlag)
                break
            campo := this.schema.Field(slot)
            valor := this.queue[slot]
            isLast := (posicion = total)
            esPreloaded := this.preloadedSlots.Has(slot)

            ; Tres razones para SKIP el paste (solo Tabs):
            ;   1. valor vacio: nada que pegar (slot omitido sin autocalc)
            ;   2. campo.skipPaste: declarado en schema (lupa de busqueda)
            ;   3. preloaded por HeaderScan: el valor ya esta en el form
            if (valor != "" && !campo.skipPaste && !esPreloaded)
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

            this.EmitirTabsTrasSlot(campo, isLast, sendFn, sleepFn, true)

            if (!isLast && this.extraTabsAfterSlot.Has(slot))
            {
                Loop this.extraTabsAfterSlot[slot]
                {
                    if (this.abortFlag)
                        break
                    sendFn.Call("{Tab}")
                    sleepFn.Call(150)
                }
            }
        }
        A_Clipboard := this.clipBackup
    }
}
