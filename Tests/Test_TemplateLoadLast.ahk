#Requires AutoHotkey v2.0
#SingleInstance Off

#Include "..\Lib\MainHud.ahk"
#Include "_AssertHelpers.ahk"

; ====================================================================
; Test_TemplateLoadLast - Interacción templateMode + Load Last
; ====================================================================
; Estos tests documentan el contrato del par (Arm + SetExtraTabsAfter)
; y cubren el flujo de MainHud.LoadLastPaste con foco en templateMode.
;
; HISTORIA: hubo un bug 2026-05-12 donde LoadLastPaste llamaba engine.Arm()
; (que clarea extraTabsAfterSlot) pero NO re-aplicaba templateMode despues.
; Fix: extraido a `MainHud.ApplyLoadLastSnapshot` static (testeable).
;
; - GRUPO A: invariantes de Arm + SetExtraTabsAfter (engine-level).
; - GRUPO B: regression guard - simula el patron BUGGY anterior; sigue
;            pasando porque el engine se comporta deterministicamente.
;            Si un dev futuro elimina la linea SetExtraTabsAfter del
;            static method, T7/T8 fallan.
; - GRUPO C: valida el production code path directamente via el static
;            method MainHud.ApplyLoadLastSnapshot (no simulacion).
; - GRUPO D: workaround manual del operador + edge cases.

; --------------------------------------------------------------------
; Helpers
; --------------------------------------------------------------------

; Cuenta {Tab} emitidos por PasteBatch (concatena todos los sendFn calls
; y cuenta substrings).
CountTabs(sendLog)
{
    total := ""
    for s in sendLog
        total .= s
    n := 0
    pos := 1
    while (pos := InStr(total, "{Tab}", , pos))
    {
        n++
        pos += 5  ; len "{Tab}"
    }
    return n
}

; Simula el flujo ACTUAL de MainHud.LoadLastPaste (linea 886-917):
; Arm + restaurar queue + AutoAdvance. Sin re-aplicar templateMode.
SimulateLoadLastBuggy(engine, savedQueue)
{
    engine.Arm()
    Loop savedQueue.Length
        engine.queue[A_Index] := savedQueue[A_Index]
    engine.AutoAdvance(0)
}

; (El flujo CORREGIDO ahora vive en MainHud.ApplyLoadLastSnapshot — los
;  tests de GRUPO C invocan ese static method directamente para validar
;  el production code path, no una simulacion.)

; Mock schema 3 slots simples (sin validators reales, sin prePasteSteps).
mock := InvoiceSchema("mock", [
    Campo("A", (raw) => raw, (val, cola) => ""),
    Campo("B", (raw) => raw, (val, cola) => ""),
    Campo("C", (raw) => raw, (val, cola) => "")
])

; ====================================================================
; GRUPO A: invariantes de Arm + SetExtraTabsAfter (engine-level)
; ====================================================================

; --- T1: Arm clarea extraTabsAfterSlot
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 1, "T1: pre-Arm extra slot1 existe")
e.Arm()
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T1: Arm clarea extras (invariante engine)")

; --- T2: Reset también clarea
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)
e.Reset()
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T2: Reset clarea extras")

; --- T3: PasteBatch sin extras emite N-1 Tabs (3 slots → 2 Tabs)
e := CaptureEngine(mock)
e.Arm()
e.PushRaw("a")
e.PushRaw("b")
e.PushRaw("c")
sendLog := []
e.PasteBatch((s) => sendLog.Push(s), (*) => "")
AssertEq(CountTabs(sendLog), 2, "T3: 3 slots sin extras = 2 Tabs (no Tab tras último)")

; --- T4: PasteBatch con SetExtraTabsAfter(1, 1) emite 1 Tab adicional
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)
e.PushRaw("a")
e.PushRaw("b")
e.PushRaw("c")
sendLog := []
e.PasteBatch((s) => sendLog.Push(s), (*) => "")
AssertEq(CountTabs(sendLog), 3, "T4: slot 1 extra=1 → 3 Tabs totales")

; ====================================================================
; GRUPO B: simulación del flujo ACTUAL de MainHud.LoadLastPaste (BUGGY)
; ====================================================================
; Estos tests reproducen exactamente lo que MainHud.LoadLastPaste hace hoy.
; Demuestran que el engine queda en estado equivocado para templateMode=ON.

; --- T5: BUG — operador con templateMode=ON arma, scanea/pega, después
;         clickea Load Last. extraTabsAfterSlot queda vacío.
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)  ; templateMode=ON aplicado al armar (estado normal)
; ... operador trabaja, hace paste batch, dispara LoadLast ...
SimulateLoadLastBuggy(e, ["lastA", "lastB", "lastC"])
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T5: BUG - LoadLast pierde el flag de template")
sendLog := []
e.PasteBatch((s) => sendLog.Push(s), (*) => "")
AssertEq(CountTabs(sendLog), 2, "T5: BUG - PasteBatch emite 2 Tabs (faltó el extra del template)")

; --- T6: con templateMode=OFF, LoadLast queda accidentalmente correcto
;         (extraTabsAfterSlot vacío coincide con OFF, pero por motivo equivocado).
e := CaptureEngine(mock)
e.Arm()
; templateMode=OFF: no se hizo SetExtraTabsAfter, extra slot1 nunca se seteó
SimulateLoadLastBuggy(e, ["lastA", "lastB", "lastC"])
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T6: templateOFF + LoadLast - estado correcto por accidente")
sendLog := []
e.PasteBatch((s) => sendLog.Push(s), (*) => "")
AssertEq(CountTabs(sendLog), 2, "T6: PasteBatch emite 2 Tabs (correcto para OFF)")

; ====================================================================
; GRUPO C: validacion DIRECTA del production code (MainHud.ApplyLoadLastSnapshot)
; ====================================================================
; Estos tests invocan el static method real que MainHud.LoadLastPaste usa
; internamente. Si alguien rompe el fix (elimina SetExtraTabsAfter del
; static), estos tests fallan inmediatamente.

; --- T7: PRODUCTION - LoadLast con templateMode=ON emite extra Tab
e := CaptureEngine(mock)
MainHud.ApplyLoadLastSnapshot(e, ["lastA", "lastB", "lastC"], true)
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 1, "T7: production preserva extra slot 1")
AssertEq(e.extraTabsAfterSlot[1], 1, "T7: production setea extra=1")
sendLog := []
e.PasteBatch((s) => sendLog.Push(s), (*) => "")
AssertEq(CountTabs(sendLog), 3, "T7: production PasteBatch emite 3 Tabs (template OK)")

; --- T8: PRODUCTION - LoadLast con templateMode=OFF no setea extras
e := CaptureEngine(mock)
MainHud.ApplyLoadLastSnapshot(e, ["lastA", "lastB", "lastC"], false)
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T8: production con OFF no setea extra")
sendLog := []
e.PasteBatch((s) => sendLog.Push(s), (*) => "")
AssertEq(CountTabs(sendLog), 2, "T8: production OFF - PasteBatch emite 2 Tabs")

; --- T8b: PRODUCTION - slot vacio del INI deja queue vacio (post-Arm clean state)
e := CaptureEngine(mock)
MainHud.ApplyLoadLastSnapshot(e, ["", "B", ""], true)
AssertEq(e.queue[1], "", "T8b: slot 1 vacio del INI queda vacio en queue")
AssertEq(e.queue[2], "B", "T8b: slot 2 del INI se carga normalmente")
AssertEq(e.queue[3], "", "T8b: slot 3 vacio del INI queda vacio en queue")
AssertEq(e.extraTabsAfterSlot[1], 1, "T8b: templateMode=ON re-aplicado correctamente con queue parcial")

; ====================================================================
; GRUPO D: workaround del operador y edge cases
; ====================================================================

; --- T9: WORKAROUND actual del operador — toggle ON manual post-LoadLast
;         restaura el state vía OnTemplateToggle (engine.isCapturing=true).
e := CaptureEngine(mock)
SimulateLoadLastBuggy(e, ["lastA", "lastB", "lastC"])
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T9: post-LoadLast empty (bug confirmado)")
; OnTemplateToggle ve isCapturing=true (LoadLast hizo Arm) y llama SetExtraTabsAfter.
e.SetExtraTabsAfter(1, 1)
AssertEq(e.extraTabsAfterSlot[1], 1, "T9: toggle manual recupera el extra")
sendLog := []
e.PasteBatch((s) => sendLog.Push(s), (*) => "")
AssertEq(CountTabs(sendLog), 3, "T9: con workaround PasteBatch emite 3 Tabs")

; --- T10: toggles múltiples rápidos preservan estado final (no es bug aparte)
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)  ; ON
e.SetExtraTabsAfter(1, 0)  ; OFF
e.SetExtraTabsAfter(1, 1)  ; ON
e.SetExtraTabsAfter(1, 0)  ; OFF
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T10: secuencia ON-OFF-ON-OFF termina OFF")
e.SetExtraTabsAfter(1, 1)  ; ON final
AssertEq(e.extraTabsAfterSlot[1], 1, "T10: toggle final ON aplica")

ReportarYSalir()
