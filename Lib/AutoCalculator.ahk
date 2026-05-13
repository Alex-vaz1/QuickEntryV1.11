#Requires AutoHotkey v2.0
#Include "Cleaners.ahk"

; ====================================================================
; AutoCalculator - GUI popup que parsea numeros tipeados/pegados,
; los limpia con NormalizarPrecio() y muestra la suma.
;
; Uso: AutoCalculator().Show()
; Single instance: si ya hay una, la trae al frente en vez de duplicar.
; ====================================================================

; --- Constantes de estilo (alineadas con MainHud) ---
global AUTOCALC_BG         := "F8FAFC"
global AUTOCALC_FG_LABEL   := "1F2937"
global AUTOCALC_FG_DIM     := "9CA3AF"
global AUTOCALC_FG_NUMBER  := "1E40AF"  ; Asignet blue
global AUTOCALC_FG_TOTAL   := "15803D"  ; green
global AUTOCALC_FONT_VALUE := "Cascadia Mono"
global AUTOCALC_FONT_LABEL := "Segoe UI"

class AutoCalculator
{
    gui := ""
    inputEdit := ""
    resultsCtrl := ""
    totalCtrl := ""
    suppressResultsChange := false

    Show()
    {
        ; Si ya hay una instancia visible, traerla al frente
        if IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)
        {
            this.gui.Show()
            this.inputEdit.Focus()
            return
        }

        this.Build()
    }

    Build()
    {
        g := Gui("+AlwaysOnTop +Resize -DPIScale", "AutoCalculator - QuickEntry")
        g.BackColor := AUTOCALC_BG
        g.SetFont("s10 c" AUTOCALC_FG_LABEL, AUTOCALC_FONT_LABEL)
        g.MarginX := 16
        g.MarginY := 16

        titleLbl := g.Add("Text", "x16 y12 w400 h24", "Σ AutoCalculator")
        titleLbl.SetFont("s12 Bold c" AUTOCALC_FG_LABEL, AUTOCALC_FONT_LABEL)

        instLbl := g.Add("Text", "x16 y40 w400 h36",
            "Pega o tipea numeros (uno por linea o juntos). Se cleanean automaticamente.")
        instLbl.SetFont("s9 c" AUTOCALC_FG_DIM, AUTOCALC_FONT_LABEL)

        this.inputEdit := g.Add("Edit", "x16 y84 w400 h140 +Multi +WantReturn -Wrap")
        this.inputEdit.SetFont("s10 c" AUTOCALC_FG_LABEL, AUTOCALC_FONT_VALUE)
        this.inputEdit.OnEvent("Change", (*) => this.Recalculate())

        resultsLbl := g.Add("Text", "x16 y232 w400 h20", "Numeros reconocidos:")
        resultsLbl.SetFont("s9 c" AUTOCALC_FG_DIM, AUTOCALC_FONT_LABEL)

        this.resultsCtrl := g.Add("Edit", "x16 y254 w400 h140 +Multi -Wrap")
        this.resultsCtrl.SetFont("s10 c" AUTOCALC_FG_NUMBER, AUTOCALC_FONT_VALUE)
        this.resultsCtrl.OnEvent("Change", (*) => this.OnResultsEdited())

        totalLbl := g.Add("Text", "x16 y406 w120 h28", "Total:")
        totalLbl.SetFont("s12 Bold c" AUTOCALC_FG_LABEL, AUTOCALC_FONT_LABEL)

        this.totalCtrl := g.Add("Text", "x140 y406 w276 h28 Right", "0.00")
        this.totalCtrl.SetFont("s12 Bold c" AUTOCALC_FG_TOTAL, AUTOCALC_FONT_VALUE)

        btnClear := g.Add("Button", "x16 y446 w120 h32", "Clear")
        btnCopy := g.Add("Button", "x140 y446 w160 h32", "Copy Total")
        btnClose := g.Add("Button", "x340 y446 w76 h32", "Cerrar")

        btnClear.OnEvent("Click", (*) => this.Clear())
        btnCopy.OnEvent("Click", (*) => this.CopyTotal())
        btnClose.OnEvent("Click", (*) => this.Hide())

        g.OnEvent("Close", (*) => this.Hide())
        g.OnEvent("Escape", (*) => this.Hide())

        this.gui := g
        g.Show("AutoSize")
        this.inputEdit.Focus()
    }

    Recalculate()
    {
        if !this.inputEdit
            return
        text := this.inputEdit.Value
        tokens := this.ExtractNumberTokens(text)
        results := []
        sum := 0.0
        anyValid := false

        for token in tokens
        {
            limpio := NormalizarPrecio(token)
            if (limpio = "")
                continue
            sum += Number(limpio)
            anyValid := true
            results.Push(limpio)
        }

        this.suppressResultsChange := true
        if (results.Length = 0)
            this.resultsCtrl.Value := ""
        else
        {
            buf := ""
            for r in results
                buf .= r "`r`n"
            this.resultsCtrl.Value := buf
        }
        SetTimer((*) => this.suppressResultsChange := false, -50)

        if anyValid
            this.totalCtrl.Value := Format("{:.2f}", sum)
        else
            this.totalCtrl.Value := "0.00"
    }

    ; --- Recalcula el total a partir de las lineas en resultsCtrl.
    ; Usado cuando el usuario edita resultsCtrl directamente (ej. borrar el "9
    ; de abril" que el OCR confundio con un numero, o agregar lineas nuevas).
    ; Por cada linea no vacia, toma el PRIMER numero reconocido. Asi tolera
    ; texto suelto en la linea ("9   <-  9 de abril" -> 9; "100 nota" -> 100).
    OnResultsEdited()
    {
        if this.suppressResultsChange
            return
        if !this.resultsCtrl
            return

        text := this.resultsCtrl.Value
        sum := 0.0
        anyValid := false

        for line in StrSplit(text, "`n", "`r")
        {
            if (Trim(line) = "")
                continue
            tokens := this.ExtractNumberTokens(line)
            if (tokens.Length = 0)
                continue
            limpio := NormalizarPrecio(tokens[1])
            if (limpio = "")
                continue
            sum += Number(limpio)
            anyValid := true
        }

        if anyValid
            this.totalCtrl.Value := Format("{:.2f}", sum)
        else
            this.totalCtrl.Value := "0.00"
    }

    Clear()
    {
        if this.inputEdit
            this.inputEdit.Value := ""
        if this.resultsCtrl
            this.resultsCtrl.Value := ""
        if this.totalCtrl
            this.totalCtrl.Value := "0.00"
        if this.inputEdit
            this.inputEdit.Focus()
    }

    CopyTotal()
    {
        if !this.totalCtrl
            return
        A_Clipboard := this.totalCtrl.Value
        ToolTip("Total copiado: " this.totalCtrl.Value)
        SetTimer(() => ToolTip(), -1500)
    }

    Hide()
    {
        if IsObject(this.gui)
            this.gui.Hide()
    }

    ; --- Extrae todos los tokens parecidos a numeros del texto.
    ;
    ; Estrategia (alternacion en el regex, primer match gana por posicion):
    ;
    ;   1. Patron ESTRICTO con decimal de 2 digitos: [\d,]+\.\d{2}
    ;      Captura "12.3456.789.00" -> ["12.34", "56.78", "9.00"].
    ;      Util para OCR que pega numeros concatenados sin separadores.
    ;      Regla del usuario: SIEMPRE 2 digitos despues del punto.
    ;
    ;   2. Patron GENERAL: \d[\d.,]*  (digitos con comas/puntos internos).
    ;      Fallback para enteros sueltos (100), numeros con miles (1,234.56),
    ;      etc. Cada token se cleanea con NormalizarPrecio en el caller.
    ;
    ; Ambos patrones admiten $ opcional al inicio, - opcional, y " CR" al final.
    ; ---
    ExtractNumberTokens(text)
    {
        tokens := []
        if (text = "")
            return tokens

        pattern := "i)\$?-?(?:[\d,]+\.\d{2}|\d[\d.,]*)(?:\s*CR)?"

        pos := 1
        while (matchPos := RegExMatch(text, pattern, &m, pos))
        {
            tokens.Push(Trim(m[0]))
            pos := matchPos + StrLen(m[0])
            if (pos > StrLen(text))
                break
        }
        return tokens
    }
}
