#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\TooltipFormatter.ahk"
#Include "..\Schemas\AsignetHeaderV1.ahk"
#Include "_AssertHelpers.ahk"

; ====================================================================
; Constantes Unicode: Chr(0x25B6)/Chr(0x25C0) declaradas aquí para que
; un cambio de encoding rompa los asserts de forma visible, no silenciosa.
; ====================================================================
NEGRITA_OPEN := Chr(0x25B6) " "
NEGRITA_CLOSE := " " Chr(0x25C0)

; ====================================================================
; EnNegrita - helper visual
; ====================================================================
AssertEq(EnNegrita("123.45"), NEGRITA_OPEN "123.45" NEGRITA_CLOSE, "EnNegrita formato")
AssertEq(EnNegrita(""), NEGRITA_OPEN NEGRITA_CLOSE, "EnNegrita string vacio")
AssertEq(EnNegrita("texto largo"), NEGRITA_OPEN "texto largo" NEGRITA_CLOSE, "EnNegrita con espacios")

e := CaptureEngine(CrearAsignetHeaderV1())
e.Arm()

; ====================================================================
; Estado inicial: solo linea 1 (sin previo)
; ====================================================================
t0 := TooltipPostAccion(e)
AssertEq(t0, 'Busca "Account number" (0/9)', "T0 estado inicial: FilledCount=0")
AssertEq(InStr(t0, "`n"), 0, "T0 sin newline")

; --- LineaPrevio vacia con actionLog vacio ---
AssertEq(LineaPrevio(e), "", "LineaPrevio actionLog vacio: string vacio")

e.PushRaw("ACC-99999")
t1 := TooltipPostAccion(e)
AssertContains(t1, 'Busca "Invoice date" (1/9)', "T1 linea 1 proximo (FilledCount=1)")
AssertContains(t1, NEGRITA_OPEN "ACC-99999" NEGRITA_CLOSE " (Account number)", "T1 linea 2 previo formato C")
AssertContains(t1, "`n", "T1 multi-linea")

; --- Orden garantizado: prompt (linea 1) va antes que previo (linea 2) ---
posL1 := InStr(t1, "Busca")
posL2 := InStr(t1, "(Account number)")
AssertEq(posL1 < posL2, true, "T1 prompt va antes que previo")

e.PushRaw("Sep 15, 2026")    ; 2 -> "09/15/2026"
e.PushRaw("Oct 15, 2026")    ; 3 -> "10/15/2026"
e.PushRaw("Logitech")         ; 4 -> "Logitech"
e.PushRaw("$1,000")           ; 5 -> "1000"

t5 := TooltipPostAccion(e)
AssertContains(t5, 'Busca "Past Total Payments" (5/9)', "T5 prompt slot 6 (FilledCount=5)")
AssertContains(t5, NEGRITA_OPEN "1000" NEGRITA_CLOSE " (Previous balance)", "T5 previo Previous balance formato C")

; ====================================================================
; Acciones (omitido / descartado / manual) en slot 6 (sin operandos)
; ====================================================================
tOm := TooltipPostAccion(e, "omitido")
AssertContains(tOm, "omitido: " NEGRITA_OPEN "1000" NEGRITA_CLOSE " (Previous balance)", "T omitido prefijo formato C")

tDes := TooltipPostAccion(e, "descartado")
AssertContains(tDes, "descartado: " NEGRITA_OPEN "1000" NEGRITA_CLOSE " (Previous balance)", "T descartado prefijo formato C")

; --- Manual: SIN prefijo "manual:" (contrato: accion="" y dejar previo natural) ---
tMan := TooltipPostAccion(e, "")
AssertContains(tMan, NEGRITA_OPEN "1000" NEGRITA_CLOSE " (Previous balance)", "T manual sin prefijo: muestra previo formato C")
AssertEq(InStr(tMan, "manual:"), 0, "T manual no incluye 'manual:' como prefijo")

; ====================================================================
; Slot 7 (Past due) - operandos Previous balance + Past Total Payments en lineas separadas
; ====================================================================
e.PushRaw("$500")             ; 6 -> "-500" (forzado neg)

t7 := TooltipPostAccion(e)
AssertContains(t7, 'Busca "Past due" (6/9) - esperado: 500.00', "T7 prompt con esperado (FilledCount=6)")
AssertContains(t7, "Previous balance: 1000", "T7 operando 1: Previous balance")
AssertContains(t7, "Past Total Payments: -500", "T7 operando 2: Past Total Payments")
; Operandos NO usan flechas (es breakdown, no enfasis del previo)
AssertEq(InStr(t7, NEGRITA_OPEN), 0, "T7 sin flechas (breakdown puro)")
; Operandos en lineas separadas, en orden definido (5 antes que 6)
posOp1 := InStr(t7, "Previous balance:")
posOp2 := InStr(t7, "Past Total Payments:")
AssertEq(posOp1 > 0 && posOp2 > 0 && posOp1 < posOp2, true, "T7 ops en orden correcto")
nlCount := 0
Loop Parse t7, "`n"
    nlCount++
AssertEq(nlCount, 3, "T7 tiene 3 lineas (prompt + 2 operandos)")

; --- Operandos NO se afectan por accion / valorOverride (es breakdown del proximo) ---
t7Om := TooltipPostAccion(e, "omitido")
AssertContains(t7Om, "Previous balance: 1000", "T7Om operando 1 sin cambio por accion")
AssertContains(t7Om, "Past Total Payments: -500", "T7Om operando 2 sin cambio por accion")
AssertEq(InStr(t7Om, "omitido:"), 0, "T7Om accion ignorada cuando hay operandos")

e.PushRaw("500")              ; 7
e.PushRaw("$2,500")           ; 8 -> "2500"

t9 := TooltipPostAccion(e)
AssertContains(t9, 'Busca "Invoice Total Including PastDue" (8/9) - esperado: 3000.00', "T9 prompt con esperado (FilledCount=8)")
AssertContains(t9, "Total ($): 2500", "T9 operando 1: Total")
AssertContains(t9, "Past due: 500", "T9 operando 2: Past due")
AssertEq(InStr(t9, NEGRITA_OPEN), 0, "T9 sin flechas (breakdown puro)")
posT9_1 := InStr(t9, "Total ($): 2500")
posT9_2 := InStr(t9, "Past due: 500")
AssertEq(posT9_1 > 0 && posT9_2 > 0 && posT9_1 < posT9_2, true, "T9 ops en orden definido [8, 7]")

; ====================================================================
; Cola completa - vuelve a previo normal (no hay proximo slot con deps)
; ====================================================================
e.PushRaw("$3,000")           ; 9 -> "3000"

tFin := TooltipPostAccion(e)
AssertContains(tFin, "Listo 9/9", "T fin: listo")
AssertContains(tFin, "cola llena", "T fin: lema cola llena")
AssertContains(tFin, "^+s para pegar, ^+e para revisar", "T fin: hints completos persistentes")
AssertContains(tFin, NEGRITA_OPEN "3000" NEGRITA_CLOSE " (Invoice Total Including PastDue)", "T fin: previo ultimo slot formato C")

; ====================================================================
; Slot omitido muestra "(vacio)"
; ====================================================================
e2 := CaptureEngine(CrearAsignetHeaderV1())
e2.Arm()
e2.SkipCurrent()  ; slot 1 omitido (push "" sin autocalc)
tSk := TooltipPostAccion(e2, "omitido")
AssertContains(tSk, "omitido: " NEGRITA_OPEN "(vacio)" NEGRITA_CLOSE " (Account number)", "T slot omitido muestra (vacio) formato C")
AssertContains(tSk, 'Busca "Invoice date" (0/9)', "T slot omitido prompt avanzo (FilledCount=0)")

; ====================================================================
; LineaPrompt con esperado en slot 7 ya validado, slot 9 en proximo
; ====================================================================
e3 := CaptureEngine(CrearAsignetHeaderV1())
e3.Arm()
Loop 8
{
    inputs := ["ACC", "01/01/2026", "02/01/2026", "Corp", "1000", "-500", "500", "2500"]
    e3.PushRaw(inputs[A_Index])
}
tP9 := LineaPrompt(e3)
AssertContains(tP9, 'Busca "Invoice Total Including PastDue" (8/9)', "tP9 prompt slot 9 (FilledCount=8)")
AssertContains(tP9, "esperado: 3000.00", "tP9 prompt incluye esperado 3000")

; ====================================================================
; LineasOperandos - directo
; ====================================================================
; e3 esta en slot 9 (8 slots pusheados): verifica ops del slot actual, no del historico
ops7 := LineasOperandos(e3)  ; e3 esta en slot 9 ahora
AssertContains(ops7, "Total ($): 2500", "LineasOperandos slot 9 op1")
AssertContains(ops7, "Past due: 500", "LineasOperandos slot 9 op2")
AssertContains(ops7, "`n", "LineasOperandos: 2 lineas separadas")

; --- Slot SIN deps -> string vacio ---
eNoDep := CaptureEngine(CrearAsignetHeaderV1())
eNoDep.Arm()
eNoDep.PushRaw("ACC")  ; ahora en slot 2 (sin deps)
AssertEq(LineasOperandos(eNoDep), "", "LineasOperandos slot sin deps = vacio")

; --- Engine completo -> vacio ---
eComp := CaptureEngine(CrearAsignetHeaderV1())
eComp.Arm()
Loop 9
{
    inputs := ["ACC", "01/01/2026", "02/01/2026", "Corp", "1000", "-500", "500", "2500", "3000"]
    eComp.PushRaw(inputs[A_Index])
}
AssertEq(LineasOperandos(eComp), "", "LineasOperandos completo = vacio")

; --- Slot 7 con dep omitida (queue[5] = "") muestra "(vacio)" ---
eOm := CaptureEngine(CrearAsignetHeaderV1())
eOm.Arm()
eOm.PushRaw("ACC")           ; 1
eOm.PushRaw("01/01/2026")    ; 2
eOm.PushRaw("02/01/2026")    ; 3
eOm.PushRaw("Corp")          ; 4
eOm.SkipCurrent()            ; 5 -> ""
eOm.PushRaw("$300")          ; 6 -> "-300"
opsOm := LineasOperandos(eOm)
AssertContains(opsOm, "Previous balance: (vacio)", "LineasOperandos dep omitida muestra (vacio)")
AssertContains(opsOm, "Past Total Payments: -300", "LineasOperandos dep llena ok")

; ====================================================================
; LineaInputInvalido - hint generico parametrizable por hotkey
; ====================================================================
AssertEq(LineaInputInvalido("^+a"), "Input invalido, recopia o ^+a para omitir", "LineaInputInvalido formato default")
AssertEq(LineaInputInvalido("F8"), "Input invalido, recopia o F8 para omitir", "LineaInputInvalido hotkey custom")

; ====================================================================
; TooltipConError - mantiene prompt + previo + agrega lineas de error
; ====================================================================
eErr := CaptureEngine(CrearAsignetHeaderV1())
eErr.Arm()
eErr.PushRaw("ACC-99999")  ; slot 1 OK; ahora en slot 2 (sin ops)

; --- Caso validacion fallo: detalle + generica ---
detalle := TooltipError("Invoice date", "fecha debe ser MM/DD/YYYY")
tErr := TooltipConError(eErr, detalle, "^+a")
AssertContains(tErr, 'Busca "Invoice date" (1/9)', "ConError mantiene prompt (FilledCount=1)")
AssertContains(tErr, NEGRITA_OPEN "ACC-99999" NEGRITA_CLOSE " (Account number)", "ConError mantiene previo formato C")
AssertContains(tErr, "Invoice date invalido: fecha debe ser MM/DD/YYYY", "ConError detalle especifico")
AssertContains(tErr, "Input invalido, recopia o ^+a para omitir", "ConError linea generica")

; --- Caso rechazo (cleaner devolvio "") - detalle vacio: NO se agrega linea de detalle ---
tRej := TooltipConError(eErr, "", "^+a")
AssertContains(tRej, 'Busca "Invoice date" (1/9)', "ConError(rechazo) mantiene prompt")
AssertContains(tRej, "(Account number)", "ConError(rechazo) mantiene previo formato C")
AssertContains(tRej, "Input invalido, recopia o ^+a para omitir", "ConError(rechazo) linea generica")
AssertEq(InStr(tRej, "invalido:") > 0 && InStr(tRej, "invalido:") = InStr(tRej, "Input invalido"), false, "ConError(rechazo) NO tiene linea ': mensaje'")
tCustom := TooltipConError(eErr, "", "F8")
AssertContains(tCustom, "Input invalido, recopia o F8 para omitir", "ConError hotkey custom")

; --- Slot con expectedDeps: prompt + ops + detalle + generica ---
eOp := CaptureEngine(CrearAsignetHeaderV1())
eOp.Arm()
inputs := ["ACC", "01/01/2026", "02/01/2026", "Corp", "$1000", "$500"]
Loop 6
    eOp.PushRaw(inputs[A_Index])
; ahora en slot 7 (Past due con ops [5, 6])
detOp := TooltipError("Past due", "suma debe ser 500.00")
tErrOp := TooltipConError(eOp, detOp, "^+a")
AssertContains(tErrOp, 'Busca "Past due" (6/9) - esperado: 500.00', "ConError op-slot prompt (FilledCount=6)")
AssertContains(tErrOp, "Previous balance: 1000", "ConError op-slot operando 1")
AssertContains(tErrOp, "Past Total Payments: -500", "ConError op-slot operando 2")
AssertContains(tErrOp, "Past due invalido: suma debe ser 500.00", "ConError op-slot detalle")
AssertContains(tErrOp, "Input invalido, recopia o ^+a para omitir", "ConError op-slot generica")

; ====================================================================
; TooltipError - usa nombre, NO numero de slot
; ====================================================================
AssertEq(TooltipError("Past due", "suma debe ser 500.00"),
         "Past due invalido: suma debe ser 500.00",
         "TError nombre + mensaje")
AssertEq(TooltipError("Invoice date", "fecha debe ser MM/DD/YYYY"),
         "Invoice date invalido: fecha debe ser MM/DD/YYYY",
         "TError fecha")
AssertEq(TooltipError("Previous balance", "no es un numero valido"),
         "Previous balance invalido: no es un numero valido",
         "TError numero")

; TooltipPostAccion con actionLog vacio + accion: no crashea, devuelve solo prompt
eEmpty := CaptureEngine(CrearAsignetHeaderV1())
eEmpty.Arm()
tEmptyAcc := TooltipPostAccion(eEmpty, "manual")
AssertEq(tEmptyAcc, 'Busca "Account number" (0/9)', "Accion sin actionLog: solo prompt")

; LineaPrompt cola llena: hints ^+s y ^+e SIEMPRE presentes (no dependen del estado)
eFin := CaptureEngine(CrearAsignetHeaderV1())
eFin.Arm()
inputsFin := ["ACC", "01/01/2026", "02/01/2026", "Corp", "1000", "-500", "500", "2500", "3000"]
Loop 9
    eFin.PushRaw(inputsFin[A_Index])

pFin := LineaPrompt(eFin)
AssertContains(pFin, "Listo 9/9", "Listo: x/n con FilledCount")
AssertContains(pFin, "cola llena", "Listo: lema cola llena")
AssertContains(pFin, "^+s para pegar", "Listo: hint paste")
AssertContains(pFin, "^+e para revisar", "Listo: hint review SIEMPRE presente")

; --- Skip x9 sin autocalc: no cuenta como cola llena (slots siguen vacios) ---
eOmCompl := CaptureEngine(CrearAsignetHeaderV1(), false)
eOmCompl.Arm()
Loop 9
    eOmCompl.SkipCurrent()
AssertEq(eOmCompl.FilledCount, 0, "Skip x9 sin autocalc: FilledCount=0")
AssertEq(eOmCompl.IsComplete, false, "Skip todo sin autocalc: NO IsComplete (hay vacios)")

; ====================================================================
; LineaPrevio - usa actionLog (no queue.Length), formato C
; ====================================================================
eLP := CaptureEngine(CrearAsignetHeaderV1())
eLP.Arm()
eLP.PushRaw("ACC-1234")
prevDirecto := LineaPrevio(eLP)
AssertContains(prevDirecto, NEGRITA_OPEN "ACC-1234" NEGRITA_CLOSE, "LineaPrevio formato C: valor con flechas")
AssertContains(prevDirecto, "(Account number)", "LineaPrevio formato C: nombre entre parentesis")
AssertEq(InStr(prevDirecto, "Account number:"), 0, "LineaPrevio formato C: NO usa 'Nombre: valor'")

; --- Tras Jump+Push, previo refleja el slot que se acaba de pushear ---
eLP.PushRaw("01/01/2026")  ; slot 2
eLP.PushRaw("02/01/2026")  ; slot 3
eLP.JumpTo(1)
eLP.PushRaw("ACC-9999")    ; reemplaza slot 1
prevTrasJump := LineaPrevio(eLP)
AssertContains(prevTrasJump, NEGRITA_OPEN "ACC-9999" NEGRITA_CLOSE, "Previo tras Jump+Push: valor nuevo")
AssertContains(prevTrasJump, "(Account number)", "Previo tras Jump+Push: nombre del slot reemplazado")

; --- Previo con accion (omitido) ---
eOm2 := CaptureEngine(CrearAsignetHeaderV1())
eOm2.Arm()
eOm2.PushRaw("ACC")
eOm2.SkipCurrent()  ; slot 2 -> "", actionLog crece
prevOm := LineaPrevio(eOm2, "omitido")
AssertContains(prevOm, "omitido: " NEGRITA_OPEN "(vacio)" NEGRITA_CLOSE " (Invoice date)", "Previo omitido formato C")

ReportarYSalir()
