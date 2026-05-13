#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "Lib\Logger.ahk"
#Include "Lib\PasteMutex.ahk"
#Include "Lib\Cleaners.ahk"
#Include "Lib\Validators.ahk"
#Include "Lib\Schema.ahk"
#Include "Lib\CaptureEngine.ahk"
#Include "Lib\TooltipFormatter.ahk"
#Include "Lib\PegadoEspecial.ahk"
#Include "Schemas\AsignetHeaderV1.ahk"
#Include "Lib\MainHud.ahk"

; ====================================================================
; QuickEntry.ahk - Entry point. Cablea hotkeys con CaptureEngine + GUI manual.
;
; Para cambiar a otra empresa: reemplazar `CrearAsignetHeaderV1()` abajo
; por el constructor del schema deseado (ver Schemas/_Plantilla_NuevaEmpresa).
;
; Documentacion completa en `docs/`:
;   - MANUAL_USUARIO.md          (uso diario)
;   - PERSONALIZACION_HOTKEYS.md (cambiar hotkeys por usuario)
;   - GUIA_TECNICA.md            (arquitectura)
;   - AGREGAR_EMPRESA.md         (alta de schemas)
; ====================================================================

; Si true, omitir un slot con expectedFn (Past due, Invoice Total)
; pushea el valor calculado en vez de "". Por default ON: el operador
; suele querer que el calculo automatico llene el slot omitido.
global AUTO_CALCULAR_TOTALES_OMITIDOS := true
; Hotkey que el usuario presiona para "omitir" el slot actual (mostrado en
; el tooltip cuando un copy es invalido). Si cambias el binding `^+a::` mas
; abajo, actualiza tambien esta cadena.
global HOTKEY_OMITIR := "^+a"

; --- Schema registry ---
; Para agregar una empresa nueva: crear `Schemas/EmpresaXHeaderV1.ahk` con su
; constructor `CrearEmpresaXHeaderV1()`, agregar `#Include` arriba, y agregar
; una entrada en el Map. El operador elige cuál usar editando
; `%APPDATA%\QuickEntry\config.ini`:
;   [General]
;   Schema=AsignetHeaderV1
global SCHEMA_REGISTRY := Map(
    "AsignetHeaderV1", CrearAsignetHeaderV1
)

configPath := A_AppData "\QuickEntry\config.ini"
schemaName := IniRead(configPath, "General", "Schema", "AsignetHeaderV1")
if !SCHEMA_REGISTRY.Has(schemaName)
{
    Logger.Warn("schema_unknown", Map("requested", schemaName, "fallback", "AsignetHeaderV1"))
    MsgBox "Schema desconocido en config.ini: '" schemaName "'.`n`nUsando AsignetHeaderV1 por default.", "QuickEntry", 48
    schemaName := "AsignetHeaderV1"
}
Logger.Info("startup", Map("schema", schemaName))
factory := SCHEMA_REGISTRY[schemaName]
global engine := CaptureEngine(factory(), AUTO_CALCULAR_TOTALES_OMITIDOS)
global hud := MainHud(engine)
; Mostrar la GUI al startup. Auto-arm el engine asi copy captura
; automaticamente sin requerir click previo en Iniciar (continuous
; capture mode). Reset (^+r) pausa la captura cuando el usuario quiere
; copiar algo no relacionado.
hud.Show()
engine.Arm(A_Clipboard)
engine.SetExtraTabsAfter(1, hud.templateMode ? 1 : 0)
hud.Update()

; ====================================================================
; PEGADO ESPECIAL via teclado
; ====================================================================
^+v::DoPegadoEspecial()

; --- DoPegadoEspecial: wrapper para soportar interactive=true desde el HUD.
;     Sin esto, el click sobre el boton del HUD quita el foco del campo donde
;     el usuario queria pegar -> ^v cae en el HUD mismo. Con interactive=true,
;     esperamos a que el usuario re-clickee el campo target. ---
DoPegadoEspecial(interactive := false)
{
    if interactive
    {
        ToolTip("Hace click en el campo donde queres pegar...")
        KeyWait("LButton")          ; suelta el click actual sobre el HUD
        KeyWait("LButton", "D")     ; siguiente click = el campo target
        Sleep 250                   ; permite que el foco se asiente
        ToolTip()
    }
    PegadoEspecial()
}

; ====================================================================
; CAPTURA BATCH - handlers schema-driven
; ====================================================================
OnClipboardChange HandlerCaptura

HandlerCaptura(tipoData)
{
    global engine, HOTKEY_OMITIR
    if (!engine.isCapturing || PasteMutex.IsLocked)
        return
    if (tipoData != 1)
        return
    crudo := A_Clipboard
    if (crudo = "")
        return

    res := engine.PushRaw(crudo)
    if !res["ok"]
    {
        detalle := (res["value"] = "") ? "" : TooltipError(res["label"], res["error"])
        ToolTip(TooltipConError(engine, detalle, HOTKEY_OMITIR))
        return
    }
    RefrescarTooltip()
}

RefrescarTooltip()
{
    global hud
    hud.Update()
}

^+a::DoArmOrSkip()

DoArmOrSkip()
{
    global engine, hud

    ; Si el GUI esta minimizado u oculto, restaurarlo y NO hacer skip.
    if (engine.isCapturing && IsObject(hud.gui))
    {
        if !WinExist("ahk_id " hud.gui.Hwnd)  ; Hidden
            shouldRestore := true
        else if (WinGetMinMax("ahk_id " hud.gui.Hwnd) = -1)  ; Minimizado
            shouldRestore := true
        else
            shouldRestore := false

        if shouldRestore
        {
            hud.Show()
            hud.Update()
            return
        }
    }

    if (engine.isCapturing)
    {
        if (engine.IsComplete)
        {
            ToolTip("Cola completa - usa ^+s o ^+u")
            SetTimer(() => ToolTip(), -1500)
            return
        }
        s := engine.SkipCurrent()
        RefrescarTooltip()
    }
    else
    {
        engine.Arm(A_Clipboard)
        ; Aplicar template mode actual del HUD (toggle persiste entre sesiones).
        engine.SetExtraTabsAfter(1, hud.templateMode ? 1 : 0)
        Logger.Info("arm", Map())
        hud.Show()
        hud.Update()
    }
}

^+s::DoSoltar()

DoSoltar(interactive := false)
{
    global engine, hud
    if (PasteMutex.IsLocked)
        return
    if (!engine.isCapturing || engine.FilledCount = 0)
    {
        MsgBox "Cola vacia. Usa ^+a para armar y copia los campos."
        return
    }
    ; Modo interactivo (boton del HUD): pide al usuario que clickee en el
    ; selector de Type del form. Sin esto, los Tabs caen sobre el HUD mismo
    ; porque el click sobre el boton dejo foco ahi. El hotkey ^+s asume
    ; que el usuario ya posiciono el cursor.
    if interactive
    {
        ToolTip("Hace click en el selector de Type (Invoice) en el form...")
        ; Esperar a que se suelte el click ACTUAL (sobre el boton del HUD) primero,
        ; sino el KeyWait("D") matchea ese click y no el siguiente.
        KeyWait("LButton")
        ; Ahora esperar el SIGUIENTE click down (el que el usuario hace en el form)
        KeyWait("LButton", "D")
        Sleep 250  ; permitir que el click pase y el foco se reasigne al form
        ToolTip()
    }

    PasteMutex.Acquire()
    KeyWait("LShift")
    KeyWait("RShift")
    KeyWait("LCtrl")
    KeyWait("RCtrl")
    Logger.Info("paste_batch_start", Map("filled", engine.FilledCount, "total", engine.schema.Length))
    try
    {
        SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
        Sleep 30
        engine.PasteBatch()
        Logger.Info("paste_batch_done", Map("filled", engine.FilledCount))
    }
    catch as e
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
        ; Auto-rearm para la proxima factura sin requerir click de Iniciar.
        ; Modo continuo: cada copy se captura hasta que el usuario haga ^+r
        ; (pausa explicita).
        engine.Arm(A_Clipboard)
        engine.SetExtraTabsAfter(1, hud.templateMode ? 1 : 0)
        hud.Update()
        PasteMutex.Release()
        ; NO clear ToolTip aca: el catch usa SetTimer 4s para su mensaje de error.
        ; En path exitoso no hay tooltip que limpiar (el interactivo se cerro arriba).
    }
}

^+r::DoReset()

DoReset()
{
    global engine, hud
    ; Si hay un PasteBatch o Scan en curso, Abort() pone el flag y los loops
    ; salen en el proximo check (~150ms). Reset() limpia state despues.
    engine.Abort()
    engine.Reset()
    hud.ClearAllPendingInvalid()
    hud.Hide()
    Logger.Info("reset", Map())
    ToolTip("Captura cancelada (freno aplicado)")
    SetTimer(() => ToolTip(), -1500)
}

^+u::DoUndo()

DoUndo()
{
    global engine
    if !engine.isCapturing
    {
        ToolTip("No hay captura activa")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    u := engine.Undo()
    if !u["ok"]
    {
        ToolTip("Nada que deshacer")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    Logger.Info("undo", Map("slot", u["slot"]))
    RefrescarTooltip()
}

^+e::hud.OpenInlineEditOnCurrentSlot()

; --- ^+h: HeaderScan ---
;     Lee los campos del form actuales (selectAll + copy + clean) y los
;     pre-popula en la cola. Despues, la captura normal solo necesita
;     llenar los slots que estaban vacios. PasteBatch saltea los preloaded.
;     PRE-CONDICION: cursor posicionado al tope de la pagina (o donde
;     prePasteSteps comienza). Para Asignet: arriba de todo, antes del
;     primer Tab. ---
^+h::DoHeaderScan()

DoHeaderScan(interactive := false)
{
    global engine, hud
    if (PasteMutex.IsLocked)
        return

    ; Modo interactivo (boton del HUD): pide al usuario que clickee en el
    ; selector "Type" del form. Esto deja el cursor posicionado para el
    ; preScanSteps. El hotkey ^+h skipea este paso (asume cursor ya posicionado).
    if interactive
    {
        ToolTip("Hace click en el selector de Type (Invoice) en el form...")
        ; Esperar a que se suelte el click ACTUAL (sobre el boton del HUD) primero,
        ; sino el KeyWait("D") matchea ese click y no el siguiente.
        KeyWait("LButton")
        ; Ahora esperar el SIGUIENTE click down (el que el usuario hace en el form)
        KeyWait("LButton", "D")
        Sleep 250  ; permitir que el click pase y el foco se reasigne al form
        ToolTip()
    }

    ; Aplicar template mode actual del HUD (toggle persiste entre sesiones).
    ; Si el form tiene el campo Template, el usuario flipea el toggle del HUD
    ; antes de scan/paste - sin prompt cada vez.
    engine.SetExtraTabsAfter(1, hud.templateMode ? 1 : 0)

    backup := A_Clipboard
    PasteMutex.Acquire()
    ToolTip("Escaneando header...")
    KeyWait("LShift")
    KeyWait("RShift")
    KeyWait("LCtrl")
    KeyWait("RCtrl")
    Logger.Info("scan_start", Map())
    try
    {
        ; Libera modificadores fisicos del hotkey (Ctrl/Shift) antes de
        ; mandar la secuencia de Tabs. Sin esto, el OS interpretaria los
        ; Tabs como Ctrl+Shift+Tab y no avanzaria foco.
        SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
        Sleep 30
        ; Escape cierra cualquier dropdown/autocomplete que haya quedado
        ; abierto de un scan anterior. Sin esto, los Tabs del scan
        ; interactuan con el widget abierto y se desfasan.
        SendInput "{Escape}"
        Sleep 150
        engine.Scan(, , , backup)
        Logger.Info("scan_done", Map("filled", engine.FilledCount))
    }
    catch as e
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
    hud.Show()
    hud.Update()
}
