#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#Include "..\Lib\Cleaners.ahk"
#Include "_AssertHelpers.ahk"

; ====================================================================
; LimpiarFechaRobusta - todos los formatos en ingles + basura
; Salida SIEMPRE MM/DD/YYYY (4 digitos anio) o "" si no es fecha valida
; ====================================================================

; --- Formato ISO yyyy-mm-dd ---
AssertEq(LimpiarFechaRobusta("2026-09-15"), "09/15/2026", "ISO yyyy-mm-dd")
AssertEq(LimpiarFechaRobusta("2026/09/15"), "09/15/2026", "ISO con barras")
AssertEq(LimpiarFechaRobusta("2026.09.15"), "09/15/2026", "ISO con puntos")

; --- Formato US numerico mm/dd/yyyy y mm/dd/yy ---
AssertEq(LimpiarFechaRobusta("09/15/2026"), "09/15/2026", "US largo")
AssertEq(LimpiarFechaRobusta("9/15/26"), "09/15/2026", "US corto sin ceros")
AssertEq(LimpiarFechaRobusta("9-15-26"), "09/15/2026", "US con guiones")
AssertEq(LimpiarFechaRobusta("09.15.2026"), "09/15/2026", "US con puntos")

; --- Mes texto abreviado (3 letras) ---
AssertEq(LimpiarFechaRobusta("Sep 15, 2026"), "09/15/2026", "mes abrev con coma")
AssertEq(LimpiarFechaRobusta("Sep 15 2026"), "09/15/2026", "mes abrev sin coma")
AssertEq(LimpiarFechaRobusta("SEP 15, 2026"), "09/15/2026", "mes abrev MAYUS")
AssertEq(LimpiarFechaRobusta("sep 15, 2026"), "09/15/2026", "mes abrev minus")
AssertEq(LimpiarFechaRobusta("Sep. 15, 2026"), "09/15/2026", "mes abrev con punto")
AssertEq(LimpiarFechaRobusta("Sept 15, 2026"), "09/15/2026", "Sept variante 4 letras")
AssertEq(LimpiarFechaRobusta("Sept. 15, 2026"), "09/15/2026", "Sept con punto")

; --- Mes texto completo ---
AssertEq(LimpiarFechaRobusta("September 15, 2026"), "09/15/2026", "mes completo")
AssertEq(LimpiarFechaRobusta("january 1, 2026"), "01/01/2026", "January minus")
AssertEq(LimpiarFechaRobusta("FEBRUARY 28 2026"), "02/28/2026", "February MAYUS sin coma")
AssertEq(LimpiarFechaRobusta("December 31, 2026"), "12/31/2026", "December")

; --- Ordinales ---
AssertEq(LimpiarFechaRobusta("Sep 1st, 2026"), "09/01/2026", "ordinal 1st")
AssertEq(LimpiarFechaRobusta("Oct 2nd, 2026"), "10/02/2026", "ordinal 2nd")
AssertEq(LimpiarFechaRobusta("Nov 3rd, 2026"), "11/03/2026", "ordinal 3rd")
AssertEq(LimpiarFechaRobusta("Sep 15th, 2026"), "09/15/2026", "ordinal 15th")
AssertEq(LimpiarFechaRobusta("Sep 21st, 2026"), "09/21/2026", "ordinal 21st")

; --- Day-first ---
AssertEq(LimpiarFechaRobusta("15 Sep 2026"), "09/15/2026", "day-first abrev")
AssertEq(LimpiarFechaRobusta("15 September 2026"), "09/15/2026", "day-first completo")
AssertEq(LimpiarFechaRobusta("15-Sep-2026"), "09/15/2026", "day-first con guiones")
AssertEq(LimpiarFechaRobusta("1st Sep 2026"), "09/01/2026", "day-first ordinal")

; --- Basura antes/despues ---
AssertEq(LimpiarFechaRobusta("Due Date: Sep 15, 2026"), "09/15/2026", "basura prefijo OCR")
AssertEq(LimpiarFechaRobusta("Sep 15, 2026 (Friday)"), "09/15/2026", "basura sufijo dia semana")
AssertEq(LimpiarFechaRobusta("[OCR] Due: Sep 15, 2026 ***"), "09/15/2026", "basura ambos lados")
AssertEq(LimpiarFechaRobusta("Invoice Date 09/15/2026 page 1"), "09/15/2026", "basura US numerico")
AssertEq(LimpiarFechaRobusta("FECHA DE VENCIMIENTO: 09-15-2026"), "09/15/2026", "espanol prefijo + guiones")
AssertEq(LimpiarFechaRobusta("   Sep 15, 2026   "), "09/15/2026", "spaces alrededor")

; --- Invalidas ---
AssertEq(LimpiarFechaRobusta(""), "", "vacio rechazado")
AssertEq(LimpiarFechaRobusta("not a date"), "", "texto sin fecha rechazado")
AssertEq(LimpiarFechaRobusta("13/45/2026"), "", "mes 13 dia 45 invalido")
AssertEq(LimpiarFechaRobusta("Xxx 15, 2026"), "", "mes texto invalido")
AssertEq(LimpiarFechaRobusta("Sep 32, 2026"), "", "dia 32 invalido")
AssertEq(LimpiarFechaRobusta("Sep 0, 2026"), "", "dia 0 invalido")

; --- Fechas cortas SIN anio: usa A_YYYY ---
AssertEq(LimpiarFechaRobusta("3/2"), "03/02/" A_YYYY, "short US 3/2")
AssertEq(LimpiarFechaRobusta("03/02"), "03/02/" A_YYYY, "short US 03/02")
AssertEq(LimpiarFechaRobusta("12/31"), "12/31/" A_YYYY, "short US 12/31")
AssertEq(LimpiarFechaRobusta("3-2"), "03/02/" A_YYYY, "short US con guiones")
AssertEq(LimpiarFechaRobusta("Mar 2"), "03/02/" A_YYYY, "Mar 2")
AssertEq(LimpiarFechaRobusta("March 2"), "03/02/" A_YYYY, "March 2")
AssertEq(LimpiarFechaRobusta("Mar 2nd"), "03/02/" A_YYYY, "Mar 2nd")
AssertEq(LimpiarFechaRobusta("Sep. 15th"), "09/15/" A_YYYY, "Sep. 15th con punto y ordinal")
AssertEq(LimpiarFechaRobusta("Jan 1"), "01/01/" A_YYYY, "Jan 1")
AssertEq(LimpiarFechaRobusta("December 31"), "12/31/" A_YYYY, "December 31")
AssertEq(LimpiarFechaRobusta("2 Mar"), "03/02/" A_YYYY, "day-first 2 Mar")
AssertEq(LimpiarFechaRobusta("15-Sep"), "09/15/" A_YYYY, "day-first 15-Sep")
AssertEq(LimpiarFechaRobusta("1st Jan"), "01/01/" A_YYYY, "day-first ordinal 1st Jan")
AssertEq(LimpiarFechaRobusta("13/45"), "", "short mes 13 dia 45 invalido")
AssertEq(LimpiarFechaRobusta("Mar 32"), "", "short Mar 32 dia invalido")
AssertEq(LimpiarFechaRobusta("Xxx 5"), "", "short mes texto invalido")

; --- Sin validacion semantica de calendario: feb-29 no-bisiesto y apr-31 se aceptan ---
; WHY: LimpiarFechaRobusta solo valida formato y rangos (1-12 / 1-31); no rechaza dias
; imposibles por mes o año bisiesto. Esa responsabilidad la delega a Asignet upstream.
AssertEq(LimpiarFechaRobusta("2/29/2026"), "02/29/2026", "feb 29 anio no-bisiesto pasa")
AssertEq(LimpiarFechaRobusta("Mar 31, 2026"), "03/31/2026", "Mar 31 valido")
AssertEq(LimpiarFechaRobusta("Apr 31, 2026"), "04/31/2026", "Apr 31 acepta (no validamos meses cortos)")
AssertEq(LimpiarFechaRobusta("01/01/2026"), "01/01/2026", "ya formato correcto preserva")
AssertEq(LimpiarFechaRobusta("Sept. 5, 2026"), "09/05/2026", "Sept. dia 1 digito")

; ====================================================================
; NormalizarPrecio - sign detection robusto
; ====================================================================

; --- CR variantes ---
AssertEq(NormalizarPrecio("100.00 CR"), "-100.00", "CR sufijo con espacio")
AssertEq(NormalizarPrecio("100.00CR"), "-100.00", "CR sufijo sin espacio")
AssertEq(NormalizarPrecio("CR 100.00"), "-100.00", "CR prefijo")
AssertEq(NormalizarPrecio("$100.00 CR"), "-100.00", "CR con $")
AssertEq(NormalizarPrecio("$100.00 cr"), "-100.00", "cr minus")
AssertEq(NormalizarPrecio("$100.00 Cr"), "-100.00", "Cr mixto")

; --- Minus prefijo ---
AssertEq(NormalizarPrecio("-100.00"), "-100.00", "minus prefijo simple")
AssertEq(NormalizarPrecio("-$100.00"), "-100.00", "minus antes de $")
AssertEq(NormalizarPrecio("$-100.00"), "-100.00", "minus despues de $")
AssertEq(NormalizarPrecio("- 100.00"), "-100.00", "minus con espacio")

; --- Minus sufijo ---
AssertEq(NormalizarPrecio("100.00-"), "-100.00", "minus sufijo")
AssertEq(NormalizarPrecio("$100.00-"), "-100.00", "minus sufijo con $")
AssertEq(NormalizarPrecio("100.00 -"), "-100.00", "minus sufijo con espacio")

; --- Doble negativo NO se cancela ---
AssertEq(NormalizarPrecio("-100.00 CR"), "-100.00", "minus + CR sigue negativo")
AssertEq(NormalizarPrecio("$-100.00 CR"), "-100.00", "minus dentro + CR sigue negativo")

; --- Positivos limpios ---
AssertEq(NormalizarPrecio("$1,234.56"), "1234.56", "positivo US")
AssertEq(NormalizarPrecio("1.234,56"), "1234.56", "positivo EU")
AssertEq(NormalizarPrecio("100"), "100", "entero positivo")
AssertEq(NormalizarPrecio("0.00"), "0.00", "cero")

; --- Basura no numerica ---
AssertEq(NormalizarPrecio(""), "", "vacio")
AssertEq(NormalizarPrecio("abc"), "", "letras puras")
AssertEq(NormalizarPrecio("$"), "", "solo simbolo")

; --- Formatos EU adicionales y miles multiples ---
AssertEq(NormalizarPrecio("1.234.567,89"), "1234567.89", "NP EU multi-grupo miles + decimal")
AssertEq(NormalizarPrecio("1,234.56"), "1234.56", "NP US 1 grupo")
AssertEq(NormalizarPrecio("1,234,567.89"), "1234567.89", "NP US multi-grupo miles")
AssertEq(NormalizarPrecio("USD 100.00"), "100.00", "NP USD prefijo")
AssertEq(NormalizarPrecio("US$ 100.00"), "100.00", "NP US$ prefijo")
AssertEq(NormalizarPrecio("100"), "100", "NP entero sin decimal")
AssertEq(NormalizarPrecio("0"), "0", "NP cero entero")
AssertEq(NormalizarPrecio("100,50"), "100.50", "NP EU coma decimal sin miles")
AssertEq(NormalizarPrecio("(1,234.56)"), "1234.56", "NP parens NO son negativos")

; ====================================================================
; LimpiarComoPegadoEspecial - delegacion a fechas/precios
; ====================================================================
AssertEq(LimpiarComoPegadoEspecial("2026-09-15"), "09/15/2026", "ISO via PegadoEspecial")
AssertEq(LimpiarComoPegadoEspecial("Sept. 15th, 2026"), "09/15/2026", "Sept. ordinal via PegadoEspecial")
AssertEq(LimpiarComoPegadoEspecial("15 September 2026"), "09/15/2026", "day-first via PegadoEspecial")
AssertEq(LimpiarComoPegadoEspecial("Due: Sep 15, 2026 (Fri)"), "09/15/2026", "garbage via PegadoEspecial")
AssertEq(LimpiarComoPegadoEspecial(""), "", "LCPE vacio")
AssertEq(LimpiarComoPegadoEspecial("   "), "", "LCPE solo espacios")
AssertEq(LimpiarComoPegadoEspecial("$1,234.56"), "1234.56", "LCPE precio US")
AssertEq(LimpiarComoPegadoEspecial("$100 CR"), "-100", "LCPE CR negativo")

; ====================================================================
; MesTextoANumero - todos los meses + edge cases
; ====================================================================
AssertEq(MesTextoANumero("Jan"), 1, "MTN Jan = 1")
AssertEq(MesTextoANumero("January"), 1, "MTN January = 1")
AssertEq(MesTextoANumero("Feb"), 2, "MTN Feb = 2")
AssertEq(MesTextoANumero("February"), 2, "MTN February = 2")
AssertEq(MesTextoANumero("Mar"), 3, "MTN Mar = 3")
AssertEq(MesTextoANumero("March"), 3, "MTN March = 3")
AssertEq(MesTextoANumero("Apr"), 4, "MTN Apr = 4")
AssertEq(MesTextoANumero("April"), 4, "MTN April = 4")
AssertEq(MesTextoANumero("May"), 5, "MTN May = 5")
AssertEq(MesTextoANumero("Jun"), 6, "MTN Jun = 6")
AssertEq(MesTextoANumero("June"), 6, "MTN June = 6")
AssertEq(MesTextoANumero("Jul"), 7, "MTN Jul = 7")
AssertEq(MesTextoANumero("July"), 7, "MTN July = 7")
AssertEq(MesTextoANumero("Aug"), 8, "MTN Aug = 8")
AssertEq(MesTextoANumero("August"), 8, "MTN August = 8")
AssertEq(MesTextoANumero("Sep"), 9, "MTN Sep = 9")
AssertEq(MesTextoANumero("Sept"), 9, "MTN Sept = 9")
AssertEq(MesTextoANumero("September"), 9, "MTN September = 9")
AssertEq(MesTextoANumero("Oct"), 10, "MTN Oct = 10")
AssertEq(MesTextoANumero("October"), 10, "MTN October = 10")
AssertEq(MesTextoANumero("Nov"), 11, "MTN Nov = 11")
AssertEq(MesTextoANumero("November"), 11, "MTN November = 11")
AssertEq(MesTextoANumero("Dec"), 12, "MTN Dec = 12")
AssertEq(MesTextoANumero("December"), 12, "MTN December = 12")
AssertEq(MesTextoANumero("JANUARY"), 1, "MTN MAYUS")
AssertEq(MesTextoANumero("january"), 1, "MTN minus")
AssertEq(MesTextoANumero("JaNuArY"), 1, "MTN mixto")
AssertEq(MesTextoANumero("Sept."), 9, "MTN ignora punto")
AssertEq(MesTextoANumero("Jan,"), 1, "MTN ignora coma")
AssertEq(MesTextoANumero(""), 0, "MTN vacio = 0")
AssertEq(MesTextoANumero("123"), 0, "MTN digitos = 0")
AssertEq(MesTextoANumero("Xyz"), 0, "MTN texto invalido = 0")
AssertEq(MesTextoANumero("Marzo"), 0, "MTN espanol NO acepta")

; ====================================================================
; FormatearFecha - pad cero, expansion anio 2->4, validacion rangos
; ====================================================================
AssertEq(FormatearFecha(3, 2, 2026), "03/02/2026", "FF pad mes y dia simple")
AssertEq(FormatearFecha(12, 31, 2026), "12/31/2026", "FF sin pad necesario")
AssertEq(FormatearFecha(1, 1, "26"), "01/01/2026", "FF expande anio 2 digitos")
AssertEq(FormatearFecha(1, 1, "2026"), "01/01/2026", "FF preserva anio 4 digitos")
AssertEq(FormatearFecha("09", "15", "2026"), "09/15/2026", "FF acepta strings")
AssertEq(FormatearFecha(0, 1, 2026), "", "FF mes 0 invalido")
AssertEq(FormatearFecha(13, 1, 2026), "", "FF mes 13 invalido")
AssertEq(FormatearFecha(1, 0, 2026), "", "FF dia 0 invalido")
AssertEq(FormatearFecha(1, 32, 2026), "", "FF dia 32 invalido")
AssertEq(FormatearFecha("abc", 1, 2026), "", "FF mes no-numero")
AssertEq(FormatearFecha(1, "xyz", 2026), "", "FF dia no-numero")

; ====================================================================
; FormatearFechaTexto - anio vacio usa A_YYYY, mes invalido = ""
; ====================================================================
AssertEq(FormatearFechaTexto("Sep", 15, 2026), "09/15/2026", "FFT happy path")
AssertEq(FormatearFechaTexto("Sep", 15, ""), "09/15/" A_YYYY, "FFT anio vacio usa A_YYYY")
AssertEq(FormatearFechaTexto("Sep", 15, 0), "09/15/" A_YYYY, "FFT anio 0 usa A_YYYY")
AssertEq(FormatearFechaTexto("Xyz", 15, 2026), "", "FFT mes invalido")
AssertEq(FormatearFechaTexto("Sep", 32, 2026), "", "FFT dia invalido")
AssertEq(FormatearFechaTexto("September", 15, 2026), "09/15/2026", "FFT mes completo")

; ====================================================================
; DetectarNegativo - todas las reglas
; ====================================================================
AssertEq(DetectarNegativo("100.00 CR"), true, "DN CR sufijo")
AssertEq(DetectarNegativo("CR 100.00"), true, "DN CR prefijo")
AssertEq(DetectarNegativo("100.00CR"), true, "DN CR sin espacio")
AssertEq(DetectarNegativo("-100.00"), true, "DN minus prefijo")
AssertEq(DetectarNegativo("$-100.00"), true, "DN $- prefijo")
AssertEq(DetectarNegativo("- 100.00"), true, "DN minus con espacio")
AssertEq(DetectarNegativo("100.00-"), true, "DN minus sufijo")
AssertEq(DetectarNegativo("100.00 -"), true, "DN minus sufijo con espacio")
AssertEq(DetectarNegativo("100.00"), false, "DN positivo simple")
AssertEq(DetectarNegativo("$100.00"), false, "DN positivo con $")
AssertEq(DetectarNegativo("(100.00)"), false, "DN parens NO son negativos")
AssertEq(DetectarNegativo(""), false, "DN vacio = false")
AssertEq(DetectarNegativo("CREDIT 100"), false, "DN CREDIT NO es CR token")
AssertEq(DetectarNegativo("ACR100"), false, "DN ACR NO es CR")

; ====================================================================
; ForzarNegativo - directos
; ====================================================================
AssertEq(ForzarNegativo("100.00"), "-100.00", "FN positivo a negativo")
AssertEq(ForzarNegativo("-100.00"), "-100.00", "FN ya negativo se mantiene")
AssertEq(ForzarNegativo("0"), "0", "FN cero queda cero")
AssertEq(ForzarNegativo("0.00"), "0.00", "FN cero decimal queda cero")
AssertEq(ForzarNegativo("0.000"), "0.000", "FN cero multi-decimal queda cero")
AssertEq(ForzarNegativo(""), "", "FN vacio sigue vacio")
AssertEq(ForzarNegativo("abc"), "abc", "FN no-numero pasa tal cual")
AssertEq(ForzarNegativo("100.5"), "-100.5", "FN positivo decimal simple")
AssertEq(ForzarNegativo("1234567.89"), "-1234567.89", "FN numero grande")

; ====================================================================
; LimpiarBillingItem
; ====================================================================
AssertEq(LimpiarBillingItem("Item: Logitech Mouse"), "Logitech Mouse", "LBI strip Item:")
AssertEq(LimpiarBillingItem("Description: Cable USB"), "Cable USB", "LBI strip Description:")
AssertEq(LimpiarBillingItem("DESC: Cable USB"), "Cable USB", "LBI strip DESC: case-insensitive")
AssertEq(LimpiarBillingItem("Concepto: Servicio mensual"), "Servicio mensual", "LBI espanol prefijo")
AssertEq(LimpiarBillingItem("Detalle: Producto X"), "Producto X", "LBI Detalle prefijo")
AssertEq(LimpiarBillingItem("Cable USB - Price:"), "Cable USB", "LBI strip Price: sufijo")
AssertEq(LimpiarBillingItem("Cable USB - Total:"), "Cable USB", "LBI strip Total: sufijo")
AssertEq(LimpiarBillingItem("Cable USB - Monto:"), "Cable USB", "LBI strip Monto: sufijo")
AssertEq(LimpiarBillingItem("Logitech Mouse-"), "Logitech Mouse", "LBI strip dash final")
AssertEq(LimpiarBillingItem("Logitech Mouse: "), "Logitech Mouse", "LBI strip dos puntos final")
AssertEq(LimpiarBillingItem("  Cable USB  "), "Cable USB", "LBI trim espacios")
AssertEq(LimpiarBillingItem("Cable USB"), "Cable USB", "LBI passthrough texto plano")

; --- Fechas sin año: completar con año actual ---
; Año actual se calcula dinámicamente para que el test no caduque.
anioActual := SubStr(A_YYYY, 1)

AssertEq(LimpiarFechaRobusta("5/8/"), "05/08/" anioActual, "fecha sin anio con slash trailing")
AssertEq(LimpiarFechaRobusta("05/8/"), "05/08/" anioActual, "fecha sin anio con mes 2-digit + slash trailing")
AssertEq(LimpiarFechaRobusta("5-8-"), "05/08/" anioActual, "fecha sin anio con guion trailing")
AssertEq(LimpiarFechaRobusta("12/31/"), "12/31/" anioActual, "fecha 12/31 sin anio")

ReportarYSalir()
