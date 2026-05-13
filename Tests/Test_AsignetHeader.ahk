#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Schemas\AsignetHeaderV1.ahk"
#Include "..\Lib\CaptureEngine.ahk"
#Include "_AssertHelpers.ahk"

; ====================================================================
; Smoke test del schema declarativo Asignet Header V1.
; Valida estructura, nombres, cleaners, validators, expectedFn y un
; pipeline integral con datos OCR-realistas.
; ====================================================================

s := CrearAsignetHeaderV1()

; --- Estructura ---
AssertEq(s.name, "Asignet Header v1", "Schema name correcto")
AssertEq(s.Length, 9, "Schema tiene 9 campos")

; --- Nombres en orden ---
nombresEsperados := [
    "Account number", "Invoice date", "Due date", "Corp name",
    "Previous balance", "Past Total Payments", "Past due", "Total ($)",
    "Invoice Total Including PastDue"
]
Loop 9
{
    i := A_Index
    AssertEq(s.Field(i).name, nombresEsperados[i], "Field(" i ").name = " nombresEsperados[i])
}

; --- tabsAfter por slot (refleja el form real de Asignet) ---
tabsEsperados := [2, 1, 3, 5, 1, 10, 1, 5, 1]
Loop 9
{
    i := A_Index
    AssertEq(s.Field(i).tabsAfter, tabsEsperados[i],
             "Field(" i ").tabsAfter = " tabsEsperados[i])
}

; --- ordenPegado refleja el orden visual del form ---
AssertEq(s.ordenPegado.Length, 9, "ordenPegado tiene 9 elementos")
ordenEsperado := [1, 2, 3, 4, 7, 5, 6, 8, 9]
Loop 9
{
    i := A_Index
    AssertEq(s.ordenPegado[i], ordenEsperado[i],
             "ordenPegado[" i "] = " ordenEsperado[i])
}

; --- prePasteSteps: 6 pasos (cursor inicia en dropdown Type) ---
prePasteEsperados := [
    "{Up 3}", "{Down}", "{Enter}",
    "{Tab}", "Invoice", "{Tab}"
]
AssertEq(s.prePasteSteps.Length, 6, "Asignet prePasteSteps 6 pasos")
Loop 6
{
    i := A_Index
    AssertEq(s.prePasteSteps[i], prePasteEsperados[i],
             "prePasteSteps[" i "] = " prePasteEsperados[i])
}

; --- preScanSteps: 2 pasos (cursor en Type, Type of Document es no-tab-stop) ---
AssertEq(s.preScanSteps.Length, 2, "Asignet preScanSteps 2 pasos")
AssertEq(s.preScanSteps[1], "{Tab}", "preScanSteps[1] = {Tab}")
AssertEq(s.preScanSteps[2], "{Tab}", "preScanSteps[2] = {Tab}")

; --- skipPaste siempre false (Asignet) ---
Loop 9
{
    i := A_Index
    AssertEq(s.Field(i).skipPaste, false, "Field(" i ").skipPaste = false")
}

; ====================================================================
; Cleaners por slot - validar invocacion + comportamiento esperado
; ====================================================================

; Slot 1: Account number
AssertEq(s.Field(1).clean.Call("ACC-12345"), "ACC-12345", "Slot1 clean alfanum passthrough")

; Slot 2: Invoice date
AssertEq(s.Field(2).clean.Call("Sep 15, 2026"), "09/15/2026", "Slot2 fecha texto -> MM/DD/YYYY")
AssertEq(s.Field(2).clean.Call("12/31/2026"), "12/31/2026", "Slot2 fecha numerica passthrough")

; Slot 3: Due date (mismo cleaner)
AssertEq(s.Field(3).clean.Call("January 1, 2026"), "01/01/2026", "Slot3 fecha texto enero")

; Slot 4: Corp name
AssertEq(s.Field(4).clean.Call("Empresa S.A."), "Empresa S.A.", "Slot4 raw passthrough")
AssertEq(s.Field(4).clean.Call("  Espacios  "), "  Espacios  ", "Slot4 NO trimea")

; Slot 5: Previous balance
AssertEq(s.Field(5).clean.Call("$1,234.56"), "1234.56", "Slot5 precio limpia $ y coma")
AssertEq(s.Field(5).clean.Call("1000.00"), "1000.00", "Slot5 precio passthrough")
AssertEq(s.Field(5).clean.Call("$500.00 CR"), "-500.00", "Slot5 CR -> negativo")

; Slot 6: Past payments (paso pegado + forzar negativo)
AssertEq(s.Field(6).clean.Call("$500.00"), "-500.00", "Slot6 fuerza negativo a positivo")
AssertEq(s.Field(6).clean.Call("$500.00 CR"), "-500.00", "Slot6 CR ya negativo, mantiene")
AssertEq(s.Field(6).clean.Call("-300.00"), "-300.00", "Slot6 negativo passthrough")
AssertEq(s.Field(6).clean.Call("0"), "0", "Slot6 cero queda cero (sin signo)")
AssertEq(s.Field(6).clean.Call(""), "", "Slot6 vacio queda vacio")

; Slot 7-9: paso pegado normal
AssertEq(s.Field(7).clean.Call("$500.00"), "500.00", "Slot7 precio")
AssertEq(s.Field(8).clean.Call("$6,234.56"), "6234.56", "Slot8 precio con coma")
AssertEq(s.Field(9).clean.Call("$7,469.12"), "7469.12", "Slot9 precio con coma")

; ====================================================================
; Validators por slot
; ====================================================================

; Slot 1: ValidarNoVacio
AssertEq(s.Field(1).validate.Call("ACC123", []), "", "Slot1 acepta texto")
AssertContains(s.Field(1).validate.Call("", []), "vacio", "Slot1 rechaza vacio")

; Slot 2-3: ValidarFechaEstricta
AssertEq(s.Field(2).validate.Call("12/31/2026", []), "", "Slot2 acepta fecha valida")
AssertContains(s.Field(2).validate.Call("Sep 15", []), "fecha", "Slot2 rechaza texto")
AssertEq(s.Field(3).validate.Call("01/01/2026", []), "", "Slot3 acepta fecha valida")

; Slot 4: ValidarNoVacio
AssertEq(s.Field(4).validate.Call("Empresa", []), "", "Slot4 acepta texto")
AssertContains(s.Field(4).validate.Call("", []), "vacio", "Slot4 rechaza vacio")

; Slot 5-6: ValidarNumero
AssertEq(s.Field(5).validate.Call("1000.00", []), "", "Slot5 acepta numero")
AssertContains(s.Field(5).validate.Call("abc", []), "numero", "Slot5 rechaza texto")
AssertEq(s.Field(6).validate.Call("-500.00", []), "", "Slot6 acepta negativo")

; Slot 7: ValidarSumaTol([5,6])
cola6 := ["ACC", "01/01/2026", "01/15/2026", "Corp", "1000.00", "-500.00"]
AssertEq(s.Field(7).validate.Call("500.00", cola6), "", "Slot7 suma 1000+(-500)=500 OK")
AssertContains(s.Field(7).validate.Call("999", cola6), "suma", "Slot7 suma erronea")
AssertContains(s.Field(7).validate.Call("999", cola6), "500.00", "Slot7 mensaje incluye esperado")

; Slot 8: ValidarNumero
AssertEq(s.Field(8).validate.Call("6234.56", []), "", "Slot8 acepta numero")

; Slot 9: ValidarSumaTol([8,7])
cola8 := ["ACC", "01/01/2026", "01/15/2026", "Corp", "1000.00", "-500.00", "500.00", "2500.00"]
AssertEq(s.Field(9).validate.Call("3000.00", cola8), "", "Slot9 suma 2500+500=3000 OK")
AssertContains(s.Field(9).validate.Call("9999", cola8), "suma", "Slot9 suma erronea")
AssertContains(s.Field(9).validate.Call("9999", cola8), "3000.00", "Slot9 mensaje incluye esperado")

; ====================================================================
; expectedFn - solo en slots 7 y 9
; ====================================================================

Loop 9
{
    i := A_Index
    if (i = 7 || i = 9)
    {
        if (s.Field(i).expectedFn = "")
            AssertEq("missing", "function", "Slot" i " debe tener expectedFn")
    }
    else
    {
        AssertEq(s.Field(i).expectedFn, "", "Slot" i " expectedFn vacio")
    }
}

; --- expectedDeps: solo slots 7 y 9 los declaran ---
AssertEq(s.Field(7).expectedDeps.Length, 2, "Slot7 expectedDeps tiene 2 elementos")
AssertEq(s.Field(7).expectedDeps[1], 5, "Slot7 expectedDeps[1] = 5 (Previous balance)")
AssertEq(s.Field(7).expectedDeps[2], 6, "Slot7 expectedDeps[2] = 6 (Past payments)")

AssertEq(s.Field(9).expectedDeps.Length, 2, "Slot9 expectedDeps tiene 2 elementos")
AssertEq(s.Field(9).expectedDeps[1], 8, "Slot9 expectedDeps[1] = 8 (Total)")
AssertEq(s.Field(9).expectedDeps[2], 7, "Slot9 expectedDeps[2] = 7 (Past due)")

Loop 9
{
    i := A_Index
    if (i != 7 && i != 9)
        AssertEq(s.Field(i).expectedDeps.Length, 0, "Slot" i " expectedDeps vacio")
}

; --- expectedFn.Call devuelve valor correcto dado cola completa ---
AssertEq(s.Field(7).expectedFn.Call(cola6), "500.00", "Slot7 expectedFn = 500.00")
AssertEq(s.Field(9).expectedFn.Call(cola8), "3000.00", "Slot9 expectedFn = 3000.00")

; --- expectedFn devuelve "" si dependencias incompletas ---
AssertEq(s.Field(7).expectedFn.Call(["ACC", "D1", "D2", "Corp", "1000.00"]), "", "Slot7 expectedFn vacio si cola corta")
AssertEq(s.Field(7).expectedFn.Call(["ACC", "D1", "D2", "Corp", "", "-500.00"]), "", "Slot7 expectedFn vacio si dep5 vacia")
AssertEq(s.Field(9).expectedFn.Call(["ACC", "D1", "D2", "Corp", "1000.00", "-500.00", "500.00"]), "", "Slot9 expectedFn vacio si cola corta")

; ====================================================================
; Pipeline integral - happy path 9 slots (datos OCR realistas)
; ====================================================================

inputs := [
    "ACC-12345",
    "Sep 15, 2026",
    "10/15/2026",
    "Empresa S.A.",
    "$1,000.00",
    "$500.00",
    "$500.00",
    "$2,500.00",
    "$3,000.00"
]
esperados := [
    "ACC-12345",
    "09/15/2026",
    "10/15/2026",
    "Empresa S.A.",
    "1000.00",
    "-500.00",
    "500.00",
    "2500.00",
    "3000.00"
]

cola := []
Loop 9
{
    i := A_Index
    limpio := s.Field(i).clean.Call(inputs[i])
    AssertEq(limpio, esperados[i], "Pipeline slot" i " clean OK")
    err := s.Field(i).validate.Call(limpio, cola)
    AssertEq(err, "", "Pipeline slot" i " validate OK (err=" err ")")
    cola.Push(limpio)
}
AssertEq(cola.Length, 9, "Pipeline cola final tiene 9 items")

; ====================================================================
; AutoCalc end-to-end con schema Asignet real - slot 7 y slot 9 en cadena
; ====================================================================

; --- AutoCalc slot 7 (Past due) ---
ea := CaptureEngine(CrearAsignetHeaderV1(), true)  ; autoCalc ON
ea.Arm()
inputsHappy := ["ACC", "01/01/2026", "02/01/2026", "Corp", "1000.00", "-500.00"]
Loop 6
    ea.PushRaw(inputsHappy[A_Index])
AssertEq(ea.NextSlot, 7, "Asignet pre-skip: NextSlot=7")
AssertEq(ea.ExpectedFor(7), "500.00", "Asignet ExpectedFor(7) cola hasta 6 = 500.00")

skP7 := ea.SkipCurrent()
AssertEq(skP7["value"], "500.00", "Asignet Skip(7) autocalc value")
AssertEq(ea.queue[7], "500.00", "Asignet queue[7] = autocalc")
AssertEq(ea.FilledCount, 7, "Asignet FilledCount tras autocalc 7 = 7 (cuenta)")

; --- AutoCalc slot 9 - usa el slot 7 autocalc'd como dependencia ---
ea.PushRaw("2500.00")  ; slot 8
AssertEq(ea.NextSlot, 9, "Asignet pre-skip 9: NextSlot=9")
AssertEq(ea.ExpectedFor(9), "3000.00", "Asignet ExpectedFor(9) = 2500 + 500 (autocalc'd) = 3000.00")

skP9 := ea.SkipCurrent()
AssertEq(skP9["value"], "3000.00", "Asignet Skip(9) autocalc value")
AssertEq(ea.queue[9], "3000.00", "Asignet queue[9] = autocalc")
AssertEq(ea.IsComplete, true, "Asignet IsComplete tras autocalc 9")
AssertEq(ea.FilledCount, 9, "Asignet FilledCount=9 con dos autocalc en cadena")

; --- AutoCalc con dep incompleta retorna "" (no rompe) ---
eaPartial := CaptureEngine(CrearAsignetHeaderV1(), true)
eaPartial.Arm()
eaPartial.PushRaw("ACC")
eaPartial.PushRaw("01/01/2026")
eaPartial.PushRaw("02/01/2026")
eaPartial.PushRaw("Corp")
eaPartial.JumpTo(7)
skBad := eaPartial.SkipCurrent()
AssertEq(skBad["value"], "", "Asignet Skip(7) con dep5,6 vacios: autocalc retorna ''")
AssertEq(eaPartial.queue[7], "", "Asignet queue[7] queda '' (no se rompe)")

ReportarYSalir()
