# Reporte final — cleanup QuickEntry para review senior

**Fecha**: 2026-05-12
**Plan**: [`docs/superpowers/plans/2026-05-12-cleanup-quickentry-plan.md`](2026-05-12-cleanup-quickentry-plan.md)
**Inventario**: [`docs/files/INDEX.md`](../../files/INDEX.md)
**Snapshot pre-cleanup**: `_archive/2026-05-12-pre-cleanup.zip`

---

## Resumen ejecutivo

| Métrica | Valor |
|---|---|
| Archivos productivos auditados | 12 |
| Archivos de test auditados | 9 (incluyendo `runner.ps1` y `_AssertHelpers.ahk`) |
| Archivos `.bak` borrados | 3 (`M720.ahk.bak`, `M720_Lib.ahk.bak`, `Test_M720_Lib.ahk.bak`) |
| Líneas borradas (total productivo) | 181 |
| Líneas borradas (total tests) | 104 |
| Comentarios borrados (entradas Fase 2) | ~82 (comentarios inline + bloques) |
| Comentarios reescritos QUÉ→WHY | ~46 |
| Símbolos muertos borrados | 0 (modo conservador; Fase 3 confirmó que los candidatos previos ya estaban ausentes del fuente) |
| Candidatos para review senior | 7 |
| Asserts pre / post | 756 / 756 (sin regresión) |
| Pre-fix portabilidad | `Tests/runner.ps1` — path AHK discovery portable |

---

## Pre-fix aplicado (Task 0.2)

`Tests/runner.ps1:6` tenía path hardcodeado `C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` (path del autor original). Cambiado a discovery portable en orden de prioridad:

1. `$env:AHK_V2` (override de CI/entorno)
2. `$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe`
3. `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`
4. `C:\Users\Usuario\...` (path original, como último recurso)

Bloqueante para uso interno multi-operador, ahora resuelto. El runner ganó 8 líneas netas (65 → 73) por el bloque de discovery.

---

## Cambios por archivo (productivos)

| Archivo | Líneas antes | Líneas después | Δ | Comentarios borrados | Reescritos |
|---|---|---|---|---|---|
| `QuickEntry.ahk` | 335 | 300 | -35 | 8 | 0 |
| `Lib/AutoCalculator.ahk` | 232 | 224 | -8 | 7 | 0 |
| `Lib/CaptureEngine.ahk` | 527 | 490 | -37 | ~14 | 5 |
| `Lib/Cleaners.ahk` | 250 | 238 | -12 | 1 (banner 13 líneas → 1 línea) | 0 |
| `Lib/HudLayout.ahk` | 89 | 87 | -2 | 1 | 1 |
| `Lib/MainHud.ahk` | 1004 | 926 | -78 | ~43 | ~18 |
| `Lib/PegadoEspecial.ahk` | 59 | 59 | 0 | 0 | 2 |
| `Lib/Schema.ahk` | 103 | 105 | +2 | 0 | 2 |
| `Lib/TooltipFormatter.ahk` | 121 | 119 | -2 | 3 | 1 |
| `Lib/Validators.ahk` | 68 | 65 | -3 | 2 | 2 |
| `Schemas/AsignetHeaderV1.ahk` | 102 | 96 | -6 | 3 | 4 |
| `Schemas/_Plantilla_NuevaEmpresa.ahk` | 135 | 135 | 0 | 0 | 0 |
| **TOTAL productivo** | **3025** | **2844** | **-181** | | |

Nota: `Lib/Schema.ahk` ganó 2 líneas (delta +2) porque las reescrituras WHY expandieron comentarios que antes eran más cortos que el nuevo contenido explicativo.

---

## Cambios por archivo (tests)

| Archivo | Líneas antes | Líneas después | Δ | Comentarios borrados | Reescritos |
|---|---|---|---|---|---|
| `Tests/_AssertHelpers.ahk` | 37 | 37 | 0 | 0 | 0 |
| `Tests/runner.ps1` | 65 | 73 | +8 | 0 | 0 (pre-fix funcional) |
| `Tests/Test_AsignetHeader.ahk` | 271 | 271 | 0 | 0 | 0 |
| `Tests/Test_CaptureEngine.ahk` | 916 | 825 | -91 | ~23 | 7 |
| `Tests/Test_Cleaners.ahk` | 271 | 273 | +2 | 0 | 1 |
| `Tests/Test_HudLayout.ahk` | 78 | 74 | -4 | 1 | 8 reescritos inline |
| `Tests/Test_Schema.ahk` | 97 | 97 | 0 | 0 | 0 |
| `Tests/Test_TooltipFormatter.ahk` | 312 | 293 | -19 | ~9 | 3 |
| `Tests/Test_Validators.ahk` | 101 | 101 | 0 | 0 | 0 |
| **TOTAL tests** | **2148** | **2044** | **-104** | | |

Nota: `runner.ps1` y `Test_Cleaners.ahk` tienen delta positivo. `runner.ps1` por el pre-fix funcional (Task 0.2). `Test_Cleaners.ahk` por la reescritura de un edge-case WHY que expandió 2 líneas con contexto de diseño.

---

## Candidatos para review senior

Agrupados por archivo. Cada uno tiene razón documentada en su `.md` correspondiente.

### `QuickEntry.ahk`

1. **`DoPegadoEspecial` — bloque `if interactive { ... }`**: el parámetro `interactive := false` nunca se pasa como `true` desde ningún caller productivo (el HUD no tiene botón para PegadoEspecial). El bloque es código defensivo con comentario inline que documenta la intención futura. No borrado: la decisión implica también borrar el comentario explicativo y es arquitectónica, no trivial.

2. **`RefrescarTooltip(res, accion := "")` — parámetros no usados en el cuerpo**: la función recibe `res` y `accion` pero su único statement es `hud.Update()`. Los parámetros son vestigios de una versión anterior donde la función armaba un tooltip antes de que el HUD absorbiera ese rol. Tiene 3 callers internos. Candidato a inlining o simplificación de firma.

### `Lib/CaptureEngine.ahk`

3. **`PreloadedCount` (getter)** — 0 referencias en producción (`QuickEntry.ahk` + `Lib/` + `Schemas/`). Solo 2 referencias en tests (`Test_CaptureEngine.ahk:296, 386`). Por criterio especial del cleanup, tests son callers válidos, por lo que no es dead code estricto. DUDOSO: si en el próximo ciclo sigue sin referencia productiva, evaluar eliminación.

### `Lib/Cleaners.ahk`

4. **`FormatearFechaTexto`** — 0 callers productivos externos. `LimpiarFechaRobusta` llama directamente a `MesTextoANumero` + `FormatearFecha` en sus 7 ramas, nunca a `FormatearFechaTexto`. Solo `Tests/Test_Cleaners.ahk:210-215` la ejercita. API pública documentada, retener como helper de conveniencia para futuros schemas o deprecar si no aparece ningún caller en el próximo ciclo.

5. **`LimpiarBillingItem`** — 0 callers productivos. `Schemas/_Plantilla_NuevaEmpresa.ahk:47` la documenta como API disponible para futuros schemas pero no la invoca. Solo `Tests/Test_Cleaners.ahk:249-262` la ejercita. Decisión: no borrar hasta que haya decisión explícita de descartar soporte de campos de descripción de factura.

### `Lib/TooltipFormatter.ahk`

6. **`TooltipPostAccion`** — 0 callers directos desde `QuickEntry.ahk` (el HUD tomó ese rol vía `hud.Update()`). Sí es caller interno de `TooltipConError` (línea 113 del fuente), y tiene 12 tests directos en `Test_TooltipFormatter.ahk`. API pública testeada; activa como bloque interno de `TooltipConError` y como punto de entrada para integraciones futuras.

7. **Parámetro `valorOverride` en `LineaPrevio` y `TooltipPostAccion`** — ningún caller productivo lo pasa con valor no-vacío; solo tests lo ejercitan. Candidato a simplificación de firma en un plan posterior.

---

## Ideas de simplificación recogidas (input para plan posterior)

### `QuickEntry.ahk`
- `RefrescarTooltip()` es hoy un wrapper de una sola línea (`hud.Update()`); se podría inlinear en cada callsite (3 ubicaciones) y eliminar la función intermedia. Riesgo bajo — verificar que no existan callers dinámicos ni tests que la nombren.
- El parámetro `accion` de `RefrescarTooltip(res, accion := "")` ya no se usa en el cuerpo; simplificar la firma a cero parámetros una vez que se decida si se inlinea o no.

### `Lib/AutoCalculator.ahk`
- Las constantes de paleta `AUTOCALC_*` podrían consolidarse en un módulo de tema compartido con `MainHud`, eliminando la duplicación con `MAINHUD_*` (hoy tienen los mismos valores hexadecimales).
- `ExtractNumberTokens` es una función pura sin dependencias de estado; podría moverse a `Lib/Cleaners.ahk` junto a `NormalizarPrecio` para centralizar la lógica de parsing numérico.
- El layout de `Build()` usa coordenadas absolutas px; parametrizar márgenes/anchos como constantes locales reduciría la deuda si el layout necesita ajustarse.

### `Lib/CaptureEngine.ahk`
- `PushRaw` y `PushForce` comparten el 80 % del cuerpo; podrían unificarse con un parámetro `skipValidation := false`.
- Los cuatro helpers privados (`EjecutarPrePasteSteps`, `EjecutarPreScanSteps`, `EmitirTabsTrasSlot`, `AutoAdvance`) no tienen convención de privacidad; documentarlos con prefijo `_` o moverlos a funciones internas top-level reduciría la superficie pública aparente.
- `DefaultCaptureField` es una función libre top-level que solo se usa como default de `captureFieldFn` en `Scan`; convertirla en método estático de `CaptureEngine` eliminaría la dependencia implícita de runtime.

### `Lib/Cleaners.ahk`
- `LimpiarFechaRobusta` tiene 7 bloques `if RegExMatch(...) { ... return }` casi idénticos; refactorizar a un array de `[patron, handler]` iterado en loop, reduciendo ~80 líneas a ~30.
- `NormalizarPrecio` y `DetectarNegativo` comparten lógica de strip de símbolos monetarios; unificar en un helper interno `_StripMonetario(s)`.
- `LimpiarComoPegadoEspecial` podría aceptar un parámetro opcional `modo` (`"fecha"` / `"precio"` / `"auto"`) cuando el contexto del campo es conocido.

### `Lib/HudLayout.ahk`
- `slotLabels` y `buttonLabels` son `Map` con `Map` anidados; podrían aplanarse con clave compuesta `"<idx>:<mode>"` para evitar el doble lookup.
- `LabelForSlot` y `LabelForButton` tienen lógica casi idéntica; extraer un helper privado `_Lookup(table, key, isCompact, fallback)`.
- El breakpoint `540` está hardcoded; documentar como deuda de diseño si se necesita un segundo breakpoint en el futuro.

### `Lib/MainHud.ahk`
- Inyectar callbacks `Do*` en el constructor en lugar de depender de funciones globales del entry point (`DoArmOrSkip`, `DoHeaderScan`, `DoSoltar`, `DoReset`, `DoUndo`). Pasarlos como `Map("arm", DoArmOrSkip.Bind(), ...)` en `__New` eliminaría el único acoplamiento invertido del grafo.
- Separar `Build()` en sub-métodos `_BuildSlotRows()`, `_BuildFooterButtons()`, `_WireEvents()` — actualmente tiene ~160 líneas mezclando construcción, wiring y registro de `OnMessage`.

### `Lib/PegadoEspecial.ahk`
- `pegadoEnCurso` es global de módulo sin encapsulación; convertir a property de objeto o closure para que el contrato con `CaptureEngine` sea explícito.
- Los timeouts y sleeps hardcodeados (`30`, `150`, `50` ms) podrían extraerse como constantes con nombre (`CLIPBOARD_UPDATE_TIMEOUT_S`, `PRE_PASTE_MODIFIER_DRAIN_MS`, etc.).
- `MsgBox "Error al actualizar clipboard."` interrumpe al operador; un tooltip efímero via `TooltipConError` sería consistente con el resto de la app.

### `Lib/Schema.ahk`
- El constructor de `Campo` acepta `expectedDeps` en posición 7 y `stepsAfter` en posición 8; migrar a un único parámetro `options := Map()` para reducir la firma larga y evitar `""` como placeholder en posiciones intermedias.
- `Field(slot)` no tiene caché; en loops del HUD que lo llaman múltiples veces por render, podría reemplazarse por acceso directo a `this.fields[slot]` cuando el caller ya validó bounds.

### `Lib/TooltipFormatter.ahk`
- `LineasOperandos` y `LineaPrevio` podrían unificarse en `LineaContexto(engine) → String` con la misma lógica de prioridad interna; reduciría la superficie pública de 8 a 6 símbolos.
- `LineaInputInvalido` es de una línea y solo la llama `TooltipConError`; candidato a inlinar (evaluando que los tests la ejerciten directamente).
- El parámetro `valorOverride` en `LineaPrevio` / `TooltipPostAccion` no tiene callers productivos que lo pasen con valor no-vacío; candidato a borrar para simplificar la firma.

### `Lib/Validators.ahk`
- `ValidarSumaCheck` podría marcarse con prefijo `_` para señalizar que no es API pública.
- Los dos skip conditions de `ValidarSumaCheck` (`cola.Length < maxIdx` y `cola[s] = ""`) podrían separarse con comentarios o sub-funciones para mejorar legibilidad del contrato.
- `ValidarFechaEstricta` podría aceptar formato configurable (`"DD/MM/YYYY"`) para reutilizarse en schemas de otras regiones.

### `Schemas/AsignetHeaderV1.ahk`
- `EsperadoSuma` podría vivir en `Lib/Schema.ahk` o `Lib/Validators.ahk` como helper genérico (duplicado en `_Plantilla_NuevaEmpresa.ahk`).
- Los tres thin wrappers `CleanRaw`, `CleanPasoPegado`, `CleanPasoPegadoForzandoNegativo` podrían unificarse en un único helper `CleanCampo(raw, forzarNeg := false)`.
- El bloque `prePasteSteps` de Corp name (slot 4) con 10 elementos hardcodeados podría extraerse a una constante `CORP_NAME_CURRENCY_STEPS`.

### `Schemas/_Plantilla_NuevaEmpresa.ahk`
- `PlantSuma` duplica el patrón de `EsperadoSuma`; extraer a helper genérico en `Lib/`.
- El docblock extenso (líneas 7–54) tiene parte de su contenido también en `docs/AGREGAR_EMPRESA.md`; evaluar reducirlo a los contratos de `Campo`/`InvoiceSchema` y referenciar el `.md` para el procedimiento.
- Los tres wrappers `PlantCleanRaw`, `PlantCleanPaso`, `PlantCleanForzarNeg` replican el patrón de `AsignetHeaderV1.ahk`; si se centraliza, los schemas nuevos dejan de necesitar redefinirlos.

### `Tests/Test_CaptureEngine.ahk`
- Una función de fábrica `CrearSchemaSimple(nSlots, tabsAfter, skipPaste)` reduciría el boilerplate de los ~15 schemas mock inline.
- `MockCapture` y variantes de `captureFieldFn` podrían unificarse en clase `MockReadFn` parametrizable (lista de valores + hook de abort opcional).
- `SendAbortFn` / `MockReadFn` como funciones top-level con estado en `Map` de script-level; convertir a instancias de clase `AbortMock` eliminaría los dos globals `abortCtl`/`scanCtl`.

### `Tests/Test_TooltipFormatter.ahk`
- El setup `e := CaptureEngine(CrearAsignetHeaderV1()) / e.Arm()` aparece 12 veces; una función helper `NuevoEngine()` de 2 líneas eliminaría el boilerplate.
- `eOmCompl` prueba un invariante de `CaptureEngine` (`IsComplete` con skip x9), no de `TooltipFormatter`; podría moverse a `Test_CaptureEngine.ahk`.

### `Tests/runner.ps1`
- El bloque de clasificación CRASH/FAIL/PASS podría extraerse a función `Invoke-AhkTest` que devuelva un objeto con propiedades `Passed`, `Asserts`, `Failures`, `CrashReason`.
- El formato de salida coloreado podría separarse de la lógica de evaluación para facilitar un modo `--quiet` o `--json`.

---

## Verificación de regresión

`Tests/runner.ps1` corrió 4 veces durante el cleanup:

| Run | Momento | Resultado |
|---|---|---|
| Baseline (Task 0.2) | Pre-cleanup, tras pre-fix runner | 756/756 |
| Test gate Fase 1 (Task 1.4) | Tras borrado de handlers M720 y `.bak` | 756/756 |
| Test gate seguridad Fase 2 (Task 2.1) | Tras cleanup de comentarios | 756/756 |
| Test gate Fase 3 (Task 3.2) | Tras audit de dead code | 756/756 |

Breakdown de asserts por suite (baseline = post-cleanup, sin cambios):

| Suite | Asserts |
|---|---|
| `Test_AsignetHeader.ahk` | 140 |
| `Test_CaptureEngine.ahk` | 218 |
| `Test_Cleaners.ahk` | 188 |
| `Test_HudLayout.ahk` | 43 |
| `Test_Schema.ahk` | 35 |
| `Test_TooltipFormatter.ahk` | 77 |
| `Test_Validators.ahk` | 55 |
| **Total** | **756** |

Ninguna regresión en los 4 runs. El cleanup fue exclusivamente de comentarios, handlers de mouse personales y metadata de docs — sin tocar lógica ni firmas de funciones.

---

## Próximo paso

Plan de simplificación posterior. Spec: este reporte (secciones "Candidatos para review senior" + "Ideas de simplificación recogidas").

Restricciones para ese plan:
- Por archivo, secuencial — un cambio puede romper conexiones a otros.
- Tests deben pasar después de CADA archivo modificado.
- Cada cambio se anota en `docs/files/<archivo>.md` sección "Bitácora de cleanup > Fase 5 — simplificación".
- Consulta inicial a `ClautoHotkey/Modules/Module_Instructions.md` + `Module_Classes.md` + `Module_GUI.md` antes de implementar.

Archivo destino del nuevo plan: `docs/superpowers/plans/2026-05-XX-simplify-quickentry-plan.md`.

---

## Cierre

Cleanup completado: 2026-05-12. Listo para senior review.

**Archivos `.bak` borrados (Task 1.2)**: `M720.ahk.bak`, `M720_Lib.ahk.bak`, `Test_M720_Lib.ahk.bak` — mapeos personales de botones de mouse Logitech M720 que no son parte del producto.

---

## Fase 5 — Simplificación segura (2026-05-12, post-cleanup)

Plan: [`2026-05-12-simplify-quickentry-plan.md`](2026-05-12-simplify-quickentry-plan.md).

### Cambios aplicados

| Archivo | Cambio | Razón |
|---|---|---|
| `QuickEntry.ahk` | `RefrescarTooltip(res, accion := "")` → `RefrescarTooltip()`. 3 callsites limpiados (HandlerCaptura, DoArmOrSkip, DoUndo). `Map()` y variable `accion` que solo existían para el call: eliminados. Global `engine` quitada del cuerpo. | Los 2 parámetros eran vestigios de una versión anterior del tooltip; el cuerpo solo llamaba `hud.Update()`. |
| `Lib/PegadoEspecial.ahk` | 4 magic numbers de timing extraídos a constantes globales nombradas. | Legibilidad: los timings son críticos pero opacos como literales inline. |
| 11 archivos productivos | Polish pass low-risk (trailing whitespace, blanks, indentación, trailing newline). Mayormente sin cambios; solo `QuickEntry.ahk` y `Schemas/AsignetHeaderV1.ahk` ganaron microcambios (trailing newline / tab→spaces). | Estado óptimo para senior review. |

### Constantes nombradas en `PegadoEspecial.ahk`

| Constante | Valor | Propósito |
|---|---|---|
| `PEGADO_MODIFIER_DRAIN_MS` | 30 | Procesar `Shift/Ctrl/Alt up` antes del próximo `SendInput`; sin esto puede generarse `^+v` en lugar de `^v`. |
| `PEGADO_CLIPBOARD_WAIT_S` | 0.5 | Timeout de `ClipWait` antes de abortar con `MsgBox`. |
| `PEGADO_POST_PASTE_SETTLE_MS` | 150 | Tiempo para que la app destino consuma `^v` antes de restaurar el clipboard original. |
| `PEGADO_MUTEX_DRAIN_MS` | 50 | Drena los `OnClipboardChange` encolados antes de liberar `pegadoEnCurso`. |

### Refactors NO aplicados (decisión senior pendiente)

Documentados en cada `docs/files/<archivo>.md` sección "Ideas de simplificación pendientes":

- **MainHud callback injection** — inyectar `Do*` callbacks en el constructor para romper la dependencia invertida HUD → entry point. Toca 8 sitios + tests + QuickEntry.
- **`MainHud.Build()` split** — fraccionar el método de ~200 líneas en `_BuildSlotRows`, `_BuildFooterButtons`, `_WireEvents`.
- **`LimpiarFechaRobusta` table-driven** — convertir 7 ramas de regex a `[patron, handler]` loop. Cambia performance characteristics; necesita benchmark.
- **`Campo` constructor con `options := Map()`** — colapsar 8 parámetros opcionales tardíos. Toca todos los schemas + tests + CaptureEngine.
- **`valorOverride` param removal en `TooltipFormatter`** — los tests ejercitan la cobertura intencionalmente. Quitarlo regresa cobertura.
- **`AutoCalculator.ExtractNumberTokens` move a `Cleaners`** — cambio de dependencia.
- **Consolidación de `CleanPasoPegado*` y `PlantClean*`** — los schemas son intencionalmente verbosos para claridad operativa.

Estos refactors quedan listos para que el senior decida cuáles tomar, en qué orden, y con qué red de seguridad adicional (benchmark, escenarios de regresión manual, etc).

### Verificación Fase 5

- Asserts pre / post Fase 5: **756 / 756** ✅
- Sintaxis: 12 productivos validados con `/validate` exit 0.
- Test runs Fase 5: 3 (post-Task 1, post-Task 2, post-Task 3).
