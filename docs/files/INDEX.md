# Inventario de archivos — QuickEntry

> Generado durante cleanup pre-producción (Plan: [`docs/superpowers/plans/2026-05-12-cleanup-quickentry-plan.md`](../superpowers/plans/2026-05-12-cleanup-quickentry-plan.md)).
> Cada archivo fuente tiene su `.md` con API, dependencias, y bitácora de cleanup.

## Estado por fase

| Fase | Descripción | Estado |
|---|---|---|
| 0 | Inventario + grafo de dependencias | 🟢 completa |
| 1 | Quitar mapping M720 (.bak + handlers mouse) | 🟢 completa |
| 2 | Quitar comentarios innecesarios | 🟢 completa |
| 3 | Quitar código muerto (conservador + anotado) | 🟢 completa |
| 4 | Handoff senior + plan de simplificación | 🟢 completa |
| 5 | Simplificación segura (post-cleanup) | 🟢 completa |
| 6 | Fix design violations D1-D6 (post code-review) | 🟢 completa |
| 7 | Critical fixes para producción multi-operador (post senior review) | 🟢 completa |

## Pre-fixes aplicados (fuera de las 5 fases)

- **2026-05-12 — `Tests/runner.ps1:6`**: path AHK64 hardcoded `C:\Users\Usuario\...` → reemplazado por discovery portable (`$env:AHK_V2` + 3 fallback paths). Razón: bloqueaba el test gate en cualquier máquina distinta a la del autor original; bloqueante también para uso interno multi-operador.

## Baseline

- **Tests**: 756 asserts pasando en 7 archivos. Output completo en [`_archive/2026-05-12-pre-cleanup/test-baseline.txt`](../../_archive/2026-05-12-pre-cleanup/test-baseline.txt).
- **Snapshot**: [`_archive/2026-05-12-pre-cleanup.zip`](../../_archive/2026-05-12-pre-cleanup.zip) (210 KB).

## Archivos productivos

### Entry point
- [`QuickEntry.md`](QuickEntry.md) — entry, hotkeys, singletons engine + hud

### `Lib/`
- [`Lib/AutoCalculator.md`](Lib/AutoCalculator.md)
- [`Lib/CaptureEngine.md`](Lib/CaptureEngine.md)
- [`Lib/Cleaners.md`](Lib/Cleaners.md)
- [`Lib/HudLayout.md`](Lib/HudLayout.md)
- [`Lib/MainHud.md`](Lib/MainHud.md)
- [`Lib/PegadoEspecial.md`](Lib/PegadoEspecial.md)
- [`Lib/Schema.md`](Lib/Schema.md)
- [`Lib/TooltipFormatter.md`](Lib/TooltipFormatter.md)
- [`Lib/Validators.md`](Lib/Validators.md)

### `Schemas/`
- [`Schemas/AsignetHeaderV1.md`](Schemas/AsignetHeaderV1.md)
- [`Schemas/_Plantilla_NuevaEmpresa.md`](Schemas/_Plantilla_NuevaEmpresa.md)

### `Tests/`
- [`Tests/_AssertHelpers.md`](Tests/_AssertHelpers.md)
- [`Tests/runner.md`](Tests/runner.md)
- [`Tests/Test_AsignetHeader.md`](Tests/Test_AsignetHeader.md)
- [`Tests/Test_CaptureEngine.md`](Tests/Test_CaptureEngine.md)
- [`Tests/Test_Cleaners.md`](Tests/Test_Cleaners.md)
- [`Tests/Test_HudLayout.md`](Tests/Test_HudLayout.md)
- [`Tests/Test_Schema.md`](Tests/Test_Schema.md)
- [`Tests/Test_TooltipFormatter.md`](Tests/Test_TooltipFormatter.md)
- [`Tests/Test_Validators.md`](Tests/Test_Validators.md)

## Archivos legacy
Removidos en Fase 1 (`M720.ahk.bak`, `M720_Lib.ahk.bak`, `Test_M720_Lib.ahk.bak`). Verificación 1.1: 66/68 símbolos migrados al código vivo, 2 descontinuados intencionalmente, 0 perdidos. Histórico disponible en [`_archive/2026-05-12-pre-cleanup.zip`](../../_archive/2026-05-12-pre-cleanup.zip).

## Grafo de dependencias

> **Nota temporal**: el grafo siguiente fue generado al cierre de Task 0.4 del cleanup (snapshot pre-Fase-1). Las **aristas de dependencia, clases públicas, funciones expuestas y globals** siguen siendo precisas (el cleanup no movió símbolos entre archivos), pero los **números de línea citados pueden estar desfasados** respecto al estado actual del código post-Fase-5. Cuando un caller cita `archivo.ahk:N`, consultar el código vivo para la línea exacta. Las referencias a símbolos eliminados (handlers `XButton1::`, `XButton2::`, `WheelLeft::`, `WheelRight::` removidos en Fase 1.3) están marcadas con tachado donde aplican.

### Edges (#Include)

Aristas directas (declaradas con `#Include` en cada archivo, con la ruta tal cual aparece en el `#Include`):

- `QuickEntry.ahk` → `Lib\Cleaners.ahk`, `Lib\Validators.ahk`, `Lib\Schema.ahk`, `Lib\CaptureEngine.ahk`, `Lib\TooltipFormatter.ahk`, `Lib\PegadoEspecial.ahk`, `Schemas\AsignetHeaderV1.ahk`, `Lib\MainHud.ahk` (líneas 2-9)
- `Lib/AutoCalculator.ahk` → `Cleaners.ahk` (línea 2)
- `Lib/CaptureEngine.ahk` → `Schema.ahk` (línea 2)
- `Lib/Cleaners.ahk` → (ninguno, sólo `#Requires`)
- `Lib/HudLayout.ahk` → (ninguno)
- `Lib/MainHud.ahk` → `CaptureEngine.ahk`, `TooltipFormatter.ahk`, `AutoCalculator.ahk`, `HudLayout.ahk` (líneas 2-5)
- `Lib/PegadoEspecial.ahk` → `Cleaners.ahk` (línea 2)
- `Lib/Schema.ahk` → (ninguno)
- `Lib/TooltipFormatter.ahk` → `CaptureEngine.ahk` (línea 2)
- `Lib/Validators.ahk` → (ninguno)
- `Schemas/AsignetHeaderV1.ahk` → `..\Lib\Cleaners.ahk`, `..\Lib\Validators.ahk`, `..\Lib\Schema.ahk` (líneas 2-4)
- `Schemas/_Plantilla_NuevaEmpresa.ahk` → `..\Lib\Cleaners.ahk`, `..\Lib\Validators.ahk`, `..\Lib\Schema.ahk` (líneas 2-4)
- `Tests/_AssertHelpers.ahk` → (ninguno)
- `Tests/Test_AsignetHeader.ahk` → `..\Schemas\AsignetHeaderV1.ahk`, `..\Lib\CaptureEngine.ahk`, `_AssertHelpers.ahk` (líneas 4-6)
- `Tests/Test_CaptureEngine.ahk` → `..\Lib\CaptureEngine.ahk`, `..\Lib\Validators.ahk`, `..\Schemas\AsignetHeaderV1.ahk`, `_AssertHelpers.ahk` (líneas 4-7)
- `Tests/Test_Cleaners.ahk` → `..\Lib\Cleaners.ahk`, `_AssertHelpers.ahk` (líneas 4-5)
- `Tests/Test_HudLayout.ahk` → `..\Lib\HudLayout.ahk`, `_AssertHelpers.ahk` (líneas 4-5)
- `Tests/Test_Schema.ahk` → `..\Lib\Validators.ahk`, `..\Lib\Schema.ahk`, `_AssertHelpers.ahk` (líneas 4-6)
- `Tests/Test_TooltipFormatter.ahk` → `..\Lib\TooltipFormatter.ahk`, `..\Schemas\AsignetHeaderV1.ahk`, `_AssertHelpers.ahk` (líneas 4-6)
- `Tests/Test_Validators.ahk` → `..\Lib\Validators.ahk`, `_AssertHelpers.ahk` (líneas 4-5)

> **Nota — cierre transitivo.** Los `#Include` de AHK v2 son recursivos y de-duplicados. `QuickEntry.ahk` arrastra (vía `MainHud.ahk`, `CaptureEngine.ahk`, etc.) todos los módulos de `Lib/` y el schema, así que basta con el set declarado para tener el grafo cargado en el entry point.

### Globals

Variables `global` declaradas/asignadas a nivel de script o leídas dentro de funciones con `global <var>`.

| Variable | Definida en (file:linea) | Leída en (file:linea) |
|---|---|---|
| `AUTO_CALCULAR_TOTALES_OMITIDOS` | `QuickEntry.ahk:28` | `QuickEntry.ahk:35` |
| `HOTKEY_OMITIR` | `QuickEntry.ahk:32` | `QuickEntry.ahk:102` (`global engine, pegadoEnCurso, HOTKEY_OMITIR`), `QuickEntry.ahk:115` |
| `engine` | `QuickEntry.ahk:35` | `QuickEntry.ahk:42, 43, 102, 111, 123, 132, 135, 152, 154, 160, 166, 168, 179, 182, 213, 218, 223, 224, 236, 239, 240, 252, 253, 259, 283, 305, 326` (singleton CaptureEngine; `global engine` declarado en `QuickEntry.ahk:102, 123, 132, 179, 236, 252, 283`) |
| `hud` | `QuickEntry.ahk:36` | `QuickEntry.ahk:41, 43, 44, 124, 132, 135, 137, 139, 146, 147, 168, 169, 170, 179, 217, 219, 224, 225, 236, 241, 242, 270, 283, 305, 333, 334` (singleton MainHud; `global hud` declarado en `QuickEntry.ahk:123, 132, 179, 236, 283`) |
| `pegadoEnCurso` | `Lib/PegadoEspecial.ahk:18` (def. inicial) — re-declarada como `global pegadoEnCurso` en `Lib/PegadoEspecial.ahk:22`, `QuickEntry.ahk:102, 179, 283` | `Lib/PegadoEspecial.ahk:23, 25, 57`; `QuickEntry.ahk:103, 180, 203, 226, 284, 308, 331` |
| `AUTOCALC_BG` | `Lib/AutoCalculator.ahk:13` | `Lib/AutoCalculator.ahk:46` |
| `AUTOCALC_FG_LABEL` | `Lib/AutoCalculator.ahk:14` | `Lib/AutoCalculator.ahk:47, 53, 61, 74` |
| `AUTOCALC_FG_DIM` | `Lib/AutoCalculator.ahk:15` | `Lib/AutoCalculator.ahk:57, 66` |
| `AUTOCALC_FG_NUMBER` | `Lib/AutoCalculator.ahk:16` | `Lib/AutoCalculator.ahk:69` |
| `AUTOCALC_FG_TOTAL` | `Lib/AutoCalculator.ahk:17` | `Lib/AutoCalculator.ahk:77` |
| `AUTOCALC_FONT_VALUE` | `Lib/AutoCalculator.ahk:18` | `Lib/AutoCalculator.ahk:61, 69, 77` |
| `AUTOCALC_FONT_LABEL` | `Lib/AutoCalculator.ahk:19` | `Lib/AutoCalculator.ahk:47, 53, 57, 66, 74` |
| `MAINHUD_BG` | `Lib/MainHud.ahk:16` | `Lib/MainHud.ahk:211` |
| `MAINHUD_BG_ROW` | `Lib/MainHud.ahk:17` | (no se lee — sólo declarada) |
| `MAINHUD_BG_ACTIVE` | `Lib/MainHud.ahk:18` | `Lib/MainHud.ahk:562` |
| `MAINHUD_FG_LABEL` | `Lib/MainHud.ahk:19` | `Lib/MainHud.ahk:212, 242, 334, 586` |
| `MAINHUD_FG_DIM` | `Lib/MainHud.ahk:20` | `Lib/MainHud.ahk:239, 245, 247, 248, 584, 605, 627` |
| `MAINHUD_FG_FILLED` | `Lib/MainHud.ahk:21` | `Lib/MainHud.ahk:254, 611, 636` |
| `MAINHUD_FG_PRELOAD` | `Lib/MainHud.ahk:22` | `Lib/MainHud.ahk:609, 631` |
| `MAINHUD_FG_FORCED` | `Lib/MainHud.ahk:23` | `Lib/MainHud.ahk:599` |
| `MAINHUD_FG_ACTIVE` | `Lib/MainHud.ahk:24` | `Lib/MainHud.ahk:578, 580, 607` |
| `MAINHUD_FG_ERROR` | `Lib/MainHud.ahk:25` | `Lib/MainHud.ahk:621` |
| `MAINHUD_FONT_VALUE` | `Lib/MainHud.ahk:26` | `Lib/MainHud.ahk:245, 248, 334, 599, 612, 621, 639` |
| `MAINHUD_FONT_LABEL` | `Lib/MainHud.ahk:27` | `Lib/MainHud.ahk:212, 242, 254, 580, 586` |
| `g_failures` | `Tests/_AssertHelpers.ahk:3` | `Tests/_AssertHelpers.ahk:8, 15, 21, 27, 34, 35, 36` (vía `global g_failures, g_total` en `AssertEq:8`, `AssertContains:21`, `ReportarYSalir:34`) |
| `g_total` | `Tests/_AssertHelpers.ahk:4` | `Tests/_AssertHelpers.ahk:8, 9, 21, 22, 34, 35` (vía `global` en mismas funciones) |
| `abortCtl` | `Tests/Test_CaptureEngine.ahk:732` (asignación implícita a nivel script) | `Tests/Test_CaptureEngine.ahk:734, 735, 736, 737, 738, 740` (`global abortCtl` en `SendAbortFn:734`) |
| `scanCtl` | `Tests/Test_CaptureEngine.ahk:767` (asignación implícita a nivel script) | `Tests/Test_CaptureEngine.ahk:769, 770, 771, 772, 776` (`global scanCtl` en `MockReadFn:769`) |

> **Notas globals.**
> - `engine` y `hud` son los dos singletons del entry point; cada handler `Do*()` los re-declara con `global <name>`. Los listo arriba con el set de líneas donde realmente se usan, no donde aparece la palabra-clave `global`.
> - `pegadoEnCurso` se declara con valor inicial en `Lib/PegadoEspecial.ahk:18` pero la rama de captura de `QuickEntry.ahk` también la lee/escribe; el contrato (documentado en el header de `PegadoEspecial.ahk`) es compartido entre `PegadoEspecial()` y `CaptureEngine.PasteBatch()`/`HandlerCaptura`.
> - `AUTOCALC_FG_INVALID`: **eliminada de la tabla** (Fase 3 auditada 2026-05-12). Grep confirma 0 ocurrencias en cualquier `.ahk`; la global no existía en el archivo fuente al momento de la auditoría. Solo `MAINHUD_BG_ROW` (`Lib/MainHud.ahk:17`) queda declarada sin lector — candidata a Fase 3 de MainHud.

### Cross-file callers/callees (resumen)

#### Clases públicas

- **Clase `CaptureEngine`** (definida en `Lib/CaptureEngine.ahk:77`).
  - Instanciada en: `QuickEntry.ahk:35` (singleton); `Tests/Test_CaptureEngine.ahk:26, 135, 157, 166, 186, 195-200 (vía clase), 217, 256, 274, 363, 379, 398, 423, 441, 458, 489, 495, 524, 541, 550, 562, 572, 600, 619, 638, 655, 671, 690, 699, 726, 766, 793, 803, 814, 821, 827, 849, 855, 864, 876, 882, 892, 910`; `Tests/Test_AsignetHeader.ahk:235, 260`; `Tests/Test_TooltipFormatter.ahk:24, 133, 143, 165, 171, 181, 202, 225, 256, 264, 287, 305`.
  - Métodos invocados desde `QuickEntry.ahk`: `Arm` (42, 166, 223), `SetExtraTabsAfter` (43, 168, 224, 305), `PushRaw` (111), `SkipCurrent` (160), `Abort` (239), `Reset` (218, 240), `Scan` (326), `PasteBatch` (213), `Undo` (259), `.isCapturing` lectura (103, 135, 152, 182, 253), `.IsComplete` (154), `.FilledCount` (182).
  - Métodos invocados desde `Lib/MainHud.ahk`: `.schema.Length` (216, 542, 945, 981), `.schema.Field` (230, 650), `.isCapturing` (531, 693, 922, 967), `.NextSlot` (543, 651, 699), `.FilledCount` (544, 967), `.queue[i]` (555, 777, 948, 986), `.preloadedSlots.Has` (558), `.ExpectedFor` (650), `.JumpTo` (711, 722, 734, 752, 821), `.PushForce` (753), `.ClearSlot` (813), `.PushManual` (822), `.Reset` (880), `.Undo` (898), `.SetExtraTabsAfter` (923), `.Arm` (976), `.AutoAdvance` (989).
  - Tests cubren todas las superficies públicas (`Arm`, `Reset`, `PushRaw`, `PushManual`, `PushForce`, `SkipCurrent`, `Undo`, `JumpTo`, `ClearSlot`, `ExpectedFor`, `Scan`, `PasteBatch`, `Abort`, `SetExtraTabsAfter`, `AutoAdvance`, props `NextSlot`/`IsComplete`/`FilledCount`/`PreloadedCount`).

- **Función `DefaultCaptureField`** (`Lib/CaptureEngine.ahk:63`): único caller es el default de `Scan()` en `Lib/CaptureEngine.ahk:398`. No tiene tests directos (depende de `SendInput`/clipboard reales).

- **Clase `MainHud`** (definida en `Lib/MainHud.ahk:29`).
  - Instanciada en `QuickEntry.ahk:36` (singleton). Sin tests unitarios (smoke-only, side-effect heavy).
  - Métodos llamados desde `QuickEntry.ahk`: `.Show` (41, 146, 169, 333), `.Update` (44, 124, 147, 170, 225, 334), `.Hide` (242), `.SaveLastPaste` (217), `.ClearAllPendingInvalid` (219, 241), `.OpenInlineEditOnCurrentSlot` (270), `.templateMode` (43, 168, 224, 305), `.gui.Hwnd` (137, 139).
  - Llamadas a funciones top-level de `QuickEntry.ahk` desde handlers internos: `DoArmOrSkip()` (`MainHud.ahk:308`), `DoHeaderScan(true)` (`MainHud.ahk:310`), `DoSoltar(true)` (`MainHud.ahk:311`), `DoReset()` (`MainHud.ahk:312`), `DoUndo()` (`MainHud.ahk:313`). **Acoplamiento bidireccional**: `MainHud` referencia los handlers `Do*` globales definidos en el entry point; `QuickEntry.ahk` llama métodos de `hud` y `engine`. No hay tests unitarios de esto (smoke-only).

- **Clase `AutoCalculator`** (definida en `Lib/AutoCalculator.ahk:22`).
  - Instanciada únicamente en `Lib/MainHud.ahk:935` (lazy, dentro de `OnAutoCalc`). Sin tests.

- **Clase `HudLayout`** (definida en `Lib/HudLayout.ahk:11`, sólo métodos estáticos).
  - Consumida desde `Lib/MainHud.ahk`: `HudLayout.IsRectVisibleAgainst` (119, 147), `HudLayout.LabelForSlot` (380), `HudLayout.LabelForButton` (396, 406, 534, 540, 928), `HudLayout.NameColWidth` (410), `HudLayout.IsCompact` (497, 671).
  - Tests: `Tests/Test_HudLayout.ahk` (8–76) ejercita `IsCompact`, `LabelForSlot`, `LabelForButton`, `NameColWidth`, `IsRectVisibleAgainst`.

- **Clases `Campo` e `InvoiceSchema`** (definidas en `Lib/Schema.ahk:46` y `:71`).
  - Instanciadas en: `Schemas/AsignetHeaderV1.ahk:58-73` (9 `Campo()` + 1 `InvoiceSchema()` en `:101`), `Schemas/_Plantilla_NuevaEmpresa.ahk:94-110, 132` (plantilla), `Tests/Test_Schema.ahk:11, 18, 24, 31, 41, 49, 57, 65` (`Campo` y `InvoiceSchema`), `Tests/Test_CaptureEngine.ahk` (innumerables veces — `CrearMock`, schemas inline `schemaTabOnly`, `schemaUno`, `schemaPre`, `schemaPre2`, `schemaSinPre`, `schemaScan`, `schemaSkipScan`, `schemaCompare`, `schemaPasteScan`, `schemaEmpty`, `schemaAbort`, `schemaAbScan`, `schemaET`, `schemaScET`), `Tests/Test_Validators.ahk` (indirecto vía Schema).
  - Consumido por `Lib/CaptureEngine.ahk` exclusivamente vía la instancia pasada al constructor (`this.schema.Field(slot)`, `this.schema.Length`, `this.schema.ordenPegado`, `this.schema.prePasteSteps`, `this.schema.preScanSteps`).

#### Funciones libres expuestas

- **`PegadoEspecial()`** (`Lib/PegadoEspecial.ahk`).
  - Callers: ~~`QuickEntry.ahk:57` (binding `XButton2`)~~ **removido en Fase 1.3**; `QuickEntry.ahk` función `DoPegadoEspecial` (invocada por hotkey `^+v::`).
  - No tiene tests directos (side-effect: clipboard + `SendInput`).

- **`CrearAsignetHeaderV1()`** (`Schemas/AsignetHeaderV1.ahk:54`).
  - Callers: `QuickEntry.ahk:35`, `Tests/Test_AsignetHeader.ahk:14, 235, 260`, `Tests/Test_CaptureEngine.ahk:524, 541, 690, 699`, `Tests/Test_TooltipFormatter.ahk:24, 133, 143, 165, 171, 181, 202, 225, 256, 264, 287, 305`.

- **Helpers locales de `Schemas/AsignetHeaderV1.ahk`** (`CleanRaw:22`, `CleanPasoPegado:23`, `CleanPasoPegadoForzandoNegativo:24`, `EsperadoSuma:31`, `ExpectedSlot5:49`, `ExpectedSlot9:50`): se usan únicamente dentro del mismo archivo (líneas 58-73) como argumentos del constructor `Campo`. Tests los ejercitan **indirectamente** vía `s.Field(i).clean.Call(...)` / `.expectedFn.Call(...)` (Test_AsignetHeader). No tienen callers en otros archivos.

- **`CrearMiEmpresaHeaderV1()`** (`Schemas/_Plantilla_NuevaEmpresa.ahk:89`) + helpers `PlantCleanRaw`, `PlantCleanPaso`, `PlantCleanForzarNeg`, `PlantSuma`: **sin callers**. Es el archivo plantilla para copiar al crear schemas de otras empresas; no se incluye en `QuickEntry.ahk` y no tiene tests. Cumple su rol de template-only.

- **Funciones de `Lib/Cleaners.ahk`**:
  - `FormatearFecha` (`:16`): callers internos en `Lib/Cleaners.ahk` (`FormatearFechaTexto:48`, `LimpiarFechaRobusta:82, 92, 102, 110, 117, 128, 138, 147`). Tests: `Tests/Test_Cleaners.ahk:193-203`. No usado por otros módulos productivos.
  - `FormatearFechaTexto` (`:41`): sin callers en producción (sólo expuesto). Tests: `Tests/Test_Cleaners.ahk:208-213`.
  - `MesTextoANumero` (`:51`): callers internos en `Lib/Cleaners.ahk` (`FormatearFechaTexto:43`, `LimpiarFechaRobusta:89, 100, 124, 136`). Tests: `Tests/Test_Cleaners.ahk:156-188`.
  - `LimpiarFechaRobusta` (`:75`): caller productivo en `Lib/Cleaners.ahk:223` (dentro de `LimpiarComoPegadoEspecial`). Tests: `Tests/Test_Cleaners.ahk:13-90, 264-269`.
  - `DetectarNegativo` (`:155`): caller productivo en `Lib/Cleaners.ahk:174` (dentro de `NormalizarPrecio`). Tests: `Tests/Test_Cleaners.ahk:218-231`.
  - `NormalizarPrecio` (`:169`): callers — `Lib/AutoCalculator.ahk:108, 159` (motor del calculator), `Lib/Cleaners.ahk:227` (vía `LimpiarComoPegadoEspecial`). Tests: `Tests/Test_Cleaners.ahk:97-139`.
  - `LimpiarBillingItem` (`:208`): **sin callers productivos** ni desde Tests sobre código de producción; sólo Test_Cleaners (`:249-260`) lo ejercita. Documentado en plantilla como cleaner disponible pero ningún schema lo usa. Candidato a evaluar en Fase 3.
  - `LimpiarComoPegadoEspecial` (`:217`): callers — `Lib/PegadoEspecial.ahk:33` (`PegadoEspecial()`), `Schemas/AsignetHeaderV1.ahk:23, 26` (`CleanPasoPegado` y `CleanPasoPegadoForzandoNegativo`), `Schemas/_Plantilla_NuevaEmpresa.ahk:58, 61` (plantilla). Tests: `Tests/Test_Cleaners.ahk:144-151`.
  - `ForzarNegativo` (`:241`): callers — `Schemas/AsignetHeaderV1.ahk:27` (vía `CleanPasoPegadoForzandoNegativo`), `Schemas/_Plantilla_NuevaEmpresa.ahk:62`. Tests: `Tests/Test_Cleaners.ahk:236-244`.

- **Funciones de `Lib/Validators.ahk`**:
  - `EsImporteValido` (`:14`): callers internos en `Lib/Validators.ahk` (`ValidarNumero:26`, `ValidarSumaCheck:46`). Tests: `Tests/Test_Validators.ahk:10-23`.
  - `ValidarNoVacio` (`:19`): callers — `Schemas/AsignetHeaderV1.ahk:58, 61` (slots 1 y 4), `Schemas/_Plantilla_NuevaEmpresa.ahk:94, 98, 104`, `Tests/Test_CaptureEngine.ahk:15, 305, 307, 345, 346, 391, 392, 393, 435, 436, 437, 481, 482, 483` (schemas mock). Tests directos: `Tests/Test_Validators.ahk:28-30`.
  - `ValidarNumero` (`:24`): callers — `Schemas/AsignetHeaderV1.ahk:69, 70, 72` (slots 5, 6, 8), `Schemas/_Plantilla_NuevaEmpresa.ahk:107, 110`, `Tests/Test_CaptureEngine.ahk:16, 306, 311, 487`. Tests directos: `Tests/Test_Validators.ahk:35-40`.
  - `ValidarFechaEstricta` (`:29`): callers — `Schemas/AsignetHeaderV1.ahk:59, 60` (slots 2, 3), `Schemas/_Plantilla_NuevaEmpresa.ahk:101`. Tests: `Tests/Test_Validators.ahk:45-54`.
  - `ValidarSumaTol` (`:39`): callers — `Schemas/AsignetHeaderV1.ahk:71, 73` (slots 7 y 9), `Tests/Test_CaptureEngine.ahk:17` (mock). Tests directos: `Tests/Test_Validators.ahk:59-99`.
  - `ValidarSumaCheck` (`:44`): helper interno de `ValidarSumaTol` (`.Bind` en `Lib/Validators.ahk:41`); no se llama desde fuera. Cubierto indirectamente por los tests de `ValidarSumaTol`.

- **Funciones de `Lib/TooltipFormatter.ahk`**:
  - `EnNegrita` (`:22`): caller productivo `Lib/TooltipFormatter.ahk:59` (dentro de `LineaPrevio`). Tests: `Tests/Test_TooltipFormatter.ahk:17-19`.
  - `LineaPrompt` (`:25`): callers — `Lib/TooltipFormatter.ahk:93` (`TooltipPostAccion`). Tests: `Tests/Test_TooltipFormatter.ahk:151-152, 270-274`.
  - `LineaPrevio` (`:45`): callers — `Lib/TooltipFormatter.ahk:99` (`TooltipPostAccion`). Tests: `Tests/Test_TooltipFormatter.ahk:35, 290, 300, 309`.
  - `LineasOperandos` (`:63`): callers — `Lib/TooltipFormatter.ahk:95` (`TooltipPostAccion`). Tests: `Tests/Test_TooltipFormatter.ahk:159, 168, 178, 189`.
  - `TooltipPostAccion` (`:91`): caller productivo `Lib/TooltipFormatter.ahk:115` (`TooltipConError`). **Sin callers directos desde `QuickEntry.ahk`** — el flujo del HUD reemplazó al tooltip; queda accesible via test harness. Tests: `Tests/Test_TooltipFormatter.ahk:30, 41, 59, 66, 69, 73, 82, 99, 110, 124, 136, 258`.
  - `TooltipError` (`:104`): callers — `QuickEntry.ahk:114`. Tests: `Tests/Test_TooltipFormatter.ahk:207, 231, 242, 245, 248`.
  - `LineaInputInvalido` (`:107`): caller productivo `Lib/TooltipFormatter.ahk:119` (`TooltipConError`). Tests: `Tests/Test_TooltipFormatter.ahk:196-197`.
  - `TooltipConError` (`:113`): caller productivo `QuickEntry.ahk:115`. Tests: `Tests/Test_TooltipFormatter.ahk:208, 215, 221, 232`.

- **Funciones top-level de `QuickEntry.ahk`** (capa de hotkeys):
  - `DoPegadoEspecial(interactive)` (`:82`): caller `QuickEntry.ahk:76` (`^+v::`). No es llamada desde `Lib/MainHud.ahk` (el HUD no tiene botón para PegadoEspecial).
  - `HandlerCaptura(tipoData)` (`:100`): registrada por `OnClipboardChange` en `QuickEntry.ahk:98`. No tiene callers explícitos (la dispara el runtime).
  - `RefrescarTooltip(res, accion)` (`:121`): callers en el mismo archivo (`:118, 162, 266`).
  - `DoArmOrSkip()` (`:130`): callers `QuickEntry.ahk:128` (`^+a::`) y `Lib/MainHud.ahk:308` (botón).
  - `DoSoltar(interactive)` (`:177`): callers `QuickEntry.ahk:175` (`^+s::`) y `Lib/MainHud.ahk:311` (botón).
  - `DoReset()` (`:234`): callers `QuickEntry.ahk:232` (`^+r::`) y `Lib/MainHud.ahk:312` (botón).
  - `DoUndo()` (`:250`): callers `QuickEntry.ahk:248` (`^+u::`) y `Lib/MainHud.ahk:313` (botón).
  - `DoHeaderScan(interactive)` (`:281`): callers `QuickEntry.ahk:279` (`^+h::`) y `Lib/MainHud.ahk:310` (botón).

- **Tests/`runner.ps1`**: harness PowerShell que enumera `Tests/Test_*.ahk` y los lanza vía `AutoHotkey64.exe`. No es código AHK; queda fuera del grafo de funciones.

#### Inconsistencias y notas

- **Globals declaradas sin uso**: `MAINHUD_BG_ROW` (`Lib/MainHud.ahk:17`). No rompe nada (constante de paleta), pero podría retirarse en Fase 3 de MainHud. `AUTOCALC_FG_INVALID` fue cerrada en Fase 3 de AutoCalculator (2026-05-12): la global no existía en el `.ahk` al momento de la auditoría — nunca fue introducida o ya había sido eliminada antes del inventario.
- **Función huérfana en código productivo**: `LimpiarBillingItem` (`Lib/Cleaners.ahk:208`). Sólo se llama desde su test; ningún schema declarado la usa. Está documentada como cleaner público en la plantilla, así que es API expuesta pero sin consumer activo — decisión consciente, no bug.
- **Acoplamiento entry-point ↔ HUD**: `Lib/MainHud.ahk` invoca funciones libres `DoArmOrSkip/DoHeaderScan/DoSoltar/DoReset/DoUndo` que viven en `QuickEntry.ahk`. No es una dependencia detectable por `#Include` (los handlers se resuelven en runtime). Es la única dependencia "invertida" del grafo y vale la pena documentarla cuando se redacte la guía técnica.
- **Sin dependencias circulares por `#Include`**: el grafo es DAG con `QuickEntry.ahk` como raíz; todas las hojas son `Lib/Cleaners.ahk`, `Lib/Schema.ahk`, `Lib/HudLayout.ahk`, `Lib/Validators.ahk`, `Tests/_AssertHelpers.ahk` (cero `#Include`).
- **Comentarios con tokens de funciones** (no son llamadas reales, sólo nomenclatura):
  - `Lib/CaptureEngine.ahk:405` menciona `DoHeaderScan` en comentario.
  - `Lib/MainHud.ahk:9, 809` mencionan `RefrescarTooltip` y `ValidarNoVacio` en comentarios.
  - `Lib/PegadoEspecial.ahk:54` menciona `HandlerCaptura` en comentario.
  - `Schemas/_Plantilla_NuevaEmpresa.ahk` enumera cleaners/validators disponibles en su docblock pero sólo usa `PlantCleanPaso`, `PlantCleanRaw`, `PlantCleanForzarNeg`, `ValidarNoVacio`, `ValidarFechaEstricta`, `ValidarNumero` en `fields`.

## Resumen de cleanup

**Cleanup cerrado: 2026-05-12.** Reporte final: [`2026-05-12-cleanup-quickentry-final.md`](../superpowers/plans/2026-05-12-cleanup-quickentry-final.md).

- **Productivo**: −181 líneas en 12 archivos (mayor: `MainHud` −78, `CaptureEngine` −37, `QuickEntry` −35).
- **Tests**: −104 líneas en 9 archivos (mayor: `Test_CaptureEngine` −91).
- **`.bak` borrados**: 3 (M720*).
- **Asserts**: 756/756 sin regresión (4 runs durante el cleanup).
- **Pre-fix portabilidad**: `Tests/runner.ps1` ahora detecta AHK64 sin path hardcoded.
- **Candidatos para review senior**: 7 anotados (input para plan de simplificación).

**Fase 5 — Simplificación cerrada: 2026-05-12.** Plan: [`2026-05-12-simplify-quickentry-plan.md`](../superpowers/plans/2026-05-12-simplify-quickentry-plan.md).

- **`QuickEntry.ahk`**: `RefrescarTooltip(res, accion := "")` → `RefrescarTooltip()`. 3 callsites simplificados. Eliminados `Map()` y variable `accion` que solo existían para pasarse como argumentos. Global `engine` quitada del cuerpo.
- **`Lib/PegadoEspecial.ahk`**: 4 magic numbers de timing extraídos a constantes nombradas (`PEGADO_MODIFIER_DRAIN_MS=30`, `PEGADO_CLIPBOARD_WAIT_S=0.5`, `PEGADO_POST_PASTE_SETTLE_MS=150`, `PEGADO_MUTEX_DRAIN_MS=50`).
- **Polish pass** en los 12 productivos: 11 ya estaban en estado óptimo (0 cambios); `QuickEntry.ahk` ganó trailing newline final; `Schemas/AsignetHeaderV1.ahk` ganó trailing newline + 1 tab → spaces.
- **Refactors NO automatizados** (decisión senior): MainHud callback injection, `Build()` split, `LimpiarFechaRobusta` table-driven, `Campo(options:=Map())`, `valorOverride` removal, `ExtractNumberTokens` move, consolidación de `CleanPasoPegado*` / `PlantClean*`. Documentados en cada `docs/files/<archivo>.md` sección "Ideas de simplificación pendientes".
- **Asserts**: 756/756 sin regresión (3 runs adicionales durante Fase 5).

**Fase 6 — Design violations fix (2026-05-12).** Plan: [`2026-05-12-fix-design-violations-plan.md`](../superpowers/plans/2026-05-12-fix-design-violations-plan.md). Backup: `_archive/2026-05-12-post-cleanup.zip`.

- **D1, D2**: `docs/MANUAL_USUARIO.md` actualizado — "tooltip flotante" → HUD persistente con triple rol de `^+a`; 3 filas de "picker" obsoleto → inline edit en HUD.
- **D3, D4**: `docs/superpowers/specs/2026-04-29-main-hud-gui-design.md` anotado con `SUPERSEDED 2026-05-12` markers — edge case 8 (× hides en lugar de ExitApp) y D1 (continuous capture mode en lugar de hide post-paste).
- **D5**: `Lib/CaptureEngine.ahk:260` — `ClearSlot` actionLog Map ahora incluye `"type", "clear"` para alinearse con spec `2026-05-10 §2.4`. Tests +1 assert (756 → 757).
- **D6**: `docs/MANUAL_USUARIO.md` + `docs/GUIA_TECNICA.md` documentan el **triple rol** de `^+a` (restaurar HUD oculto / omitir slot / armar captura).
- **Asserts**: 756 → **757** ✅ sin regresión (1 nuevo test verificando `"type"`).

**Fase 7 — Critical fixes para producción multi-operador (2026-05-12).** Plan: [`2026-05-12-critical-fixes-production-plan.md`](../superpowers/plans/2026-05-12-critical-fixes-production-plan.md). Backup: `_archive/2026-05-12-post-fase6.zip`.

- **C1**: `#SingleInstance Force` agregado en `QuickEntry.ahk:2`. Doble instancia ya no corrompe la cola (la vieja muere, la nueva toma su lugar).
- **C2**: `try/catch as e` agregado en `DoSoltar` y `DoHeaderScan`. Errores muestran tooltip user-friendly + log estructurado en lugar de stacktrace AHK.
- **C3**: Nuevo `Lib/Logger.ahk` (file logging + rotación a 1 MB) — output a `%APPDATA%\QuickEntry\events.log`. Wireado en `arm` / `paste_batch_start|done|failed` / `scan_start|done|failed` / `reset` / `undo` / `startup` / `schema_unknown`. **Tests**: +8 asserts (`Test_Logger.ahk`).
- **C4**: Schema selection runtime via INI (`%APPDATA%\QuickEntry\config.ini` `[General]\Schema=`). Registry `SCHEMA_REGISTRY` en `QuickEntry.ahk` permite multi-empresa sin editar código. Fallback a `AsignetHeaderV1` con MsgBox + log si key desconocida. `docs/AGREGAR_EMPRESA.md` actualizado con Paso 7 (registrar schema) + Paso 8 (activar via INI).
- **C5**: Title del HUD ahora muestra `QuickEntry — CAPTURA ACTIVA (Ctrl+C guarda al slot)` cuando `engine.isCapturing`, y `QuickEntry — pausado (Ctrl+Shift+A para armar)` en caso contrario. Operador nuevo ve el estado de un vistazo.
- **C6**: Nuevo `Lib/PasteMutex.ahk` encapsula el lock antes-global `pegadoEnCurso`. `PegadoEspecial`, `HandlerCaptura`, `DoSoltar`, `DoHeaderScan` usan `PasteMutex.IsLocked` / `Acquire()` / `Release()`. Cero `global pegadoEnCurso` en el repo. **Tests**: +8 asserts (`Test_PasteMutex.ahk`).
- **Asserts**: 757 → **773** ✅ sin regresión. Sintaxis: 14 archivos validados (+2 nuevos módulos `Lib/Logger.ahk`, `Lib/PasteMutex.ahk` + 2 nuevos tests).
- **Pendientes (Important del senior review, próximo ciclo)**: callback injection MainHud, `Build()` split, magic numbers en `CaptureEngine`, `INSTALL.md`, versionado visible, `last_paste.ini` opt-out, tests de GUI mínimos. Documentados al final del plan de Fase 7.
