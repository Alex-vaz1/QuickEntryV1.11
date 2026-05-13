#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\Validators.ahk"
#Include "..\Lib\Schema.ahk"
#Include "_AssertHelpers.ahk"

; ====================================================================
; Campo - constructor + defaults
; ====================================================================
c := Campo("Mi campo", (r) => r, (v, q) => "")
AssertEq(c.name, "Mi campo", "Campo name set")
AssertEq(c.tabsAfter, 1, "Campo default tabsAfter = 1")
AssertEq(c.skipPaste, false, "Campo default skipPaste = false")
AssertEq(c.expectedFn, "", "Campo default expectedFn = empty")

; --- tabsAfter y skipPaste override: verifica que ctor posiciones 4-5 pisan defaults ---
c2 := Campo("X", (r) => r, (v, q) => "", 2, true)
AssertEq(c2.tabsAfter, 2, "Campo tabsAfter custom")
AssertEq(c2.skipPaste, true, "Campo skipPaste true")
AssertEq(c2.name, "X", "Campo name X")

; --- callbacks reales (no stubs): firma (val,cola)=>String validada en integración ---
cTrim := Campo("Trim", Trim, ValidarNoVacio)
AssertEq(cTrim.clean.Call("  hola  "), "hola", "Campo invoca clean (Trim)")
AssertEq(cTrim.validate.Call("X", []), "", "Campo invoca validate ok")
AssertContains(cTrim.validate.Call("", []), "vacio", "Campo invoca validate fail")

; --- Campo con expectedFn ---
sumarFn := (cola) => (cola.Length >= 2) ? Format("{:.2f}", Number(cola[1]) + Number(cola[2])) : ""
cExp := Campo("Suma", (r) => r, ValidarNumero, 1, false, sumarFn)
AssertEq(cExp.expectedFn.Call(["10", "20"]), "30.00", "Campo expectedFn calcula")
AssertEq(cExp.expectedFn.Call(["10"]), "", "Campo expectedFn vacio si cola corta")

; --- expectedDeps default: ctor debe normalizar ausencia a array vacio, no nil ---
AssertEq(IsObject(c.expectedDeps), true, "Campo default expectedDeps es objeto")
AssertEq(c.expectedDeps.Length, 0, "Campo default expectedDeps vacio")
AssertEq(cExp.expectedDeps.Length, 0, "Campo sin deps explicitos: vacio")

; --- expectedDeps explicit: verifica que [1,2] no se aplana ni se descarta ---
cDeps := Campo("Suma", (r) => r, ValidarNumero, 1, false, sumarFn, [1, 2])
AssertEq(cDeps.expectedDeps.Length, 2, "Campo con expectedDeps Length 2")
AssertEq(cDeps.expectedDeps[1], 1, "Campo expectedDeps[1] = 1")
AssertEq(cDeps.expectedDeps[2], 2, "Campo expectedDeps[2] = 2")

; ====================================================================
; InvoiceSchema
; ====================================================================
s := InvoiceSchema("test", [c, c2])
AssertEq(s.name, "test", "Schema name")
AssertEq(s.Length, 2, "Schema length 2")
AssertEq(s.Field(1).name, "Mi campo", "Schema Field(1)")
AssertEq(s.Field(2).name, "X", "Schema Field(2)")
AssertEq(s.Field(2).tabsAfter, 2, "Schema Field(2).tabsAfter custom")

; --- schema sin campos: Length no puede ser undefined ni 1 por off-by-one ---
sEmpty := InvoiceSchema("vacio", [])
AssertEq(sEmpty.Length, 0, "Schema vacio Length=0")

; --- prePasteSteps default: igual que expectedDeps, debe ser array vacio, no nil ---
AssertEq(IsObject(s.prePasteSteps), true, "Schema prePasteSteps es objeto")
AssertEq(s.prePasteSteps.Length, 0, "Schema sin prePasteSteps explicitos: vacio")

; --- prePasteSteps custom: [1] en ordenPegado es placeholder, no sujeto del test ---
sPre := InvoiceSchema("conPre", [c], [1], ["{Tab 5}", "Invoice", "{Tab}"])
AssertEq(sPre.prePasteSteps.Length, 3, "Schema con prePasteSteps Length=3")
AssertEq(sPre.prePasteSteps[1], "{Tab 5}", "prePasteSteps[1]")
AssertEq(sPre.prePasteSteps[2], "Invoice", "prePasteSteps[2]")
AssertEq(sPre.prePasteSteps[3], "{Tab}", "prePasteSteps[3]")

; --- ordenPegado auto-generado: ctor crea [1..N] para no romper CaptureEngine ---
AssertEq(s.ordenPegado.Length, 2, "Schema sin ordenPegado: default [1..N]")
AssertEq(s.ordenPegado[1], 1, "ordenPegado default [1]")
AssertEq(s.ordenPegado[2], 2, "ordenPegado default [2]")

; --- Field fuera de rango: ValueError con texto "fuera de rango" para catch en UI ---
try
{
    s.Field(0)
    AssertEq("no-throw", "esperaba-throw", "Schema Field(0) throw")
}
catch ValueError as e
{
    AssertContains(e.Message, "fuera de rango", "Schema Field(0) error msg")
}

try
{
    s.Field(99)
    AssertEq("no-throw", "esperaba-throw", "Schema Field(99) throw")
}
catch ValueError as e
{
    AssertContains(e.Message, "fuera de rango", "Schema Field(99) error msg")
}

ReportarYSalir()
