---
file: Lib/Cleaners.ahk
last_review: 2026-05-12
status: active
---

# `Lib/Cleaners.ahk`

## Propósito

Colección de funciones puras de limpieza y normalización de strings. No tiene estado,
no produce side-effects y no depende del clipboard, GUI ni variables globales. Toma un
string crudo (OCR, copy de PDF, texto pegado) y devuelve un string limpio, o `""` si
el input no pudo reconocerse.

## API pública

### Funciones libres

- **`FormatearFecha(mes, dia, anio) → String`** — Formatea componentes numéricos de fecha a `"MM/DD/YYYY"`. Normaliza año de 2 dígitos a 4 prefijando `"20"`. Devuelve `""` si mes < 1, mes > 12, dia < 1 o dia > 31.
  - Llamado desde: `Lib/Cleaners.ahk:48` (`FormatearFechaTexto`), `Lib/Cleaners.ahk:82, 92, 102, 110, 117, 128, 138, 147` (`LimpiarFechaRobusta` — 8 ramas)
  - Llama a: `Format()` (built-in), `Integer()` (built-in), `StrLen()` (built-in)

- **`FormatearFechaTexto(mesTexto, dia, anio) → String`** — Convierte un mes en texto (`"Jan"`, `"January"`, etc.) a su número y delega a `FormatearFecha`. Si `anio` es vacío o 0, usa `A_YYYY` (año en curso). Devuelve `""` si el texto no mapea a ningún mes.
  - Llamado desde: (ningún caller productivo fuera de Cleaners; expuesto como API pública)
  - Llama a: `MesTextoANumero`, `FormatearFecha`

- **`MesTextoANumero(texto) → Integer`** — Mapea nombre de mes en inglés (abreviado o completo) a entero 1–12 vía un `Map` estático. Normaliza el input con `StrLower` + `RegExReplace` quitando no-letras. Devuelve `0` si no reconoce el mes.
  - Llamado desde: `Lib/Cleaners.ahk:43` (`FormatearFechaTexto`), `Lib/Cleaners.ahk:89, 100, 124, 136` (`LimpiarFechaRobusta`)
  - Llama a: `StrLower()` (built-in), `RegExReplace()` (built-in)

- **`LimpiarFechaRobusta(crudo) → String`** — Intenta reconocer una fecha en 7 formatos distintos (ver Notas técnicas). Devuelve la primera coincidencia como `"MM/DD/YYYY"`, o `""` si ningún patrón aplica.
  - Llamado desde: `Lib/Cleaners.ahk:223` (`LimpiarComoPegadoEspecial`), `Tests/Test_Cleaners.ahk:13-90, 264-269`
  - Llama a: `FormatearFecha`, `MesTextoANumero`, `RegExMatch()` (built-in)

- **`DetectarNegativo(s) → Boolean`** — Devuelve `true` si el string representa un importe negativo: detecta sufijo/prefijo `CR` (whole-word), guión inicial, `$ -` o guión al final.
  - Llamado desde: `Lib/Cleaners.ahk:174` (`NormalizarPrecio`)
  - Llama a: `RegExMatch()` (built-in), `RegExReplace()` (built-in), `SubStr()` (built-in)

- **`NormalizarPrecio(precio) → String`** — Normaliza un string de precio a número decimal sin símbolos (`"1,234.56"` → `"1234.56"`, `"$-50.00 CR"` → `"-50.00"`). Resuelve ambigüedad punto/coma por posición relativa. Devuelve `""` si el resultado no es numérico puro.
  - Llamado desde: `Lib/AutoCalculator.ahk:108, 159`, `Lib/Cleaners.ahk:227` (`LimpiarComoPegadoEspecial`)
  - Llama a: `DetectarNegativo`, `RegExReplace()`, `InStr()`, `StrReplace()`, `RegExMatch()`

- **`LimpiarBillingItem(item) → String`** — Limpia el prefijo de etiqueta (`"Item:"`, `"Description:"`, `"Concepto:"`, etc.) y el sufijo de precio/total de una línea de descripción de factura. Devuelve el texto del concepto recortado con `Trim()`.
  - Llamado desde: `Tests/Test_Cleaners.ahk:249-260` (solo tests; ningún schema productivo lo usa actualmente)
  - Llama a: `RegExReplace()` (built-in), `RegExMatch()` (built-in), `Trim()` (built-in)

- **`LimpiarComoPegadoEspecial(crudo) → String`** — Función orquestadora del flujo de pegado especial. Quita espacios Unicode (NBSP `\x{00A0}`, ZWSP `\x{200B}`), luego intenta reconocer el valor como fecha, como precio, o como string con signo CR. Es la única función de este módulo con lógica de "pipeline".
  - Llamado desde: `Lib/PegadoEspecial.ahk:33` (`PegadoEspecial()`), `Schemas/AsignetHeaderV1.ahk:23` (`CleanPasoPegado`), `Schemas/AsignetHeaderV1.ahk:26` (`CleanPasoPegadoForzandoNegativo`)
  - Llama a: `RegExReplace()`, `LimpiarFechaRobusta`, `NormalizarPrecio`, `RegExMatch()`

- **`ForzarNegativo(s) → String`** — Si el string es un número positivo (regex `^\d+(\.\d+)?$`), le antepone `-`. Si ya es negativo, o es cero, o no es numérico puro, lo devuelve sin cambios.
  - Llamado desde: `Schemas/AsignetHeaderV1.ahk:27` (`CleanPasoPegadoForzandoNegativo`), `Schemas/_Plantilla_NuevaEmpresa.ahk:62`
  - Llama a: `RegExMatch()` (built-in), `Number()` (built-in), `SubStr()` (built-in)

## Dependencias

- **#Include directos**: ninguno (`#Requires AutoHotkey v2.0` únicamente)
- **Incluido por**: `QuickEntry.ahk` (línea 2), `Lib/AutoCalculator.ahk` (línea 2), `Lib/PegadoEspecial.ahk` (línea 2), `Schemas/AsignetHeaderV1.ahk` (línea 2), `Schemas/_Plantilla_NuevaEmpresa.ahk` (línea 2), `Tests/Test_Cleaners.ahk` (línea 4)
- **Globales que define**: ninguna
- **Globales que usa (leídas)**: `A_YYYY` (built-in de AHK v2, año actual del sistema; usada en `FormatearFechaTexto:47` y múltiples ramas de `LimpiarFechaRobusta` como año por defecto cuando el input no incluye año)
- **Símbolos externos invocados**: solo built-ins de AHK v2 (`Format`, `Integer`, `StrLen`, `StrLower`, `RegExMatch`, `RegExReplace`, `InStr`, `StrReplace`, `SubStr`, `Trim`, `Number`)

## Notas técnicas (WHY no-obvio)

- **Siete patrones de fecha en orden de especificidad** (`LimpiarFechaRobusta`): el orden importa porque un string puede coincidir con múltiples patrones. La precedencia es: (1) ISO `YYYY-MM-DD`, (2) `DD MMM YYYY` con ordinales opcionales, (3) `MMM DD, YYYY`, (4) `DD/MM/YYYY` o `MM/DD/YYYY` con 2–4 dígitos de año, (5) `MM/DD` sin año, (6) `MMM DD` sin año, (7) `DD MMM` sin año. El primer match gana. El patrón 4 es ambiguo (no distingue MM/DD de DD/MM); el sistema asume siempre MM/DD porque es el formato del cliente.

- **Lookbehind/lookahead `(?<!\d)` y `(?!\d)`**: todos los patrones de fecha usan estas aserciones para no capturar fragmentos de números más largos (por ejemplo, evitar que `20240112` matchee como fecha `0112`).

- **Resolución de ambigüedad punto/coma en `NormalizarPrecio`**: si el string tiene ambos separadores, el que aparece más a la derecha (`InStr(p, ".",, -1)` con 4to param negativo = búsqueda desde el final) se trata como separador decimal. Si solo hay coma, se evalúa si es miles (`",(\d{3})$"`) o decimal.

- **`Map` estático en `MesTextoANumero`**: se usa `static meses := Map(...)` para que el mapa se inicialice una sola vez en la primera llamada. Los alias `"sept"` (abreviación no estándar) y `"may"` (sin abreviación alternativa porque es igual en EN) están cubiertos explícitamente.

- **Unicode whitespace en `LimpiarComoPegadoEspecial`**: el regex de trim usa `\x{00A0}` (NBSP) y `\x{200B}` (zero-width space) además del `\s` estándar. Estos caracteres aparecen con frecuencia en copy-paste desde PDFs y no los elimina `Trim()` de AHK.

- **`LimpiarBillingItem` sin consumer productivo**: la función es API pública con tests propios, pero ningún `Campo` de los schemas activos la referencia. Se documentó como candidata a evaluar en Fase 3 (ver grafo en INDEX.md). La decisión de retenerla es consciente: puede ser útil cuando se agreguen schemas de vendors con columnas de descripción.

- **`ForzarNegativo` preserva cero**: el guard `if (Number(s) = 0) return s` evita convertir `"0"` en `"-0"`, lo cual rompería validaciones numéricas downstream.

- **`try/catch` en `FormatearFecha`**: el bloque catch captura el caso en que `Integer(mes)` o `Integer(dia)` recibe un string no numérico (ej: `""`, `"N/A"`). El catch devuelve `""` en lugar de propagar la excepción, manteniendo el contrato de "nunca lanza" de todo el módulo.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (no aplica — Cleaners.ahk no contiene handlers de mouse ni referencias M720)

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Borrado**: bloque de header `; ====...====` (líneas 2–14 originales, 13 líneas). Contenía: nombre de archivo, descripción de propósito, tabla de categorías con todas las funciones. Todo eso ya está en `docs/files/Lib/Cleaners.md` (Propósito + API pública). Era redundancia pura — el .ahk no es el lugar de la documentación.
  - **Re-escrito → WHY**: reemplazado por una línea `; Cleaners.ahk — funciones puras de limpieza/normalización. Ver docs/files/Lib/Cleaners.md.` que redirige al lector a la fuente canónica.
  - **Ningún otro comentario presente**: el cuerpo del archivo no tenía comentarios inline adicionales. Cero borrones en funciones.
- Sintaxis: `AutoHotkey64.exe /validate` → exit 0, sin errores.
- Dudosos: ninguno. El archivo era excepcionalmente limpio.

### Fase 3 — dead code
- [x] Auditado 2026-05-12
- Borrados: ninguno (modo CONSERVADOR — 0 funciones eliminadas)
- Resultado por función:

  | Función | Callers producción | Callers tests | Estado |
  |---|---|---|---|
  | `FormatearFecha` | Sí (interno: `FormatearFechaTexto`, `LimpiarFechaRobusta` — 9 call-sites) | Sí (Test_Cleaners:195-205) | USADO |
  | `FormatearFechaTexto` | **0** externos | Sí (Test_Cleaners:210-215) | **DUDOSO** (ver nota) |
  | `MesTextoANumero` | Sí (interno: `FormatearFechaTexto`, `LimpiarFechaRobusta` — 5 call-sites) | Sí (Test_Cleaners:158-190) | USADO |
  | `LimpiarFechaRobusta` | Sí (`LimpiarComoPegadoEspecial:211`) | Sí (Test_Cleaners:13-92, 268-271) | USADO |
  | `DetectarNegativo` | Sí (interno: `NormalizarPrecio:162`) | Sí (Test_Cleaners:220-233) | USADO |
  | `NormalizarPrecio` | Sí (`AutoCalculator.ahk:102,151`; `LimpiarComoPegadoEspecial:215`) | Sí (Test_Cleaners:99-141) | USADO |
  | `LimpiarBillingItem` | **0** productivos (`_Plantilla_NuevaEmpresa.ahk:47` es doc de API, no caller) | Sí (Test_Cleaners:251-262) | **DUDOSO** (ver nota) |
  | `LimpiarComoPegadoEspecial` | Sí (`PegadoEspecial.ahk:33`; `AsignetHeaderV1.ahk:21,24`; `_Plantilla_NuevaEmpresa.ahk:58,61`) | Sí (Test_Cleaners:146-153) | USADO |
  | `ForzarNegativo` | Sí (`AsignetHeaderV1.ahk:25`; `_Plantilla_NuevaEmpresa.ahk:62`) | Sí (Test_Cleaners:238-246) | USADO |

- Candidatos para review senior (DUDOSOS — NO borrados en modo conservador):

  - **`FormatearFechaTexto`** (`Lib/Cleaners.ahk:29`) — 0 callers productivos externos. `LimpiarFechaRobusta` llama directamente a `MesTextoANumero` + `FormatearFecha` en sus 7 ramas, nunca a `FormatearFechaTexto`. Solo `Tests/Test_Cleaners.ahk:210-215` la ejercita. Es API pública documentada en este .md y tiene tests propios. DUDOSO: retener como helper de conveniencia para futuros schemas, o deprecar si no aparece ningún caller en el próximo ciclo.

  - **`LimpiarBillingItem`** (`Lib/Cleaners.ahk:196`) — 0 callers productivos. `Schemas/_Plantilla_NuevaEmpresa.ahk:47` la documenta como API pública disponible para futuros schemas, pero no la invoca. Solo `Tests/Test_Cleaners.ahk:249-262` la ejercita. DUDOSO: API pública documentada en plantilla aunque sin callers actuales. NO BORRAR hasta que haya decisión explícita de descartar soporte de campos de descripción de factura.

- Sintaxis: `AutoHotkey64.exe /validate` → exit 0, sin errores.

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno. El archivo ya cumple todos los criterios del polish pass.
  - Trailing whitespace: 0 líneas afectadas.
  - Blank lines 3+: no existen.
  - Indentación: 4 espacios consistentes en todo el archivo, sin tabs.
  - Trailing newline: único, correcto.
  - Comentarios huérfanos: ninguno. El único comentario es el header de redirección a este .md (intencional, conservado desde Fase 2).
- Sintaxis: `AutoHotkey64.exe /validate` → exit 0, sin errores.

## Ideas de simplificación pendientes

- `LimpiarFechaRobusta` tiene 7 bloques `if RegExMatch(...) { ... return }` casi idénticos. Se podría refactorizar a un array de `[patron, handler]` iterado en un loop, reduciendo ~80 líneas a ~30 sin cambiar comportamiento ni firma.
- `NormalizarPrecio` y `DetectarNegativo` comparten lógica de "strip de símbolos monetarios". Unificarlos en un helper interno `_StripMonetario(s)` reduciría la duplicación del regex `[\$\s\-()]|USD|US\$|CR`.
- `LimpiarComoPegadoEspecial` podría aceptar un parámetro opcional `modo` (`"fecha"` / `"precio"` / `"auto"`) para saltear los intentos de reconocimiento automático cuando el contexto del campo ya es conocido. Esto requiere cambio de firma y coordinación con `PegadoEspecial.ahk` y los schemas.
