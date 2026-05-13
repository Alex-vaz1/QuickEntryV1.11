#Requires AutoHotkey v2.0
#Include "..\Lib\Cleaners.ahk"
#Include "..\Lib\Validators.ahk"
#Include "..\Lib\Schema.ahk"

; ====================================================================
; AsignetHeaderV1 - Header de factura del sistema Asignet (web app).
;
; 9 campos en orden fijo. Ecuaciones de validacion:
;   slot 7 (Past due)          = slot 5 + slot 6
;   slot 9 (Total w/ past due) = slot 8 + slot 7
;
; Slot 6 (Past payments) SIEMPRE es egreso -> forzamos negativo al limpiar
; para que la suma del slot 7 sea aritmeticamente correcta.
; Slots 1 y 4 (Account number, Corp name) tienen lupa en el form: el
; pegado rellena el filtro de busqueda; el operador confirma con click.
; ====================================================================

; --- Cleaners especificos del schema ---
CleanRaw(raw) => raw                                              ; passthrough (ej. Corp name)
CleanPasoPegado(raw) => LimpiarComoPegadoEspecial(raw)            ; fechas + precios + texto
CleanPasoPegadoForzandoNegativo(raw)
{
    limpio := LimpiarComoPegadoEspecial(raw)
    return (limpio = "") ? "" : ForzarNegativo(limpio)
}

; --- Helpers de "esperado" para el tooltip ---
EsperadoSuma(slotsIdx, cola)
{
    maxIdx := 0
    for s in slotsIdx
        if (s > maxIdx)
            maxIdx := s
    if (cola.Length < maxIdx)
        return ""
    suma := 0.0
    for s in slotsIdx
    {
        if (cola[s] = "")
            return ""
        suma += Number(cola[s])
    }
    return Format("{:.2f}", suma)
}

ExpectedSlot5(cola) => EsperadoSuma([5, 6], cola)
ExpectedSlot9(cola) => EsperadoSuma([8, 7], cola)


CrearAsignetHeaderV1()
{
    fields := [
        Campo("Account number",      CleanPasoPegado,                   ValidarNoVacio,           2,    false),
        Campo("Invoice date",        CleanPasoPegado,                   ValidarFechaEstricta,     1,    false),
        Campo("Due date",            CleanPasoPegado,                   ValidarFechaEstricta,     3,    false),
        Campo("Corp name",           CleanRaw,                          ValidarNoVacio,           5,    false, "", "", [
            300,                          ; settling: deja que el autocomplete/dropdown de Corp name termine antes de tabular
            "{Tab}", 250,                 ; tab 1 (pausa extra para que el foco avance del campo intermedio)
            "{Tab}", 250,                 ; tab 2 -> Currency
            "US", 500,                    ; escribe "US", espera autocomplete
            "{Tab}", "{Enter}", 200,      ; selecciona "US Dollars"
            "{Tab}", "{Tab}", "{Tab}"     ; tabs restantes hasta Past due
        ]),
        Campo("Previous balance",    CleanPasoPegado,                   ValidarNumero,            1,    false),
        Campo("Past Total Payments", CleanPasoPegadoForzandoNegativo,   ValidarNumero,            10,   false),
        Campo("Past due",            CleanPasoPegado,                   ValidarSumaTol([5, 6]),   1,    false, ExpectedSlot5, [5, 6]),
        Campo("Total ($)",           CleanPasoPegado,                   ValidarNumero,            5,    false),
        Campo("Invoice Total Including PastDue", CleanPasoPegado,       ValidarSumaTol([8, 7]),   1,    false, ExpectedSlot9, [8, 7])
    ]

    ; Orden de pegado (1-based): el operador copia en orden de lectura de la
    ; factura; el form tiene disposicion distinta. El quinto valor pegado
    ; es el slot 7 de la cola (Past due), no el slot 5.
    ordenPegado := [1, 2, 3, 4, 7, 5, 6, 8, 9]

    ; Form vacio: navega desde el tope hasta Account number y selecciona
    ; "Invoice" en el dropdown Type of Document ({Down}+{Enter}).
    prePasteSteps := [
        "{Up 3}",
        "{Down}",
        "{Enter}",
        "{Tab}",
        "Invoice",
        "{Tab}"
    ]

    ; Form ya cargado: "Type of Document" es readonly/no-tab-stop, asi que
    ; dos {Tab} van directo a Account #. No se tipea "Invoice" (ya esta).
    preScanSteps := [
        "{Tab}",
        "{Tab}",
    ]

    return InvoiceSchema("Asignet Header v1", fields, ordenPegado, prePasteSteps, preScanSteps)
}

