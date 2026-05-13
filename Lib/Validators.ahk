#Requires AutoHotkey v2.0
; ====================================================================
; Validators.ahk — Funciones puras de validacion.
; Firma uniforme: (val, cola) => "" si OK, mensaje si NO.
; Permite que CaptureEngine llame cualquier validator polimorficamente.
; ====================================================================

EsImporteValido(s)
{
    return RegExMatch(s, "^-?\d+(\.\d+)?$") > 0
}

ValidarNoVacio(val, cola)
{
    return (val = "") ? "valor vacio" : ""
}

ValidarNumero(val, cola)
{
    return EsImporteValido(val) ? "" : "no es un numero valido"
}

ValidarFechaEstricta(val, cola)
{
    ; Valida formato MM/DD/YYYY, no combinaciones de calendario (ej: 02/31).
    ; La correccion semantica la garantiza Asignet al procesar la factura.
    if RegExMatch(val, "^(0[1-9]|1[0-2])/(0[1-9]|[12]\d|3[01])/\d{4}$")
        return ""
    return "fecha debe ser MM/DD/YYYY"
}

; Builder: fija slotsIndices y tol como parametros parciales via .Bind().
; tol := 0.01 cubre el error de redondeo tipico en sumas de dos decimales.
; Si algun operando esta vacio (""), retorna "" (skip): el usuario puede
; llegar al campo de suma antes de completar sus operandos.
ValidarSumaTol(slotsIndices, tol := 0.01)
{
    return ValidarSumaCheck.Bind(slotsIndices, tol)
}

ValidarSumaCheck(slotsIndices, tol, val, cola)
{
    if !EsImporteValido(val)
        return "no es un numero valido"

    maxIdx := 0
    for s in slotsIndices
        if (s > maxIdx)
            maxIdx := s

    if (cola.Length < maxIdx)
        return ""

    suma := 0.0
    for s in slotsIndices
    {
        if (cola[s] = "")
            return ""
        suma += Number(cola[s])
    }

    if (Abs(Number(val) - suma) > tol)
        return "suma debe ser " . Format("{:.2f}", suma)
    return ""
}
