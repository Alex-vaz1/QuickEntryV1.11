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
; FOCO: state-level (queue + extraTabsAfterSlot + preloadedSlots). NO se
; invoca PasteBatch porque en CI headless el clipboard real puede bloquear
; (ClipWait sin servicio de clipboard) — la cobertura de PasteBatch + Tabs
; vive en Test_CaptureEngine.ahk (219 asserts), no aca.
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

; Simula el flujo ACTUAL de MainHud.LoadLastPaste (linea 886-917):
; Arm + restaurar queue + AutoAdvance. Sin re-aplicar templateMode.
SimulateLoadLastBuggy(engine, savedQueue)
{
    engine.Arm()
    Loop savedQueue.Length
        engine.queue[A_Index] := savedQueue[A_Index]
    engine.AutoAdvance(0)
}

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

; --- T3: SetExtraTabsAfter(1, 1) deja el extra en estado correcto
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 1, "T3: setea extra slot 1")
AssertEq(e.extraTabsAfterSlot[1], 1, "T3: valor extra slot 1 = 1")

; --- T4: SetExtraTabsAfter(1, 0) borra el extra
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)
e.SetExtraTabsAfter(1, 0)
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T4: SetExtraTabsAfter(1, 0) borra el extra")

; ====================================================================
; GRUPO B: simulación del flujo BUGGY anterior de MainHud.LoadLastPaste
; ====================================================================
; Reproduce exactamente lo que MainHud.LoadLastPaste hacia ANTES del fix.
; Demuestra que el engine queda en estado equivocado para templateMode=ON.

; --- T5: BUG histórico — templateMode=ON + LoadLast buggy pierde el flag.
e := CaptureEngine(mock)
e.Arm()
e.SetExtraTabsAfter(1, 1)  ; templateMode=ON aplicado al armar (estado normal)
; ... operador trabaja, hace paste batch, dispara LoadLast ...
SimulateLoadLastBuggy(e, ["lastA", "lastB", "lastC"])
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T5: BUG histórico - LoadLast pierde el flag de template")
AssertEq(e.queue[1], "lastA", "T5: queue se restaura igual")
AssertEq(e.queue[2], "lastB", "T5: queue se restaura igual")
AssertEq(e.queue[3], "lastC", "T5: queue se restaura igual")

; --- T6: con templateMode=OFF, LoadLast buggy queda accidentalmente correcto
;         (extraTabsAfterSlot vacío coincide con OFF, pero por motivo equivocado).
e := CaptureEngine(mock)
e.Arm()
; templateMode=OFF: no se llama SetExtraTabsAfter, extra slot1 nunca se seteó
SimulateLoadLastBuggy(e, ["lastA", "lastB", "lastC"])
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T6: templateOFF + LoadLast - estado correcto por accidente")

; ====================================================================
; GRUPO C: validación DIRECTA del production code (MainHud.ApplyLoadLastSnapshot)
; ====================================================================
; Invocan el static method real que MainHud.LoadLastPaste usa internamente.
; Si alguien rompe el fix (elimina SetExtraTabsAfter del static), estos
; tests fallan inmediatamente.

; --- T7: PRODUCTION - LoadLast con templateMode=ON re-aplica el extra Tab
e := CaptureEngine(mock)
MainHud.ApplyLoadLastSnapshot(e, ["lastA", "lastB", "lastC"], true)
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 1, "T7: production preserva extra slot 1 con templateMode=true")
AssertEq(e.extraTabsAfterSlot[1], 1, "T7: production setea extra=1")
AssertEq(e.queue[1], "lastA", "T7: queue se restaura desde snapshot")
AssertEq(e.queue[3], "lastC", "T7: queue se restaura desde snapshot")

; --- T8: PRODUCTION - LoadLast con templateMode=OFF deja extras vacios
e := CaptureEngine(mock)
MainHud.ApplyLoadLastSnapshot(e, ["lastA", "lastB", "lastC"], false)
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T8: production con templateMode=false no setea extra")

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

; --- T9: WORKAROUND del operador — toggle ON manual post-LoadLast buggy
;         restaura el state vía OnTemplateToggle (engine.isCapturing=true).
e := CaptureEngine(mock)
SimulateLoadLastBuggy(e, ["lastA", "lastB", "lastC"])
AssertEq(e.extraTabsAfterSlot.Has(1) ? 1 : 0, 0, "T9: post-LoadLast buggy state empty (bug confirmado)")
; OnTemplateToggle ve isCapturing=true (LoadLast hizo Arm) y llama SetExtraTabsAfter.
e.SetExtraTabsAfter(1, 1)
AssertEq(e.extraTabsAfterSlot[1], 1, "T9: toggle manual recupera el extra")

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
