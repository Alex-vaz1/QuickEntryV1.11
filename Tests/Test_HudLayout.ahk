#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\HudLayout.ahk"
#Include "_AssertHelpers.ahk"

; --- IsCompact: breakpoint 540 es exclusivo (540 ya es normal, 539 aun compact) ---
AssertEq(HudLayout.IsCompact(539) ? 1 : 0, 1, "compact at 539")
AssertEq(HudLayout.IsCompact(540) ? 1 : 0, 0, "normal at exactly 540")
AssertEq(HudLayout.IsCompact(541) ? 1 : 0, 0, "normal at 541")
AssertEq(HudLayout.IsCompact(800) ? 1 : 0, 0, "normal at 800")
AssertEq(HudLayout.IsCompact(0) ? 1 : 0, 1, "compact at 0 (degenerate: width=0 no debe crashear)")

; --- LabelForSlot: cada slot tiene label largo (normal) y corto (compact); slot inexistente retorna "" ---
AssertEq(HudLayout.LabelForSlot(1, false), "Account number", "slot 1 normal")
AssertEq(HudLayout.LabelForSlot(1, true),  "Acct #",         "slot 1 compact")
AssertEq(HudLayout.LabelForSlot(4, false), "Corp name",      "slot 4 normal")
AssertEq(HudLayout.LabelForSlot(4, true),  "Corp",           "slot 4 compact")
AssertEq(HudLayout.LabelForSlot(9, false), "Invoice Total Including PastDue", "slot 9 normal")
AssertEq(HudLayout.LabelForSlot(9, true),  "Total + PD",     "slot 9 compact")
; slot 99 no existe en el schema -> debe retornar "" en lugar de crashear o retornar basura
AssertEq(HudLayout.LabelForSlot(99, true), "",               "slot 99 returns empty")

; LabelForButton: cada boton tiene texto completo (normal) y solo simbolo (compact); id desconocido -> "?"
AssertEq(HudLayout.LabelForButton("start", false),       "▶ Iniciar",      "start normal")
AssertEq(HudLayout.LabelForButton("start", true),        "▶",              "start compact")
AssertEq(HudLayout.LabelForButton("skip", false),        "⏭ Omitir",       "skip normal")
AssertEq(HudLayout.LabelForButton("skip", true),         "⏭",              "skip compact")
AssertEq(HudLayout.LabelForButton("templateOn", false),  "☑ Template",     "templateOn normal")
AssertEq(HudLayout.LabelForButton("templateOn", true),   "☑",              "templateOn compact")
AssertEq(HudLayout.LabelForButton("templateOff", false), "☐ Template",     "templateOff normal")
AssertEq(HudLayout.LabelForButton("templateOff", true),  "☐",              "templateOff compact")
AssertEq(HudLayout.LabelForButton("scan", false),        "⇣ Scan",         "scan normal")
AssertEq(HudLayout.LabelForButton("scan", true),         "⇣",              "scan compact")
AssertEq(HudLayout.LabelForButton("release", false),     "▶▶ Pegar",       "release normal")
AssertEq(HudLayout.LabelForButton("release", true),      "▶▶",             "release compact")
AssertEq(HudLayout.LabelForButton("reset", false),       "⊘ Reset",        "reset normal")
AssertEq(HudLayout.LabelForButton("reset", true),        "⊘",              "reset compact")
AssertEq(HudLayout.LabelForButton("undo", false),        "↶ Undo",         "undo normal")
AssertEq(HudLayout.LabelForButton("undo", true),         "↶",              "undo compact")
AssertEq(HudLayout.LabelForButton("loadLast", false),    "↻ Load Last",    "loadLast normal")
AssertEq(HudLayout.LabelForButton("loadLast", true),     "↻",              "loadLast compact")
AssertEq(HudLayout.LabelForButton("autocalc", false),    "Σ Calc",         "autocalc normal")
AssertEq(HudLayout.LabelForButton("autocalc", true),     "Σ",              "autocalc compact")
AssertEq(HudLayout.LabelForButton("setDefault", false),  "⊙",              "setDefault normal (already symbol)")
AssertEq(HudLayout.LabelForButton("setDefault", true),   "⊙",              "setDefault compact (same)")
AssertEq(HudLayout.LabelForButton("nonexistent", true),  "?",              "unknown id returns ?")

; NameColWidth: 200 normal porque es el label mas largo del schema; 100 compact porque es el minimo legible
AssertEq(HudLayout.NameColWidth(false), 200, "nameCol normal (cabe nombre mas largo del schema)")
AssertEq(HudLayout.NameColWidth(true),  100, "nameCol compact")

; IsRectVisibleAgainst: retorna true si al menos 100x100 px del rect interseca algun monitor
; (monitores pasados como array sintetico para no depender del hardware real)
mons1 := [Map("l", 0, "t", 0, "r", 1920, "b", 1080)]

AssertEq(HudLayout.IsRectVisibleAgainst(100, 100, 540, 460, mons1) ? 1 : 0, 1, "rect dentro de monitor")
AssertEq(HudLayout.IsRectVisibleAgainst(2000, 100, 540, 460, mons1) ? 1 : 0, 0, "rect a la derecha del monitor")
; -490: interseccion horizontal = max(0, 540-490) = 50 px < umbral 100 -> false
AssertEq(HudLayout.IsRectVisibleAgainst(-490, 100, 540, 460, mons1) ? 1 : 0, 0, "rect con solo 50px visibles")
; -400: interseccion horizontal = max(0, 540-400) = 140 px >= umbral 100 -> true (pinza umbral desde el otro lado)
AssertEq(HudLayout.IsRectVisibleAgainst(-400, 100, 540, 460, mons1) ? 1 : 0, 1, "rect con 140px visibles cuenta")

; segundo monitor side-by-side estandar: verifica que la busqueda itera todos los monitores del array
mons2 := [
    Map("l", 0,    "t", 0, "r", 1920, "b", 1080),
    Map("l", 1920, "t", 0, "r", 3840, "b", 1080)
]
AssertEq(HudLayout.IsRectVisibleAgainst(2500, 200, 540, 460, mons2) ? 1 : 0, 1, "rect en segundo monitor")

; degenerate: array vacio -> no hay monitor que intersectar -> false (no debe crashear)
AssertEq(HudLayout.IsRectVisibleAgainst(0, 0, 540, 460, []) ? 1 : 0, 0, "sin monitores retorna false")

ReportarYSalir()
