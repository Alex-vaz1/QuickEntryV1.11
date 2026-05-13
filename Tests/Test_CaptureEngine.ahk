#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\CaptureEngine.ahk"
#Include "..\Lib\Validators.ahk"
#Include "..\Schemas\AsignetHeaderV1.ahk"
#Include "_AssertHelpers.ahk"

; ====================================================================
; Schemas inline — aíslan al engine de producción
; ====================================================================
CrearMock()
{
    return InvoiceSchema("mock", [
        Campo("A", (r) => r, ValidarNoVacio),
        Campo("B", (r) => r, ValidarNumero),
        Campo("Suma", (r) => r, ValidarSumaTol([1, 2]), 2, false,
              (cola) => (cola.Length >= 2 && cola[1] != "" && cola[2] != "")
                  ? Format("{:.2f}", Number(cola[1]) + Number(cola[2])) : "")
    ])
}

; ====================================================================
; State machine — estado inicial, Arm, Reset
; ====================================================================
e := CaptureEngine(CrearMock())
AssertEq(e.NextSlot, 1, "engine no armado: NextSlot=1 (cola vacia)")
AssertEq(e.isCapturing, false, "engine no armado: isCapturing=false")
AssertEq(e.IsComplete, false, "engine no armado: !IsComplete")
AssertEq(e.queue.Length, 3, "engine no armado: queue pre-alocada a schema.Length")
AssertEq(e.queue[1], "", "engine no armado: queue[1] = ''")
AssertEq(e.FilledCount, 0, "engine no armado: FilledCount=0")

e.Arm("CLIPBACKUP")
AssertEq(e.isCapturing, true, "Arm: isCapturing=true")
AssertEq(e.NextSlot, 1, "Arm: NextSlot=1")
AssertEq(e.clipBackup, "CLIPBACKUP", "Arm: clipBackup snapshot")
AssertEq(e.IsComplete, false, "Arm: !IsComplete")

; ====================================================================
; PushRaw / PushForce / ExpectedFor
; ====================================================================
r1 := e.PushRaw("100")
AssertEq(r1["ok"], true, "PushRaw 1 ok=true")
AssertEq(r1["value"], "100", "PushRaw 1 value")
AssertEq(r1["slot"], 1, "PushRaw 1 slot")
AssertEq(r1["label"], "A", "PushRaw 1 label")
AssertEq(r1["error"], "", "PushRaw 1 error vacio")
AssertEq(e.NextSlot, 2, "PushRaw 1: NextSlot=2")

; ValidarNumero rechaza "abc": NextSlot no avanza, FilledCount no muta
r2bad := e.PushRaw("abc")
AssertEq(r2bad["ok"], false, "PushRaw 2 abc rechazo")
AssertContains(r2bad["error"], "numero", "PushRaw 2 error num")
AssertEq(r2bad["label"], "B", "PushRaw 2 label B")
AssertEq(r2bad["slot"], 2, "PushRaw 2 slot=2")
AssertEq(r2bad["value"], "abc", "PushRaw 2 value preserva input limpio")
AssertEq(e.NextSlot, 2, "PushRaw rechazo no avanza")
AssertEq(e.FilledCount, 1, "PushRaw rechazo no muta cola")

e.PushRaw("50")
AssertEq(e.NextSlot, 3, "PushRaw 2 OK: NextSlot=3")

; ExpectedFor: solo devuelve valor cuando el campo tiene expectedFn
AssertEq(e.ExpectedFor(3), "150.00", "ExpectedFor 3 = 100+50")
AssertEq(e.ExpectedFor(1), "", "ExpectedFor 1 sin expectedFn = vacio")
AssertEq(e.ExpectedFor(2), "", "ExpectedFor 2 sin expectedFn = vacio")
AssertEq(e.ExpectedFor(99), "", "ExpectedFor fuera rango = vacio")
AssertEq(e.ExpectedFor(0), "", "ExpectedFor 0 = vacio")

; ValidarSumaTol rechaza si el ingresado no coincide con la expectedFn
r3bad := e.PushRaw("999")
AssertEq(r3bad["ok"], false, "PushRaw 3 suma mal: rechazo")
AssertContains(r3bad["error"], "suma", "PushRaw 3 error suma")
AssertContains(r3bad["error"], "150.00", "PushRaw 3 error incluye esperado")

; Cola completa: NextSlot=0, IsComplete=true
e.PushRaw("150")
AssertEq(e.IsComplete, true, "IsComplete tras pushear los 3")
AssertEq(e.NextSlot, 0, "NextSlot=0 cuando completo")
AssertEq(e.FilledCount, 3, "FilledCount=3 completo")

; PushRaw post-completo: rechaza sin mutar cola
rOver := e.PushRaw("X")
AssertEq(rOver["ok"], false, "PushRaw post-completo: ok=false")
AssertContains(rOver["error"], "cola completa", "PushRaw post-completo: error 'cola completa'")
AssertEq(rOver["slot"], 0, "PushRaw post-completo: slot=0")
AssertEq(e.FilledCount, 3, "PushRaw post-completo no muta cola")

; ====================================================================
; Undo / JumpTo / AutoAdvance
; ====================================================================
; Undo: pop del actionLog, restaura queue[slot] al prevValue
u := e.Undo()
AssertEq(u["ok"], true, "Undo ok")
AssertEq(u["slot"], 3, "Undo slot 3")
AssertEq(u["label"], "Suma", "Undo label Suma")
AssertEq(e.NextSlot, 3, "Undo: NextSlot=3 (targetSlot apunta al deshecho)")
AssertEq(e.IsComplete, false, "Undo: !IsComplete")
AssertEq(e.queue[3], "", "Undo restaura queue[3] al prevValue (vacio inicial)")

; --- Multi-undo ---
e.Undo()
e.Undo()
AssertEq(e.actionLog.Length, 0, "Undo x3 vacia actionLog")
AssertEq(e.NextSlot, 1, "Undo total: NextSlot=1 (targetSlot apunta al primero deshecho)")
AssertEq(e.FilledCount, 0, "Undo total: FilledCount=0")

; --- Undo en actionLog vacio ---
uVacio := e.Undo()
AssertEq(uVacio["ok"], false, "Undo actionLog vacio: ok=false")
AssertEq(uVacio["slot"], 0, "Undo actionLog vacio: slot=0")
AssertEq(uVacio["label"], "", "Undo actionLog vacio: label vacio")

; ====================================================================
; SkipCurrent / FilledCount / ClearSlot
; ====================================================================
; Sin autoCalc: queue[slot]="", NextSlot vuelve al mismo slot (sigue vacío,
; picker puede recuperarlo; cola no está completa)
e3 := CaptureEngine(CrearMock())
e3.Arm()
e3.PushRaw("100")
e3.PushRaw("50")
sk := e3.SkipCurrent()
AssertEq(sk["value"], "", "Skip slot 3 sin autoCalc: vacio")
AssertEq(sk["slot"], 3, "Skip slot 3")
AssertEq(sk["label"], "Suma", "Skip label Suma")
AssertEq(e3.queue[3], "", "Skip pushea vacio")
AssertEq(e3.IsComplete, false, "Skip sin autocalc: cola NO completa (slot sigue vacio)")
AssertEq(e3.NextSlot, 3, "Skip sin autocalc: NextSlot vuelve a slot 3 (sigue vacio)")

; Skip post-completo: slot=0
e3.PushRaw("150")
AssertEq(e3.IsComplete, true, "Tras push slot 3: IsComplete")
skOver := e3.SkipCurrent()
AssertEq(skOver["slot"], 0, "Skip post-completo: slot=0")

; Con autoCalc: usa expectedFn para calcular el valor del slot
e4 := CaptureEngine(CrearMock(), true)
e4.Arm()
e4.PushRaw("100")
e4.PushRaw("50")
sa := e4.SkipCurrent()
AssertEq(sa["value"], "150.00", "Skip autoCalc: valor calculado")
AssertEq(e4.queue[3], "150.00", "Skip autoCalc pushea calculado")

; autoCalc en slot sin expectedFn: pushea "" (no hay función que calcule)
e4b := CaptureEngine(CrearMock(), true)
e4b.Arm()
saSlot1 := e4b.SkipCurrent()
AssertEq(saSlot1["value"], "", "Skip autoCalc slot1 sin expectedFn: vacio")

; Reset: limpia todo el estado mutable del engine
e3.Reset()
AssertEq(e3.isCapturing, false, "Reset: isCapturing false")
AssertEq(e3.queue.Length, 3, "Reset: queue sigue pre-alocada")
AssertEq(e3.queue[1], "", "Reset: queue[1]=''")
AssertEq(e3.actionLog.Length, 0, "Reset: actionLog vacio")
AssertEq(e3.targetSlot, 0, "Reset: targetSlot=0")
AssertEq(e3.FilledCount, 0, "Reset: FilledCount=0")
AssertEq(e3.clipBackup, "", "Reset: clipBackup vacio")

; schema info expuesta al exterior del engine (tabsAfter, Length)
eInfo := CaptureEngine(CrearMock())
AssertEq(eInfo.schema.Field(3).tabsAfter, 2, "schema slot 3 tabsAfter=2")
AssertEq(eInfo.schema.Length, 3, "schema length 3")

; ====================================================================
; PasteBatch
; ====================================================================
; Todos los schemas de PasteBatch usan skipPaste=true para no mutar A_Clipboard.
; El path Tab-only es el único testeable sin side-effects reales.
schemaTabOnly := InvoiceSchema("tab-only", [
    Campo("A", (r) => r, (v, q) => "", 1, true),
    Campo("B", (r) => r, (v, q) => "", 2, true),
    Campo("C", (r) => r, (v, q) => "", 3, true)
])
eTab := CaptureEngine(schemaTabOnly)
eTab.Arm()
eTab.PushRaw("a")
eTab.PushRaw("b")
eTab.PushRaw("c")
sentTabs := []
eTab.PasteBatch((s) => sentTabs.Push(s), (ms) => "")
; Slot 1→1 Tab, slot 2→2 Tabs, slot 3 last→0 Tabs (no Tab final en último slot)
AssertEq(sentTabs.Length, 3, "PasteBatch sin Tab final: 1+2+0 = 3 Tabs totales")
AssertEq(sentTabs[1], "{Tab}", "PasteBatch slot 1 Tab")
AssertEq(sentTabs[2], "{Tab}", "PasteBatch slot 2 Tab 1/2")
AssertEq(sentTabs[3], "{Tab}", "PasteBatch slot 2 Tab 2/2")

; Slot único es siempre "last": tabsAfter se ignora, 0 Tabs emitidos
schemaUno := InvoiceSchema("uno", [Campo("X", (r) => r, (v, q) => "", 5, true)])
eUno := CaptureEngine(schemaUno)
eUno.Arm()
eUno.PushRaw("x")
sentUno := []
eUno.PasteBatch((s) => sentUno.Push(s), (ms) => "")
AssertEq(sentUno.Length, 0, "PasteBatch 1 slot last: 0 Tabs")

; prePasteSteps se emiten antes de cualquier slot
schemaPre := InvoiceSchema(
    "conPre",
    [Campo("X", (r) => r, (v, q) => "", 1, true)],   ; 1 slot skipPaste
    [1],                                              ; ordenPegado
    ["{Tab 5}", "{Enter}", "Invoice", "{Tab}"]        ; prePasteSteps
)
ePre := CaptureEngine(schemaPre)
ePre.Arm()
ePre.PushRaw("hello")
sentPre := []
ePre.PasteBatch((s) => sentPre.Push(s), (ms) => "")
; Slot único es last + skipPaste: aporta 0. Solo los 4 prePasteSteps aparecen.
AssertEq(sentPre.Length, 4, "PasteBatch envia los 4 prePasteSteps")
AssertEq(sentPre[1], "{Tab 5}", "prePasteSteps[1] sent")
AssertEq(sentPre[2], "{Enter}", "prePasteSteps[2] sent")
AssertEq(sentPre[3], "Invoice", "prePasteSteps[3] sent")
AssertEq(sentPre[4], "{Tab}", "prePasteSteps[4] sent")

; Orden: prePasteSteps primero, luego Tabs inter-slot
schemaPre2 := InvoiceSchema(
    "preMasSlots",
    [
        Campo("A", (r) => r, (v, q) => "", 1, true),
        Campo("B", (r) => r, (v, q) => "", 2, true)
    ],
    [1, 2],                          ; ordenPegado
    ["{Tab 3}", "Invoice"]           ; prePasteSteps
)
ePre2 := CaptureEngine(schemaPre2)
ePre2.Arm()
ePre2.PushRaw("a")
ePre2.PushRaw("b")
sentPre2 := []
ePre2.PasteBatch((s) => sentPre2.Push(s), (ms) => "")
; 2 pre + 1 Tab tras slot 1 (tabsAfter=1, no last) + 0 de slot 2 (last) = 3
AssertEq(sentPre2.Length, 3, "PasteBatch pre + 1 Tab inter-slot = 3")
AssertEq(sentPre2[1], "{Tab 3}", "Pre primero #1")
AssertEq(sentPre2[2], "Invoice", "Pre primero #2")
AssertEq(sentPre2[3], "{Tab}", "Slot 1 Tab tras prePasteSteps")

; Sin prePasteSteps (default): 0 sends (slot last skipPaste no aporta nada)
schemaSinPre := InvoiceSchema(
    "sinPre",
    [Campo("X", (r) => r, (v, q) => "", 1, true)]
)
eSinPre := CaptureEngine(schemaSinPre)
eSinPre.Arm()
eSinPre.PushRaw("z")
sentSinPre := []
eSinPre.PasteBatch((s) => sentSinPre.Push(s), (ms) => "")
AssertEq(sentSinPre.Length, 0, "Schema sin prePasteSteps: 0 sends (slot last skipPaste)")

; ====================================================================
; Scan / HeaderScan
; ====================================================================
; MockCapture es clase (no fat-arrow con ++var): en AHK v2, fat arrows con
; pre-increment sobre variables de script-level tienen scoping extraño al
; capturarse en closures. this.idx como propiedad de instancia evita el bug.
class MockCapture
{
    idx := 0
    values := []
    __New(values)
    {
        this.values := values
    }
    Read()
    {
        this.idx += 1
        return this.values[this.idx]
    }
}

; Schema Scan: 3 slots normales (skipPaste=false), prePasteSteps de 1 paso
schemaScan := InvoiceSchema("scan",
    [
        Campo("A", (r) => r, ValidarNoVacio, 1, false),
        Campo("B", (r) => r, ValidarNumero, 2, false),
        Campo("C", (r) => r, ValidarNoVacio, 3, false)
    ],
    [1, 2, 3],
    ["{Tab 5}"])  ; un solo paso pre

; Form simulado: slot 2 vacío → no entra en preloadedSlots, NextSlot apunta a él
mockSc := MockCapture(["alfa", "", "gamma"])
eSc := CaptureEngine(schemaScan)
sentSc := []
eSc.Scan(mockSc.Read.Bind(mockSc), (s) => sentSc.Push(s), (ms) => "")

AssertEq(eSc.queue[1], "alfa", "Scan slot 1 lleno con valor del form")
AssertEq(eSc.queue[2], "", "Scan slot 2 form vacio queda ''")
AssertEq(eSc.queue[3], "gamma", "Scan slot 3 lleno")
AssertEq(eSc.preloadedSlots.Has(1), true, "Slot 1 marcado preloaded")
AssertEq(eSc.preloadedSlots.Has(2), false, "Slot 2 NO preloaded (estaba vacio)")
AssertEq(eSc.preloadedSlots.Has(3), true, "Slot 3 marcado preloaded")
AssertEq(eSc.PreloadedCount, 2, "PreloadedCount = 2")
AssertEq(eSc.FilledCount, 2, "FilledCount = 2 (preloaded cuentan)")
AssertEq(eSc.isCapturing, true, "Scan setea isCapturing=true")
AssertEq(eSc.clipBackup, "", "Scan guarda clipBackup snapshot (default '')")
AssertEq(eSc.NextSlot, 2, "Tras Scan: NextSlot = primer vacio (slot 2)")

; Secuencia sendFn: prePasteSteps + Tabs inter-slot (skipPaste=false no agrega paste).
; "{Tab 5}" + Tab(slot1,tabsAfter=1) + Tab Tab(slot2,tabsAfter=2) = 4. Slot 3 last→0.
AssertEq(sentSc.Length, 4, "Scan envia prePasteSteps + Tabs inter-slot")
AssertEq(sentSc[1], "{Tab 5}", "Scan paso 1: prePasteSteps")
AssertEq(sentSc[2], "{Tab}", "Scan slot 1 -> 2: 1 Tab")
AssertEq(sentSc[3], "{Tab}", "Scan slot 2 -> 3: 2 Tabs (1/2)")
AssertEq(sentSc[4], "{Tab}", "Scan slot 2 -> 3: 2 Tabs (2/2)")

; Scan no llama captureFieldFn en slots skipPaste=true (no los preloada)
schemaSkipScan := InvoiceSchema("skipscan",
    [
        Campo("A", (r) => r, ValidarNoVacio, 1, true),    ; lupa, no se lee
        Campo("B", (r) => r, ValidarNoVacio, 1, false)
    ],
    [1, 2])

captureSkipMock := () => "valor"

eSk := CaptureEngine(schemaSkipScan)
eSk.Scan(captureSkipMock, (s) => "", (ms) => "")
AssertEq(eSk.queue[1], "", "Scan: skipPaste slot queda '' (no se lee)")
AssertEq(eSk.queue[2], "valor", "Scan: slot normal lee valor")
AssertEq(eSk.preloadedSlots.Has(1), false, "Scan: skipPaste slot NO preloaded")
AssertEq(eSk.preloadedSlots.Has(2), true, "Scan: slot normal preloaded")

; Push sobre slot preloaded: reemplaza valor y lo quita de preloadedSlots
mockOv := MockCapture(["X", "Y", "Z"])
eOv := CaptureEngine(schemaScan)
eOv.Scan(mockOv.Read.Bind(mockOv), (s) => "", (ms) => "")
AssertEq(eOv.preloadedSlots.Count, 3, "Pre-override: 3 preloaded")
AssertEq(eOv.NextSlot, 0, "Pre-override: cola llena (no vacios)")

; Slot 2 valida ValidarNumero, necesitamos número para que pase
eOv.JumpTo(2)
eOv.PushRaw("999")
AssertEq(eOv.queue[2], "999", "Push tras Jump reemplaza queue[2]")
AssertEq(eOv.preloadedSlots.Has(2), false, "Push sobre preloaded: lo quita del map")
AssertEq(eOv.preloadedSlots.Has(1), true, "Otros preloaded sin tocar")
AssertEq(eOv.preloadedSlots.Count, 2, "PreloadedCount baja a 2")

; Skip sobre slot preloaded también limpia preloadedSlots (mismo contrato que Push)
mockSkPre := MockCapture(["a", "b", "c"])
eSkPre := CaptureEngine(schemaScan)
eSkPre.Scan(mockSkPre.Read.Bind(mockSkPre), (s) => "", (ms) => "")
eSkPre.JumpTo(1)
eSkPre.SkipCurrent()
AssertEq(eSkPre.queue[1], "", "Skip sobre preloaded: queue[1] vuelve a ''")
AssertEq(eSkPre.preloadedSlots.Has(1), false, "Skip sobre preloaded: lo quita del map")

; PasteBatch: slots preloaded no reciben ^v, solo Tabs (el form ya tiene el valor)
schemaPasteScan := InvoiceSchema("pasteScan",
    [
        Campo("A", (r) => r, ValidarNoVacio, 1, false),
        Campo("B", (r) => r, ValidarNoVacio, 2, false),
        Campo("C", (r) => r, ValidarNoVacio, 3, false)
    ],
    [1, 2, 3])

mockPB := MockCapture(["preloadedA", "preloadedB", ""])  ; slot 3 vacio
ePB := CaptureEngine(schemaPasteScan)
ePB.Scan(mockPB.Read.Bind(mockPB), (s) => "", (ms) => "")
ePB.PushRaw("manualC")  ; llena el unico vacio (slot 3)
AssertEq(ePB.queue[3], "manualC", "Push slot 3 manual")
AssertEq(ePB.preloadedSlots.Count, 2, "Tras push manual: 2 preloaded (1, 2)")

sentPB := []
ePB.PasteBatch((s) => sentPB.Push(s), (ms) => "")

; Slots 1,2 preloaded→solo Tabs. Slot 3 manual→reset modificadores + ^v. Slot 3 last→0 Tabs.
; Total: Tab(slot1) + Tab Tab(slot2) + reset + ^v = 5
AssertEq(sentPB.Length, 5, "PasteBatch skip preloaded: 1+2 Tabs + reset + ^v slot 3")
AssertEq(sentPB[1], "{Tab}", "Slot 1 (preloaded): solo Tab")
AssertEq(sentPB[2], "{Tab}", "Slot 2 (preloaded): Tab 1/2")
AssertEq(sentPB[3], "{Tab}", "Slot 2 (preloaded): Tab 2/2")
AssertEq(sentPB[4], "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}", "Slot 3: reset modificadores")
AssertEq(sentPB[5], "^v", "Slot 3 (no preloaded): paste")

; Reset limpia preloadedSlots
mockRP := MockCapture(["x", "y", "z"])
eRP := CaptureEngine(schemaScan)
eRP.Scan(mockRP.Read.Bind(mockRP), (s) => "", (ms) => "")
AssertEq(eRP.preloadedSlots.Count, 3, "Pre-Reset: 3 preloaded")
eRP.Reset()
AssertEq(eRP.preloadedSlots.Count, 0, "Reset: preloadedSlots limpio")
AssertEq(eRP.PreloadedCount, 0, "Reset: PreloadedCount=0")

; REGRESION: PasteBatch nunca dispara ^v en slots vacíos
schemaEmpty := InvoiceSchema("emptyPaste",
    [
        Campo("A", (r) => r, ValidarNoVacio, 1, false),
        Campo("B", (r) => r, ValidarNoVacio, 1, false),
        Campo("C", (r) => r, ValidarNoVacio, 1, false)
    ],
    [1, 2, 3])

eEmp := CaptureEngine(schemaEmpty)
eEmp.Arm()
; Solo slot 2 lleno; slots 1 y 3 quedan ""
eEmp.JumpTo(2)
eEmp.PushRaw("solo-2")

sentEmp := []
eEmp.PasteBatch((s) => sentEmp.Push(s), (ms) => "")

; Exactamente 1 ^v (solo para slot 2 lleno)
vCount := 0
for s in sentEmp
    if (s = "^v")
        vCount++
AssertEq(vCount, 1, "PasteBatch slots vacios: solo 1 ^v (slot 2 lleno), nunca para 1 ni 3")

; Misma garantía tras 3 Skips sin autocalc: cola toda "" → 0 ^v
eEmp2 := CaptureEngine(schemaEmpty)
eEmp2.Arm()
eEmp2.SkipCurrent()  ; slot 1 → ""; AutoAdvance vuelve a slot 1 (todos vacíos)
eEmp2.JumpTo(2)
eEmp2.SkipCurrent()
eEmp2.JumpTo(3)
eEmp2.SkipCurrent()
sentEmp2 := []
eEmp2.PasteBatch((s) => sentEmp2.Push(s), (ms) => "")
vCount2 := 0
for s in sentEmp2
    if (s = "^v")
        vCount2++
AssertEq(vCount2, 0, "PasteBatch tras 3 skips sin autocalc: 0 ^v")

; REGRESION: Scan y PasteBatch deben emitir idéntica secuencia de navegación
; (mismo schema → mismo camino de Tabs/prePasteSteps)
schemaCompare := InvoiceSchema("compare",
    [
        Campo("A", (r) => r, ValidarNoVacio, 3, false),
        Campo("B", (r) => r, ValidarNoVacio, 5, false),
        Campo("C", (r) => r, ValidarNoVacio, 1, false)
    ],
    [1, 2, 3],
    ["{Tab 7}", "{Enter}"])


mockC := MockCapture(["a", "b", "c"])
eC1 := CaptureEngine(schemaCompare)
sentScan := []
eC1.Scan(mockC.Read.Bind(mockC), (s) => sentScan.Push(s), (ms) => "")

eC2 := CaptureEngine(schemaCompare)
eC2.Arm()
eC2.PushRaw("a")
eC2.PushRaw("b")
eC2.PushRaw("c")
sentPaste := []
eC2.PasteBatch((s) => sentPaste.Push(s), (ms) => "")

; Solo Tabs y prePasteSteps (descartamos ^v y reset, que solo aparecen en PasteBatch)
filtrarNav(arr) {
    out := []
    for s in arr
        if (s = "{Tab}" || s = "{Tab 7}" || s = "{Enter}")
            out.Push(s)
    return out
}
navScan := filtrarNav(sentScan)
navPaste := filtrarNav(sentPaste)
AssertEq(navScan.Length, navPaste.Length, "Scan y PasteBatch: misma cantidad de pasos de navegacion")
Loop navScan.Length
{
    AssertEq(navScan[A_Index], navPaste[A_Index],
             "Nav step " A_Index ": Scan='" navScan[A_Index] "' vs Paste='" navPaste[A_Index] "'")
}

; -- Integración con AsignetHeaderV1 --
ea := CaptureEngine(CrearAsignetHeaderV1())
ea.Arm()
AssertEq(ea.schema.Length, 9, "Asignet engine tiene 9 slots")
AssertEq(ea.NextSlot, 1, "Asignet engine NextSlot=1")
ea.PushRaw("ACC-1")
ea.PushRaw("Sep 15, 2026")
AssertEq(ea.queue[2], "09/15/2026", "Asignet engine slot 2 limpia fecha")
AssertEq(ea.NextSlot, 3, "Asignet engine NextSlot=3 tras 2 pushes")

; ExpectedFor(7) con cola parcial: 1000 + (-500) = 500.00
ea.PushRaw("Oct 15, 2026")    ; slot 3
ea.PushRaw("Logitech")         ; slot 4
ea.PushRaw("$1,000")           ; slot 5 → "1000"
ea.PushRaw("$500")             ; slot 6 forzado neg → "-500"
AssertEq(ea.ExpectedFor(7), "500.00", "Asignet ExpectedFor 7 = 1000+(-500)=500.00")

; PushManual es alias de PushRaw (mismo resultado)
ea2 := CaptureEngine(CrearAsignetHeaderV1())
ea2.Arm()
rm := ea2.PushManual("ACC-MANUAL")
AssertEq(rm["ok"], true, "PushManual ok")
AssertEq(ea2.queue[1], "ACC-MANUAL", "PushManual pushea valor limpio")

; FilledCount: cuenta slots donde queue[i] != ""
eFC := CaptureEngine(CrearMock())
AssertEq(eFC.FilledCount, 0, "FilledCount engine virgen = 0")
eFC.Arm()
AssertEq(eFC.FilledCount, 0, "FilledCount tras Arm = 0")
eFC.PushRaw("100")
AssertEq(eFC.FilledCount, 1, "FilledCount tras 1 push = 1")
eFC.SkipCurrent()  ; slot 2 sin autocalc → "" (no suma a FilledCount)
AssertEq(eFC.FilledCount, 1, "FilledCount Skip(no autocalc) NO suma")
eFC.PushRaw("999")  ; slot 3: ValidarSumaTol skipea si dep[2]="" (pasa igual)
AssertEq(eFC.FilledCount, 2, "FilledCount tras push slot 3 = 2 (skipeado no cuenta)")

; Con autocalc: Skip calcula el valor → no vacío → FilledCount lo cuenta
eFCa := CaptureEngine(CrearMock(), true)
eFCa.Arm()
eFCa.PushRaw("100")
eFCa.PushRaw("50")
eFCa.SkipCurrent()  ; slot 3 autocalc -> "150.00"
AssertEq(eFCa.FilledCount, 3, "FilledCount autocalc cuenta slot calculado")

; JumpTo: setea targetSlot, no muta queue ni actionLog
eJ := CaptureEngine(CrearMock())
eJ.Arm()
eJ.PushRaw("100")
AssertEq(eJ.NextSlot, 2, "Pre-jump NextSlot=2")
j := eJ.JumpTo(1)
AssertEq(j["slot"], 1, "JumpTo retorna slot")
AssertEq(j["label"], "A", "JumpTo retorna label")
AssertEq(eJ.targetSlot, 1, "JumpTo setea targetSlot")
AssertEq(eJ.NextSlot, 1, "JumpTo cambia NextSlot al target")
AssertEq(eJ.queue[1], "100", "JumpTo NO muta queue")
AssertEq(eJ.actionLog.Length, 1, "JumpTo NO toca actionLog")

; --- JumpTo fuera de rango lanza ValueError ---
threwLow := false
try eJ.JumpTo(0)
catch ValueError
    threwLow := true
AssertEq(threwLow, true, "JumpTo(0) throw ValueError")

threwHigh := false
try eJ.JumpTo(99)
catch ValueError
    threwHigh := true
AssertEq(threwHigh, true, "JumpTo(N+1) throw ValueError")

; Push tras JumpTo: reemplaza queue[slot], registra prevValue en actionLog, AutoAdvance
eJP := CaptureEngine(CrearMock())
eJP.Arm()
eJP.PushRaw("100")
eJP.PushRaw("50")
eJP.JumpTo(1)
rOver2 := eJP.PushRaw("999")
AssertEq(rOver2["ok"], true, "Push tras Jump ok")
AssertEq(rOver2["slot"], 1, "Push tras Jump usa slot del jump")
AssertEq(eJP.queue[1], "999", "Push tras Jump reemplaza queue[1]")
AssertEq(eJP.targetSlot, 3, "Push tras Jump auto-advance a proximo vacio (slot 3)")
AssertEq(eJP.actionLog.Length, 3, "actionLog crece con push tras jump")
ultAccion := eJP.actionLog[3]
AssertEq(ultAccion["slot"], 1, "ultima accion: slot=1")
AssertEq(ultAccion["prevValue"], "100", "ultima accion: prevValue del slot 1 = 100")

; AutoAdvance cíclico: busca adelante (slot+1..end) y si no, atrás (1..slot-1)
eAA := CaptureEngine(CrearMock())
eAA.Arm()
eAA.PushRaw("100")
eAA.SkipCurrent()      ; slot 2 → ""
eAA.PushRaw("50")      ; slot 3 (ValidarSumaTol skip si dep[2]="")
; Cola ["100","","50"]: AutoAdvance encuentra slot 2 vacío → NextSlot=2
AssertEq(eAA.NextSlot, 2, "Tras push 3 con slot 2 vacio: NextSlot=2 (cycle back)")

; Push en slot 2: AutoAdvance no encuentra más vacíos → targetSlot=0, IsComplete
eAA.PushRaw("60")
AssertEq(eAA.queue[2], "60", "queue[2] llenado")
AssertEq(eAA.targetSlot, 0, "AutoAdvance no encuentra vacio -> targetSlot=0")
AssertEq(eAA.IsComplete, true, "IsComplete tras llenar todo")
AssertEq(eAA.FilledCount, 3, "FilledCount=3")

; Undo restaura prevValue y setea targetSlot al slot deshecho
eU := CaptureEngine(CrearMock())
eU.Arm()
eU.PushRaw("100")
eU.PushRaw("50")
eU.JumpTo(1)
eU.PushRaw("777")  ; sobreescribe slot 1 (prevValue="100")
u1 := eU.Undo()
AssertEq(u1["slot"], 1, "Undo retorna slot")
AssertEq(eU.queue[1], "100", "Undo restaura queue[1] al prevValue (100)")
AssertEq(eU.targetSlot, 1, "Undo setea targetSlot al deshecho")
AssertEq(eU.NextSlot, 1, "NextSlot = slot deshecho")
AssertEq(eU.actionLog.Length, 2, "actionLog -1")

; Reset limpia todo (actionLog, targetSlot, clipBackup)
eR := CaptureEngine(CrearMock())
eR.Arm("backup")
eR.PushRaw("100")
eR.JumpTo(2)
eR.Reset()
AssertEq(eR.isCapturing, false, "Reset: isCapturing=false")
AssertEq(eR.actionLog.Length, 0, "Reset: actionLog vacio")
AssertEq(eR.targetSlot, 0, "Reset: targetSlot=0")
AssertEq(eR.FilledCount, 0, "Reset: FilledCount=0")
AssertEq(eR.queue.Length, 3, "Reset: queue sigue pre-alocada a schema.Length")
AssertEq(eR.queue[1], "", "Reset: queue[1] = ''")
AssertEq(eR.clipBackup, "", "Reset: clipBackup vacio")

; PushForce: bypassa validate, no bypassa clean
ePF := CaptureEngine(CrearMock())
ePF.Arm()
ePF.PushRaw("100")
ePF.PushRaw("50")
; Slot 3 requeriría ValidarSumaTol=150; PushForce bypassa esa validación
rPF := ePF.PushForce("999")
AssertEq(rPF["ok"], true, "PushForce bypassa validate")
AssertEq(rPF["value"], "999", "PushForce value es el limpio")
AssertEq(rPF["slot"], 3, "PushForce slot=3")
AssertEq(ePF.queue[3], "999", "PushForce escribe queue[slot]")
AssertEq(ePF.IsComplete, true, "PushForce completa la cola")
AssertEq(ePF.actionLog.Length, 3, "PushForce registra en actionLog")

; Undo tras PushForce restaura prevValue vacío
uPF := ePF.Undo()
AssertEq(uPF["ok"], true, "Undo tras PushForce ok")
AssertEq(ePF.queue[3], "", "Undo restaura queue[3]='' (prevValue)")

; PushForce aún rechaza si clean("") devuelve "":
; slot 1 usa CleanPasoPegado (LimpiarComoPegadoEspecial), que rechaza vacío
ePF2 := CaptureEngine(CrearAsignetHeaderV1())
ePF2.Arm()
rPF2 := ePF2.PushForce("")
AssertEq(rPF2["ok"], false, "PushForce con clean='' rechaza")
AssertContains(rPF2["error"], "no se reconocio", "PushForce mensaje rechazo")

; PushForce sobre slot preloaded limpia preloadedSlots[slot]
ePF3 := CaptureEngine(CrearAsignetHeaderV1())
ePF3.Arm()
ePF3.preloadedSlots[1] := true
ePF3.queue[1] := "OLD"
ePF3.targetSlot := 1
rPF3 := ePF3.PushForce("NEW-VAL")
AssertEq(ePF3.queue[1], "NEW-VAL", "PushForce sobre preloaded actualiza queue")
AssertEq(ePF3.preloadedSlots.Has(1), false, "PushForce sobre preloaded limpia el flag")

; ====================================================================
; Abort
; ====================================================================
; tabsAfter=5 en cada slot: sin abort se emitirían 5+5+0=10 Tabs, con abort < 10.
; abortCtl usa Map (no fat-arrow con ++) para evitar el bug de scoping de AHK v2.
schemaAbort := InvoiceSchema("abort",
    [
        Campo("A", (r) => r, (v, q) => "", 5, true),
        Campo("B", (r) => r, (v, q) => "", 5, true),
        Campo("C", (r) => r, (v, q) => "", 5, true)
    ],
    [1, 2, 3])
eAb := CaptureEngine(schemaAbort)
eAb.Arm()
eAb.PushRaw("a")
eAb.PushRaw("b")
eAb.PushRaw("c")
sentAb := []
abortCtl := Map("eng", eAb, "sent", sentAb, "n", 0)
SendAbortFn(s) {
    global abortCtl
    abortCtl["sent"].Push(s)
    abortCtl["n"]++
    if (abortCtl["n"] = 2)
        abortCtl["eng"].Abort()
}
eAb.PasteBatch(SendAbortFn, (ms) => "")
; Assert con < 10 (no posición exacta): el punto de corte depende del scheduler;
; la condición laxa es suficientemente estricta y determinista.
AssertEq(sentAb.Length < 10, true,
         "PasteBatch corta tras abort - " sentAb.Length " sends < 10")
AssertEq(eAb.abortFlag, true, "PasteBatch dejo abortFlag en true")

; Reset limpia abortFlag (próxima Paste/Scan corre normal)
eAb.Reset()
AssertEq(eAb.abortFlag, false, "Reset() limpia abortFlag")

; Arm también limpia abortFlag (permite reusar engine sin Reset previo)
eAb2 := CaptureEngine(schemaAbort)
eAb2.abortFlag := true  ; simula estado residual de abort anterior
eAb2.Arm()
AssertEq(eAb2.abortFlag, false, "Arm() limpia abortFlag")

; Scan corta mid-loop: MockReadFn dispara Abort en la primera lectura;
; el segundo slot no debe leerse (scanCtl["n"]=1)
schemaAbScan := InvoiceSchema("abscan",
    [
        Campo("A", (r) => r, (v, q) => "", 1, false),
        Campo("B", (r) => r, (v, q) => "", 1, false)
    ],
    [1, 2])
eScAb := CaptureEngine(schemaAbScan)
scanCtl := Map("eng", eScAb, "n", 0)
MockReadFn() {
    global scanCtl
    scanCtl["n"]++
    if (scanCtl["n"] = 1)
        scanCtl["eng"].Abort()
    return "value"
}
sentSc := []
eScAb.Scan(MockReadFn, (s) => sentSc.Push(s), (ms) => "")
AssertEq(eScAb.abortFlag, true, "Scan respeta abortFlag")
AssertEq(scanCtl["n"], 1, "Scan corta tras abort - solo se leyo 1 slot")

; -- SetExtraTabsAfter / extraTabsAfterSlot --
schemaET := InvoiceSchema("extra-tabs",
    [
        Campo("A", (r) => r, (v, q) => "", 1, true),  ; skipPaste para no mutar clipboard
        Campo("B", (r) => r, (v, q) => "", 1, true),
        Campo("C", (r) => r, (v, q) => "", 1, true)
    ],
    [1, 2, 3])

; Baseline: sin extra tabs → 2 Tabs (tabsAfter=1 en slots 1 y 2; slot 3 last → 0)
eET := CaptureEngine(schemaET)
eET.Arm()
eET.PushRaw("a")
eET.PushRaw("b")
eET.PushRaw("c")
sentET := []
eET.PasteBatch((s) => sentET.Push(s), (ms) => "")
AssertEq(sentET.Length, 2, "Sin extra tabs: 2 Tabs (slot 1->2, slot 2->3)")

; SetExtraTabsAfter(1,1): 1 Tab extra tras slot 1 → total 3 Tabs
eET2 := CaptureEngine(schemaET)
eET2.Arm()
eET2.SetExtraTabsAfter(1, 1)
eET2.PushRaw("a")
eET2.PushRaw("b")
eET2.PushRaw("c")
sentET2 := []
eET2.PasteBatch((s) => sentET2.Push(s), (ms) => "")
AssertEq(sentET2.Length, 3, "Con +1 tab tras slot 1: 3 Tabs total")

; count=0 elimina la entrada (noop en PasteBatch/Scan)
eET3 := CaptureEngine(schemaET)
eET3.SetExtraTabsAfter(1, 1)
AssertEq(eET3.extraTabsAfterSlot.Has(1), true, "SetExtraTabsAfter(1,1): entrada presente")
eET3.SetExtraTabsAfter(1, 0)
AssertEq(eET3.extraTabsAfterSlot.Has(1), false, "SetExtraTabsAfter(1,0): entrada eliminada")

; Arm llama ResetState, que limpia extraTabsAfterSlot (template per-capture)
eET4 := CaptureEngine(schemaET)
eET4.SetExtraTabsAfter(2, 3)
eET4.Arm()
AssertEq(eET4.extraTabsAfterSlot.Count, 0, "Arm() limpia extraTabsAfterSlot")

; Slot last ignora extra tabs: no hay slot siguiente que skipear
eET5 := CaptureEngine(schemaET)
eET5.Arm()
eET5.SetExtraTabsAfter(3, 5)  ; slot 3 es last
eET5.PushRaw("a")
eET5.PushRaw("b")
eET5.PushRaw("c")
sentET5 := []
eET5.PasteBatch((s) => sentET5.Push(s), (ms) => "")
AssertEq(sentET5.Length, 2, "Extra tabs en slot last se ignoran (2 Tabs total, no 7)")

; Scan respeta extraTabsAfterSlot de la misma forma que PasteBatch
schemaScET := InvoiceSchema("scan-extra-tabs",
    [
        Campo("A", (r) => r, (v, q) => "", 1, true),  ; skipPaste -> no lee
        Campo("B", (r) => r, (v, q) => "", 1, true),
        Campo("C", (r) => r, (v, q) => "", 1, true)
    ],
    [1, 2, 3])

eScET := CaptureEngine(schemaScET)
sentScET := []
eScET.Scan(() => "", (s) => sentScET.Push(s), (ms) => "")
AssertEq(sentScET.Length, 2, "Scan sin extra tabs: 2 Tabs total")

eScET2 := CaptureEngine(schemaScET)
eScET2.SetExtraTabsAfter(1, 1)
sentScET2 := []
eScET2.Scan(() => "", (s) => sentScET2.Push(s), (ms) => "")
AssertEq(sentScET2.Length, 3, "Scan con +1 tab tras slot 1: 3 Tabs total")

; ClearSlot: limpia slot a "", registra en actionLog para soporte de Undo
e := CaptureEngine(CrearMock())
e.PushRaw("A1")
e.PushRaw("42")
e.ClearSlot(1)
AssertEq(e.queue[1], "", "ClearSlot deja slot vacio")
AssertEq(e.queue[2], "42", "ClearSlot no toca otros slots")
AssertEq(e.actionLog[e.actionLog.Length]["type"], "clear", "ClearSlot registra type='clear' en actionLog")

; Undo restaura el valor anterior al clear
e.Undo()
AssertEq(e.queue[1], "A1", "Undo de ClearSlot restaura prev value")

; Fuera de rango: noop, actionLog no crece
e2 := CaptureEngine(CrearMock())
prevLen := e2.actionLog.Length
e2.ClearSlot(99)
AssertEq(e2.actionLog.Length, prevLen, "ClearSlot OOR no toca actionLog")

; Quita el slot de preloadedSlots
e3 := CaptureEngine(CrearMock())
e3.queue[1] := "preloaded-val"
e3.preloadedSlots[1] := true
e3.ClearSlot(1)
AssertEq(e3.preloadedSlots.Has(1) ? 1 : 0, 0, "ClearSlot elimina preloaded")

; REGRESION "clipboard fantasma": Scan con campo vacío sobreescribe queue[slot]=""
; (no mantiene valor residual de load-last ni inicialización previa)
e := CaptureEngine(CrearMock())
e.queue[1] := "PREV"        ; valor residual que Scan debe sobrescribir
e.queue[2] := "OTRO"
emptyFn := () => ""
nopSend := (s) => 0
nopSleep := (ms) => 0
e.Scan(emptyFn, nopSend, nopSleep, "")

AssertEq(e.queue[1], "", "Scan empty borra slot 1 (no mantiene PREV)")
AssertEq(e.preloadedSlots.Has(1) ? 1 : 0, 0, "Scan empty no deja slot 1 en preloaded")

; Map para contador mutable: fat-arrow con ++ sobre variable de script-level
; cuelga en AHK v2 al capturarse en closure; Map preserva estado entre llamadas
counter := Map("n", 0)
mixedFn := () => ((counter["n"] := counter["n"] + 1) = 1) ? "" : "captured-val"
e2 := CaptureEngine(CrearMock())
e2.queue[1] := "OLD1"
e2.queue[2] := "OLD2"
e2.Scan(mixedFn, nopSend, nopSleep, "")
AssertEq(e2.queue[1], "", "Scan slot 1 vacio borra")

ReportarYSalir()
