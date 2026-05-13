#Requires AutoHotkey v2.0
; Cleaners.ahk — funciones puras de limpieza/normalización. Ver docs/files/Lib/Cleaners.md.

FormatearFecha(mes, dia, anio)
{
    try
    {
        if (Integer(mes) < 1 || Integer(mes) > 12)
            return ""
        if (Integer(dia) < 1 || Integer(dia) > 31)
            return ""

        mesFmt := Format("{:02d}", Integer(mes))
        diaFmt := Format("{:02d}", Integer(dia))

        if (StrLen(anio) = 2)
            anioFmt := "20" . anio
        else
            anioFmt := anio

        return mesFmt . "/" . diaFmt . "/" . anioFmt
    }
    catch
    {
        return ""
    }
}

FormatearFechaTexto(mesTexto, dia, anio)
{
    mesNum := MesTextoANumero(mesTexto)
    if (mesNum = 0)
        return ""
    if (anio = "" || anio = 0)
        anio := A_YYYY
    return FormatearFecha(mesNum, dia, anio)
}

MesTextoANumero(texto)
{
    static meses := Map(
        "jan", 1, "january", 1,
        "feb", 2, "february", 2,
        "mar", 3, "march", 3,
        "apr", 4, "april", 4,
        "may", 5,
        "jun", 6, "june", 6,
        "jul", 7, "july", 7,
        "aug", 8, "august", 8,
        "sep", 9, "sept", 9, "september", 9,
        "oct", 10, "october", 10,
        "nov", 11, "november", 11,
        "dec", 12, "december", 12
    )
    key := StrLower(RegExReplace(texto, "[^A-Za-z]", ""))
    if (key = "")
        return 0
    if meses.Has(key)
        return meses[key]
    return 0
}

LimpiarFechaRobusta(crudo)
{
    if (crudo = "")
        return ""

    if RegExMatch(crudo, "(?<!\d)(\d{4})[\-\/.](\d{1,2})[\-\/.](\d{1,2})(?!\d)", &m)
    {
        r := FormatearFecha(m[2], m[3], m[1])
        if (r != "")
            return r
    }

    if RegExMatch(crudo, "i)(?<!\d)(\d{1,2})(?:st|nd|rd|th)?[\s\-]+([A-Za-z]{3,9})\.?[\s\-,]+(\d{2,4})(?!\d)", &m)
    {
        mesNum := MesTextoANumero(m[2])
        if (mesNum > 0)
        {
            r := FormatearFecha(mesNum, m[1], m[3])
            if (r != "")
                return r
        }
    }

    if RegExMatch(crudo, "i)([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?[\s,]+(\d{2,4})(?!\d)", &m)
    {
        mesNum := MesTextoANumero(m[1])
        if (mesNum > 0)
        {
            r := FormatearFecha(mesNum, m[2], m[3])
            if (r != "")
                return r
        }
    }

    if RegExMatch(crudo, "(?<!\d)(\d{1,2})[\-\/.](\d{1,2})[\-\/.](\d{2,4})(?!\d)", &m)
    {
        r := FormatearFecha(m[1], m[2], m[3])
        if (r != "")
            return r
    }

    if RegExMatch(crudo, "(?<!\d)(\d{1,2})[\-\/.](\d{1,2})(?!\d)(?![\-\/.])", &m)
    {
        r := FormatearFecha(m[1], m[2], A_YYYY)
        if (r != "")
            return r
    }

    if RegExMatch(crudo, "i)([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?!\w)", &m)
    {
        mesNum := MesTextoANumero(m[1])
        if (mesNum > 0)
        {
            r := FormatearFecha(mesNum, m[2], A_YYYY)
            if (r != "")
                return r
        }
    }

    if RegExMatch(crudo, "i)(?<!\d)(\d{1,2})(?:st|nd|rd|th)?[\s\-]+([A-Za-z]{3,9})\.?(?!\w)", &m)
    {
        mesNum := MesTextoANumero(m[2])
        if (mesNum > 0)
        {
            r := FormatearFecha(mesNum, m[1], A_YYYY)
            if (r != "")
                return r
        }
    }

    if RegExMatch(crudo, "(?<!\d)(\d{1,2})[\-\/.](\d{1,2})[\-\/.](?!\d)", &m)
    {
        r := FormatearFecha(m[1], m[2], A_YYYY)
        if (r != "")
            return r
    }

    return ""
}

DetectarNegativo(s)
{
    if RegExMatch(s, "i)(?:^|[^A-Za-z])CR(?:$|[^A-Za-z])")
        return true
    stripped := RegExReplace(s, "^[\s\$]+", "")
    if (SubStr(stripped, 1, 1) = "-")
        return true
    if RegExMatch(s, "\$\s*-")
        return true
    if RegExMatch(s, "-\s*$")
        return true
    return false
}

NormalizarPrecio(precio)
{
    if (precio = "")
        return ""

    esNegativo := DetectarNegativo(precio)

    p := RegExReplace(precio, "i)[\$\s\-()]|USD|US\$|CR", "")

    if (p = "")
        return ""

    tienePunto := InStr(p, ".")
    tieneComa := InStr(p, ",")

    if (tienePunto && tieneComa)
    {
        if (InStr(p, ".",, -1) > InStr(p, ",",, -1))
            p := StrReplace(p, ",", "")
        else
        {
            p := StrReplace(p, ".", "")
            p := StrReplace(p, ",", ".")
        }
    }
    else if (tieneComa && !tienePunto)
    {
        if RegExMatch(p, ",(\d{3})$")
            p := StrReplace(p, ",", "")
        else
            p := StrReplace(p, ",", ".")
    }

    if !RegExMatch(p, "^\d+(\.\d+)?$")
        return ""

    return esNegativo ? "-" . p : p
}

LimpiarBillingItem(item)
{
    item := RegExReplace(item, "i)^(Item|Description|Service|Product|Concepto|Detalle|Desc)\s*:\s*", "")
    if RegExMatch(item, "i)^(.*?)\s*[-|–—]?\s*(Price|Precio|Amount|Monto|Total|Valor)\s*:", &m)
        item := m[1]
    item := RegExReplace(item, "\s*[-|–—:]+\s*$", "")
    return Trim(item)
}

LimpiarComoPegadoEspecial(crudo)
{
    texto := RegExReplace(crudo, "^[\s\x{00A0}\x{200B}]+|[\s\x{00A0}\x{200B}]+$", "")
    if (texto = "")
        return ""

    fecha := LimpiarFechaRobusta(texto)
    if (fecha != "")
        return fecha

    precio := NormalizarPrecio(texto)
    if (precio != "")
        return precio

    esCredito := RegExMatch(texto, "i)\bCR\b")
    limpio := RegExReplace(texto, "[\s()$,]+", "")
    limpio := RegExReplace(limpio, "i)CR", "")

    if (esCredito && RegExMatch(limpio, "^[\d.]+$"))
        limpio := "-" . limpio

    return limpio
}

ForzarNegativo(s)
{
    if !RegExMatch(s, "^-?\d+(\.\d+)?$")
        return s
    if (Number(s) = 0)
        return s
    if (SubStr(s, 1, 1) = "-")
        return s
    return "-" . s
}
