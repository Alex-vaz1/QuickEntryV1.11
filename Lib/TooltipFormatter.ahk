#Requires AutoHotkey v2.0
#Include "CaptureEngine.ahk"

; ====================================================================
; TooltipFormatter - convierte estado del CaptureEngine en texto de
; tooltip de 2-3 lineas. Funciones puras (sin side effects).
;
; Layout (caso normal, proximo slot SIN expectedDeps):
;   Linea 1: prompt del PROXIMO slot ('Busca "X" (n/N)' [+ esperado])
;   Linea 2: feedback del slot PREVIO (nombre + valor entre flechas)
;
; Layout cuando proximo slot tiene expectedDeps (Past due, Total w/past due):
;   Linea 1: prompt + esperado
;   Linea 2: <Operand1>: <valor1>     (sin flechas - es breakdown)
;   Linea 3: <Operand2>: <valor2>
;   (el "previo" se omite: los operandos lo subsumen y son mas informativos)
;
; Mensajes de error usan NOMBRE del campo, no numero de slot.
; ====================================================================

; ▶/◀ Unicode: inmunes a encodings de clipboard y presentes en Segoe UI.
; AHK ToolTip no soporta markup, por eso no se usan asteriscos ni ANSI bold.
EnNegrita(valor) => Chr(0x25B6) " " valor " " Chr(0x25C0)

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

; --- Linea 2: feedback del slot recien actuado (vacio si actionLog vacio).
;     Formato C: "<prefijo>▶ valor ◀ (NombreCampo)" - valor primero,
;     nombre entre parentesis para que el operador no lea el nombre
;     primero y termine "buscando dos veces" el campo previo. ---
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

LineasOperandos(engine)
{
    if (engine.IsComplete)
        return ""
    slot := engine.NextSlot
    if (slot < 1)
        return ""
    campo := engine.schema.Field(slot)
    deps := campo.expectedDeps
    if (!IsObject(deps) || deps.Length = 0)
        return ""

    out := ""
    for dep in deps
    {
        if (dep < 1 || dep > engine.schema.Length)
            continue
        depCampo := engine.schema.Field(dep)
        valor := (dep <= engine.queue.Length) ? engine.queue[dep] : ""
        if (valor = "")
            valor := "(vacio)"
        linea := depCampo.name ": " valor
        out := (out = "") ? linea : out "`n" linea
    }
    return out
}

TooltipPostAccion(engine, accion := "", valorOverride := "")
{
    l1 := LineaPrompt(engine)

    operandos := LineasOperandos(engine)
    if (operandos != "")
        return l1 "`n" operandos

    l2 := LineaPrevio(engine, accion, valorOverride)
    return (l2 = "") ? l1 : l1 "`n" l2
}

; --- Tooltip de error de validacion (usa nombre, no slot) ---
TooltipError(label, mensajeValidacion) => label " invalido: " mensajeValidacion

; --- Linea generica que invita a recopiar u omitir; hotkey configurable ---
LineaInputInvalido(hotkeyOmitir) => "Input invalido, recopia o " hotkeyOmitir " para omitir"

; --- Tooltip completo cuando una captura es invalida.
;     Mantiene prompt + previo/operandos visibles (no se pierde el contexto)
;     y agrega: (opcional) detalle especifico + linea generica.
;     `detalle` vacio = caso rechazo del cleaner; sino = mensaje de validacion. ---
TooltipConError(engine, detalle, hotkeyOmitir)
{
    base := TooltipPostAccion(engine)
    out := base
    if (detalle != "")
        out .= "`n" detalle
    out .= "`n" LineaInputInvalido(hotkeyOmitir)
    return out
}
