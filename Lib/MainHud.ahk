#Requires AutoHotkey v2.0
#Include "CaptureEngine.ahk"
#Include "TooltipFormatter.ahk"
#Include "AutoCalculator.ahk"
#Include "HudLayout.ahk"

; ====================================================================
; MainHud — GUI principal persistente de QuickEntry. Redimensionable,
; siempre-encima. Soporta edición inline por click en valor, jump de
; slot por click en nombre, persistencia de posición/tamaño en INI y
; modo compacto/normal según ancho de ventana.
; Side-effect-only: sin tests unit. Smoke manual con ^+a / ^+h / ^+s.
; ====================================================================

; --- Paleta de colores y fuentes (light theme) ---
global MAINHUD_BG          := "F8FAFC"  ; very light blue-gray (almost white)
global MAINHUD_BG_ACTIVE   := "DBEAFE"  ; light blue tint para slot apuntado
global MAINHUD_FG_LABEL    := "1F2937"  ; dark gray text
global MAINHUD_FG_DIM      := "9CA3AF"  ; medium gray (empty / inactive)
global MAINHUD_FG_FILLED   := "15803D"  ; green
global MAINHUD_FG_PRELOAD  := "1D4ED8"  ; medium blue
global MAINHUD_FG_FORCED   := "D97706"  ; amber
global MAINHUD_FG_ACTIVE   := "1E40AF"  ; deep Asignet blue (slot apuntado accent)
global MAINHUD_FG_ERROR    := "DC2626"  ; red
global MAINHUD_FONT_VALUE  := "Cascadia Mono"
global MAINHUD_FONT_LABEL  := "Segoe UI"

class MainHud
{
    engine := ""
    gui := ""
    rows := []                  ; rows[i] = Map("nameCtrl", c, "valueCtrl", c, "iconCtrl", c, "opRows", [])
    inlineEditCtrl := ""        ; persistent Edit (created in Build, hidden)
    inlineEditDefaultBtn := ""  ; persistent Default Button (Enter trigger, hidden)
    inlineEditActive := false
    inlineEditSlot := 0
    inlineEditCommitting := false
    autoCalc := ""
    btnTooltips := Map()
    mouseMoveRegistered := false
    lastTooltipHwnd := 0
    titleCounterCtrl := ""
    btnArm := ""
    btnTemplateToggle := ""
    buttonsById := Map()
    currentMode := "normal"  ; "normal" | "compact"
    templateMode := false
    lastX := 0
    lastY := 0
    defaultX := 0
    defaultY := 0
    lastW := 0
    lastH := 0
    defaultW := 0
    defaultH := 0
    iniPath := ""

    __New(engine)
    {
        this.engine := engine
        this.iniPath := A_AppData "\QuickEntry\layout.ini"
        DirCreate(A_AppData "\QuickEntry")
        this.LoadPosition()
    }

    ; ====================================================================
    ; PERSISTENCE
    ; ====================================================================

    ; Itera todos los monitores activos y devuelve Array<Map{l,t,r,b}> con
    ; sus work areas. Fuente que LoadPosition pasa a HudLayout.IsRectVisibleAgainst.
    ; Devuelve [] si MonitorGetCount/WorkArea fallan — IsRectVisibleAgainst con []
    ; retorna false, forzando el fallback de centrado.
    EnumMonitorsForLayout()
    {
        out := []
        try
        {
            count := MonitorGetCount()
            Loop count
            {
                MonitorGetWorkArea(A_Index, &mL, &mT, &mR, &mB)
                out.Push(Map("l", mL, "t", mT, "r", mR, "b", mB))
            }
        }
        catch
        {
        }
        return out
    }

    LoadPosition()
    {
        this.defaultW := Integer(IniRead(this.iniPath, "Window", "defaultW", 540))
        this.defaultH := Integer(IniRead(this.iniPath, "Window", "defaultH", 460))
        this.lastW    := Integer(IniRead(this.iniPath, "Window", "lastW", this.defaultW))
        this.lastH    := Integer(IniRead(this.iniPath, "Window", "lastH", this.defaultH))

        ; Centra en monitor primario como fallback cuando la posición guardada ya
        ; no es visible (monitor desconectado, resolución cambiada).
        MonitorGetWorkArea(MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
        centerX := mLeft + ((mRight - mLeft) - this.lastW) // 2
        centerY := mTop  + ((mBottom - mTop) - this.lastH) // 2

        monitors := this.EnumMonitorsForLayout()

        savedLastX := IniRead(this.iniPath, "Window", "lastX", "")
        savedLastY := IniRead(this.iniPath, "Window", "lastY", "")
        if (savedLastX = "" || savedLastY = "")
        {
            this.lastX := centerX
            this.lastY := centerY
        }
        else
        {
            sx := Integer(savedLastX)
            sy := Integer(savedLastY)
            if HudLayout.IsRectVisibleAgainst(sx, sy, this.lastW, this.lastH, monitors)
            {
                this.lastX := sx
                this.lastY := sy
            }
            else
            {
                this.lastX := centerX
                this.lastY := centerY
            }
        }

        savedDefX := IniRead(this.iniPath, "Window", "defaultX", "")
        savedDefY := IniRead(this.iniPath, "Window", "defaultY", "")
        defCenterX := mLeft + ((mRight - mLeft) - this.defaultW) // 2
        defCenterY := mTop  + ((mBottom - mTop) - this.defaultH) // 2
        if (savedDefX = "" || savedDefY = "")
        {
            this.defaultX := defCenterX
            this.defaultY := defCenterY
        }
        else
        {
            dx := Integer(savedDefX)
            dy := Integer(savedDefY)
            if HudLayout.IsRectVisibleAgainst(dx, dy, this.defaultW, this.defaultH, monitors)
            {
                this.defaultX := dx
                this.defaultY := dy
            }
            else
            {
                this.defaultX := defCenterX
                this.defaultY := defCenterY
            }
        }

        this.templateMode := IniRead(this.iniPath, "Window", "templateMode", "0") = "1"
    }

    SaveLastPosition()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetPos(&x, &y, &w, &h)
        this.lastX := x
        this.lastY := y
        this.lastW := w
        this.lastH := h
        IniWrite(x, this.iniPath, "Window", "lastX")
        IniWrite(y, this.iniPath, "Window", "lastY")
        IniWrite(w, this.iniPath, "Window", "lastW")
        IniWrite(h, this.iniPath, "Window", "lastH")
    }

    SaveAsDefault()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetPos(&x, &y, &w, &h)
        this.defaultX := x
        this.defaultY := y
        this.defaultW := w
        this.defaultH := h
        this.lastX := x
        this.lastY := y
        this.lastW := w
        this.lastH := h
        IniWrite(x, this.iniPath, "Window", "defaultX")
        IniWrite(y, this.iniPath, "Window", "defaultY")
        IniWrite(w, this.iniPath, "Window", "defaultW")
        IniWrite(h, this.iniPath, "Window", "defaultH")
        IniWrite(x, this.iniPath, "Window", "lastX")
        IniWrite(y, this.iniPath, "Window", "lastY")
        IniWrite(w, this.iniPath, "Window", "lastW")
        IniWrite(h, this.iniPath, "Window", "lastH")
        ToolTip("Posicion + tamanio default actualizados")
        SetTimer(() => ToolTip(), -1500)
    }

    SaveTemplateMode()
    {
        IniWrite(this.templateMode ? "1" : "0", this.iniPath, "Window", "templateMode")
    }

    ; ====================================================================
    ; BUILD
    ; ====================================================================
    Build()
    {
        g := Gui("+AlwaysOnTop +Resize +MinSize380x340 -DPIScale", "QuickEntry")
        g.BackColor := MAINHUD_BG
        g.SetFont("s10 c" MAINHUD_FG_LABEL, MAINHUD_FONT_LABEL)
        g.MarginX := 16
        g.MarginY := 16

        n := this.engine.schema.Length
        rowH := 28
        windowW := 600

        ; --- Slot rows ---
        this.rows := []
        yPos := 10
        Loop n
        {
            i := A_Index
            campo := this.engine.schema.Field(i)
            yRow := yPos + (i-1) * rowH

            ; bgUnderlay cubre toda la fila para pintar fondo continuo cuando
            ; el slot está activo (sin gaps entre controles internos). Se agrega
            ; PRIMERO para quedar en z-order bajo; los controles van encima.
            bgUnderlay := g.Add("Text", "x12 y" yRow " w" (windowW - 24) " h" rowH, "")

            slotTxt  := g.Add("Text", "x16 y" yRow " w28 h" rowH " +0x100 c" MAINHUD_FG_DIM, i)
            nameCtrl := g.Add("Text", "x50 y" yRow " w220 h" rowH " +0x100", campo.name)
            nameCtrl.SetFont("s10 c" MAINHUD_FG_LABEL, MAINHUD_FONT_LABEL)
            valueCtrl := g.Add("Text", "x280 y" yRow " w260 h" rowH " +0x100", "—")
            valueCtrl.SetFont("s10 c" MAINHUD_FG_DIM, MAINHUD_FONT_VALUE)
            iconCtrl := g.Add("Text", "x550 y" yRow " w28 h" rowH " Right c" MAINHUD_FG_DIM, "—")
            iconCtrl.SetFont("s12 c" MAINHUD_FG_DIM, MAINHUD_FONT_VALUE)

            ; forceBtn (✓ verde): visible SOLO cuando hay pendingInvalidValue en el
            ; slot. Click → PushForce. Posicionado a la izquierda del iconCtrl ("!").
            forceBtn := g.Add("Button", "x518 y" (yRow + 2) " w28 h" (rowH - 4) " Hidden", "✓")
            forceBtn.SetFont("s10 Bold c" MAINHUD_FG_FILLED, MAINHUD_FONT_LABEL)
            forceBtn.OnEvent("Click", this.MakeForceHandler(i))

            jumpHandler := this.MakeJumpHandler(i)
            slotTxt.OnEvent("Click", jumpHandler)
            nameCtrl.OnEvent("Click", jumpHandler)
            valueCtrl.OnEvent("Click", this.MakeValueHandler(i))

            this.rows.Push(Map(
                "bgUnderlay", bgUnderlay,
                "slotTxt", slotTxt,
                "nameCtrl", nameCtrl,
                "valueCtrl", valueCtrl,
                "iconCtrl", iconCtrl,
                "forceBtn", forceBtn,
                "pendingInvalidValue", "",
                "opRows", []
            ))
        }

        ; --- Footer (3 filas de botones) ---
        ;   Row 1: Template | Scan | Pegar
        ;   Row 2: Iniciar/Omitir | Undo | Reset
        ;   Row 3: ⊙ default | Load Last | Σ Calc
        footerY  := yPos + n * rowH + 14
        footerY2 := footerY + 34
        footerY3 := footerY2 + 34

        ; Anchos +20% vs diseño original (gap=4px entre botones).
        templateLbl := this.templateMode ? "☑ Template" : "☐ Template"
        btnTemplateToggle := g.Add("Button", "x16 y" footerY " w132 h28", templateLbl)
        btnScan           := g.Add("Button", "x152 y" footerY " w108 h28", "⇣ Scan")
        btnSoltar         := g.Add("Button", "x264 y" footerY " w108 h28", "▶▶ Pegar")

        btnArm   := g.Add("Button", "x16 y" footerY2 " w108 h28",  "▶ Iniciar")
        btnUndo  := g.Add("Button", "x128 y" footerY2 " w108 h28", "↶ Undo")
        btnReset := g.Add("Button", "x240 y" footerY2 " w108 h28", "⊘ Reset")

        btnSetDefault := g.Add("Button", "x16 y" footerY3 " w38 h28",  "⊙")
        btnLoadLast   := g.Add("Button", "x58 y" footerY3 " w132 h28", "↻ Load Last")
        btnCalc       := g.Add("Button", "x194 y" footerY3 " w96 h28", "Σ Calc")

        windowH := footerY3 + 41

        ; Update() refresca estos labels en cada call (label depende de estado del engine)
        this.btnArm := btnArm
        this.btnTemplateToggle := btnTemplateToggle

        ; Contratos de callback: estos nombres son funciones top-level en QuickEntry.ahk
        btnArm.OnEvent("Click", (*) => DoArmOrSkip())
        btnTemplateToggle.OnEvent("Click", (*) => this.OnTemplateToggle())
        btnScan.OnEvent("Click", (*) => DoHeaderScan(true))
        btnSoltar.OnEvent("Click", (*) => DoSoltar(true))
        btnReset.OnEvent("Click", (*) => DoReset())
        btnUndo.OnEvent("Click", (*) => DoUndo())
        btnLoadLast.OnEvent("Click", (*) => this.OnLoadLast())
        btnCalc.OnEvent("Click", (*) => this.OnAutoCalc())
        btnSetDefault.OnEvent("Click", (*) => this.SaveAsDefault())

        ; IDs coinciden con las lookup keys de HudLayout.LabelForButton
        this.buttonsById := Map(
            "start", btnArm,
            "templateOff", btnTemplateToggle,
            "scan", btnScan,
            "release", btnSoltar,
            "reset", btnReset,
            "undo", btnUndo,
            "loadLast", btnLoadLast,
            "autocalc", btnCalc,
            "setDefault", btnSetDefault
        )

        ; --- Inline edit persistente (se crea una vez; se reusa en cada ShowInlineEdit) ---
        ; Crear/destruir en cada edición causa flickering y pérdida de foco en AHK v2.
        this.inlineEditCtrl := g.Add("Edit", "x100 y100 w200 h28 Hidden", "")
        this.inlineEditCtrl.SetFont("s10 c" MAINHUD_FG_LABEL, MAINHUD_FONT_VALUE)
        this.inlineEditCtrl.OnEvent("LoseFocus", (*) => this.OnInlineEditCommit())

        ; Default button posicionado en 1x1 px (no off-screen ni Hidden puro):
        ; AHK v2 puede no enrutar Enter de forma confiable si el botón está fuera
        ; de la región visible del GUI.
        this.inlineEditDefaultBtn := g.Add("Button", "x0 y0 w1 h1 Default Hidden", "")
        this.inlineEditDefaultBtn.OnEvent("Click", (*) => this.OnInlineEditCommit())

        this.gui := g

        this.btnTooltips := Map(
            btnArm.Hwnd, "Omitir slot actual (^+a)",
            btnTemplateToggle.Hwnd, "Toggle: si existe el campo 'Template' despues de Account Number, activa esto.",
            btnScan.Hwnd, "HeaderScan: pide click en selector de Type, lee form (^+h)",
            btnSoltar.Hwnd, "Pegar: pide click en form, despues pega todos los valores (^+s)",
            btnReset.Hwnd, "Cancelar captura / Freno paste/scan en curso (^+r)",
            btnUndo.Hwnd, "Descartar el ultimo valor cargado (^+u)",
            btnLoadLast.Hwnd, "Cargar la ultima cola pegada",
            btnCalc.Hwnd, "AutoCalculator: pega numeros y muestra suma",
            btnSetDefault.Hwnd, "Marcar posicion actual como default"
        )

        ; OnMessage registrado una sola vez: guard evita duplicados si Build() se
        ; llamara más de una vez (aunque Show() sólo llama Build si !IsObject(gui)).
        if !this.mouseMoveRegistered
        {
            OnMessage(0x0200, ObjBindMethod(this, "OnMouseMoveHover"))
            this.mouseMoveRegistered := true
        }

        g.OnEvent("Close", (*) => this.OnClose())
        g.OnEvent("Escape", (*) => this.OnEscape())
        g.OnEvent("ContextMenu", (*) => "")  ; suprime context menu del GUI
        g.OnEvent("Size", (*) => this.OnResize())
    }

    ; ====================================================================
    ; RENDER
    ; ====================================================================

    ; Aplica modo normal/compact: labels de slots (vía HudLayout.LabelForSlot),
    ; labels de botones y posiciones/anchos de slot rows + footer buttons.
    RenderMode(mode)
    {
        isCompact := (mode = "compact")

        for i, row in this.rows
        {
            label := HudLayout.LabelForSlot(i, isCompact)
            if (label != "")
                row["nameCtrl"].Text := label
        }

        if this.buttonsById.Has("templateOff")
        {
            id := this.templateMode ? "templateOn" : "templateOff"
            this.buttonsById["templateOff"].Text := HudLayout.LabelForButton(id, isCompact)
        }

        for id, ctrl in this.buttonsById
        {
            if (id = "templateOff")
                continue
            if (id = "start")  ; lo maneja Update() porque depende de engine.isCapturing
                continue
            ctrl.Text := HudLayout.LabelForButton(id, isCompact)
        }

        ; Anchos de columnas de slot rows:
        ;   slotTxt:   x16 w28  (fijo)
        ;   nameCtrl:  x50 w<nameW>
        ;   valueCtrl: x<50+nameW+10> w<208 normal / 144 compact>
        ;   iconCtrl:  x<valueX+valueW+10> w28
        ;   forceBtn:  x<iconX-32>
        nameW := HudLayout.NameColWidth(isCompact)
        valueW := isCompact ? 144 : 208
        nameX := 50
        valueX := nameX + nameW + 10
        iconX := valueX + valueW + 10
        forceX := iconX - 32

        for row in this.rows
        {
            row["nameCtrl"].Move(nameX, , nameW)
            row["valueCtrl"].Move(valueX, , valueW)
            row["iconCtrl"].Move(iconX)
            row["forceBtn"].Move(forceX)
            this.gui.GetClientPos(, , &winW)
            row["bgUnderlay"].Move(, , winW - 24)
        }

        ; En compact, botones se reducen a ~36 px (cuadrados con sólo el ícono).
        ; En normal, posiciones coinciden con Build() (anchos *1.2, gap=4).
        if isCompact
        {
            footerWidths := Map(
                "templateOff", 36, "scan", 36, "release", 36,
                "start", 36, "undo", 36, "reset", 36,
                "setDefault", 32, "loadLast", 36, "autocalc", 36
            )
            x1 := 16
            for id in ["templateOff", "scan", "release"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x1, , w)
                x1 += w + 4
            }
            x2 := 16
            for id in ["start", "undo", "reset"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x2, , w)
                x2 += w + 4
            }
            x3 := 16
            for id in ["setDefault", "loadLast", "autocalc"]
            {
                ctrl := this.buttonsById[id]
                w := footerWidths[id]
                ctrl.Move(x3, , w)
                x3 += w + 4
            }
        }
        else
        {
            normalLayout := Map(
                "templateOff", Map("x", 16,  "w", 132),
                "scan",        Map("x", 152, "w", 108),
                "release",     Map("x", 264, "w", 108),
                "start",       Map("x", 16,  "w", 108),
                "undo",        Map("x", 128, "w", 108),
                "reset",       Map("x", 240, "w", 108),
                "setDefault",  Map("x", 16,  "w", 38),
                "loadLast",    Map("x", 58,  "w", 132),
                "autocalc",    Map("x", 194, "w", 96)
            )
            for id, pos in normalLayout
                this.buttonsById[id].Move(pos["x"], , pos["w"])
        }
    }

    OnResize()
    {
        if !IsObject(this.gui)
            return
        this.gui.GetClientPos(, , &w)
        newMode := HudLayout.IsCompact(w) ? "compact" : "normal"
        if (newMode != this.currentMode)
        {
            this.currentMode := newMode
            this.RenderMode(newMode)
        }
        else
        {
            ; Mismo modo: sólo actualizar bgUnderlay para que cubra el nuevo ancho
            for row in this.rows
                row["bgUnderlay"].Move(, , w - 24)
        }
    }

    OnClose(*)
    {
        this.SaveLastPosition()
        this.Hide()
    }

    OnEscape(*)
    {
        this.Hide()
    }

    ; ====================================================================
    ; UPDATE
    ; ====================================================================
    Update()
    {
        if !IsObject(this.gui)
            return

        if this.engine.isCapturing
            this.gui.Title := "QuickEntry — CAPTURA ACTIVA (Ctrl+C guarda al slot)"
        else
            this.gui.Title := "QuickEntry — pausado (Ctrl+Shift+A para armar)"

        if (IsObject(this.btnArm))
        {
            esActivo := this.engine.isCapturing
            isCompact := (this.currentMode = "compact")
            this.btnArm.Text := HudLayout.LabelForButton(esActivo ? "skip" : "start", isCompact)
        }
        if (IsObject(this.btnTemplateToggle))
        {
            isCompactT := (this.currentMode = "compact")
            this.btnTemplateToggle.Text := HudLayout.LabelForButton(this.templateMode ? "templateOn" : "templateOff", isCompactT)
        }
        n := this.engine.schema.Length
        next := this.engine.NextSlot
        filled := this.engine.FilledCount

        if IsObject(this.titleCounterCtrl)
            this.titleCounterCtrl.Value := filled "/" n

        Loop n
        {
            i := A_Index
            row := this.rows[i]
            valor := this.engine.queue[i]
            esActivo := (i = next)
            esVacio := (valor = "")
            esPreloaded := this.engine.preloadedSlots.Has(i)

            ; Underlay + 4 controles internos reciben el mismo Background para
            ; fondo continuo sin gaps. Redraw() forzado porque AHK v2 no invalida
            ; el área de controles Text automáticamente en algunos formularios.
            bgOpt := esActivo ? "+Background" MAINHUD_BG_ACTIVE : "+BackgroundTrans"
            row["bgUnderlay"].Opt(bgOpt)
            row["slotTxt"].Opt(bgOpt)
            row["nameCtrl"].Opt(bgOpt)
            row["valueCtrl"].Opt(bgOpt)
            row["iconCtrl"].Opt(bgOpt)
            row["bgUnderlay"].Redraw()
            row["slotTxt"].Redraw()
            row["nameCtrl"].Redraw()
            row["valueCtrl"].Redraw()
            row["iconCtrl"].Redraw()

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

            ; Si hay pendingInvalidValue, lo mostramos en ámbar en lugar del valor
            ; del engine — permite al usuario ver lo que tipeo y decidir si forzar.
            pendingInv := row["pendingInvalidValue"]
            if (pendingInv != "")
            {
                row["valueCtrl"].Value := (StrLen(pendingInv) > 28)
                    ? SubStr(pendingInv, 1, 25) "..."
                    : pendingInv
                row["valueCtrl"].SetFont("s10 c" MAINHUD_FG_FORCED, MAINHUD_FONT_VALUE)
            }
            else
            {
                valorMostrado := this.TruncarValor(valor, esVacio, i)
                row["valueCtrl"].Value := valorMostrado
                colorVal := MAINHUD_FG_DIM
                if (esActivo && esVacio)
                    colorVal := MAINHUD_FG_ACTIVE
                else if esPreloaded
                    colorVal := MAINHUD_FG_PRELOAD
                else if !esVacio
                    colorVal := MAINHUD_FG_FILLED
                row["valueCtrl"].SetFont("s10 c" colorVal, MAINHUD_FONT_VALUE)
            }

            ; pendingInvalidValue: "!" rojo + forceBtn visible.
            ; Sin pending: icono normal de estado + forceBtn oculto.
            if (pendingInv != "")
            {
                row["iconCtrl"].Value := "!"
                row["iconCtrl"].SetFont("s12 Bold c" MAINHUD_FG_ERROR, MAINHUD_FONT_VALUE)
                row["forceBtn"].Visible := true
            }
            else
            {
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
                row["forceBtn"].Visible := false
            }
        }
    }

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

    Show()
    {
        if !IsObject(this.gui)
            this.Build()
        if IsObject(this.gui)
        {
            showOpts := "x" this.lastX " y" this.lastY " w" this.lastW " h" this.lastH
            this.gui.Show(showOpts)
            this.gui.GetClientPos(, , &w)
            this.currentMode := HudLayout.IsCompact(w) ? "compact" : "normal"
            this.RenderMode(this.currentMode)
        }
    }

    Hide()
    {
        if IsObject(this.gui)
            this.gui.Hide()
    }

    ; ====================================================================
    ; CLICK HANDLERS
    ; ====================================================================
    MakeJumpHandler(slot) => ((*) => this.OnRowClickName(slot))
    MakeValueHandler(slot) => ((*) => this.OnRowClickValue(slot))
    MakeForceHandler(slot) => ((*) => this.OnForceCommit(slot))

    ; ^+e: abre inline edit en el slot activo (NextSlot). Si GUI minimizada, la
    ; restaura primero. No actúa si no hay captura o cola llena.
    OpenInlineEditOnCurrentSlot()
    {
        if !this.engine.isCapturing
        {
            ToolTip("No hay captura activa - presiona Iniciar primero")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        slot := this.engine.NextSlot
        if (slot = 0)
        {
            ToolTip("Cola llena - click en algun valor para editarlo")
            SetTimer(() => ToolTip(), -2000)
            return
        }
        this.Show()
        if this.inlineEditActive
            this.OnInlineEditCommit()
        try this.engine.JumpTo(slot)
        this.Update()
        this.ShowInlineEdit(slot)
    }

    OnRowClickName(slot)
    {
        ; Click en Text no dispara LoseFocus en el Edit activo (Text no toma foco).
        ; Commit explícito antes del jump para no perder el input en curso.
        if this.inlineEditActive
            this.OnInlineEditCommit()
        try this.engine.JumpTo(slot)
        this.Update()
    }

    OnRowClickValue(slot)
    {
        ; Commit ANTES del jump: PushManual en el commit puede auto-avanzar el
        ; slot — re-jumpeamos al slot que el usuario clickeó realmente.
        if this.inlineEditActive
            this.OnInlineEditCommit()
        try this.engine.JumpTo(slot)
        this.Update()
        this.ShowInlineEdit(slot)
    }

    ; Click en ✓ verde: fuerza el pendingInvalidValue sin pasar por validación.
    ; El valor ya fue limpiado (clean) cuando se intentó PushManual originalmente.
    OnForceCommit(slot)
    {
        if (slot < 1 || slot > this.rows.Length)
            return
        row := this.rows[slot]
        val := row["pendingInvalidValue"]
        if (val = "")
            return
        this.engine.JumpTo(slot)
        this.engine.PushForce(val)
        row["pendingInvalidValue"] := ""
        this.Update()
    }

    ; ====================================================================
    ; INLINE EDIT
    ; ====================================================================
    ShowInlineEdit(slot)
    {
        ; Si llegamos con edit activo, commitear (no descartar): CloseInlineEdit
        ; sólo oculta sin guardar.
        if this.inlineEditActive
            this.OnInlineEditCommit()

        row := this.rows[slot]
        valueCtrl := row["valueCtrl"]
        valueCtrl.GetPos(&x, &y, &w, &h)
        valueCtrl.Visible := false

        ; Si hay pendingInvalidValue previo, pre-cargar para que el usuario corrija
        ; sin re-tipear desde cero.
        if (row["pendingInvalidValue"] != "")
            valor := row["pendingInvalidValue"]
        else
            valor := this.engine.queue[slot]
        this.inlineEditCtrl.Value := valor
        this.inlineEditCtrl.Move(x, y, w, h)
        this.inlineEditCtrl.Visible := true
        this.inlineEditDefaultBtn.Visible := true
        this.inlineEditCtrl.Focus()

        this.inlineEditSlot := slot
        this.inlineEditActive := true

        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Escape", (*) => this.OnInlineEditEsc(), "On")
        HotIf()
    }

    OnInlineEditCommit()
    {
        ; Semáforo de re-entrada: LoseFocus puede dispararse durante el commit
        ; si el commit mismo provoca un cambio de foco → doble-PushManual.
        if this.inlineEditCommitting
            return
        if !this.inlineEditActive
            return

        this.inlineEditCommitting := true
        try
        {
            val := this.inlineEditCtrl.Value
            slot := this.inlineEditSlot

            ; Valor en blanco → clear slot (no pasa por PushManual, que dispararía
            ; ValidarNoVacio y mostraría "!" rojo). El slot queda vacío limpio.
            if (Trim(val) = "")
            {
                this.engine.ClearSlot(slot)
                this.CloseInlineEdit()
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := ""
                this.Update()
                return
            }

            this.engine.JumpTo(slot)
            res := this.engine.PushManual(val)

            this.CloseInlineEdit()

            if !res["ok"]
            {
                ; Validación fallida: guardamos el valor rechazado en pendingInvalidValue.
                ; Update() lo renderiza en ámbar + "!" + botón ✓ para forzar.
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := val
                this.Update()
            }
            else
            {
                if (slot >= 1 && slot <= this.rows.Length)
                    this.rows[slot]["pendingInvalidValue"] := ""
                this.Update()
            }
        }
        finally
        {
            this.inlineEditCommitting := false
        }
    }

    OnInlineEditEsc()
    {
        this.CloseInlineEdit()
        this.Update()
    }

    CloseInlineEdit()
    {
        if !this.inlineEditActive
            return
        slot := this.inlineEditSlot
        this.inlineEditActive := false
        this.inlineEditSlot := 0

        ; Ocultar sin destruir — se reusan en el próximo ShowInlineEdit
        this.inlineEditCtrl.Visible := false
        this.inlineEditDefaultBtn.Visible := false

        if (slot >= 1 && slot <= this.rows.Length)
            this.rows[slot]["valueCtrl"].Visible := true

        HotIfWinActive("ahk_id " this.gui.Hwnd)
        try Hotkey("Escape", "Off")
        HotIf()
    }

    ; Limpia pendingInvalidValue de todos los rows. Llamado tras Reset o PasteBatch:
    ; los pending pertenecen a la sesión anterior y no deben sobrevivir.
    ClearAllPendingInvalid()
    {
        for row in this.rows
            row["pendingInvalidValue"] := ""
    }

    OnLoadLast()
    {
        if this.LoadLastPaste()
        {
            this.Show()
            this.Update()
        }
    }

    OnTemplateToggle()
    {
        this.templateMode := !this.templateMode
        this.SaveTemplateMode()
        ; Sync inmediato si hay captura activa; si no, se aplica en el próximo Arm.
        if (IsObject(this.engine) && this.engine.isCapturing)
            this.engine.SetExtraTabsAfter(1, this.templateMode ? 1 : 0)
        if (IsObject(this.btnTemplateToggle))
        {
            isCompactT := (this.currentMode = "compact")
            this.btnTemplateToggle.Text := HudLayout.LabelForButton(this.templateMode ? "templateOn" : "templateOff", isCompactT)
        }
    }

    OnAutoCalc()
    {
        if !IsObject(this.autoCalc)
            this.autoCalc := AutoCalculator()
        this.autoCalc.Show()
    }

    ; ====================================================================
    ; PERSISTENCE — last_paste / load-last
    ; ====================================================================
    SaveLastPaste()
    {
        path := A_AppData "\QuickEntry\last_paste.ini"
        try FileDelete(path)
        Loop this.engine.schema.Length
        {
            i := A_Index
            valor := this.engine.queue[i]
            ; IniWrite no acepta \r\n / \n — sanitizar antes de escribir.
            valor := StrReplace(valor, "`r`n", " ")
            valor := StrReplace(valor, "`n", " ")
            IniWrite(valor, path, "Queue", "slot" i)
        }
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

        if (this.engine.isCapturing && this.engine.FilledCount > 0)
        {
            resp := MsgBox("Hay una captura en curso. ¿Reemplazar con la ultima cola pegada?",
                           "Load Last", "YesNo Icon?")
            if (resp != "Yes")
                return false
        }

        ; Leer queue persistida del INI (1-indexed, slot vacio = "").
        ; NO restauramos preloadedSlots: PasteBatch los SKIP, pero Load Last
        ; debe pegar todos los slots en el form actual (que está vacío).
        queueValues := []
        Loop this.engine.schema.Length
        {
            i := A_Index
            valor := IniRead(path, "Queue", "slot" i, "")
            queueValues.Push(valor)
        }

        ; Aplicar el snapshot al engine. La logica esta en un static method
        ; testeable; ver Test_TemplateLoadLast.ahk para los casos cubiertos.
        MainHud.ApplyLoadLastSnapshot(this.engine, queueValues, this.templateMode)
        return true
    }

    ; Aplica un snapshot de cola al engine respetando el flag templateMode.
    ; Pure logic - sin GUI, sin INI - para que sea testeable engine-level.
    ; Llamada por LoadLastPaste tras leer el INI; ver Test_TemplateLoadLast.ahk
    ; para validar el contrato (Arm clarea extras, SetExtraTabsAfter re-aplica).
    static ApplyLoadLastSnapshot(engine, queueValues, templateMode)
    {
        engine.Arm()
        Loop queueValues.Length
        {
            if (queueValues[A_Index] != "")
                engine.queue[A_Index] := queueValues[A_Index]
        }
        engine.AutoAdvance(0)
        ; FIX (post-bug-2026-05-12): re-aplicar templateMode despues del Arm.
        ; Arm() llama ResetState() que clarea extraTabsAfterSlot. Sin esta
        ; linea, LoadLast con templateMode=ON dejaba el engine sin el Tab
        ; extra del slot 1 - resultado: factura corrupta (slot 2 caia sobre
        ; el campo Template).
        engine.SetExtraTabsAfter(1, templateMode ? 1 : 0)
    }

    ; WM_MOUSEMOVE (0x0200): debounce por lastTooltipHwnd; muestra ToolTip
    ; del botón si está en btnTooltips, borra ToolTip al salir de cualquier botón.
    OnMouseMoveHover(wParam, lParam, msg, hwnd)
    {
        if (hwnd = this.lastTooltipHwnd)
            return
        this.lastTooltipHwnd := hwnd
        if this.btnTooltips.Has(hwnd)
            ToolTip(this.btnTooltips[hwnd])
        else
            ToolTip()
    }
}
