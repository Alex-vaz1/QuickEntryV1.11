---
file: Schemas/_Plantilla_NuevaEmpresa.ahk
last_review: 2026-05-12
status: template-only
---

# `Schemas/_Plantilla_NuevaEmpresa.ahk`

## Propósito

Plantilla de referencia para crear el schema de header de factura de una empresa nueva. **No tiene callers en producción**: no está incluida en `QuickEntry.ahk` ni en ningún test, y no forma parte del grafo de ejecución activo. Su rol es exclusivamente documental y de punto de partida: se copia a `Schemas/<MiEmpresa>HeaderV1.ahk`, se renombra la función constructora, se ajustan los campos, y se registra el nuevo schema en el entry point. Ver procedimiento completo en [`docs/AGREGAR_EMPRESA.md`](../../AGREGAR_EMPRESA.md).

## API pública

### Funciones libres

- **`CrearMiEmpresaHeaderV1() → InvoiceSchema`** — construye y devuelve un `InvoiceSchema` de ejemplo con 6 `Campo` variados que ilustran los casos de uso más comunes: campo de texto simple, campo con lupa (`skipPaste`), fecha con validación estricta, campo doble (`tabsAfter 2`), monto numérico y monto forzado a negativo. Incluye en comentarios el patrón completo con `expectedFn`/`expectedDeps`, `ordenPegado` y `prePasteSteps`.
  - Llamado desde: **ninguno** (plantilla pura sin callers)
  - Llama a: `Campo` (×6, `Lib/Schema.ahk`), `InvoiceSchema` (`Lib/Schema.ahk`), `PlantCleanRaw`, `PlantCleanPaso`, `PlantCleanForzarNeg`, `ValidarNoVacio`, `ValidarFechaEstricta`, `ValidarNumero`

### Helpers internos (file-scope, no expuestos fuera del archivo)

- **`PlantCleanRaw(raw) → raw`** — passthrough; para campos donde el form acepta el valor literal (ej. filtros con lupa, códigos de referencia). Equivalente a `CleanRaw` en `AsignetHeaderV1.ahk`.
  - Llamado desde: `CrearMiEmpresaHeaderV1()` como argumento `clean` del slot 2 (Cliente)
  - Llama a: (ninguno)

- **`PlantCleanPaso(raw) → String`** — delega a `LimpiarComoPegadoEspecial(raw)`; normaliza fechas, precios y texto según el tipo detectado.
  - Llamado desde: `CrearMiEmpresaHeaderV1()` como `clean` de los slots 1, 3, 4 y 5
  - Llama a: `LimpiarComoPegadoEspecial` (`Lib/Cleaners.ahk`)

- **`PlantCleanForzarNeg(raw) → String`** — igual que `PlantCleanPaso` pero fuerza el resultado a negativo; para campos que representan egresos (descuentos, pagos).
  - Llamado desde: `CrearMiEmpresaHeaderV1()` como `clean` del slot 6 (Descuento)
  - Llama a: `LimpiarComoPegadoEspecial` (`Lib/Cleaners.ahk`), `ForzarNegativo` (`Lib/Cleaners.ahk`)

- **`PlantSuma(slotsIdx, cola) → String`** — suma los valores en `cola` en las posiciones indicadas por `slotsIdx` (1-based); devuelve `""` si alguna posición está vacía o `cola` es más corta que el índice máximo. Formatea con `{:.2f}`. Equivalente a `EsperadoSuma` en `AsignetHeaderV1.ahk`; se usa como base para `expectedFn` de campos con totales calculados (ver comentario slot 7 en el archivo fuente).
  - Llamado desde: ninguno activo (sólo referenciado en comentario de ejemplo dentro del archivo)
  - Llama a: `Number`, `Format` (built-ins AHK v2)

## Dependencias

- **#Include directos**: `..\Lib\Cleaners.ahk` (línea 2), `..\Lib\Validators.ahk` (línea 3), `..\Lib\Schema.ahk` (línea 4)
- **Incluido por**: (ninguno — plantilla pura, no tiene callers en producción ni en tests)
- **Globales que define**: (ninguna)
- **Globales que usa (leídas)**: (ninguna)
- **Símbolos externos invocados**:
  - `LimpiarComoPegadoEspecial` (de `Lib/Cleaners.ahk`) — vía `PlantCleanPaso` y `PlantCleanForzarNeg`
  - `ForzarNegativo` (de `Lib/Cleaners.ahk`) — vía `PlantCleanForzarNeg`
  - `ValidarNoVacio` (de `Lib/Validators.ahk`) — slots 1, 2 y 4
  - `ValidarFechaEstricta` (de `Lib/Validators.ahk`) — slot 3
  - `ValidarNumero` (de `Lib/Validators.ahk`) — slots 5 y 6
  - `Campo` (de `Lib/Schema.ahk`) — constructor de cada campo (×6 activos + 1 comentado)
  - `InvoiceSchema` (de `Lib/Schema.ahk`) — constructor del schema completo

## Notas técnicas (WHY no-obvio)

- **Archivo de uso como plantilla de copia, no de include.** A diferencia de los schemas de empresa activos, este archivo nunca se incluye desde `QuickEntry.ahk`. El procedimiento correcto es copiar todo el archivo, renombrar la función `CrearMiEmpresaHeaderV1` con el nombre de la empresa nueva, y ajustar la lista `fields`. El `#Include` se agrega en `QuickEntry.ahk` sólo después de completar y testear el nuevo schema.

- **El docblock (líneas 7–54) es la documentación operativa.** Explica los cinco pasos para usar la plantilla, el contrato completo de `Campo` (cada propiedad con su tipo y semántica) y el contrato de `InvoiceSchema` (incluyendo `ordenPegado` y `prePasteSteps`). También lista todos los cleaners y validators disponibles en `Lib/`. Actualizar este docblock al agregar nuevos cleaners o validators mantiene la plantilla como referencia de onboarding.

- **Slot 7 comentado ilustra `expectedFn` + `expectedDeps`.** El `Campo("Total", ...)` comentado (líneas 116-117) muestra el patrón completo para campos con totales calculados: `ValidarSumaTol`, `expectedFn` como lambda, y `expectedDeps` como array de slots. El comentario en línea explica qué muestra el tooltip cuando `expectedDeps` tiene índices.

- **`PlantSuma` es código activo aunque sin callers.** La función existe en el archivo compilable (no en comentario) para que `AutoHotkey64.exe /validate` la valide y para que al copiar la plantilla el adoptante tenga el helper listo sin escribirlo. Si se activa el slot 7 comentado, `PlantSuma` se conecta sin cambios adicionales.

- **`ordenPegado` y `prePasteSteps` en comentario.** Las líneas 123 y 130 muestran las declaraciones con valores de ejemplo. Están comentadas porque la mayoría de schemas simples no los necesitan; el adoptante sólo las descomenta y pasa las variables al constructor de `InvoiceSchema` cuando el form requiere reordenamiento o navegación previa.

- **Cleaners disponibles listados en el docblock (no todos usados en el ejemplo).** `LimpiarBillingItem` aparece en el docblock (línea 48) como cleaner disponible pero ningún campo de la plantilla lo usa. Es una referencia de catálogo, no una dependencia activa.

## Campos declarados (resumen tabular)

| # | Nombre | Clean | Validate | tabsAfter | skipPaste | expectedFn | expectedDeps |
|---|---|---|---|---|---|---|---|
| 1 | Numero factura | `PlantCleanPaso` | `ValidarNoVacio` | 1 | false | — | — |
| 2 | Cliente | `PlantCleanRaw` | `ValidarNoVacio` | 1 | true | — | — |
| 3 | Fecha emision | `PlantCleanPaso` | `ValidarFechaEstricta` | 1 | false | — | — |
| 4 | Concepto | `PlantCleanPaso` | `ValidarNoVacio` | 2 | false | — | — |
| 5 | Subtotal | `PlantCleanPaso` | `ValidarNumero` | 1 | false | — | — |
| 6 | Descuento | `PlantCleanForzarNeg` | `ValidarNumero` | 1 | false | — | — |
| 7 | Total *(comentado)* | `PlantCleanPaso` | `ValidarSumaTol([5,6])` | 1 | false | `PlantSuma([5,6], cola)` | `[5, 6]` |

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios (2026-05-12)
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno
- Criterio aplicado:
  - Docblock líneas 7–54: cohesivo y operativo → conservado entero
  - Banners decorativos `====`: 2 bloques (docblock + sección declarativa) → dentro del límite máx 2
  - Ejemplos comentados de Campo (slots 1–6 con encabezado descriptivo, slot 7 completo): patrón a copiar → conservados
  - `ordenPegado` y `prePasteSteps` en comentario (líneas 121–130): ejemplos pedagógicos con valores concretos → conservados
  - `; Con extras:` + return comentado (líneas 133–134): muestra activación de parámetros opcionales → conservado
  - `; Ejemplo: PlantExpectedSlotN(cola)` (línea 83): referencia de uso de `PlantSuma` → conservado
  - Encabezados de sección `; --- Cleaners locales`, `; --- Helpers de "esperado"`: orientan al adoptante → conservados
  - TODOs viejos: ninguno encontrado
  - Código comentado no pedagógico: ninguno encontrado

### Fase 3 — dead code (2026-05-12)
- [x] Auditado 2026-05-12
- Borrados: ninguno
- Criterio aplicado:
  - CASO ESPECIAL: archivo es plantilla pedagógica. Cero callers en producción es el estado correcto y esperado — no es dead code.
  - `PlantCleanRaw`, `PlantCleanPaso`, `PlantCleanForzarNeg`: todos usados dentro de `CrearMiEmpresaHeaderV1()` como argumentos `clean` de sus slots respectivos. Coherencia pedagógica completa.
  - `PlantSuma`: sin callers activos, pero documentado en Notas técnicas (línea 62 del .md) con razón explícita: (a) pasa `/validate` para que el adoptante sepa que es código real, (b) el slot 7 comentado lo referencia como `expectedFn`, conectando el helper con su uso concreto. Coherencia pedagógica completa.
  - Slot 7 comentado (`Campo("Total", ...)`): usa `PlantSuma` y `ValidarSumaTol` — la relación helper→ejemplo está trazada dentro del archivo. Nada queda huérfano.
  - `ordenPegado` y `prePasteSteps` en comentario (líneas 121–130): ejemplos con valores concretos y explicación en docblock. Conservados.
- Candidatos para review senior (NO borrados): ninguno
- Sintaxis: `AutoHotkey64.exe /validate` → exit code 0

### Fase 5 — polish (2026-05-12)
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno
- Criterio aplicado:
  - Trailing whitespace: 0 ocurrencias
  - Líneas en blanco consecutivas 4+: ninguna (máximo 1 línea en blanco entre secciones)
  - Trailing newline: exactamente 1 `\n` final (correcto)
  - Sintaxis: `AutoHotkey64.exe /validate` → exit code 0

## Ideas de simplificación pendientes (input para plan posterior)

- `PlantSuma` duplica el mismo patrón que `EsperadoSuma` en `AsignetHeaderV1.ahk`. Extraer ambas a un helper genérico en `Lib/Validators.ahk` o `Lib/Schema.ahk` eliminaría la duplicación y reduciría el riesgo de que las dos implementaciones diverjan al agregar nuevas empresas.
- El docblock (líneas 7–54) es extenso y parte de su contenido ya está en `docs/AGREGAR_EMPRESA.md`. Evaluar si el docblock puede reducirse a los contratos de `Campo` e `InvoiceSchema` (lo que no tiene otra fuente canónica) y referenciar `AGREGAR_EMPRESA.md` para el procedimiento de adopción.
- `PlantCleanRaw`, `PlantCleanPaso` y `PlantCleanForzarNeg` replican el mismo patrón de wrappers thin que `CleanRaw`, `CleanPasoPegado` y `CleanPasoPegadoForzandoNegativo` de `AsignetHeaderV1.ahk`. Si `EsperadoSuma` se mueve a `Lib/`, considerar mover también estos tres wrappers como helpers exportados de `Lib/Cleaners.ahk` para que los schemas nuevos no necesiten redefinirlos.
