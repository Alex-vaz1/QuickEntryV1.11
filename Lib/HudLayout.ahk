#Requires AutoHotkey v2.0
; ====================================================================
; HudLayout.ahk - Layout decisions del MainHud (modulo PURO).
; Sin estado. Sin GUI. Lookup tables + funciones de decision por breakpoint.
;
; Modos:
;   Normal:  ancho >= 540px. Layout actual (nameCol 200, full labels).
;   Compact: ancho < 540px.  Slots abreviados + botones solo simbolo.
; ====================================================================

class HudLayout
{
    static breakpoint := 540

    static IsCompact(width)
    {
        return width < this.breakpoint
    }

    static slotLabels := Map(
        1, Map("full", "Account number",                 "compact", "Acct #"),
        2, Map("full", "Invoice date",                   "compact", "Inv date"),
        3, Map("full", "Due date",                       "compact", "Due date"),
        4, Map("full", "Corp name",                      "compact", "Corp"),
        5, Map("full", "Previous balance",               "compact", "Prev bal"),
        6, Map("full", "Past Total Payments",            "compact", "Payments"),
        7, Map("full", "Past due",                       "compact", "Past due"),
        8, Map("full", "Total ($)",                      "compact", "Total"),
        9, Map("full", "Invoice Total Including PastDue","compact", "Total + PD")
    )

    static LabelForSlot(idx, isCompact)
    {
        if !this.slotLabels.Has(idx)
            return ""
        return this.slotLabels[idx][isCompact ? "compact" : "full"]
    }

    static buttonLabels := Map(
        "start",       Map("full", "▶ Iniciar",      "compact", "▶"),
        "skip",        Map("full", "⏭ Omitir",       "compact", "⏭"),
        "templateOn",  Map("full", "☑ Template",     "compact", "☑"),
        "templateOff", Map("full", "☐ Template",     "compact", "☐"),
        "scan",        Map("full", "⇣ Scan",         "compact", "⇣"),
        "release",     Map("full", "▶▶ Pegar",       "compact", "▶▶"),
        "reset",       Map("full", "⊘ Reset",        "compact", "⊘"),
        "undo",        Map("full", "↶ Undo",         "compact", "↶"),
        "loadLast",    Map("full", "↻ Load Last",    "compact", "↻"),
        "autocalc",    Map("full", "Σ Calc",         "compact", "Σ"),
        "setDefault",  Map("full", "⊙",              "compact", "⊙")
    )

    static LabelForButton(buttonId, isCompact)
    {
        if !this.buttonLabels.Has(buttonId)
            return "?"
        return this.buttonLabels[buttonId][isCompact ? "compact" : "full"]
    }

    static NameColWidth(isCompact)
    {
        ; Normal: 200px = ancho de "Invoice Total Including PastDue" en Segoe UI s9
        ;         + ~12px de padding. El value empieza pocos pixels despues.
        ; Compact: 100px = ancho de los nombres abreviados (ej. "Acct #").
        return isCompact ? 100 : 200
    }

    ; Puro por diseño: el caller pasa los rectángulos (Array<Map> con keys
    ; "l","t","r","b") en vez de llamar a MonitorGetWorkArea aquí,
    ; para que los tests puedan cubrir multi-monitor con arrays sintéticos.
    ; minVisible=100: umbral mínimo de intersección para excluir ventanas
    ; casi totalmente fuera de pantalla tras desconectar un monitor externo.
    static IsRectVisibleAgainst(x, y, w, h, monitorsArray)
    {
        minVisible := 100
        for mon in monitorsArray
        {
            ix := Max(x, mon["l"])
            iy := Max(y, mon["t"])
            ir := Min(x + w, mon["r"])
            ib := Min(y + h, mon["b"])
            if (ir - ix >= minVisible && ib - iy >= minVisible)
                return true
        }
        return false
    }
}
