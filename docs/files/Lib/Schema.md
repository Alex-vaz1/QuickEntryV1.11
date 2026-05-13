---
file: Lib/Schema.ahk
last_review: 2026-05-12
status: active
---

# `Lib/Schema.ahk`

## Propósito

Define los dos contratos de datos centrales del sistema: `Campo` (descriptor de un slot individual del formulario) e `InvoiceSchema` (conjunto ordenado de `Campo`s con metadatos de navegación y pegado). Es la hoja más pura del grafo de dependencias: no incluye ningún otro módulo y todos los módulos que trabajan con schemas dependen de él transitivamente.

## API pública

### Clases

#### **`Campo(name, clean, validate, tabsAfter := 1, skipPaste := false, expectedFn := "", expectedDeps := "", stepsAfter := "")`** — descriptor inmutable de un slot del formulario

- **Propiedades**:
  - `name` — `String`: display name del campo (ej. `"Invoice date"`, `"Past due"`).
  - `clean` — `Func`: `(raw:String) => limpio:String` — normaliza el valor capturado; devuelve `""` para rechazar.
  - `validate` — `Func`: `(val:String, cola:Array) => ""` si ok, o `String` con mensaje de error.
  - `tabsAfter` — `Integer` (default `1`): cantidad de `{Tab}` a enviar después de pegar este campo. Usado siempre por `Scan`; usado por `PasteBatch` sólo como fallback cuando `stepsAfter` está vacío.
  - `stepsAfter` — `Array` (default `[]`): pasos de navegación POST-campo para `PasteBatch`. Reemplaza a `tabsAfter` en `PasteBatch` cuando está definido. Elementos: `String` = `SendInput`, `Integer` = `Sleep(ms)`. Ejemplo: `["{Tab}", "{Tab}", "US", 1000, "{Tab}"]`.
  - `skipPaste` — `Boolean` (default `false`): si `true`, `PasteBatch` no pega el valor — sólo ejecuta los pasos de navegación. Útil para campos con lupa donde el operador hace clic manual.
  - `expectedFn` — `Func | ""` (default `""`): `(cola:Array) => "X.XX"` — calcula el valor esperado para mostrar en tooltip antes de copiar (slots tipo *Past due*, *Total w/ past due*).
  - `expectedDeps` — `Array<Integer>` (default `[]`): índices 1-based de los slots cuyos valores alimentan `expectedFn`. El tooltip los muestra como breakdown para que el operador verifique los inputs.

- **Métodos**:
  - `__New(name, clean, validate, tabsAfter := 1, skipPaste := false, expectedFn := "", expectedDeps := "", stepsAfter := "") → Campo` — constructor; normaliza `stepsAfter` y `expectedDeps` a `[]` si no son objetos.
    - Llamado desde: `Schemas/AsignetHeaderV1.ahk:58-73`, `Schemas/_Plantilla_NuevaEmpresa.ahk:94-110`, `Tests/Test_Schema.ahk:11,18,24,31,41`, `Tests/Test_CaptureEngine.ahk` (múltiples schemas inline).
    - Llama a: `IsObject()` (builtin AHK v2).

---

#### **`InvoiceSchema(name, fields, ordenPegado := "", prePasteSteps := "", preScanSteps := "")`** — colección ordenada de `Campo`s con metadatos de navegación

- **Propiedades**:
  - `name` — `String`: display name del schema (ej. `"Asignet Header v1"`).
  - `fields` — `Array<Campo>`: campos en orden de captura (1-based).
  - `ordenPegado` — `Array<Integer>`: orden de pegado al formulario (1-based). Default = `[1..N]` (igual al orden de captura).
  - `prePasteSteps` — `Array<String>`: pasos de `SendInput` a ejecutar **antes** de pegar el primer slot (navegación al form, selección de tipo, etc.). Default = `[]`.
  - `preScanSteps` — `Array<String>`: pasos de navegación previos al `HeaderScan`. Si vacío, `Scan` usa `prePasteSteps`. Útil cuando el form ya lleno tiene distinto tab-order que el form vacío. Default = `[]`.

- **Propiedades computadas**:
  - `Length` — `Integer` (getter): `this.fields.Length` — count de campos.
    - Llamado desde: `Lib/CaptureEngine.ahk` (múltiples sitios), `Lib/MainHud.ahk:216,542,945,981`, `Tests/Test_Schema.ahk:51,58`, `Tests/Test_CaptureEngine.ahk` (múltiples).

- **Métodos**:
  - `__New(name, fields, ordenPegado := "", prePasteSteps := "", preScanSteps := "") → InvoiceSchema` — constructor; si `ordenPegado` no es objeto o está vacío, auto-genera `[1..N]`; normaliza `prePasteSteps` y `preScanSteps` a `[]` si no son objetos.
    - Llamado desde: `Schemas/AsignetHeaderV1.ahk:101`, `Schemas/_Plantilla_NuevaEmpresa.ahk:132`, `Tests/Test_Schema.ahk:49,57,65`, `Tests/Test_CaptureEngine.ahk` (múltiples schemas inline).
    - Llama a: `IsObject()` (builtin AHK v2), `Array.Push()`.

  - `Field(slot) → Campo` — devuelve el campo en la posición `slot` (1-based). Lanza `ValueError("slot fuera de rango: <slot>")` si `slot < 1` o `slot > fields.Length`.
    - Llamado desde: `Lib/CaptureEngine.ahk` (múltiples sitios), `Lib/MainHud.ahk:230,650`, `Tests/Test_Schema.ahk:52,53`, `Tests/Test_CaptureEngine.ahk` (múltiples).
    - Llama a: `ValueError` (builtin AHK v2).

## Dependencias

- **#Include directos**: ninguno (hoja del DAG).
- **Incluido por**:
  - `QuickEntry.ahk:4` (vía `#Include "Lib\Schema.ahk"`)
  - `Lib/CaptureEngine.ahk:2` (vía `#Include "Schema.ahk"`)
  - `Schemas/AsignetHeaderV1.ahk:4` (vía `#Include "..\Lib\Schema.ahk"`)
  - `Schemas/_Plantilla_NuevaEmpresa.ahk:4` (vía `#Include "..\Lib\Schema.ahk"`)
  - `Tests/Test_Schema.ahk:5` (vía `#Include "..\Lib\Schema.ahk"`)
- **Globales que define**: ninguna.
- **Globales que usa (leídas)**: ninguna.
- **Símbolos externos invocados**: `IsObject()`, `ValueError` (builtins AHK v2).

## Notas técnicas (WHY no-obvio)

- **`stepsAfter` vs `tabsAfter`: contrato de dos velocidades.** `tabsAfter` es el mecanismo simple (N tabs uniformes); `stepsAfter` es el mecanismo expresivo para formularios donde un campo ocupa múltiples controles o requiere interacción (selects, sleeps, Enter). `PasteBatch` usa `stepsAfter` cuando está presente; `Scan` siempre usa `tabsAfter` porque el form ya lleno no necesita interacción extra (sólo lectura).

- **`skipPaste` sin omitir la navegación.** Cuando `skipPaste = true`, `PasteBatch` salta el pegado del valor pero igual ejecuta los pasos de navegación (`stepsAfter` o N tabs). Esto permite que el operador haga clic manual en un campo con lupa mientras la automatización avanza al siguiente campo.

- **`ordenPegado` desacopla captura de pegado.** El operador puede capturar valores en el orden en que aparecen en el PDF (orden de lectura) y el schema define un orden de pegado diferente (orden del formulario). `CaptureEngine` accede a los slots por índice de captura (`fields[i]`), pero `PasteBatch` itera en `ordenPegado`.

- **`preScanSteps` como override de `prePasteSteps` para `Scan`.** En el form vacío, el tab-order puede diferir del form ya lleno (ej. un campo `Type of Document` es editable en form vacío pero readonly en form lleno, cambiando cuántos tabs se necesitan para posicionarse). `preScanSteps` permite especificar la navegación inicial correcta para cada contexto sin duplicar el schema.

- **`expectedDeps` vacío = comportamiento previo con flechas.** Cuando `expectedDeps = []`, el tooltip no muestra breakdown de inputs; cuando tiene índices, el tooltip los muestra abajo del prompt para que el operador verifique los valores que alimentan el cálculo.

- **`Field(slot)` lanza `ValueError` en vez de retornar `""`.** La falla silenciosa en acceso out-of-range sería difícil de debuggear en un flujo de pegado automatizado. `ValueError` sube hasta el catch del caller (`CaptureEngine`, `MainHud`) que lo registra y muestra al usuario.

- **Sin dependencias: diseño intencional.** `Schema.ahk` no incluye `Cleaners.ahk` ni `Validators.ahk` porque las funciones `clean` y `validate` se pasan como callbacks al constructor de `Campo`. El schema es un contrato de datos puro; la lógica vive en los módulos que lo consumen.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Reescritura `expectedDeps`**: reemplazado "comportamiento previo: previo con flechas" (referencia interna opaca) por WHY explícito: "el operador solo ve el total esperado, sin saber de donde vienen los sumandos (menos contexto)".
  - **Reescritura `prePasteSteps`**: reemplazado descripción WHAT genérica por WHY: "la posición del cursor al abrir el form no es determinista; estos pasos normalizan el punto de partida antes de que PasteBatch empiece a iterar los campos".
  - Sin banners eliminados (el único banner existente es el contrato docblock; dentro del límite de 2).
  - Sin código comentado ni TODOs obsoletos encontrados.
  - Sintaxis validada: AHK v2 `/validate` → exit code 0, sin errores.

### Fase 3 — dead code
- [x] Auditado 2026-05-12
- Borrados (0 referencias en producción + tests): ninguno — 0 símbolos muertos encontrados.
- Candidatos para review senior (NO borrados): ninguno.
- Resultado auditado símbolo a símbolo (grep cruzado):
  - **Campo.name** — USADO: CaptureEngine ×8, TooltipFormatter ×3, MainHud, Tests.
  - **Campo.clean** — USADO: CaptureEngine ×3, Tests.
  - **Campo.validate** — USADO: CaptureEngine ×1, Tests.
  - **Campo.tabsAfter** — USADO: CaptureEngine (`Loop campo.tabsAfter`), Tests.
  - **Campo.stepsAfter** — USADO: CaptureEngine (`.Length > 0`, `for paso in`).
  - **Campo.skipPaste** — USADO: CaptureEngine ×2, Tests.
  - **Campo.expectedFn** — USADO: CaptureEngine ×2 (`IsObject` guard + `.Call`), Tests.
  - **Campo.expectedDeps** — USADO: TooltipFormatter (`campo.expectedDeps`), Tests.
  - **InvoiceSchema.name** — USADO: Tests (Test_Schema, Test_AsignetHeader).
  - **InvoiceSchema.fields** — USADO: sólo internamente (backing store de `Field()` y `Length`); diseño intencional — nunca accedido como `.fields[x]` desde afuera.
  - **InvoiceSchema.ordenPegado** — USADO: CaptureEngine ×2, Tests.
  - **InvoiceSchema.prePasteSteps** — USADO: CaptureEngine ×2, Tests.
  - **InvoiceSchema.preScanSteps** — USADO: CaptureEngine (`.Length > 0` + fallback), Tests.
  - **InvoiceSchema.Length** (getter) — USADO: CaptureEngine ×7+, MainHud ×3, TooltipFormatter ×3, Tests.
  - **InvoiceSchema.Field(slot)** — USADO: CaptureEngine ×8, MainHud ×2, TooltipFormatter ×2, Tests.
- Sintaxis validada: AHK v2 `/validate` → exit code 0, sin errores.

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno — archivo ya cumplía todos los criterios.
  - Trailing whitespace: 0 líneas afectadas.
  - Blank lines 3+: ninguna run detectada (máximo 2 líneas en blanco consecutivas entre clases).
  - Indentación: todas las líneas de código usan múltiplos exactos de 4 espacios.
  - Trailing newline: archivo termina con LF único (last byte = 0x0A).
  - Comentarios huérfanos: ninguno — el único bloque de comentario es el docblock de contrato en líneas 2-46, dentro del límite permitido.
- Sintaxis validada: AHK v2 `/validate` → exit code 0, sin errores.

## Ideas de simplificación pendientes (input para plan posterior)

- El constructor de `Campo` acepta `expectedDeps` como posición 7 y `stepsAfter` como posición 8, pero ambos son opcionales y rara vez se pasan juntos. Considerar migrar a un único parámetro `options := Map()` para reducir la firma larga y evitar pasar `""` como placeholder en posiciones intermedias (ej. `Campo("X", fn, fn, 1, false, "", "", steps)`).
- `InvoiceSchema.__New` hace la auto-generación de `ordenPegado` en el constructor. Si en el futuro se necesita un schema con orden dinámico (reordenable en runtime), este diseño requeriría un setter o método de mutación; documentar como invariante que `ordenPegado` es inmutable post-construcción.
- `Field(slot)` no tiene caché: cada llamada hace la validación de bounds. Para schemas con muchos accesos en loops del HUD (`MainHud.ahk` lo llama en múltiples iteraciones de render), podría reemplazarse por acceso directo a `this.fields[slot]` cuando el caller ya validó bounds (o simplificar el contrato de lanzar a una precondición documentada).
