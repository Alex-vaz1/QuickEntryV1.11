#Requires AutoHotkey v2.0
#Include "..\Lib\Cleaners.ahk"
#Include "..\Lib\Validators.ahk"
#Include "..\Lib\Schema.ahk"

; ====================================================================
; PLANTILLA: Schema de header de factura para una empresa nueva.
;
; Como usar esta plantilla:
;   1) Copiar este archivo a `Schemas\<MiEmpresa>HeaderV1.ahk`
;   2) Renombrar la funcion `CrearMiEmpresaHeaderV1` por convencion
;   3) Ajustar la lista `fields` con los campos del formulario destino
;   4) Cambiar el QuickEntry.ahk (entry point) para llamar al nuevo schema
;   5) Crear `Tests\Test_MiEmpresaHeader.ahk` (copiar Test_AsignetHeader)
;
; Conceptos clave del contrato `Campo`:
;   - name        : nombre legible para tooltips/errores ("Past due")
;   - clean       : (raw) => limpio - convierte el clipboard al valor final
;   - validate    : (val, cola) => "" si OK, mensaje si error
;   - tabsAfter   : Tabs DESPUES del paste (1 = normal, 2 = campo doble)
;   - skipPaste   : true = solo manda Tabs, no pega valor (campos con lupa
;                   donde el operador hace click manual en el resultado)
;   - expectedFn  : opcional - (cola) => "X.XX" para mostrar valor esperado
;                   en tooltip ANTES de copiar (ej. sumas calculadas)
;   - expectedDeps: opcional - Array<Integer> con los slots usados por
;                   expectedFn. El tooltip los muestra abajo (1 linea por
;                   operando) para que el operador verifique los inputs.
;
; Conceptos clave del contrato `InvoiceSchema`:
;   - ordenPegado   : opcional - Array<Integer> 1-based con el orden en que
;                     PasteBatch pega los slots. Default = [1..N] (capture
;                     order = paste order). Util cuando el operador copia en
;                     orden de lectura pero el form tiene los inputs en
;                     otro orden. Ej. Asignet: [1,2,3,4,7,5,6,8,9].
;   - prePasteSteps : opcional - Array<String> de directivas SendInput que
;                     se ejecutan ANTES de pegar el primer slot. Util para
;                     navegar desde el tope de la pagina hasta el primer
;                     input, seleccionar tipo de factura, etc. Cada string
;                     se pasa tal cual a SendInput con 150ms entre pasos.
;                     Ej: ["{Tab 13}", "{Enter}", "Invoice", "{Tab}"].
;
; Cleaners disponibles (Lib/Cleaners.ahk):
;   - LimpiarComoPegadoEspecial : detecta fecha/precio/texto, normaliza
;   - NormalizarPrecio          : "$1,234.56" -> "1234.56"
;   - LimpiarFechaRobusta       : varias formas -> "MM/DD/YYYY"
;   - ForzarNegativo            : "500.00" -> "-500.00"
;   - LimpiarBillingItem        : limpia codigo de item de factura
;
; Validators disponibles (Lib/Validators.ahk):
;   - ValidarNoVacio
;   - ValidarNumero
;   - ValidarFechaEstricta
;   - ValidarSumaTol(slotsIndices, tol := 0.01)  -> builder
; ====================================================================

; --- Cleaners locales (passthrough u otros wrappers) ---
PlantCleanRaw(raw) => raw
PlantCleanPaso(raw) => LimpiarComoPegadoEspecial(raw)
PlantCleanForzarNeg(raw)
{
    limpio := LimpiarComoPegadoEspecial(raw)
    return (limpio = "") ? "" : ForzarNegativo(limpio)
}

; --- Helpers de "esperado" (opcional, solo si tu schema tiene sumas) ---
PlantSuma(slotsIdx, cola)
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
; Ejemplo: PlantExpectedSlotN(cola) => PlantSuma([slotsDep], cola)

; ====================================================================
; Definicion declarativa - EJEMPLO con campos variados.
; Modifica las filas, agrega/quita las que necesites.
; ====================================================================
CrearMiEmpresaHeaderV1()
{
    fields := [
        ; #  name              clean              validate                  tabs  skipPaste  expectedFn   expectedDeps
        ; --- Ejemplo 1: campo simple de texto, 1 Tab despues ---
        Campo("Numero factura", PlantCleanPaso,   ValidarNoVacio,           1,    false),

        ; --- Ejemplo 2: campo con lupa (no pega valor, solo Tabs) ---
        ; El operador hace click manual sobre el resultado del filtro.
        Campo("Cliente",        PlantCleanRaw,    ValidarNoVacio,           1,    true),

        ; --- Ejemplo 3: fecha con validacion estricta ---
        Campo("Fecha emision",  PlantCleanPaso,   ValidarFechaEstricta,     1,    false),

        ; --- Ejemplo 4: campo doble (necesita 2 Tabs para llegar al siguiente) ---
        Campo("Concepto",       PlantCleanPaso,   ValidarNoVacio,           2,    false),

        ; --- Ejemplo 5: monto numerico ---
        Campo("Subtotal",       PlantCleanPaso,   ValidarNumero,            1,    false),

        ; --- Ejemplo 6: campo que SIEMPRE es egreso (forzar negativo) ---
        Campo("Descuento",      PlantCleanForzarNeg, ValidarNumero,         1,    false)

        ; --- Ejemplo 7: total calculado (suma con tolerancia + expectedFn + expectedDeps) ---
        ; Descomentar si tu formulario tiene un campo derivado.
        ; expectedDeps = [5, 6] hace que el tooltip muestre los valores de
        ; Subtotal y Descuento en 2 lineas distintas al pedir este Total.
        ; , Campo("Total", PlantCleanPaso, ValidarSumaTol([5, 6]), 1, false,
        ;       (cola) => PlantSuma([5, 6], cola), [5, 6])
    ]

    ; --- ordenPegado: opcional. Si tu form tiene los inputs en distinto
    ;     orden que el orden de lectura del operador, declaralo aqui.
    ;     Default = [1..N] (capture order = paste order). ---
    ; ordenPegado := [1, 2, 3, 4, 5, 6]

    ; --- prePasteSteps: opcional. Pasos SendInput a ejecutar ANTES de
    ;     pegar el primer slot, util para navegacion al form / seleccion
    ;     de tipo. Default = [] (no navegacion previa).
    ;     Ejemplos: "{Tab 13}", "{Enter}", "{Up}", "{Down}", "{Tab}",
    ;     "Texto literal" (escribe ese texto). ---
    ; prePasteSteps := ["{Tab 5}", "{Enter}", "Tipo Factura", "{Tab}"]

    return InvoiceSchema("MiEmpresa Header v1", fields)
    ; Con extras:
    ; return InvoiceSchema("MiEmpresa Header v1", fields, ordenPegado, prePasteSteps)
}
