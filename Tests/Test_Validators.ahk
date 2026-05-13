#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\Validators.ahk"
#Include "_AssertHelpers.ahk"

; ====================================================================
; EsImporteValido - predicado base
; ====================================================================
AssertEq(EsImporteValido("100"), true, "EIV entero positivo")
AssertEq(EsImporteValido("100.00"), true, "EIV decimal")
AssertEq(EsImporteValido("-100"), true, "EIV entero negativo")
AssertEq(EsImporteValido("-100.50"), true, "EIV decimal negativo")
AssertEq(EsImporteValido("0"), true, "EIV cero")
AssertEq(EsImporteValido("0.00"), true, "EIV cero decimal")
AssertEq(EsImporteValido(""), false, "EIV vacio")
AssertEq(EsImporteValido("abc"), false, "EIV letras")
AssertEq(EsImporteValido("$100"), false, "EIV con $ no es valido")
AssertEq(EsImporteValido("1,234"), false, "EIV con coma no es valido")
AssertEq(EsImporteValido("100."), false, "EIV punto sin decimales")
AssertEq(EsImporteValido(".5"), false, "EIV decimal sin parte entera")
AssertEq(EsImporteValido("100-"), false, "EIV minus sufijo no es valido")
AssertEq(EsImporteValido("--100"), false, "EIV doble minus")

; ====================================================================
; ValidarNoVacio
; ====================================================================
AssertEq(ValidarNoVacio("ACC", []), "", "VNV acepta texto")
AssertEq(ValidarNoVacio("  spaces  ", []), "", "VNV acepta strings con espacios (no trim)")
AssertContains(ValidarNoVacio("", []), "vacio", "VNV rechaza vacio")

; ====================================================================
; ValidarNumero
; ====================================================================
AssertEq(ValidarNumero("100.50", []), "", "VN acepta decimal")
AssertEq(ValidarNumero("-100", []), "", "VN acepta negativo")
AssertEq(ValidarNumero("0", []), "", "VN acepta cero")
AssertContains(ValidarNumero("abc", []), "numero", "VN rechaza texto")
AssertContains(ValidarNumero("", []), "numero", "VN rechaza vacio")
AssertContains(ValidarNumero("$100", []), "numero", "VN rechaza con simbolo")

; ====================================================================
; ValidarFechaEstricta
; ====================================================================
AssertEq(ValidarFechaEstricta("12/31/2026", []), "", "VFE acepta MM/DD/YYYY")
AssertEq(ValidarFechaEstricta("01/01/2026", []), "", "VFE acepta enero")
AssertEq(ValidarFechaEstricta("09/15/2026", []), "", "VFE acepta septiembre")
AssertContains(ValidarFechaEstricta("9/15/2026", []), "fecha", "VFE rechaza sin pad mes")
AssertContains(ValidarFechaEstricta("09/5/2026", []), "fecha", "VFE rechaza sin pad dia")
AssertContains(ValidarFechaEstricta("09/15/26", []), "fecha", "VFE rechaza anio 2 digitos")
AssertContains(ValidarFechaEstricta("Sep 15, 2026", []), "fecha", "VFE rechaza texto")
AssertContains(ValidarFechaEstricta("13/01/2026", []), "fecha", "VFE rechaza mes 13")
AssertContains(ValidarFechaEstricta("12/32/2026", []), "fecha", "VFE rechaza dia 32")
AssertContains(ValidarFechaEstricta("", []), "fecha", "VFE rechaza vacio")

; ====================================================================
; ValidarSumaTol - builder para suma de slots con tolerancia
; ====================================================================
v7 := ValidarSumaTol([5, 6])
cola := ["A", "D1", "D2", "Corp", "1000.00", "-500.00"]

AssertEq(v7.Call("500.00", cola), "", "VST 1000+(-500)=500 OK")
AssertContains(v7.Call("9999", cola), "suma", "VST suma erronea")
AssertContains(v7.Call("9999", cola), "500.00", "VST mensaje incluye esperado")

; --- tol=0.01 es la frontera: cubre redondeo bancario a 2 dec sin enmascarar errores reales ---
AssertEq(v7.Call("500.01", cola), "", "VST +0.01 OK")
AssertEq(v7.Call("499.99", cola), "", "VST -0.01 OK")
AssertContains(v7.Call("500.02", cola), "suma", "VST +0.02 fuera tolerancia")
AssertContains(v7.Call("499.98", cola), "suma", "VST -0.02 fuera tolerancia")

; --- Skip si dep omitida (string vacio) ---
AssertEq(v7.Call("500.00", ["A", "D1", "D2", "Corp", "", "-500.00"]), "", "VST skip si dep5 vacia")
AssertEq(v7.Call("500.00", ["A", "D1", "D2", "Corp", "1000.00", ""]), "", "VST skip si dep6 vacia")
AssertEq(v7.Call("500.00", ["A", "D1", "D2", "Corp", "1000.00"]), "", "VST skip si cola corta")

; --- Builder con 3 slots ---
v3 := ValidarSumaTol([1, 2, 3])
AssertEq(v3.Call("60", ["10", "20", "30"]), "", "VST 3 slots suma OK")
AssertContains(v3.Call("99", ["10", "20", "30"]), "suma", "VST 3 slots suma errada")
AssertContains(v3.Call("99", ["10", "20", "30"]), "60.00", "VST 3 slots mensaje incluye esperado")

; --- Builder con tolerancia custom ---
v7Loose := ValidarSumaTol([5, 6], 1.0)
AssertEq(v7Loose.Call("500.50", cola), "", "VST tolerancia 1.0 acepta +0.50")
AssertEq(v7Loose.Call("499.50", cola), "", "VST tolerancia 1.0 acepta -0.50")
AssertContains(v7Loose.Call("502.00", cola), "suma", "VST tolerancia 1.0 rechaza +2.00")

; --- la validacion de formato precede a la suma: evita que "abc" llegue a Float() ---
AssertContains(v7.Call("abc", cola), "numero", "VST rechaza no-numero antes de comparar suma")
AssertContains(v7.Call("", cola), "numero", "VST rechaza vacio")

; --- Builder devuelve closures independientes ---
vA := ValidarSumaTol([1, 2])
vB := ValidarSumaTol([3, 4])
AssertEq(vA.Call("30", ["10", "20", "100", "200"]), "", "VST builder vA usa slots 1,2")
AssertEq(vB.Call("300", ["10", "20", "100", "200"]), "", "VST builder vB usa slots 3,4")
AssertContains(vA.Call("999", ["10", "20", "100", "200"]), "30.00", "VST vA suma 30 esperada")
AssertContains(vB.Call("999", ["10", "20", "100", "200"]), "300.00", "VST vB suma 300 esperada")

ReportarYSalir()
