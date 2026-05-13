# Fix design violations (D1-D6) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (en sesión, no es paralelizable — son ediciones puntuales secuenciales). Steps usan checkbox (`- [ ]`) syntax.

**Goal:** Resolver las 6 violaciones de diseño (D1-D6) detectadas por el code-review formal. La mayoría son docs/specs que quedaron stale al evolucionar la UX post-spec — la decisión es **alinear documentación al código actual** (no romper código en producción para volver a un spec obsoleto). Excepción: D5 es un fix de código (1 línea + 1 test).

**Architecture:** 6 tasks secuenciales independientes. Cinco son ediciones de docs (D1, D2, D3, D4, D6). Una es código + test (D5). Test gate al final.

**Tech Stack:** AutoHotkey v2.0, runner.ps1 portable, docs markdown.

**Baseline asserts:** 756.
**Target post-fix:** 757 (+1 nuevo test del `"type": "clear"` en ClearSlot).

**Backups:**
- `_archive/2026-05-12-pre-cleanup.zip` (pre-cleanup, Fase 0).
- `_archive/2026-05-12-post-cleanup.zip` (post-Fase-5, antes de este plan).

---

## Decisiones de dirección por cada D

| D | Naturaleza | Dirección del fix |
|---|---|---|
| D1 | MANUAL describe tooltip; código usa HUD persistente | **Doc** → describir el HUD persistente |
| D2 | MANUAL describe picker; código usa inline edit en HUD | **Doc** → describir inline edit |
| D3 | Spec dice × debería confirmar+ExitApp; código solo Hide | **Doc** → marcar spec superseded + agregar nota en MANUAL: "× oculta, `^+r` para limpiar, cerrar el script desde Tray" |
| D4 | Spec dice `^+s` oculta HUD; código auto-rearma (continuous capture) | **Doc** → marcar spec superseded + agregar sección "modo captura continua" en MANUAL |
| D5 | Spec exige `actionLog.type="clear"`; código omite el field | **Código** → agregar `"type", "clear"` al Map + nuevo assert |
| D6 | `DoArmOrSkip` rama restore-minimized sin docs | **Doc** → documentar la rama en MANUAL + GUIA |

Las decisiones D3/D4 superseden specs aprobados pre-MainHud. El criterio: **el código en producción que pasa 756 asserts es la fuente de verdad ahora**; los specs viejos quedan como histórico pero anotados.

---

## File Structure (modified files)

```
docs/
├── MANUAL_USUARIO.md       ← MOD: D1, D2, D3, D4, D6 (5 secciones tocadas)
├── GUIA_TECNICA.md         ← MOD: D6 (1 sección tocada)
└── superpowers/specs/
    └── 2026-04-29-main-hud-gui-design.md  ← MOD: D3, D4 superseded markers
Lib/
└── CaptureEngine.ahk       ← MOD: D5 (línea 260, agrega "type":"clear")
Tests/
└── Test_CaptureEngine.ahk  ← MOD: D5 (+1 assert)
```

---

## Task 1 (D1): MANUAL describe "tooltip flotante" — el actual es el HUD persistente

**Files:**
- Modify: `docs/MANUAL_USUARIO.md` sección "2. Armá la captura"

- [ ] **Step 1.1: Reemplazar el bloque viejo**

En `docs/MANUAL_USUARIO.md` líneas 52-58 (sección `### 2. Armá la captura`), reemplazar:

```markdown
### 2. Armá la captura
Apretá **`Ctrl+Shift+A`**. Aparece un tooltip flotante:
```
Busca "Account number" (1/9)
```
Eso te dice qué campo viene primero.
```

Por:

```markdown
### 2. Armá la captura
Cuando arrancás QuickEntry, **el HUD principal queda al frente** (light theme, esquina configurable). El HUD ya está **armado para capturar** desde el primer copy — no necesitás disparar nada. La primera fila te dice qué campo viene primero:

```
Busca "Account number" (1/9)
```

`Ctrl+Shift+A` cumple **tres roles** según el estado:
- **HUD oculto o minimizado** → lo restaura al frente (sin tocar la cola).
- **Captura activa con slot pendiente** → **omite** el slot actual (push `""` o autocalc).
- **Captura no activa** (después de Reset) → re-arma + muestra el HUD.
```

- [ ] **Step 1.2: Verificar render**

Abrir el archivo en visor markdown. Confirmar que las tres viñetas se renderizan bien y que el code-fence sigue cerrando correctamente.

---

## Task 2 (D2): MANUAL describe "picker" — el actual es inline edit en el HUD

**Files:**
- Modify: `docs/MANUAL_USUARIO.md` sección "4. Cuando algo sale mal" (filas que mencionan picker)

- [ ] **Step 2.1: Reemplazar las 3 filas obsoletas**

En `docs/MANUAL_USUARIO.md`, reemplazar las filas 81-83 de la tabla (las tres que mencionan "picker") por:

```markdown
| El valor existe pero el OCR lo lee mal y no podés corregirlo desde la fuente | `Ctrl+Shift+E` abre **inline edit** sobre la fila del slot actual del HUD. Tipeás el valor + Enter (commit) o Esc (cancelar). Si el valor no valida, el Edit queda abierto en rojo; Enter de nuevo sin cambiar valor abre `¿Forzar igual?` (Yes = `PushForce` sin validar). |
| Querés volver a un slot que omitiste o cargar uno fuera de orden | **Click en el nombre del slot** (columna izquierda) en el HUD → cursor salta a ese slot. Próximo copy lo llena. Si querés editar el valor directamente, **click en la columna VALOR** → abre inline edit ahí. |
| Querés editar un slot ya lleno | **Click en la columna VALOR** del slot lleno → inline edit con el valor precargado. Enter commit, Esc cancel. Si el slot estaba preloaded (por HeaderScan), el commit hace `PushForce` (bypass del cleaner). |
```

- [ ] **Step 2.2: Verificar render**

Abrir el archivo. Confirmar que la tabla sigue alineando bien las 3 columnas en cada fila.

---

## Task 3 (D3): Documentar que × oculta el HUD (no exits) + supersede el edge case 8 del spec

**Files:**
- Modify: `docs/MANUAL_USUARIO.md` (agregar nota en sección "Cuando algo sale mal")
- Modify: `docs/superpowers/specs/2026-04-29-main-hud-gui-design.md` (superseded marker en edge case 8)

- [ ] **Step 3.1: Agregar fila a la tabla "Cuando algo sale mal"**

En `docs/MANUAL_USUARIO.md`, **al final de la tabla** de la sección "4. Cuando algo sale mal" (después de la fila "Cancelar todo y empezar de cero"), agregar:

```markdown
| Querés cerrar el HUD sin cerrar QuickEntry | El botón **×** de la ventana solo **oculta** el HUD; el script sigue corriendo con los hotkeys activos. Para restaurarlo: `Ctrl+Shift+A` (o cualquier nuevo `Ctrl+C` con captura activa). Para cerrar QuickEntry completo, hay que cerrarlo desde la bandeja del sistema (System Tray, ícono verde de AHK → click derecho → Exit). |
```

- [ ] **Step 3.2: Marcar el edge case 8 del spec como superseded**

En `docs/superpowers/specs/2026-04-29-main-hud-gui-design.md`, buscar la sección "Edge case 8" (o el bloque que dice `Cerrar la GUI con ×: Confirm "¿Cerrar QuickEntry?"`). Agregar **antes** de ese bloque, una línea:

```markdown
> **⚠️ SUPERSEDED 2026-05-12**: la decisión final en producción fue que × **oculta** la GUI sin confirmar (el operador puede accidentalmente clickear ×; cerrar el script entero sin warning es peligroso). El hotkey de escape sigue siendo `Ctrl+Shift+R` para reset. Para cerrar QuickEntry: System Tray.
```

---

## Task 4 (D4): Documentar modo captura continua + supersede D1 del spec

**Files:**
- Modify: `docs/MANUAL_USUARIO.md` (agregar sección "Modo captura continua")
- Modify: `docs/superpowers/specs/2026-04-29-main-hud-gui-design.md` (superseded marker en D1)

- [ ] **Step 4.1: Agregar sección "Modo captura continua" al MANUAL**

En `docs/MANUAL_USUARIO.md`, **al final de la sección "5. Pegar en el formulario"** (después del bullet sobre "Campos con lupa"), agregar:

```markdown
### 5.1. Modo captura continua (auto-rearm)

QuickEntry corre en **modo captura continua** por default: después de `Ctrl+Shift+S` (paste batch), el engine se rearma automáticamente y queda listo para la próxima factura **sin que tengas que volver a armar**. El flujo es:

1. Copiás los 9 campos de la factura A.
2. `Ctrl+Shift+S` → pega los 9 valores en el form.
3. Acomodás los campos con lupa, hacés submit en el form de Asignet.
4. **Sin tocar QuickEntry**, copiás los 9 campos de la factura B. El HUD ya está armado, los acepta directamente.
5. `Ctrl+Shift+S` de nuevo, y así para cada factura.

**Cuándo necesitás pausar la captura**:
- Vas a copiar algo no relacionado con la factura (URL, email, número de tracking).
- Apretá `Ctrl+Shift+R` (reset). El engine pausa hasta el próximo `Ctrl+Shift+A`.

> **Importante:** mientras la captura esté activa, cualquier `Ctrl+C` que hagas se intentará pushear al slot actual. Si el cleaner lo rechaza (input inválido), aparece tooltip de error y la cola no avanza — pero el operador nuevo se puede confundir. Si vas a copiar texto que no es del header de la factura, **pausá con `Ctrl+Shift+R`** primero.
```

- [ ] **Step 4.2: Marcar D1 del spec como superseded**

En `docs/superpowers/specs/2026-04-29-main-hud-gui-design.md`, en la tabla "Decisiones aprobadas", localizar la fila **D1** que dice "se oculta en `^+r` (reset) **y al final de `^+s` (paste batch)**". Reemplazar el contenido de esa fila por:

```markdown
| **D1** | **Reemplaza el tooltip de ESTADO** (el persistente de `RefrescarTooltip`). ~~La GUI siempre visible cuando `engine.isCapturing == true`: aparece en `^+a` (armar), se oculta en `^+r` (reset) y al final de `^+s` (paste batch).~~ **⚠️ SUPERSEDED 2026-05-12**: la GUI se muestra al **startup** del script (no al armar) y permanece visible permanentemente; `^+s` **no oculta el HUD** sino que dispara auto-rearm (modo captura continua, ver MANUAL §5.1). `^+r` sí oculta el HUD. **Mantener los `ToolTip(...)` transientes** (1.5s) para mensajes one-shot. | Coexistir status tooltip + GUI (UI fragmentada). |
```

---

## Task 5 (D5): Agregar `"type": "clear"` al actionLog Map en ClearSlot

**Files:**
- Modify: `Lib/CaptureEngine.ahk:260`
- Modify: `Tests/Test_CaptureEngine.ahk` (agregar 1 assert)

- [ ] **Step 5.1: Editar `Lib/CaptureEngine.ahk:260`**

Reemplazar exactamente:

```ahk
        this.actionLog.Push(Map("slot", slot, "prevValue", this.queue[slot]))
```

Por:

```ahk
        this.actionLog.Push(Map("type", "clear", "slot", slot, "prevValue", this.queue[slot]))
```

(Razón: spec `docs/superpowers/specs/2026-05-10-quickestEntry-ui-cleanup-design.md` §2.4 exige el campo `type` para que callers de `Undo()` puedan distinguir clears de pushes en una futura UI.)

- [ ] **Step 5.2: Validar sintaxis**

```powershell
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","/validate","Lib/CaptureEngine.ahk" -Wait -PassThru -NoNewWindow
```
Expected: exit 0.

- [ ] **Step 5.3: Agregar assert al test existente de ClearSlot**

En `Tests/Test_CaptureEngine.ahk`, justo después de la línea actual:

```ahk
e.ClearSlot(1)
AssertEq(e.queue[1], "", "ClearSlot deja slot vacio")
```

Agregar **antes** del próximo `AssertEq` del mismo bloque:

```ahk
AssertEq(e.actionLog[e.actionLog.Length]["type"], "clear", "ClearSlot registra type='clear' en actionLog")
```

- [ ] **Step 5.4: Correr tests, verificar 757 asserts**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 2>&1 | Select-Object -Last 12
```
Expected:
- `Test_CaptureEngine.ahk === 219 tests, 0 failures ===` (uno más).
- `Total asserts: 757`
- `ALL TESTS PASSED`
- exit 0.

Si falla, rollback de `CaptureEngine.ahk` y `Test_CaptureEngine.ahk` desde `_archive/2026-05-12-post-cleanup.zip` y reportar.

- [ ] **Step 5.5: Registrar en `docs/files/Lib/CaptureEngine.md`**

En la sección "Bitácora de cleanup", **al final de la subsección "Fase 5 — polish"** (o crear nueva subsección "Fase 6 — design alignment" si no existe), agregar:

```markdown
### Fase 6 — design alignment
- [x] Aplicado 2026-05-12
- Cambios aplicados:
  - `Lib/CaptureEngine.ahk:260` — `ClearSlot` actionLog Map ahora incluye `"type", "clear"` para alinearse con spec `2026-05-10-quickestEntry-ui-cleanup-design.md §2.4`. Habilita que un futuro `Undo()` distinga clears de pushes para UI feedback. Backward-compatible: el Undo actual ignora el campo, no rompe nada.
  - `Tests/Test_CaptureEngine.ahk` — +1 assert verificando que el field `"type"="clear"` está presente. Conteo: 218 → 219.
```

---

## Task 6 (D6): Documentar la tercera rama de `DoArmOrSkip` (restore HUD)

**Files:**
- Modify: `docs/MANUAL_USUARIO.md` (ya cubierta indirectamente por Task 1 — verificar)
- Modify: `docs/GUIA_TECNICA.md` (tabla de hotkeys: clarificar el "doble rol" de `^+a` a "triple rol")

- [ ] **Step 6.1: Verificar que Task 1 ya documenta la tercera rama**

Re-abrir `docs/MANUAL_USUARIO.md` sección "2. Armá la captura" (modificada en Task 1). Confirmar que las tres viñetas describen los tres roles de `^+a`:
1. HUD oculto/minimizado → restaurar.
2. Captura activa con slot pendiente → omitir.
3. Captura no activa → armar + mostrar.

Si Task 1 quedó bien, este step es **no-op**. Si falta alguna viñeta, agregarla.

- [ ] **Step 6.2: Actualizar la tabla de hotkeys de `docs/GUIA_TECNICA.md`**

En `docs/GUIA_TECNICA.md` sección "Flujo end-to-end", la fila de `^+a` actualmente dice:

```markdown
| `^+a` | **Armar** captura (resetea cola, snapshot del clipboard). Si ya está armado: **omitir** el slot actual (push `""` o autocálculo). |
```

Reemplazar por:

```markdown
| `^+a` | Triple rol según estado: (a) si HUD oculto/minimizado → **restaurar al frente**; (b) si captura activa con slot pendiente → **omitir** el slot actual (push `""` o autocálculo); (c) si captura no activa → **armar** + mostrar HUD. |
```

---

## Task 7: Verificación final

**Files:** (read-only)

- [ ] **Step 7.1: Validar sintaxis productivos**

```powershell
$ahk = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$prod = @('QuickEntry.ahk','Lib/AutoCalculator.ahk','Lib/CaptureEngine.ahk','Lib/Cleaners.ahk',
          'Lib/HudLayout.ahk','Lib/MainHud.ahk','Lib/PegadoEspecial.ahk','Lib/Schema.ahk',
          'Lib/TooltipFormatter.ahk','Lib/Validators.ahk',
          'Schemas/AsignetHeaderV1.ahk','Schemas/_Plantilla_NuevaEmpresa.ahk')
$failures = @()
foreach ($f in $prod) {
  $p = Start-Process $ahk -ArgumentList "/ErrorStdOut=utf-8","/validate",$f -Wait -PassThru -NoNewWindow -RedirectStandardError "$env:TEMP\v.err" -RedirectStandardOutput "$env:TEMP\v.out"
  if ($p.ExitCode -ne 0) { $failures += $f }
}
if ($failures) { throw "Sintaxis falló: $($failures -join ', ')" }
"OK: 12 productivos validados"
```
Expected: `OK: 12 productivos validados`.

- [ ] **Step 7.2: Test gate final**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 2>&1 | Select-Object -Last 12
"exit: $LASTEXITCODE"
```
Expected:
- `Total asserts: 757`
- `ALL TESTS PASSED`
- exit 0

- [ ] **Step 7.3: Marcar Fase 6 en INDEX**

En `docs/files/INDEX.md`, agregar fila a la tabla "Estado por fase":

```markdown
| 6 | Fix design violations D1-D6 (post code-review) | 🟢 completa |
```

Y agregar al final de la sección "Resumen de cleanup":

```markdown
**Fase 6 — Design violations fix (2026-05-12).** Plan: [`2026-05-12-fix-design-violations-plan.md`](../superpowers/plans/2026-05-12-fix-design-violations-plan.md).

- **D1, D2**: docs/MANUAL_USUARIO.md actualizado — tooltip flotante → HUD persistente, picker → inline edit.
- **D3, D4**: `docs/superpowers/specs/2026-04-29-main-hud-gui-design.md` anotado con SUPERSEDED markers (edge case 8 = × hides, D1 = continuous capture mode).
- **D5**: `Lib/CaptureEngine.ahk:260` agrega `"type", "clear"` al actionLog. Tests +1 assert (757).
- **D6**: docs/MANUAL_USUARIO.md + docs/GUIA_TECNICA.md documentan el triple rol de `^+a`.
- **Asserts**: 756 → 757 ✅.
```

---

## Self-review checklist

1. **Spec coverage:**
   - ✅ D1 → Task 1.
   - ✅ D2 → Task 2.
   - ✅ D3 → Task 3 (doc + spec superseded marker).
   - ✅ D4 → Task 4 (doc nueva sección + spec superseded marker).
   - ✅ D5 → Task 5 (código + test).
   - ✅ D6 → Task 6 (doc en MANUAL + GUIA).
   - ✅ Backup zip → ya hecho antes de este plan, citado arriba.
   - ✅ Verificación final → Task 7.

2. **Placeholder scan:** ningún TBD, ninguna abstracción "implement later". Cada step tiene snippet exacto o comando ejecutable.

3. **Type consistency:** "Fase 6" usado consistentemente en INDEX update, en .md update, y en sección de Resumen. Conteo asserts: 756 baseline → 757 target después de D5.

---

## Notas operativas

- Las 6 tareas son **independientes** (no hay deps inter-task). Si una falla, las otras pueden seguir. Pero ejecutar secuencial es más simple para el rollback.
- D5 es el único cambio de código. Si rompe, los otros 5 fixes (docs) quedan igual.
- El backup zip ya está: `_archive/2026-05-12-post-cleanup.zip`. Rollback con `Expand-Archive` si hace falta.
- Los specs viejos (2026-04-29) son histórico — los SUPERSEDED markers son sufficient, no hace falta borrarlos.
