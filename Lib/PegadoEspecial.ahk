#Requires AutoHotkey v2.0
#Include "Cleaners.ahk"
#Include "PasteMutex.ahk"

; ====================================================================
; PegadoEspecial - intercepta el paste del operador para normalizar
; fechas/precios antes de que lleguen al campo destino, sin alterar
; el clipboard de sistema al terminar.
;
; NOTA HISTORICA: la version legacy soportaba pegar DOS fechas consecutivas
; con Tab entre ellas (PegarDosFechas / "CASO A"). Ese flujo nunca se uso
; en produccion y se elimino para simplificar.
;
; PasteMutex (Lib/PasteMutex.ahk) es lock compartido con CaptureEngine.PasteBatch:
; impide que HandlerCaptura interprete los cambios de clipboard internos de este
; flujo como copias reales del usuario y contamine la cola de captura.
; ====================================================================

; Timings críticos de PegadoEspecial — valores mínimos probados manualmente;
; cambiarlos puede romper el flujo de paste en apps lentas (SAP GUI, Adobe).
PEGADO_MODIFIER_DRAIN_MS  := 30   ; tick para que AHK procese los Shift/Ctrl/Alt up antes del siguiente SendInput
PEGADO_CLIPBOARD_WAIT_S   := 0.5  ; timeout de ClipWait: cuánto esperar a que el clipboard refleje el valor limpio
PEGADO_POST_PASTE_SETTLE_MS := 150 ; tiempo para que la app destino consuma el ^v antes de restaurar el clipboard
PEGADO_MUTEX_DRAIN_MS     := 50   ; drena OnClipboardChange encolados antes de liberar el mutex

PegadoEspecial()
{
    if !PasteMutex.Acquire()
        return
    try
    {
        SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
        Sleep PEGADO_MODIFIER_DRAIN_MS

        clipOriginal := A_Clipboard
        crudo := A_Clipboard
        limpio := LimpiarComoPegadoEspecial(crudo)

        if (limpio = "")
            return

        A_Clipboard := ""
        A_Clipboard := limpio
        if !ClipWait(PEGADO_CLIPBOARD_WAIT_S, 1)
        {
            A_Clipboard := clipOriginal
            MsgBox "Error al actualizar clipboard."
            return
        }
        SendInput "^v"
        Sleep PEGADO_POST_PASTE_SETTLE_MS
        A_Clipboard := clipOriginal
    }
    finally
    {
        ; Drena los OnClipboardChange encolados (clear + set limpio + restore).
        ; Si soltamos el mutex antes de que el message pump los procese,
        ; HandlerCaptura los ve como copias reales y contamina la cola.
        Sleep PEGADO_MUTEX_DRAIN_MS
        PasteMutex.Release()
    }
}
