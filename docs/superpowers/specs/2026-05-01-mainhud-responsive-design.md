# MainHud Responsive Layout Design

**Fecha:** 2026-05-01
**Autor (operador):** Ale
**Estado:** Draft → en revisión

---

## 1. Goal (una frase)

MainHud adopta **dos modos de layout** (Normal / Compact) con switch automático según ancho de la ventana, y permite **bloquear ancho mínimo** para que la ventana nunca quede inservible al achicarla.

## 2. Por qué existe

Dos problemas concretos hoy:

1. **Ventana no entra en laptop chica**: el ancho actual (~600px) + posiciones absolutas hardcoded hacen que en laptops con resolución limitada los botones del borde derecho se corten.
2. **Achicar manualmente rompe el layout**: si el usuario arrastra el borde de la ventana, los controles quedan en posiciones absolutas y desaparecen del área visible.

Solución mínima: dos modos (Normal/Compact) con autoswitching por breakpoint, MinSize bloqueado.

## 3. Modos

### Normal (ancho ≥ 540px)
- Layout actual sin cambios visibles.
- Slots con nombres completos.
- Botones del footer con texto.

### Compact (ancho < 540px)
- Slots con nombres abreviados (ver tabla 6.1).
- Botones del footer **solo con símbolos** (sin texto), congruentes entre sí.
- Anchos de columnas reducidos.
- **Ancho mínimo de la ventana: 480px** (MinSize bloqueado).

## 4. Breakpoint

- Switch a Compact cuando `ancho < 540px`.
- Switch a Normal cuando `ancho ≥ 540px`.
- Sin histéresis al inicio (un solo umbral). Si en testing aparece flapping al arrastrar justo en el borde, agregar zona muerta de 20px (Compact si <540, Normal si >=560).

## 5. Persistencia (INI)

`%AppData%\QuickEntry\layout.ini` agrega cuatro campos:

```ini
[Window]
defaultX=...     ; (existe)
defaultY=...     ; (existe)
defaultW=540     ; NUEVO
defaultH=...     ; NUEVO
lastX=...        ; (existe)
lastY=...        ; (existe)
lastW=540        ; NUEVO
lastH=...        ; NUEVO
```

- Al arrancar: cargá `lastW/lastH`. Si faltan, usar `defaultW/defaultH`. Si esos faltan, defaults hardcoded (540 ancho, alto autocalc).
- Al cerrar / al hide: guardá `lastW/lastH` actuales.
- "Marcar como default" (botón ⊙): guarda `defaultX/Y/W/H` actuales como nuevos defaults.

## 6. Tablas de abreviaciones

### 6.1 Slots (modo Compact)

| # | Normal | Compact |
|---|---|---|
| 1 | Account number | Acct # |
| 2 | Invoice date | Inv date |
| 3 | Due date | Due date |
| 4 | Corp name | Corp |
| 5 | Previous balance | Prev bal |
| 6 | Past Total Payments | Payments |
| 7 | Past due | Past due |
| 8 | Total ($) | Total |
| 9 | Invoice Total Including PastDue | Total + PD |

### 6.2 Botones del footer (modo Compact)

| Botón | Normal | Compact |
|---|---|---|
| Iniciar / Omitir | "▶ Iniciar" / "⏭ Omitir" | ▶ / ⏭ |
| Template toggle | "☐ Template" / "☑ Template" | ☐ / ☑ |
| Scan | "⇣ Scan" | ⇣ |
| Soltar | "▶▶ Soltar" | ▶▶ |
| Reset | "⊘ Reset" | ⊘ |
| Undo | "↶ Undo" | ↶ |
| Load Last | "↻ Load Last" | ↻ |
| Manual edit | "⌨ Editar" | ⌨ |
| Pegar limpio | "📋 Pegar limpio" | 📋 |
| AutoCalc | "Σ Calc" | Σ |
| Set default | "⊙" *(ya es símbolo)* | ⊙ |

Tooltips de hover (en compact) muestran el nombre completo del botón. Eso preserva la affordance sin cargar la GUI visualmente.

## 7. Anchos de columna

| Modo | nameCol | valueCol | iconCol | total interno (sin márgenes) |
|---|---|---|---|---|
| Normal | 240 | 240 | 32 | ~600 |
| Compact | 100 | 240 | 32 | ~480 |

Slot column (número del slot) y márgenes laterales no cambian. La diferencia toda viene del nameCol.

## 8. Arquitectura

### 8.1 Nuevo módulo `Lib/HudLayout.ahk` (puro, testeable)

```
class HudLayout
{
    static breakpoint := 540

    static IsCompact(width)        ; bool: width < breakpoint
    static LabelForSlot(idx, isCompact)   ; string: nombre full o abreviado
    static LabelForButton(buttonId, isCompact) ; string: texto o símbolo
    static NameColWidth(isCompact) ; int: 240 o 100
}
```

**Tablas internas** son `Map`s estáticos con los datos de tablas 6.1 y 6.2.

`buttonId` es un identificador estable que MainHud asigna a cada botón al construirlo (`"start"`, `"release"`, `"reset"`, etc.). Eso desacopla el ID del texto.

### 8.2 `MainHud.ahk` consume `HudLayout`

Cambios en MainHud:

- **Build()**: cuando crea botones, asigna `buttonId` a cada uno (vía `Map` `buttonsById`) y arma el texto inicial vía `HudLayout.LabelForButton(id, isCompact)`.
- **Build()**: agrega `g.OnEvent("Size", (*) => this.OnResize())`.
- **Build()**: opciones del Gui incluyen `+MinSize480x` (alto auto).
- Nuevo método `OnResize()`:
  - Lee ancho actual de la ventana.
  - Calcula `isCompact` con `HudLayout.IsCompact(w)`.
  - Si `isCompact` cambió desde la última vez: re-renderiza textos de slots + botones, ajusta `nameCol` width, reposiciona controles.
  - Persiste `lastW/lastH` en INI.
- Nuevo método `RenderMode(isCompact)`:
  - Itera slots: actualiza `nameCtrl.Text` con `HudLayout.LabelForSlot(i, isCompact)`.
  - Itera botones (vía `buttonsById`): actualiza `Text` con `HudLayout.LabelForButton(id, isCompact)`.
  - Reposiciona controles a las nuevas X según `nameColWidth`.

### 8.3 Tooltips en modo compact

Los `btnTooltips` de hoy ya están definidos. En compact, los tooltips pasan a ser **el único hint del nombre**, así que se vuelven más importantes. No cambia el código del tooltip — solo el contexto de uso.

## 9. Tests (TDD del módulo puro)

`Tests/Test_HudLayout.ahk`:

- `IsCompact(539)` = true; `IsCompact(540)` = false; `IsCompact(800)` = false; `IsCompact(0)` = true.
- `LabelForSlot(1, true)` = "Acct #"; `LabelForSlot(1, false)` = "Account number".
- `LabelForSlot(9, true)` = "Total + PD"; `LabelForSlot(9, false)` = "Invoice Total Including PastDue".
- `LabelForButton("start", true)` = "▶"; `LabelForButton("start", false)` = "Iniciar".
- `LabelForButton("autocalc", true)` = "Σ"; `LabelForButton("autocalc", false)` = "Σ Calc".
- `NameColWidth(true)` = 100; `NameColWidth(false)` = 240.

Target: ~15 asserts. Las partes GUI (`OnResize`, `RenderMode`) se validan smoke (validate + arranque + manual visual test).

## 10. Out of scope (explícito)

- **Más de 2 modos** (no hay "wide" o "ultra-compact" — solo Normal/Compact).
- **Símbolos vs íconos**: solo Unicode chars, no SVG ni imágenes.
- **Animaciones de transición** entre modos (cambio instantáneo).
- **Auto-detect de resolución al primer arranque**: el usuario achica si quiere; defaults son 540x autocalc para todos.
- **Botones que se redimensionan proporcionalmente** dentro de un modo (mantienen tamaños fijos por modo).
- **Histéresis del breakpoint** (se agrega solo si aparece flapping en testing).

## 11. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| `+MinSize480x` no es sintaxis válida en AHK v2 | Confirmar en plan/implementación. Alternativa: hook `WM_GETMINMAXINFO`. |
| Resize event dispara muchas veces durante arrastre | `OnResize` es idempotente y barato; aceptar. Si genera flicker, agregar debounce de 50ms. |
| Tooltip con nombre completo no aparece rápido en compact (delay nativo de Windows) | Aceptable como costo del minimalismo. Alternativa: hover-show inmediato (out of scope hoy). |
| Inline edit (`^+e`) abierto cuando el modo cambia | Cerrar inline edit al cambiar de modo (igual que `OnToggleCompact` antiguo lo hacía). |
| Underlay paint del row activo no se redibuja al cambiar nameCol width | Re-asignar coordenadas del underlay en `RenderMode`. |

## 12. UX flow

1. Usuario arranca QuickEntry. Ventana aparece con tamaño guardado en `lastW/lastH` (default: 540 ancho).
2. Si el usuario arrastra el borde para achicar:
   - Cuando cruza por debajo de 540px → todos los slots/botones cambian de texto a abreviación/símbolo simultáneamente.
   - No puede pasar de 480px (MinSize lo bloquea).
3. Al subir de 540px de vuelta, todo vuelve al texto completo.
4. Al cerrar / hide, el tamaño actual se persiste en `lastW/lastH`.
5. Si el usuario hace click en "⊙ Marcar default", el tamaño actual se graba como `defaultW/defaultH` (además del x/y existentes).
