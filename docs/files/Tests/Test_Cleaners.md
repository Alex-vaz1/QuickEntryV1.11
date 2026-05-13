---
file: Tests/Test_Cleaners.ahk
last_review: 2026-05-12
status: active
---

# `Tests/Test_Cleaners.ahk`

## Propósito

Suite de tests unitarios para el módulo `Lib/Cleaners.ahk`. Ejercita las 9 funciones
públicas del módulo mediante `AssertEq` de `_AssertHelpers.ahk`. No instancia clases ni
tiene estado propio: cada línea es una llamada `AssertEq(función(input), esperado, label)`.
Cierra con `ReportarYSalir()` que emite el exit code para el runner.

## Cobertura por función

| Función fuente | Asserts | Casos cubiertos |
|---|---|---|
| `LimpiarFechaRobusta` | 64 | ISO (`yyyy-mm-dd`, `/`, `.`); US numérico largo y corto; mes texto 3 letras / completo (todos los 12); variante `Sept`/`Sept.`; ordinales (`1st`, `2nd`, `3rd`, `th`); day-first (`15 Sep 2026`, `15-Sep-2026`, `1st Sep`); basura prefijo/sufijo/ambos lados (OCR, día semana, español); strings inválidos (vacío, texto sin fecha, mes 13, día 32/0, mes texto inválido); fechas cortas sin año (usa `A_YYYY`); trailing-separator (`5/8/`, `5-8-`); edge cases (Feb 29 no-bisiesto acepta, Apr 31 acepta, formato ya correcto se preserva) |
| `NormalizarPrecio` | 31 | CR sufijo/prefijo/sin espacio/con `$`/minus; minus prefijo/sufijo/con espacio; `$-`, `- `; doble negativo sin cancelación; positivos US (`$1,234.56`), EU (`1.234,56`), entero, cero; basura no numérica (vacío, letras, solo `$`); EU multi-grupo; US multi-grupo; prefijos `USD`/`US$`; EU coma-decimal sin miles; paréntesis NO negativos |
| `LimpiarComoPegadoEspecial` | 8 | Delegación a fecha ISO, `Sept.` ordinal, day-first, basura OCR; vacío; solo espacios; precio US; CR negativo |
| `MesTextoANumero` | 33 | Los 12 meses: abreviado + completo (24 casos); `Sept` (4 letras); case insensitive MAYUS/minus/mixto (3 casos); punto y coma ignorados (`Sept.`, `Jan,`); vacío → 0; dígitos → 0; texto inválido → 0; español `Marzo` → 0 |
| `FormatearFecha` | 17 | Pad mes y día simple; sin pad necesario; expansión año 2→4 dígitos; año 4 dígitos preservado; acepta strings; mes 0 → `""`; mes 13 → `""`; día 0 → `""`; día 32 → `""`; mes no-número → `""`; día no-número → `""` |
| `FormatearFechaTexto` | 6 | Happy path; año vacío → `A_YYYY`; año 0 → `A_YYYY`; mes texto inválido → `""`; día inválido → `""`; mes completo (`September`) |
| `DetectarNegativo` | 14 | CR sufijo/prefijo/sin espacio; minus prefijo/`$-`/`- `/sufijo/sufijo con espacio; positivo simple/con `$`; paréntesis NO negativos; vacío → `false`; `CREDIT` (no whole-word CR) → `false`; `ACR` (no CR) → `false` |
| `ForzarNegativo` | 9 | Positivo a negativo; ya negativo se mantiene; cero `"0"` queda `"0"`; cero decimal `"0.00"` queda; cero multi-decimal; vacío pasa; no-número pasa tal cual; decimal simple; número grande |
| `LimpiarBillingItem` | 12 | Strip prefijo `Item:`, `Description:`, `DESC:` (case-insensitive), `Concepto:`, `Detalle:`; strip sufijo `Price:`, `Total:`, `Monto:`; strip dash final; strip dos puntos final; trim espacios; passthrough texto plano |
| **TOTAL** | **194** | |

## API expuesta (re-exports implícitos via `#Include`)

El archivo no define funciones propias. Al hacer `#Include "..\Lib\Cleaners.ahk"` y
`#Include "_AssertHelpers.ahk"`, hace disponibles en su scope todas las funciones de
ambos módulos. No hay exports propios.

## Dependencias

- **`#Include` directos**:
  - `"..\Lib\Cleaners.ahk"` (línea 4) — módulo bajo test
  - `"_AssertHelpers.ahk"` (línea 5) — harness de asserts y exit code
- **Incluido por**: nadie (es un ejecutable de test; el runner lo invoca directamente)
- **Globales que define**: ninguna propia (hereda `g_failures`, `g_total` de `_AssertHelpers`)
- **Globales que usa (leídas)**: `A_YYYY` (built-in AHK v2; usada directamente en asserts de fechas sin año, líneas 68–80, 264–269)
- **Símbolos externos invocados**: `AssertEq`, `ReportarYSalir` (de `_AssertHelpers.ahk`); toda la API de `Lib/Cleaners.ahk`

## Notas técnicas (WHY no-obvio)

- **`anioActual := SubStr(A_YYYY, 1)` (línea 264)**: la suite calcula el año corriente en
  tiempo de ejecución en lugar de hardcodearlo, de modo que los asserts de fechas sin año
  no caduquen al cambiar el año calendario. Las 4 líneas siguientes (266–269) usan esta
  variable en los expected.

- **Cobertura de `LimpiarFechaRobusta` (64 asserts)**: es la función con mayor superficie de
  riesgo (7 ramas de regex + validación de rangos). La suite la cubre con 9 grupos de
  subescenarios claramente delimitados por comentarios de sección. Los edge cases
  `"Feb 29 anio no-bisiesto"` y `"Apr 31"` documentan explícitamente que el módulo NO
  valida semántica del calendario (solo formato y rangos numéricos), delegando esa
  responsabilidad a Asignet.

- **Paréntesis no son negativos (líneas 139 y 228)**: tanto `NormalizarPrecio` como
  `DetectarNegativo` tienen asserts explícitos para `(1,234.56)` y `(100.00)` → positivos.
  Esto documenta una decisión de diseño: la notación contable de paréntesis NO se soporta
  como indicador de negativo.

- **`LimpiarBillingItem` sin callers productivos**: la función tiene 12 asserts propios pero
  ningún schema activo la usa. El test existe para preservar el contrato si se adopta en
  el futuro. Ver `docs/files/Lib/Cleaners.md` → Notas técnicas y Fase 3 del cleanup.

- **Orden de secciones**: el archivo agrupa los asserts en bloques separados por cabeceras de
  comentario `; ===...===`. El orden es: `LimpiarFechaRobusta` → `NormalizarPrecio` →
  `LimpiarComoPegadoEspecial` → `MesTextoANumero` → `FormatearFecha` →
  `FormatearFechaTexto` → `DetectarNegativo` → `ForzarNegativo` → `LimpiarBillingItem` →
  trailing-separator edge cases de `LimpiarFechaRobusta` (líneas 262–269, fuera de la
  sección principal).

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (no aplica — `Test_Cleaners.ahk` no contiene handlers de mouse ni referencias M720)

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Re-escrito** (QUÉ → WHY): `; --- Edge cases adicionales ---` (línea 85) expandido a
    bloque de 3 líneas que explica que `LimpiarFechaRobusta` no valida semántica de
    calendario (feb-29 no-bisiesto, Apr-31) y delega esa responsabilidad a Asignet upstream.
  - **Borrados**: ninguno — el archivo estaba limpio. Sin código comentado, sin TODOs, sin
    banners puramente decorativos, sin redundancias.
  - **Conservados sin cambios**: todos los banners de sección (`; ===...===`, 9 en total);
    todos los comentarios de sub-sección dentro de `LimpiarFechaRobusta` (fixture headers);
    el bloque `; Año actual se calcula dinámicamente...` (WHY explícito, línea 263);
    los sub-headers de `NormalizarPrecio` y `DetectarNegativo` (fixture/WHY implícito).
  - **Sintaxis validada**: `AutoHotkey64.exe /validate` sin errores.

### Fase 3 — dead code
- [ ] Auditado
- Borrados:
- Candidatos para review senior:
  - Los 12 asserts de `LimpiarBillingItem` (líneas 249–260) cubren una función sin callers productivos. Son tests válidos y deben mantenerse si se decide conservar la función. Si se retira `LimpiarBillingItem` en Fase 3, esta sección debe eliminarse junto con la función.

## Ideas de simplificación pendientes

- Los asserts de fechas sin año (líneas 68–80 y 264–269) están divididos en dos bloques no
  contiguos del archivo. Moverlos a un único bloque consolidado bajo `; --- Fechas sin
  año ---` reduciría la fricción cognitiva al leer la suite.
- Los 64 asserts de `LimpiarFechaRobusta` podrían parametrizarse con un array de pares
  `[input, expected, label]` iterado en un loop, siguiendo el mismo patrón que se propuso
  para refactorizar la función fuente. Reduciría el archivo de ~270 a ~180 líneas sin
  perder cobertura.
- La sección de trailing-separator (líneas 262–269) está colocada después de
  `ReportarYSalir()` — en realidad antes, en línea 271 — pero visualmente queda "fuera"
  de la sección `LimpiarFechaRobusta` principal. Moverla antes del bloque de inválidas
  o al final de esa sección mejoraría la legibilidad del flujo.
