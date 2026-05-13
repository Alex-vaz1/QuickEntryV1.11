---
file: Lib/Validators.ahk
last_review: 2026-05-12
status: active
---

# `Lib/Validators.ahk`

## Propósito

Colección de funciones puras de validación para los campos de un invoice header. Cada validator cumple la firma `(val, cola) => "" si OK, mensaje si NO`, lo que permite pasarlos directamente como `validateFn` en el constructor de `Campo`. El módulo también expone un builder (`ValidarSumaTol`) que retorna un validator configurado via `.Bind()`, sin estado mutable propio.

## API pública

### Funciones libres

- **`EsImporteValido(s) → Bool`** — predicado base: retorna `true` si `s` matchea `^-?\d+(\.\d+)?$` (entero o decimal, signo opcional), `false` en caso contrario.
  - Llamado desde: `Lib/Validators.ahk:26` (`ValidarNumero`), `Lib/Validators.ahk:46` (`ValidarSumaCheck`)
  - Llama a: `RegExMatch` (built-in AHK v2)

- **`ValidarNoVacio(val, cola) → String`** — retorna `""` si `val` no es cadena vacía; `"valor vacio"` si lo es.
  - Llamado desde: `Schemas/AsignetHeaderV1.ahk:58` (slot 1), `Schemas/AsignetHeaderV1.ahk:61` (slot 4); `Schemas/_Plantilla_NuevaEmpresa.ahk:94, 98, 104`; `Tests/Test_CaptureEngine.ahk:15, 305, 307, 345, 346, 391, 392, 393, 435, 436, 437, 481, 482, 483` (schemas mock)
  - Llama a: (ninguno — comparación directa)

- **`ValidarNumero(val, cola) → String`** — retorna `""` si `val` es un importe válido; `"no es un numero valido"` en caso contrario.
  - Llamado desde: `Schemas/AsignetHeaderV1.ahk:69, 70, 72` (slots 5, 6, 8); `Schemas/_Plantilla_NuevaEmpresa.ahk:107, 110`; `Tests/Test_CaptureEngine.ahk:16, 306, 311, 487`
  - Llama a: `EsImporteValido` (`Lib/Validators.ahk:14`)

- **`ValidarFechaEstricta(val, cola) → String`** — retorna `""` si `val` cumple el formato `MM/DD/YYYY` estricto (meses `01–12`, días `01–31`); `"fecha debe ser MM/DD/YYYY"` en caso contrario.
  - Llamado desde: `Schemas/AsignetHeaderV1.ahk:59, 60` (slots 2, 3); `Schemas/_Plantilla_NuevaEmpresa.ahk:101`
  - Llama a: `RegExMatch` (built-in AHK v2)

- **`ValidarSumaTol(slotsIndices, tol := 0.01) → Func`** — builder: retorna un validator (closure via `.Bind`) que verifica que `val ≈ sum(cola[s] for s in slotsIndices)` con tolerancia `tol`. Si alguna dependencia en `cola` está vacía (`""`), el validator retorna `""` (skip).
  - Llamado desde: `Schemas/AsignetHeaderV1.ahk:71, 73` (slots 7 y 9); `Tests/Test_CaptureEngine.ahk:17` (mock)
  - Llama a: `ValidarSumaCheck.Bind(slotsIndices, tol)` (`Lib/Validators.ahk:41`)

- **`ValidarSumaCheck(slotsIndices, tol, val, cola) → String`** — helper interno; implementa la lógica de suma que `ValidarSumaTol` vincula vía `.Bind`. Retorna `""` si la diferencia `|val - suma| <= tol`; `"suma debe ser <valor formateado>"` en caso contrario. Retorna `""` (skip) si `val` no es importe o si algún slot de `cola` está vacío o fuera de rango.
  - Llamado desde: `Lib/Validators.ahk:41` exclusivamente (via `.Bind` dentro de `ValidarSumaTol`); no tiene callers directos externos
  - Llama a: `EsImporteValido` (`Lib/Validators.ahk:14`), `Number` (built-in), `Abs` (built-in), `Format` (built-in)

## Dependencias

- **#Include directos**: (ninguno — `#Requires AutoHotkey v2.0` únicamente)
- **Incluido por**: `QuickEntry.ahk` (línea 3); `Schemas/AsignetHeaderV1.ahk` (línea 3); `Schemas/_Plantilla_NuevaEmpresa.ahk` (línea 3); `Tests/Test_Validators.ahk` (línea 4); `Tests/Test_CaptureEngine.ahk` (línea 5); `Tests/Test_Schema.ahk` (línea 4)
- **Globales que define**: (ninguna)
- **Globales que usa (leídas)**: (ninguna)
- **Símbolos externos invocados**: `RegExMatch` (built-in), `Number` (built-in), `Abs` (built-in), `Format` (built-in)

## Notas técnicas (WHY no-obvio)

- **Firma `(val, cola)`**: `cola` es el array completo de valores actuales de todos los slots en el momento de la validación. Los validators atómicos (`ValidarNoVacio`, `ValidarNumero`, `ValidarFechaEstricta`) lo ignoran; `ValidarSumaCheck` lo usa para leer los summands por índice. Esta firma uniforme permite que `CaptureEngine` llame cualquier validator polimórficamente sin conocer su tipo.

- **Builder pattern con `.Bind()`**: `ValidarSumaTol` no ejecuta ninguna validación; solo fija `slotsIndices` y `tol` como primeros parámetros parciales de `ValidarSumaCheck`. El objeto `Func` resultante sí cumple la firma `(val, cola)`. Esto evita capturar variables en closures manuales, que en AHK v2 son más verbosas y propensas a errores de scope.

- **Semántica de skip**: si `cola.Length < maxIdx` (array más corto que el índice mayor referenciado) o si cualquier `cola[s]` es `""`, `ValidarSumaCheck` retorna `""` sin error. El contrato documentado en el header del archivo establece que un campo con dependencias omitidas no debe bloquearse. Esto es intencional: durante la captura, el usuario puede llegar al campo de suma antes de completar sus operandos.

- **Regex de fecha**: `^(0[1-9]|1[0-2])/(0[1-9]|[12]\d|3[01])/\d{4}$` no valida combinaciones imposibles (ej: `02/31/2024`). Es validación de formato, no de calendario. La corrección semántica la garantiza la aplicación destino (Asignet) al procesar la factura.

- **Regex de importe**: `^-?\d+(\.\d+)?$` acepta enteros negativos, positivos y decimales de precisión arbitraria. No limita cantidad de dígitos ni exige separador de miles, consistente con el formato de clipboard que genera Asignet.

- **Tolerancia por defecto `tol := 0.01`**: cubre el error de redondeo habitual en operaciones de punto flotante de dos decimales (ej: `1.10 + 2.20 = 3.3000000000000003`). Los schemas productivos no pasan `tol` explícitamente; usan el default.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (ninguno — `Lib/Validators.ahk` no contiene handlers de mouse ni referencias a M720)

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Borrados**: banner de sección `; --- Builder: validar suma de N slots con tolerancia ---` (línea 36 original); lista de categorías del banner principal (`Predicado base / Atomicos / Builders`) — redundante con el código.
  - **Colapsado**: banner principal de 11 líneas → 4 líneas; conserva firma uniforme y razón del polimorfismo (`CaptureEngine`).
  - **Reescritos (QUÉ → WHY)**:
    - Comentario de `ValidarSumaTol`: ahora documenta por qué `.Bind()` (evita closures manuales verbosas), por qué `tol := 0.01` (error de redondeo en sumas de dos decimales) y por qué el skip (el usuario puede llegar al campo de suma antes de completar los operandos).
    - Comentario inline en `ValidarFechaEstricta`: añadido (era WHY solo en `.md`); aclara que es validación de formato, no de calendario, y que Asignet garantiza la corrección semántica.
  - **Dudosos**: ninguno. `EsImporteValido`, `ValidarNoVacio` y `ValidarNumero` son autoexplicativos; no requieren comentario adicional.
  - **Sintaxis**: OK — `AutoHotkey64.exe /validate` sin errores.

### Fase 3 — dead code
- [x] Auditado 2026-05-12
- Borrados (0 referencias en producción + tests): **ninguno** — todas las funciones tienen referencias activas.
- Candidatos para review senior (NO borrados): **ninguno** — modo conservador, 0 dudosos.
- Resultado por función:
  - `EsImporteValido` — **USADO**: llamado desde `ValidarNumero` y `ValidarSumaCheck` internamente; 14 asserts directos en `Tests/Test_Validators.ahk`.
  - `ValidarNoVacio` — **USADO**: referenciado en `Schemas/AsignetHeaderV1.ahk` (slots 1 y 4), `Schemas/_Plantilla_NuevaEmpresa.ahk` (slots 1, 2, 4), `Tests/Test_CaptureEngine.ahk` (múltiples schemas mock) y `Tests/Test_Schema.ahk`.
  - `ValidarNumero` — **USADO**: referenciado en `Schemas/AsignetHeaderV1.ahk` (slots 5, 6, 8), `Schemas/_Plantilla_NuevaEmpresa.ahk` y `Tests/Test_CaptureEngine.ahk`.
  - `ValidarFechaEstricta` — **USADO**: referenciado en `Schemas/AsignetHeaderV1.ahk` (slots 2, 3), `Schemas/_Plantilla_NuevaEmpresa.ahk` y `Tests/Test_AsignetHeader.ahk`.
  - `ValidarSumaTol` — **USADO**: referenciado en `Schemas/AsignetHeaderV1.ahk` (slots 7, 9) y `Tests/Test_CaptureEngine.ahk`; 19 asserts indirectos vía `Tests/Test_Validators.ahk`.
  - `ValidarSumaCheck` — **INTERNO** (no DUDOSO): usado exclusivamente via `.Bind` dentro de `ValidarSumaTol` (`Lib/Validators.ahk:38`); grep externo da 0 callers directos por diseño. No es dead code.
- Sintaxis: OK — `AutoHotkey64.exe /validate` exit 0 (sin cambios al código fuente).

## Ideas de simplificación pendientes (input para plan posterior)

- `ValidarSumaCheck` podría extraerse a una función privada con prefijo `_` (`_ValidarSumaCheck`) para señalizar explícitamente que no es parte de la API pública; actualmente no hay convención de privacidad en este módulo.
- El skip por `cola.Length < maxIdx` y el skip por `cola[s] = ""` son dos condiciones distintas mezcladas en el mismo early-return implícito; separarlas con comentarios o en sub-funciones mejoraría la legibilidad del contrato de "skip".
- `ValidarFechaEstricta` podría aceptar un segundo argumento de formato configurable (ej: `"DD/MM/YYYY"`) para reutilizarse en schemas de otras regiones sin duplicar la función; hoy solo soporta `MM/DD/YYYY`.

### Fase 5 — polish

- [x] Auditado 2026-05-12
- Cambios aplicados: **ninguno** — el archivo ya cumple todos los criterios. Sin trailing whitespace, sin runs de 3+ líneas en blanco, indentación 4-space consistente, sin tabs, trailing newline único (LF), sin comentarios huérfanos sin contexto.
- Sintaxis: OK — `AutoHotkey64.exe /validate` exit 0.
