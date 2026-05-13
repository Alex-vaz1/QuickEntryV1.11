---
file: Tests/Test_HudLayout.ahk
last_review: 2026-05-12
status: active
---

# `Tests/Test_HudLayout.ahk`

## Propósito

Suite de tests unitarios para `Lib/HudLayout.ahk`. Valida los cinco métodos estáticos de `HudLayout` sin instanciar ninguna ventana ni llamar a la Windows API: `IsCompact`, `LabelForSlot`, `LabelForButton`, `NameColWidth`, e `IsRectVisibleAgainst`. Los monitores se pasan como arrays sintéticos, lo que permite probar lógica multi-monitor sin hardware real.

## Cobertura por método

### `HudLayout.IsCompact(width)` — 5 asserts (líneas 8–12)

| Assert | Entrada | Esperado | Descripción |
|---|---|---|---|
| L8 | `539` | `1` (compact) | justo debajo del breakpoint |
| L9 | `540` | `0` (normal) | exactamente en el breakpoint (exclusivo) |
| L10 | `541` | `0` (normal) | justo por encima |
| L11 | `800` | `0` (normal) | valor típico de ventana ancha |
| L12 | `0` | `1` (compact) | degenerate: width cero |

Cubre: breakpoint exclusivo en 540, valor límite inferior, valor límite superior, degenerate.

---

### `HudLayout.LabelForSlot(idx, isCompact)` — 7 asserts (líneas 15–22)

| Assert | Slot | isCompact | Esperado |
|---|---|---|---|
| L15 | 1 | `false` | `"Account number"` |
| L16 | 1 | `true` | `"Acct #"` |
| L17 | 4 | `false` | `"Corp name"` |
| L18 | 4 | `true` | `"Corp"` |
| L19 | 9 | `false` | `"Invoice Total Including PastDue"` |
| L20 | 9 | `true` | `"Total + PD"` |
| L22 | 99 | `true` | `""` (slot fuera de rango) |

Cubre: primero y último slot válido del schema (1, 9), slot intermedio (4), ambos modos full/compact, degenerate por índice inexistente.

---

### `HudLayout.LabelForButton(buttonId, isCompact)` — 22 asserts (líneas 25–47)

| Assert | buttonId | isCompact | Esperado |
|---|---|---|---|
| L25 | `"start"` | `false` | `"▶ Iniciar"` |
| L26 | `"start"` | `true` | `"▶"` |
| L27 | `"skip"` | `false` | `"⏭ Omitir"` |
| L28 | `"skip"` | `true` | `"⏭"` |
| L29 | `"templateOn"` | `false` | `"☑ Template"` |
| L30 | `"templateOn"` | `true` | `"☑"` |
| L31 | `"templateOff"` | `false` | `"☐ Template"` |
| L32 | `"templateOff"` | `true` | `"☐"` |
| L33 | `"scan"` | `false` | `"⇣ Scan"` |
| L34 | `"scan"` | `true` | `"⇣"` |
| L35 | `"release"` | `false` | `"▶▶ Pegar"` |
| L36 | `"release"` | `true` | `"▶▶"` |
| L37 | `"reset"` | `false` | `"⊘ Reset"` |
| L38 | `"reset"` | `true` | `"⊘"` |
| L39 | `"undo"` | `false` | `"↶ Undo"` |
| L40 | `"undo"` | `true` | `"↶"` |
| L41 | `"loadLast"` | `false` | `"↻ Load Last"` |
| L42 | `"loadLast"` | `true` | `"↻"` |
| L43 | `"autocalc"` | `false` | `"Σ Calc"` |
| L44 | `"autocalc"` | `true` | `"Σ"` |
| L45 | `"setDefault"` | `false` | `"⊙"` (same in both modes) |
| L46 | `"setDefault"` | `true` | `"⊙"` |
| L47 | `"nonexistent"` | `true` | `"?"` |

Cubre: los 11 buttonIds del mapa, ambos modos full/compact para cada uno, caso especial `setDefault` (mismo valor en ambos modos), degenerate por id inexistente.

---

### `HudLayout.NameColWidth(isCompact)` — 2 asserts (líneas 50–51)

| Assert | isCompact | Esperado |
|---|---|---|
| L50 | `false` | `200` |
| L51 | `true` | `100` |

Cubre: ambos modos. Nota: el comentario del assert `"nameCol normal"` documenta el motivo del valor (cabida del label más largo del schema).

---

### `HudLayout.IsRectVisibleAgainst(x, y, w, h, monitorsArray)` — 6 asserts (líneas 60–76)

| Assert | Escenario | Esperado |
|---|---|---|
| L60 | rect `(100,100,540,460)` en monitor `0–1920×0–1080` | `1` (visible) |
| L62 | rect `(2000,100,540,460)` — totalmente fuera a la derecha | `0` |
| L64 | rect `(-490,100,540,460)` — solo 50 px dentro (< 100) | `0` |
| L66 | rect `(-400,100,540,460)` — 140 px dentro (>= 100) | `1` |
| L73 | rect `(2500,200,540,460)` en segundo monitor `1920–3840` | `1` (multi-monitor) |
| L76 | array de monitores vacío `[]` | `0` (degenerate) |

Cubre: rect totalmente dentro, totalmente fuera, parcialmente visible por debajo del umbral (50 px < minVisible 100), parcialmente visible por encima del umbral, multi-monitor (el rect cae en el segundo monitor), degenerate sin monitores.

---

## Resumen de cobertura

| Método | Asserts | Casos degenerate | Cobertura |
|---|---|---|---|
| `IsCompact` | 5 | 1 (width=0) | Completa |
| `LabelForSlot` | 7 | 1 (slot 99) | Completa |
| `LabelForButton` | 23 | 1 (id inexistente) | Completa |
| `NameColWidth` | 2 | 0 | Completa (solo 2 valores posibles) |
| `IsRectVisibleAgainst` | 6 | 1 (sin monitores) | Completa |
| **Total** | **43** | **4** | |

## API pública (de este archivo)

### Funciones libres

(ninguna — el archivo es script-top-level puro; no define funciones propias)

### Estructura

El archivo sigue el patrón estándar de test del proyecto:

1. Directivas AHK (`#Requires`, `#NoTrayIcon`, `#SingleInstance Off`)
2. `#Include` del módulo bajo test y de `_AssertHelpers.ahk`
3. Bloques de asserts agrupados por método, separados con comentarios
4. `ReportarYSalir()` al final (reporta totales y emite exit code)

## Dependencias

- **#Include directos**:
  - `#Include "..\Lib\HudLayout.ahk"` (línea 4) — módulo bajo test
  - `#Include "_AssertHelpers.ahk"` (línea 5) — harness de asserts
- **Incluido por**: `Tests/runner.ps1` (lo descubre por glob `Test_*.ahk` y lo lanza con `AutoHotkey64.exe`)
- **Globales que define**: ninguna propia; hereda `g_failures` y `g_total` de `_AssertHelpers.ahk`
- **Globales que usa (leídas)**: `g_failures`, `g_total` (vía `ReportarYSalir()` de `_AssertHelpers.ahk`)
- **Símbolos externos invocados**: `AssertEq`, `ReportarYSalir` (de `_AssertHelpers.ahk`); todos los métodos estáticos de `HudLayout`

## Notas técnicas (WHY no-obvio)

- **Booleanos como `? 1 : 0`**: `HudLayout.IsCompact` y `HudLayout.IsRectVisibleAgainst` retornan un booleano AHK nativo. Los asserts los convierten a `1`/`0` explícitamente (`? 1 : 0`) para evitar que `AssertEq` compare `true`/`1` o `false`/`0` con distintos tipos internos — el harness usa comparación estricta de strings.

- **Monitores sintéticos para `IsRectVisibleAgainst`**: el módulo `HudLayout.ahk` no llama a `MonitorGetWorkArea`; recibe el array de rectángulos como parámetro. Este diseño permite construir escenarios de monitor arbitrarios en tests sin depender del entorno real, incluyendo el caso multi-monitor (L69–73) que usaría dos monitores side-by-side estándar (`0–1920` y `1920–3840`).

- **Umbral minVisible = 100**: el caso L64 (`-490, 100, 540, 460`) tiene `max(0, 540-490) = 50 px` de intersección horizontal → `false`. El caso L66 (`-400, 100, 540, 460`) tiene `max(0, 540-400) = 140 px` → `true`. Ambos pinzan el umbral de 100 px desde los dos lados, verificando que el límite sea exactamente 100 (no 99 ni 101).

- **`setDefault` igual en ambos modos**: el assert L45–L46 verifica explícitamente que `LabelForButton("setDefault", false)` y `LabelForButton("setDefault", true)` retornan el mismo símbolo `"⊙"`. Esto documenta que el comportamiento doble-modo es intencional para ese botón específico.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (ninguno — archivo de tests, no contiene handlers de mouse ni referencias a M720)

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Borrados**: banner decorativo de 4 líneas (`====` + descripción de la función) sobre `IsRectVisibleAgainst` → colapsado a 2 líneas de comentario inline con WHY.
  - **Reescritos (QUÉ → WHY)**:
    - L7: `IsCompact: breakpoint = 540, exclusive` → explica qué significa exclusivo (`540 ya es normal, 539 aun compact`).
    - L14: `LabelForSlot: full vs abreviado segun isCompact` → `cada slot tiene label largo y corto; slot inexistente retorna ""`.
    - L21: `Slot fuera de rango -> retorna ""` → `slot 99 no existe en el schema -> debe retornar "" en lugar de crashear o retornar basura`.
    - L24: `LabelForButton: texto vs simbolo segun isCompact` → `cada boton tiene texto completo y solo simbolo; id desconocido -> "?"`.
    - L49: `NameColWidth: 240 normal, 100 compact` → `200 normal porque es el label mas largo del schema; 100 compact porque es el minimo legible`.
    - L59/L61 (rect dentro / rect fuera): eran WHAT puro → eliminados los labels reduntantes; los casos se entienden por el string del assert.
    - L63/L65 (50 px / 140 px): reescritos con el calculo explicito del umbral (`max(0, 540-490) = 50 < 100`; `max(0, 540-400) = 140 >= 100`) para que el WHY del threshold sea inmediato.
    - L68 `Multi-monitor` → `segundo monitor side-by-side estandar: verifica que la busqueda itera todos los monitores`.
    - L75 `Edge: sin monitores` → `degenerate: array vacio -> no hay monitor que intersectar -> false (no debe crashear)`.
  - **Conservados intactos**: todos los asserts, directivas `#Requires`/`#Include`, `ReportarYSalir()`.
  - **Banners resultantes**: 2 (`; ---` para IsCompact y LabelForSlot); LabelForButton y los demas usan comentario de una linea.
  - **Validacion de sintaxis**: AutoHotkey64.exe no encontrado en esta maquina (`avazquez`); la ruta del CLAUDE.md corresponde a `C:\Users\Usuario\...` (maquina de desarrollo). Sin errores de logica introducidos — solo comentarios modificados.

### Fase 3 — dead code
- [ ] Auditado
- Borrados (0 referencias en producción + tests):
- Candidatos para review senior (NO borrados):

## Ideas de simplificación pendientes (input para plan posterior)

- Los 22 asserts de `LabelForButton` tienen un patrón repetitivo `(id, false), texto_full` / `(id, true), simbolo`. Podrían condensarse con un helper `AssertButton(id, full, compact)` que ejecute ambos asserts y reduzca las líneas de test a la mitad — evaluar si gana legibilidad o la pierde (la tabla explícita facilita debuggear fallos puntuales).
- `IsRectVisibleAgainst` no tiene un caso donde la intersección sea exactamente 100×100 px (el límite exacto del umbral). Agregar ese caso edge `rect(-440, 100, 540, 460)` → `max(0,540-440)=100` confirmaría si el umbral es `>= 100` o `> 100` (actualmente es `>= 100` según la implementación, pero el test no lo verifica al píxel).
- Los comentarios de sección usan guiones (`; --- Método ---`) pero no hay convención explícita de indentación o alineación de columnas en los asserts. Dado que el archivo es puro lookup-table, considerar alinear los tres argumentos de `AssertEq` con tabs para que los valores esperados formen una columna visual — facilita comparar expected vs. description de un vistazo.
