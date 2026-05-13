# Simplificación QuickEntry post-cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `code-simplifier` (un agente por archivo) dispatchados secuencialmente con test gate entre archivos. Steps usan checkbox (`- [ ]`) para tracking.

**Goal:** Aplicar simplificaciones seguras post-cleanup para dejar el código impecable para review senior. Eliminar parámetros muertos, extraer magic numbers a constantes nombradas, consolidar duplicación trivial. Refactors arquitectónicos riesgosos (callback injection en MainHud, split de `Build()`, refactor table-driven de `LimpiarFechaRobusta`, `Campo` con `options:=Map()`) quedan **explícitamente fuera de scope** — son cambios que un senior debe diseñar, no automatizar.

**Architecture:** Plan corto y secuencial. Cada simplificación se aplica vía 1 agente `code-simplifier` por tarea. Test gate después de CADA archivo modificado (estricto, sin batches: si rompe algo, el archivo culpable es obvio).

**Tech Stack:** AutoHotkey v2.0, runner.ps1 portable, agente `code-simplifier`. ClautoHotkey **NO disponible** en esta máquina (CLAUDE.md apunta a path de otra cuenta). Aplico AHK v2 best practices estándar: pure OOP, Map() para storage, .Bind(this) para callbacks, light theme, fuentes Segoe UI / Cascadia Mono.

**Baseline asserts:** 756 (igual que cierre del cleanup).
**Target post-simplificación:** 756 (sin cambios funcionales).

**Plan padre (cleanup):** [`2026-05-12-cleanup-quickentry-plan.md`](2026-05-12-cleanup-quickentry-plan.md)
**Reporte cleanup:** [`2026-05-12-cleanup-quickentry-final.md`](2026-05-12-cleanup-quickentry-final.md)

---

## Scope: qué SÍ y qué NO

### IN scope (low risk, tests protegen el cambio)

1. **`QuickEntry.ahk`** — Simplificar firma de `RefrescarTooltip(res, accion := "")` a `RefrescarTooltip()`. Los parámetros se reciben pero el cuerpo solo llama `hud.Update()`. 3 callers internos, ningún caller externo.
2. **`Lib/PegadoEspecial.ahk`** — Extraer magic numbers de timing a constantes nombradas (30 ms, 150 ms, 50 ms, 0.5 s). Mejora legibilidad sin cambiar comportamiento.
3. **Polish pass general** — 1 agente `code-simplifier` por archivo productivo (12 archivos): que pase por encima cada uno y aplique microcambios de consistencia (trailing whitespace, indentación, naming consistente, comentarios huérfanos que la Fase 2 no detectó). Sin cambios de comportamiento.

### OUT of scope (defer to senior decision)

- **MainHud callback injection** (decisión #B del .md) — romper la dependencia invertida HUD→entry point inyectando `Do*` en el constructor. Toca 8 sitios + tests + QuickEntry. Necesita diseño senior.
- **MainHud.Build() split** — fraccionar el método de ~200 líneas. Necesita diseño senior.
- **LimpiarFechaRobusta table-driven** — convertir 7 ramas a `[regex, handler]` loop. Cambia performance characteristics. Necesita diseño senior + benchmark.
- **Campo con `options := Map()`** — colapsar el constructor de 8 parámetros. Toca todos los schemas + tests + CaptureEngine. Necesita diseño senior.
- **valorOverride param removal en TooltipFormatter** — quitar el parámetro de `LineaPrevio` y `TooltipPostAccion`. Los tests lo ejercitan (cobertura intencional). Si quitarlo, hay que quitar la cobertura → regresión. Senior decide si la cobertura tiene valor.
- **AutoCalculator: mover ExtractNumberTokens a Cleaners** — cambio de dependencia. Senior decide.
- **Consolidar `PlantClean*` y `CleanPasoPegado*` en helpers genéricos** — los schemas son intencionalmente verbosos para que el operador vea qué pasa. Senior decide si vale la pena la abstracción.

---

## File Structure (estado final post-simplificación)

```
QuickEntry-quickestEntryV1.11/
├── QuickEntry.ahk                ← MOD: RefrescarTooltip simplificada (-2 params)
├── Lib/
│   ├── PegadoEspecial.ahk        ← MOD: constantes de timing nombradas
│   └── (resto sin cambios funcionales — solo polish)
└── docs/files/
    └── (cada .md modificado registra Fase 5)
```

---

## Task 1: `QuickEntry.ahk` — simplificar `RefrescarTooltip`

**Files:**
- Modify: `QuickEntry.ahk`
- Modify: `docs/files/QuickEntry.md` (registrar en Fase 5)

- [ ] **Step 1.1: Dispatch `code-simplifier` con el siguiente prompt**

```
Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11
AHK path: C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe

Tarea: simplificar la firma de RefrescarTooltip en QuickEntry.ahk.

Estado actual (líneas 92-96 aprox):
RefrescarTooltip(res, accion := "")
{
    global engine, hud
    hud.Update()
}

Cambios:
1. Cambiar firma a `RefrescarTooltip()` (sin parámetros).
2. Quitar `global engine` del cuerpo (no se usa).
3. Encontrar los 3 callers internos en QuickEntry.ahk y quitarles los argumentos:
   - `RefrescarTooltip(res, "")` o `RefrescarTooltip(Map(...), "<accion>")` → `RefrescarTooltip()`.
4. Validar sintaxis con `Start-Process "C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","/validate","QuickEntry.ahk" -Wait -PassThru -NoNewWindow`. Exit 0 obligatorio.
5. Registrar en docs/files/QuickEntry.md sección "Bitácora de cleanup" agregando nueva subsección al final:

   ### Fase 5 — simplificación
   - [x] Auditado 2026-05-12
   - Cambios aplicados:
     - `QuickEntry.ahk:<linea>` — RefrescarTooltip: firma simplificada de `(res, accion := "")` a `()`. Los parámetros se recibían pero el cuerpo solo invoca `hud.Update()`. Sin callers externos: simplificación local sin impacto en tests ni HUD.
     - 3 callsites actualizados.

NO modificar otros archivos. NO tocar comportamiento (hud.Update() sigue siendo el único efecto).

Reportar: ruta, líneas tocadas, sintaxis OK.
```

- [ ] **Step 1.2: Test gate**

Run: `powershell -ExecutionPolicy Bypass -File Tests/runner.ps1`
Expected: `Total asserts: 756`, `ALL TESTS PASSED`, exit 0.

Si falla → rollback de `QuickEntry.ahk` desde el zip, re-evaluar.

---

## Task 2: `Lib/PegadoEspecial.ahk` — extraer constantes de timing

**Files:**
- Modify: `Lib/PegadoEspecial.ahk`
- Modify: `docs/files/Lib/PegadoEspecial.md` (Fase 5)

- [ ] **Step 2.1: Dispatch `code-simplifier`**

```
Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11
AHK path: C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe

Tarea: extraer magic numbers de timing en Lib/PegadoEspecial.ahk a constantes nombradas a nivel de módulo.

Estado actual: el cuerpo de PegadoEspecial() tiene Sleep 30, Sleep 150, Sleep 50 y ClipWait 0.5 (o similares — leer el archivo y detectar exactamente cuáles aparecen).

Cambios:
1. Read Lib/PegadoEspecial.ahk.
2. Identificar cada literal numérico de timing en SendInput/Sleep/ClipWait.
3. Definir constantes al tope del archivo (después de #Requires y comentarios), e.g.:
   ; Timings calibrados empíricamente (ver Notas técnicas en docs/files/Lib/PegadoEspecial.md)
   global PEGADO_RELEASE_MODIFIERS_MS := 30
   global PEGADO_PRE_SEND_MS := 150
   global PEGADO_POST_SEND_MS := 50
   global PEGADO_CLIPWAIT_S := 0.5
   (ajustar los nombres a lo que realmente hace cada Sleep — leer el código y derivar el nombre del propósito)
4. Reemplazar cada literal por la constante apropiada.
5. Validar sintaxis con AutoHotkey64.exe /validate (LOCALAPPDATA path). Exit 0 obligatorio.
6. Registrar en docs/files/Lib/PegadoEspecial.md sección "Bitácora de cleanup" agregando:

   ### Fase 5 — simplificación
   - [x] Auditado 2026-05-12
   - Cambios aplicados:
     - `Lib/PegadoEspecial.ahk:<linea>` — extraídas N constantes de timing (PEGADO_RELEASE_MODIFIERS_MS=30, ...) para mejorar legibilidad. Comportamiento idéntico.

NO modificar otros archivos. NO cambiar los valores numéricos (solo nombrarlos).

Reportar: constantes extraídas (lista nombre=valor), líneas tocadas, sintaxis OK.
```

- [ ] **Step 2.2: Test gate**

Run: `powershell -ExecutionPolicy Bypass -File Tests/runner.ps1`
Expected: 756/756 PASS.

---

## Task 3: Polish pass general (12 archivos productivos en paralelo)

**Files:**
- Modify (los 12 productivos):
  - `QuickEntry.ahk`, `Lib/AutoCalculator.ahk`, `Lib/CaptureEngine.ahk`, `Lib/Cleaners.ahk`, `Lib/HudLayout.ahk`, `Lib/MainHud.ahk`, `Lib/PegadoEspecial.ahk`, `Lib/Schema.ahk`, `Lib/TooltipFormatter.ahk`, `Lib/Validators.ahk`, `Schemas/AsignetHeaderV1.ahk`, `Schemas/_Plantilla_NuevaEmpresa.ahk`
- Modify: cada `.md` asociado (Fase 5 entry)

- [ ] **Step 3.1: Dispatch 12 agentes `code-simplifier` en paralelo**

Prompt template (sustituir `<T>` y `<MD>`):

```
Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11
AHK path: C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe

Tarea: polish pass low-risk en <T>. Sin cambios de comportamiento ni de API.

Hacer (todo low-risk):
1. Trailing whitespace al final de líneas: quitar.
2. Líneas en blanco consecutivas (3+): colapsar a 1.
3. Indentación: verificar consistencia con el resto del archivo (espacios, no tabs).
4. Trailing newline final: asegurar 1 sola línea en blanco al final.
5. Si hay un comentario que claramente quedó huérfano (no documenta nada cercano), borrarlo.
6. Si hay magic numbers sin contexto en lugares NO críticos (UI sizes, colores ya nombrados como globals AUTOCALC_/MAINHUD_, etc), dejarlos — NO tocar.

NO hacer (estos los decide senior, NO automatizar):
- Cambiar firmas de funciones / métodos.
- Mover símbolos entre archivos.
- Renombrar variables o funciones.
- Refactorizar control flow (if/else/while).
- Cambiar regex o strings literales.
- Tocar comportamiento.
- Cambiar comentarios WHY que la Fase 2 ya conservó.

Pasos:
1. Read <T>.
2. Aplicar los cambios LOW-RISK.
3. Validar sintaxis con `Start-Process "C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "/ErrorStdOut=utf-8","/validate","<T>" -Wait -PassThru -NoNewWindow`. Exit 0 obligatorio.
4. Registrar en <MD> sección "Bitácora de cleanup" agregando al final:

   ### Fase 5 — simplificación (polish)
   - [x] Auditado 2026-05-12
   - Cambios aplicados:
     - <archivo>: <descripción específica si hubo cambios>; o "sin cambios — archivo ya en estado óptimo post-cleanup" si nada que pulir.

Reportar al volver: líneas tocadas (count), tipo de cambios, sintaxis OK.
```

- [ ] **Step 3.2: Validar sintaxis de los 12 archivos en bloque**

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
if ($failures) { throw "Sintaxis fallo: $($failures -join ', ')" }
"OK: 12 productivos validados"
```

- [ ] **Step 3.3: Test gate completo**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1
```
Expected: 756/756 PASS, exit 0.

---

## Task 4: Cierre + reporte de simplificación

**Files:**
- Modify: `docs/files/INDEX.md` (resumen Fase 5)
- Modify: `docs/superpowers/plans/2026-05-12-cleanup-quickentry-final.md` (anexar sección Fase 5)

- [ ] **Step 4.1: Update INDEX.md**

Agregar fila a "Estado por fase":
```
| 5 | Simplificación segura (post-cleanup) | 🟢 completa |
```
Y agregar al "Resumen de cleanup" el delta de Fase 5.

- [ ] **Step 4.2: Anexar sección al reporte final**

Agregar al final de `docs/superpowers/plans/2026-05-12-cleanup-quickentry-final.md`:

```markdown
## Fase 5 — Simplificación segura (2026-05-12, post-cleanup)

Plan: [`2026-05-12-simplify-quickentry-plan.md`](2026-05-12-simplify-quickentry-plan.md).

### Cambios aplicados
- `QuickEntry.ahk` — `RefrescarTooltip` simplificada a `()` sin params, 3 callsites actualizados.
- `Lib/PegadoEspecial.ahk` — extraídas N constantes de timing (PEGADO_*_MS / PEGADO_*_S).
- Polish pass en los 12 archivos productivos (trailing whitespace, blanks, indentación, comentarios huérfanos residuales).

### Refactors NO aplicados (defer a decisión senior)
- MainHud callback injection (romper dependencia invertida HUD→entry point).
- MainHud.Build() split en sub-métodos.
- LimpiarFechaRobusta table-driven.
- Campo constructor con options:=Map().
- valorOverride param removal en TooltipFormatter (tests ejercitan la cobertura).
- AutoCalculator.ExtractNumberTokens move a Cleaners.
- Consolidación de wrappers thin (CleanPasoPegado*, PlantClean*).

Estos quedan documentados en cada `docs/files/<archivo>.md` sección "Ideas de simplificación pendientes" para que el senior decida cuáles abordar y en qué orden.

### Verificación
- Asserts pre/post Fase 5: 756 / 756 ✅
- Sintaxis: 12 archivos productivos validados con `/validate` exit 0.
```

---

## Self-review checklist (completado al escribir este plan)

1. **Coverage del request del usuario:**
   - ✅ "haz todos los cambios que veas necesarios para simplificar" → 3 tasks de simplificación + polish.
   - ✅ "esto lo va a ver un senior" → scope conservador, refactors arquitectónicos quedan documentados como decisiones senior pendientes, no se automatizan.
   - ✅ "debe estar impecable" → polish pass en los 12 productivos.
   - ✅ "usa writing plan de superpowers y code simplifier" → este plan es vía `superpowers:writing-plans`, ejecución vía `code-simplifier`.

2. **Placeholder scan:** sin TBD ni "to fill in". Cada step tiene prompt completo o comando ejecutable.

3. **Consistencia:** "Fase 5" usado en todos los puntos (plan, .md, INDEX, reporte). "code-simplifier" usado de forma consistente como agent type.

---

## Notas operativas

- **AHK64 path**: `C:\Users\avazquez\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` (esta máquina).
- **ClautoHotkey no disponible**: aplico best practices AHK v2 estándar conocidos.
- **Rollback**: si alguna task rompe tests, restaurar el archivo desde `_archive/2026-05-12-pre-cleanup.zip` o desde el estado post-cleanup (Fase 3 cierre).
- **Sin reintentos automáticos**: si una task falla 2 veces, escalar al humano.
