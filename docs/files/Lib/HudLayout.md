---
file: Lib/HudLayout.ahk
last_review: 2026-05-12
status: active
---

# `Lib/HudLayout.ahk`

## Propósito

Módulo puro de decisiones de layout para el MainHud. No tiene estado, no crea GUI, no llama a Windows API. Provee lookup tables de etiquetas por slot y por botón (full vs compact), el ancho de la columna de nombres, y la lógica de visibilidad de rectángulos contra monitores. Está separado de MainHud para poder testearse sin instanciar ninguna ventana.

## API pública

### Clases

- **`HudLayout`** — clase estática (sin instancias), agrupa todo el módulo de layout
  - **Propiedades**:
    - `static breakpoint := 540` — umbral de píxeles para el modo compact
    - `static slotLabels` — `Map` privado: slot index → `Map("full", ..., "compact", ...)` con 9 entradas (slots 1–9)
    - `static buttonLabels` — `Map` privado: button id string → `Map("full", ..., "compact", ...)` con 11 entradas
  - **Métodos**:
    - `static IsCompact(width) → Boolean` — retorna `true` si `width < breakpoint` (540)
      - Llamado desde: `Lib/MainHud.ahk:497`, `Lib/MainHud.ahk:671`
      - Llama a: ninguno
    - `static LabelForSlot(idx, isCompact) → String` — retorna la etiqueta del slot `idx` en modo full o compact; retorna `""` si `idx` no existe en `slotLabels`
      - Llamado desde: `Lib/MainHud.ahk:380`
      - Llama a: ninguno
    - `static LabelForButton(buttonId, isCompact) → String` — retorna la etiqueta del botón `buttonId` en modo full o compact; retorna `"?"` si `buttonId` no existe en `buttonLabels`
      - Llamado desde: `Lib/MainHud.ahk:396`, `Lib/MainHud.ahk:406`, `Lib/MainHud.ahk:534`, `Lib/MainHud.ahk:540`, `Lib/MainHud.ahk:928`
      - Llama a: ninguno
    - `static NameColWidth(isCompact) → Integer` — retorna `100` (compact) o `200` (normal)
      - Llamado desde: `Lib/MainHud.ahk:410`
      - Llama a: ninguno
    - `static IsRectVisibleAgainst(x, y, w, h, monitorsArray) → Boolean` — retorna `true` si al menos 100×100 px del rectángulo `(x, y, w, h)` interseca algún monitor de `monitorsArray`; `monitorsArray` es `Array<Map>` con keys `"l"`, `"t"`, `"r"`, `"b"` (work area)
      - Llamado desde: `Lib/MainHud.ahk:119`, `Lib/MainHud.ahk:147`
      - Llama a: ninguno (módulo puro — el caller le pasa los rectángulos)

### Funciones libres

(ninguna — todo es estático dentro de `HudLayout`)

## Dependencias

- **#Include directos**: ninguno
- **Incluido por**: `Lib/MainHud.ahk:5` (`#Include "HudLayout.ahk"`)
- **Incluido en tests por**: `Tests/Test_HudLayout.ahk:4` (`#Include "..\Lib\HudLayout.ahk"`)
- **Globales que define**: ninguna
- **Globales que usa (leídas)**: ninguna
- **Símbolos externos invocados**: ninguno

## Notas técnicas (WHY no-obvio)

- **Módulo puro por diseño**: `IsRectVisibleAgainst` no llama a `MonitorGetWorkArea` aunque podría hacerlo. El caller (`MainHud.EnumMonitorsForLayout`) obtiene los rectángulos de la Windows API y los pasa como parámetro. Esto permite testear la lógica de intersección sin depender del entorno de pantallas del sistema — los tests cubren multi-monitor con arrays sintéticos.
- **Breakpoint exclusivo en 540**: `width < 540` → compact; `width >= 540` → normal. El valor 540 fue calibrado para que "Invoice Total Including PastDue" (el label más largo del schema, slot 9) quepa en la columna de nombres (200 px en Segoe UI s9 + ~12 px de padding).
- **NameColWidth normal = 200**: dimensionado para el label más largo del schema (`"Invoice Total Including PastDue"`). Compact = 100 cubre los nombres abreviados como `"Acct #"`.
- **minVisible = 100**: el umbral de 100×100 px en `IsRectVisibleAgainst` evita falsos positivos donde la ventana quedó casi totalmente fuera de pantalla al desconectar un monitor externo. Solo se acepta una intersección que permita al usuario arrastrar la ventana de vuelta.
- **`buttonLabels["setDefault"]`**: tanto `"full"` como `"compact"` retornan `"⊙"` — el botón ya es un símbolo puro, no tiene texto largo en ningún modo.
- **No usa `new`**: la clase es completamente estática. Instanciarla sería un anti-pattern para este módulo.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Borrado**: `; --- Tabla privada: nombres por slot, full vs compact ---` (línea 20) — QUE puro, la firma del Map ya lo dice.
  - **Reescrito**: bloque de 6 líneas sobre `IsRectVisibleAgainst` → 5 líneas. Se eliminó la descripción de parámetros (QUE) y se concentró en WHY: módulo puro para testear sin Windows API + umbral 100×100 para ventanas post-desconexión de monitor.
  - **Conservados sin cambio**: banner del archivo (único, informativo), comentario de `NameColWidth` (calibración 200px/540px es WHY no-obvio).

### Fase 3 — dead code
- [x] Auditado 2026-05-12
- Borrados (0 referencias en producción + tests): ninguno. No existe código sin referencias.
- Candidatos para review senior (NO borrados): ninguno.
- Resultado del audit:
  - **breakpoint** — USADO: leído por `IsCompact` (que lo usa directamente) y cubierto por 5 asserts en Test_HudLayout.
  - **IsCompact** — USADO: MainHud.ahk:467, MainHud.ahk:631. Tests: 5 asserts.
  - **LabelForSlot** — USADO: MainHud.ahk:367 (loop sobre todos los slots 1–9). Tests: 7 asserts (slots 1, 4, 9, 99).
  - **LabelForButton** — USADO: MainHud.ahk:375, 384 (loop sobre buttonsById), 504 (skip/start dinámico), 509, 852 (templateOn/Off). Los 11 keys de buttonLabels están todos alcanzados: `start`, `skip`, `templateOn`, `templateOff`, `scan`, `release`, `reset`, `undo`, `loadLast`, `autocalc`, `setDefault`. Tests: 22 asserts (todos los keys + id desconocido). Sin DUDOSOS.
  - **NameColWidth** — USADO: MainHud.ahk:393. Tests: 2 asserts.
  - **IsRectVisibleAgainst** — USADO: MainHud.ahk:118, 143. Tests: 6 asserts (dentro, fuera, borde, multi-monitor, array vacío).
  - **slotLabels** (9 entries) — todas USADAS: el loop `for i, row in this.rows` (n=9 slots del schema) itera los índices 1–9 completos.
  - **buttonLabels** (11 entries) — todas USADAS: ver detalle de LabelForButton arriba.
- Sintaxis validada: `AutoHotkey64.exe /validate` → exit 0.

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno. Archivo ya conforme: sin trailing whitespace, sin tabs, sin bloques de 3+ líneas en blanco, trailing newline único (LF), indentación consistente en múltiplos de 4 espacios.

## Ideas de simplificación pendientes (input para plan posterior)
- `slotLabels` y `buttonLabels` son `Map` con `Map` anidados. Podrían ser `Map` de dos dimensiones aplanados con clave compuesta `"<idx>:<mode>"` para evitar el doble lookup — medir si hay ganancia real antes de hacerlo.
- `LabelForSlot` y `LabelForButton` tienen lógica casi idéntica (Has-check, lookup `[key][mode]`, fallback). Se podría extraer un helper privado `_Lookup(table, key, isCompact, fallback)` para eliminar la duplicación.
- El breakpoint `540` está hardcoded en `IsCompact` y referenciado en los comentarios de `NameColWidth`. Si en el futuro se necesita un segundo breakpoint (ej. "very compact" < 400), la clase no está preparada para eso sin refactor — documentar como deuda de diseño.
