#Requires AutoHotkey v2.0
; ====================================================================
; Schema.ahk - Contratos: Campo y InvoiceSchema.
;
; class Campo:
;   name        - display name ("Past due", "Invoice date")
;   clean       - function: (raw:String) => limpio:String  ("" si rechazo)
;   validate    - function: (val:String, cola:Array) => "" o mensaje error
;   tabsAfter   - Integer: cantidad de Tabs DESPUES de pegar este campo
;                 (default 1; util para formularios donde un campo ocupa 2 controles).
;                 Usado por Scan y como fallback de PasteBatch si no hay stepsAfter.
;   stepsAfter  - Array opcional: pasos de navegacion POST-campo para PasteBatch.
;                 Reemplaza tabsAfter en PasteBatch cuando esta definido.
;                 String = SendInput, Integer = Sleep(ms). Ejemplo:
;                 ["{Tab}", "{Tab}", "US", 1000, "{Tab}", "{Enter}", "{Tab}", "{Tab}"]
;                 Scan SIEMPRE usa tabsAfter (form lleno no necesita interaccion extra).
;   skipPaste   - Boolean: si true, NO pega valor (solo Tabs); util para campos
;                 con lupa donde el operador hace click manual
;   expectedFn  - function opcional: (cola) => "X.XX" para mostrar valor esperado
;                 en tooltip antes de copiar (slots tipo Past due, Total w/ past due)
;   expectedDeps- Array<Integer> opcional: indices de slots cuyos valores
;                 alimentan el calculo de expectedFn. El tooltip los muestra
;                 abajo del prompt para que el operador verifique los inputs.
;                 Vacio = sin breakdown; el operador solo ve el total esperado,
;                 sin saber de donde vienen los sumandos (menos contexto).
;
; class InvoiceSchema:
;   name           - display ("Asignet Header v1")
;   fields         - Array<Campo>
;   ordenPegado    - Array<Integer> opcional: orden en que se pegan los slots
;                    al formulario (1-based). Permite copiar en orden de
;                    lectura del operador y pegar en el orden del form.
;                    Default = [1..N] (capture order = paste order).
;   prePasteSteps  - Array<String> opcional: pasos de SendInput a ejecutar
;                    ANTES de pegar el primer slot. Necesario porque la
;                    posicion del cursor al abrir el form no es determinista;
;                    estos pasos normalizan el punto de partida antes de que
;                    PasteBatch empiece a iterar los campos.
;                    Ejemplo: ["{Tab 13}", "{Enter}", "Invoice", "{Tab}"].
;   preScanSteps   - Array<String> opcional: pasos de navegacion previos al
;                    HeaderScan. Si vacio, Scan usa prePasteSteps. Util
;                    cuando el form ya lleno tiene distinto tab-order que
;                    el form vacio (ej. Type of Document readonly en filled).
;   Length         - count
;   Field(slot)    - campo en posicion 1-based
; ====================================================================

class Campo
{
    name := ""
    clean := (raw) => raw
    validate := (val, cola) => ""
    tabsAfter := 1
    stepsAfter := []
    skipPaste := false
    expectedFn := ""
    expectedDeps := []

    __New(name, clean, validate, tabsAfter := 1, skipPaste := false, expectedFn := "", expectedDeps := "", stepsAfter := "")
    {
        this.name := name
        this.clean := clean
        this.validate := validate
        this.tabsAfter := tabsAfter
        this.stepsAfter := IsObject(stepsAfter) ? stepsAfter : []
        this.skipPaste := skipPaste
        this.expectedFn := expectedFn
        this.expectedDeps := IsObject(expectedDeps) ? expectedDeps : []
    }
}


class InvoiceSchema
{
    name := ""
    fields := []
    ordenPegado := []
    prePasteSteps := []
    preScanSteps := []

    __New(name, fields, ordenPegado := "", prePasteSteps := "", preScanSteps := "")
    {
        this.name := name
        this.fields := fields
        if IsObject(ordenPegado) && ordenPegado.Length > 0
            this.ordenPegado := ordenPegado
        else
        {
            this.ordenPegado := []
            Loop fields.Length
                this.ordenPegado.Push(A_Index)
        }
        this.prePasteSteps := IsObject(prePasteSteps) ? prePasteSteps : []
        this.preScanSteps := IsObject(preScanSteps) ? preScanSteps : []
    }

    Length => this.fields.Length

    Field(slot)
    {
        if (slot < 1 || slot > this.fields.Length)
            throw ValueError("slot fuera de rango: " slot)
        return this.fields[slot]
    }
}
