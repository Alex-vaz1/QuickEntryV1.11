#Requires AutoHotkey v2.0

; PasteMutex.ahk - encapsula el lock que coordina:
;   - PegadoEspecial (^+v): paste con limpieza standalone
;   - HandlerCaptura (OnClipboardChange): captura batch al engine
;   - DoSoltar / DoHeaderScan: batch paste / scan del form
;
; Antes de Fase-7 esto era una global `pegadoEnCurso` cross-file. Esta clase
; centraliza la convencion para que un tercer flujo no pueda olvidar tomar el lock.

class PasteMutex
{
    static _locked := false

    ; readonly property - true si algun flujo tiene el lock tomado.
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
