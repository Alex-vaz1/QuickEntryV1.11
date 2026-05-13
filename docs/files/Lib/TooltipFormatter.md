---
file: Lib/TooltipFormatter.ahk
last_review: 2026-05-12
status: active
---

# `Lib/TooltipFormatter.ahk`

## Propósito
Convierte el estado de un `CaptureEngine` en texto de tooltip de 2-3 líneas para mostrar al operador. Contiene exclusivamente funciones puras (sin side effects, sin llamadas a `ToolTip()`): toda la lógica de presentación está aquí; la decisión de cuándo mostrar el tooltip queda en el caller.

## API pública

### Funciones libres

- **`EnNegrita(valor) → String`** — envuelve `valor` entre flechas Unicode ▶ … ◀ para énfasis visual
  - Llamado desde: `Lib/TooltipFormatter.ahk:59` (interno, por `LineaPrevio`)
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:17-19`
  - Llama a: `Chr()` (built-in AHK)

- **`LineaPrompt(engine) → String`** — genera la línea 1: prompt del próximo slot (`Busca "X" (n/N)`) o mensaje de "Listo" si el engine está completo; incluye el valor esperado si el slot tiene `expectedDeps`
  - Llamado desde: `Lib/TooltipFormatter.ahk:93` (interno, por `TooltipPostAccion`)
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:151, 270`
  - Llama a: `engine.IsComplete`, `engine.FilledCount`, `engine.schema.Length`, `engine.NextSlot`, `engine.schema.Field()`, `engine.ExpectedFor()`

- **`LineaPrevio(engine, accion := "", valorOverride := "") → String`** — genera la línea de feedback del slot recién actuado; formato C: `▶ valor ◀ (NombreCampo)`; devuelve `""` si `actionLog` está vacío
  - Llamado desde: `Lib/TooltipFormatter.ahk:99` (interno, por `TooltipPostAccion`)
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:35, 290, 300, 309`
  - Llama a: `engine.actionLog`, `engine.schema.Field()`, `engine.queue[]`, `EnNegrita()`

- **`LineasOperandos(engine) → String`** — genera las líneas de breakdown de los inputs del cálculo del próximo slot (cuando tiene `expectedDeps`); devuelve `""` si no hay deps o el engine está completo
  - Llamado desde: `Lib/TooltipFormatter.ahk:95` (interno, por `TooltipPostAccion`)
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:159, 168, 178, 189`
  - Llama a: `engine.IsComplete`, `engine.NextSlot`, `engine.schema.Field()`, `campo.expectedDeps`, `engine.queue[]`

- **`TooltipPostAccion(engine, accion := "", valorOverride := "") → String`** — tooltip completo para el flujo normal: línea 1 = prompt del próximo slot; línea 2 = operandos (si hay `expectedDeps`) o feedback del slot previo; es la función principal consumida por los callers externos
  - Llamado desde: `QuickEntry.ahk` (vía `Lib/MainHud.ahk`)
  - Llamado desde: `Lib/TooltipFormatter.ahk:115` (interno, por `TooltipConError`)
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:30, 41, 59, 66, 69, 73, 82, 99, 110, 124, 136, 258`
  - Llama a: `LineaPrompt()`, `LineasOperandos()`, `LineaPrevio()`

- **`TooltipError(label, mensajeValidacion) → String`** — formatea un mensaje de error de validación con nombre de campo (no número de slot): `"<label> invalido: <mensajeValidacion>"`
  - Llamado desde: `QuickEntry.ahk:114`
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:207, 231, 242, 245, 248`
  - Llama a: (ninguno)

- **`LineaInputInvalido(hotkeyOmitir) → String`** — genera la línea genérica de instrucción cuando el input fue rechazado: `"Input invalido, recopia o <hotkeyOmitir> para omitir"`; el hotkey es configurable para no hardcodear la tecla
  - Llamado desde: `Lib/TooltipFormatter.ahk:119` (interno, por `TooltipConError`)
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:196, 197`
  - Llama a: (ninguno)

- **`TooltipConError(engine, detalle, hotkeyOmitir) → String`** — tooltip completo cuando una captura es inválida: mantiene el contexto visible (prompt + previo/operandos) y agrega opcionalmente el detalle específico de validación más la línea genérica de instrucción; `detalle = ""` para rechazos del cleaner
  - Llamado desde: `QuickEntry.ahk:115`
  - Llamado desde (tests): `Tests/Test_TooltipFormatter.ahk:208, 215, 221, 232`
  - Llama a: `TooltipPostAccion()`, `LineaInputInvalido()`

## Dependencias

- **#Include directos**: `CaptureEngine.ahk`
- **Incluido por**: `QuickEntry.ahk` (línea 6), `Lib/MainHud.ahk` (línea 3), `Tests/Test_TooltipFormatter.ahk` (línea 4)
- **Globales que define**: ninguna
- **Globales que usa (leídas)**: ninguna
- **Símbolos externos invocados**: `CaptureEngine` (instancia recibida como parámetro `engine`), `engine.IsComplete`, `engine.FilledCount`, `engine.NextSlot`, `engine.ExpectedFor()`, `engine.schema.Field()`, `engine.schema.Length`, `engine.actionLog`, `engine.queue[]`, `campo.expectedDeps`

## Notas técnicas (WHY no-obvio)

- **Diseño de 2-3 líneas intencional**: el tooltip tiene un máximo de 3 líneas para no tapar la pantalla del sistema ERP que el operador tiene detrás. Línea 1 siempre es el prompt del próximo slot; líneas 2-3 son contexto.
- **`LineasOperandos` reemplaza a `LineaPrevio` (no se acumulan)**: cuando el próximo slot tiene `expectedDeps` (ej: "Past due w/ Total"), mostrar los operandos es más informativo que el feedback del slot anterior — los operandos ya incluyen los valores previos relevantes. Por eso `TooltipPostAccion` hace un `if/else` y nunca muestra ambas cosas a la vez.
- **Formato C en `LineaPrevio` (valor primero, nombre entre paréntesis)**: si se mostrara `NombreCampo: valor`, el operador lee primero el nombre y busca mentalmente ese campo de nuevo ("¿ya lo llené?"). El formato `▶ valor ◀ (Nombre)` pone el dato relevante al frente y el nombre como confirmación secundaria.
- **`TooltipError` usa `label` (nombre de campo), no número de slot**: el número de slot es un detalle de implementación. El operador trabaja con nombres de campo del formulario, no con índices numéricos.
- **`detalle = ""` en `TooltipConError` = rechazo del cleaner**: cuando el cleaner descarta silenciosamente un input (ej: string no numérico cuando se espera un número), no hay mensaje de validación estructurado, solo la instrucción genérica de la línea final.
- **Funciones puras**: ninguna función en este módulo llama a `ToolTip()`, modifica estado, ni tiene side effects. Esto es deliberado para que sean testeables sin GUI y reutilizables en cualquier contexto de presentación.
- **`EnNegrita` usa `Chr(0x25B6)` / `Chr(0x25C0)`**: caracteres Unicode ▶ y ◀ — garantizan que el énfasis visual sea inmune a encodings de clipboard y a la fuente (Segoe UI los tiene). No se usan `*`, `**` ni ANSI bold (AHK ToolTip no soporta markup).

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - BORRADO: `; --- Linea 1: prompt del proximo slot (o "Listo" si completo) ---` (WHAT puro; nombre `LineaPrompt` es autoexplicativo; WHY del layout ya está en el header)
  - BORRADO: `; --- Lineas de operandos: breakdown de los inputs del calculo del proximo slot ---` (WHAT puro; `LineasOperandos` autoexplicativo)
  - BORRADO: `; --- Tooltip completo (prompt + breakdown si hay deps, sino prompt + previo) ---` (WHAT puro; el header describe el layout completo)
  - REESCRITO: `; --- Helper visual: marca de "negrita" con flechas Unicode ---` → 2 líneas WHY: por qué Unicode ▶/◀ (inmunidad a encodings + Segoe UI) y por qué no asteriscos (AHK ToolTip no soporta markup)
  - CONSERVADOS: comentario de `LineaPrevio` (Formato C WHY), `TooltipError` (nombre no slot), `LineaInputInvalido` (hotkey configurable), `TooltipConError` (detalle vacío = cleaner), header block de layout

### Fase 3 — dead code
- [x] Auditado 2026-05-12
- Borrados (0 referencias en producción + tests): **ninguno** — todas las funciones tienen al menos una referencia real.
- Candidatos para review senior (NO borrados):
  - **`TooltipPostAccion`** — 0 callers directos desde `QuickEntry.ahk` (el HUD tomó ese rol vía `hud.Update()`). Sí es caller interno de `TooltipConError` (línea 113), y tiene 12 tests directos. DECISIÓN: DUDOSO — API pública testeada; sigue activa como punto de entrada para integraciones futuras y como bloque interno de `TooltipConError`. No borrar.
  - **`valorOverride` (parámetro de `LineaPrevio` y `TooltipPostAccion`)** — ningún caller productivo lo pasa con valor no-vacío; solo tests lo ejercitan. Candidato a simplificación de firma en Fase 4 (ver Ideas de simplificación). No borrar en modo conservador.

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno. Trailing whitespace: 0. Blank runs 3+: 0. Tabs: 0. Indentación (4-space múltiplos): ok. Trailing newline único: ok. Comentarios huérfanos: 0 (todos los comentarios sueltos son WHY no-obvio conservados en Fase 2 o el header block de layout).

## Ideas de simplificación pendientes (input para plan posterior)
- `LineasOperandos` y `LineaPrevio` podrían unificarse en una sola función `LineaContexto(engine) → String` con la misma lógica de prioridad interna; reduciría la superficie pública de 8 a 6 símbolos y haría explícita la relación de exclusión.
- `LineaInputInvalido` es una fat arrow de una línea llamada solo desde `TooltipConError`; podría inlinearse dentro de `TooltipConError` para eliminar un símbolo público que no tiene valor semántico independiente (a evaluar: los tests la ejercen directamente, lo que es un argumento para mantenerla separada).
- El parámetro `valorOverride` en `LineaPrevio` / `TooltipPostAccion` no tiene callers que lo pasen con valor no-vacío en producción (solo tests); si confirma en Fase 3, candidato a borrar para simplificar la firma.
