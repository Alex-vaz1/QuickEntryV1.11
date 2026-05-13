---
file: Lib/CaptureEngine.ahk
last_review: 2026-05-12
status: active
---

# `Lib/CaptureEngine.ahk`

## Propósito

Motor de captura schema-driven para QuickEntry. Mantiene una cola de slots (`queue`) alineada al `InvoiceSchema`, expone operaciones puras de estado (`PushRaw`, `SkipCurrent`, `Undo`, `JumpTo`) y operaciones con side-effects de I/O (`Scan`, `PasteBatch`). Es la pieza central que separa la lógica de captura de la presentación (MainHud) y del entry point (QuickEntry.ahk).

## API pública

### Funciones libres

- **`DefaultCaptureField() → String`** — lee el campo actualmente enfocado vía `Ctrl+A` + `Ctrl+C`; retorna `""` si el campo está vacío o si `ClipWait` no recibe datos en 0.5 s.
  - Llamado desde: `Lib/CaptureEngine.ahk:398` (default del parámetro `captureFieldFn` en `Scan()`)
  - Llama a: `SendInput`, `ClipWait`, `A_Clipboard`

### Clases

- **`CaptureEngine(schema, autoCalcFlag := false)`** — motor de captura; instanciar una vez por sesión de captura activa.
  - **Propiedades**:
    - `schema` — `InvoiceSchema` pasado al constructor; inmutable durante la captura.
    - `queue` — `Array<String>` pre-alocado a `schema.Length`; `""` = slot vacío.
    - `actionLog` — `Array<Map>` de acciones `{slot, prevValue}` para soporte de `Undo`.
    - `targetSlot` — `Integer`; `0` = cursor secuencial (lo determina `NextSlot`), distinto de `0` = slot forzado por picker o `Undo`.
    - `preloadedSlots` — `Map<Integer, true>`; slots pre-cargados por `Scan()`. `PasteBatch` los omite en paste y solo emite Tabs.
    - `isCapturing` — `Boolean`; `true` entre `Arm()` y `Reset()`/`Abort()`.
    - `clipBackup` — `String`; snapshot del clipboard antes de `Arm`/`Scan`, restaurado al final de `PasteBatch` y `Scan`.
    - `autoCalcFlag` — `Boolean`; si `true`, `SkipCurrent` en un slot con `expectedFn` empuja el valor calculado en lugar de `""`.
    - `abortFlag` — `Boolean`; seteado por `Abort()` para interrumpir loops de `PasteBatch`/`Scan` en curso. No toca `queue` ni `actionLog`.
    - `extraTabsAfterSlot` — `Map<slot, count>`; tabs adicionales a emitir después de la navegación normal de un slot (para fields opcionales intercalados en el form).
  - **Propiedades computadas (getters)**:
    - `NextSlot → Integer` — retorna `targetSlot` si distinto de `0`; si no, el primer `""` en `queue`; si no hay ninguno, `0`.
    - `IsComplete → Boolean` — `true` cuando `NextSlot = 0`.
    - `FilledCount → Integer` — cantidad de slots cuyo `queue[i] != ""`.
    - `PreloadedCount → Integer` — `preloadedSlots.Count`.
  - **Métodos**:
    - `Arm(clipSnapshot := "") → void` — resetea estado, setea `isCapturing := true`, guarda `clipSnapshot` en `clipBackup`.
      - Llamado desde: `QuickEntry.ahk:42, 166, 223`; `Lib/MainHud.ahk:976`
      - Llama a: `ResetState()`
    - `Reset() → void` — resetea estado, setea `isCapturing := false`, limpia `clipBackup`.
      - Llamado desde: `QuickEntry.ahk:218, 240`; `Lib/MainHud.ahk:880`
      - Llama a: `ResetState()`
    - `Abort() → void` — setea `abortFlag := true`; idempotente. Los loops de `PasteBatch`/`Scan` hacen `break` en el siguiente ciclo.
      - Llamado desde: `QuickEntry.ahk:239`
    - `SetExtraTabsAfter(slot, count) → void` — configura tabs adicionales tras el slot `slot`. `count = 0` elimina la entrada del map.
      - Llamado desde: `QuickEntry.ahk:43, 168, 224, 305`; `Lib/MainHud.ahk:923`
    - `JumpTo(slot) → Map(slot, label)` — fuerza `targetSlot`. Lanza `ValueError` si `slot` fuera de rango `[1, schema.Length]`.
      - Llamado desde: `Lib/MainHud.ahk:711, 722, 734, 752, 821`
    - `PushRaw(raw) → Map(ok, error, label, slot, value)` — limpia (`campo.clean`) y valida (`campo.validate`) el raw; si pasa, graba en `queue[NextSlot]`, registra en `actionLog`, llama `AutoAdvance`. Retorna `ok: false` si cola completa, si `clean` retorna `""`, o si `validate` retorna error.
      - Llamado desde: `QuickEntry.ahk:111`
      - Llama a: `campo.clean.Call(raw)`, `campo.validate.Call(limpio, queue)`, `AutoAdvance()`
    - `PushManual(value) → Map(ok, error, label, slot, value)` — alias de `PushRaw`.
      - Llamado desde: `Lib/MainHud.ahk:822`
    - `PushForce(raw) → Map(ok, error, label, slot, value)` — limpia sin validar; bypassa `campo.validate`. El `clean` sigue aplicándose; si devuelve `""`, rechaza igual. Pensado para "forzar igual" tras entrada inválida confirmada por el operador.
      - Llamado desde: `Lib/MainHud.ahk:753`
      - Llama a: `campo.clean.Call(raw)`, `AutoAdvance()`
    - `SkipCurrent() → Map(value, slot, label)` — empuja `""` (o el valor de `expectedFn` si `autoCalcFlag` y el campo lo tiene) al slot actual, registra en `actionLog`, llama `AutoAdvance`. Si `NextSlot = 0`, retorna todo vacío.
      - Llamado desde: `QuickEntry.ahk:160`
      - Llama a: `campo.expectedFn.Call(queue)` (condicional), `AutoAdvance()`
    - `Undo() → Map(ok, slot, label)` — pop del `actionLog`, restaura `queue[slot]` al `prevValue`, fuerza `targetSlot := slot`. Retorna `ok: false` si el log está vacío.
      - Llamado desde: `QuickEntry.ahk:259`; `Lib/MainHud.ahk:898`
    - `ClearSlot(slot) → void` — borra `queue[slot]` a `""` y lo quita de `preloadedSlots`; registra en `actionLog`. No ejecuta validadores.
      - Llamado desde: `Lib/MainHud.ahk:813`
    - `ExpectedFor(slot) → String` — delega a `campo.expectedFn.Call(queue)`; retorna `""` si el slot está fuera de rango o el campo no tiene `expectedFn`.
      - Llamado desde: `Lib/MainHud.ahk:650`
    - `Scan(captureFieldFn?, sendFn?, sleepFn?, clipSnapshot?) → void` — pre-popula `queue`/`preloadedSlots` leyendo cada slot del form vía `captureFieldFn` + `campo.clean`. Preserva `extraTabsAfterSlot` a través del `ResetState` interno. Ejecuta `preScanSteps` (o `prePasteSteps` como fallback). Revisa `abortFlag` en cada iteración. Restaura el clipboard al terminar.
      - Llamado desde: `QuickEntry.ahk:326`
      - Llama a: `ResetState()`, `EjecutarPreScanSteps()`, `EmitirTabsTrasSlot()`, `AutoAdvance()`, `DefaultCaptureField` (default `captureFieldFn`)
    - `PasteBatch(sendFn?, sleepFn?) → void` — itera `schema.ordenPegado`; para cada slot no-preloaded con valor no-vacío y no-`skipPaste`: copia al clipboard con `ClipWait`, emite `^v`. Slots preloaded o vacíos solo emiten Tabs. Revisa `abortFlag` en cada iteración. Restaura el clipboard al terminar.
      - Llamado desde: `QuickEntry.ahk:213`
      - Llama a: `EjecutarPrePasteSteps()`, `EmitirTabsTrasSlot()`, `ClipWait`

#### Métodos privados (internos, no invocar desde fuera)

- `ResetState() → void` — inicializa `queue`, `actionLog`, `targetSlot`, `preloadedSlots`, `abortFlag`, `extraTabsAfterSlot`.
- `AutoAdvance(slotJustActed) → void` — busca el próximo `""` cíclicamente (primero `slot+1..end`, luego `1..slot-1`); actualiza `targetSlot`; si no hay vacíos, `targetSlot := 0`.
- `EjecutarPrePasteSteps(sendFn, sleepFn) → void` — emite `schema.prePasteSteps` con 150 ms entre pasos.
- `EjecutarPreScanSteps(sendFn, sleepFn) → void` — emite `schema.preScanSteps` (o `prePasteSteps` como fallback) con 150 ms entre pasos.
- `EmitirTabsTrasSlot(campo, isLast, sendFn, sleepFn, usarStepsAfter := false) → void` — emite tabs de navegación; si `usarStepsAfter=true` y el campo tiene `stepsAfter`, los ejecuta en lugar de los tabs.

## Dependencias

- **#Include directos**: `Schema.ahk`
- **Incluido por**: `QuickEntry.ahk` (vía `#Include Lib\CaptureEngine.ahk`); `Lib/MainHud.ahk`; `Lib/TooltipFormatter.ahk`; `Tests/Test_CaptureEngine.ahk`; `Tests/Test_AsignetHeader.ahk`; `Tests/Test_TooltipFormatter.ahk`
- **Globales que define**: ninguna
- **Globales que usa (leídas)**: `A_Clipboard` (built-in AHK v2)
- **Símbolos externos invocados**:
  - `InvoiceSchema` / `Campo` (de `Schema.ahk`) — pasados como `schema` al constructor; accedidos vía `.Length`, `.Field(slot)`, `.ordenPegado`, `.prePasteSteps`, `.preScanSteps`
  - `SendInput` (built-in AHK v2) — en `DefaultCaptureField` y como default de `sendFn` en `Scan`/`PasteBatch`
  - `Sleep` (built-in AHK v2) — como default de `sleepFn`
  - `ClipWait` (built-in AHK v2) — en `DefaultCaptureField` (timeout 0.5 s) y en `PasteBatch` (timeout 0.5 s)

## Notas técnicas (WHY no-obvio)

- **State machine de `isCapturing`**: `Arm()` → activa; `Reset()` → desactiva; `Abort()` → solo interrumpe I/O, no desactiva (el caller hace `Reset()` después). Esto permite que el HUD muestre el estado "capturando" hasta que el reset sea confirmado.
- **Timings de `DefaultCaptureField`**: `Sleep 30` antes de soltar modificadores, `Sleep 20` tras liberarlos, `Sleep 80` tras `Ctrl+A` antes de `Ctrl+C`. El sleep de 80 ms existe porque algunos forms web tienen debouncing y la selección no está lista para `Ctrl+C` de inmediato. `ClipWait(0.5, 1)` da margen al OS para serializar eventos de clipboard.
- **Race condition con `OnClipboardChange`**: `PasteBatch` escribe directamente a `A_Clipboard` para paste. Si `HandlerCaptura` (registrado en `OnClipboardChange`) se dispara durante ese write, podría interferir. La solución es que `PasteBatch` setea `A_Clipboard := ""` antes de asignar el valor y usa `ClipWait` para confirmar la actualización antes de emitir `^v`.
- **`abortFlag` y loops**: `Abort()` solo setea el flag; no usa `Critical` ni locks. Los loops de `PasteBatch` y `Scan` comprueban el flag al inicio de cada iteración. Si el abort llega entre la escritura de clipboard y el `^v`, el valor queda en clipboard pero no se pega (el loop ya rompió). El caller hace `Reset()` que restaura `clipBackup` a `A_Clipboard`.
- **Scan — bug corregido de "clipboard fantasma"**: si un campo del form está vacío, `captureFieldFn()` retorna `""` y el slot se sobreescribe a `""` explícitamente (`queue[slot] := ""`). La versión anterior hacía `skip` y dejaba el valor anterior en `queue`, causando que un `ClipWait` anterior "fantasma" llenara slots que el operador no había completado.
- **`extraTabsAfterSlot` y `ResetState`**: `Scan()` hace backup de `extraTabsAfterSlot` antes de llamar `ResetState()` y lo restaura después, porque el caller (`DoHeaderScan`) configura los tabs extra ANTES de llamar a `Scan`. Sin el backup, `ResetState` los borraría.
- **`PasteBatch` — tres razones para skip de paste**: (1) `valor = ""` (slot omitido sin autocalc), (2) `campo.skipPaste` declarado en schema (ej.: campo de búsqueda/lupa), (3) slot en `preloadedSlots` (valor ya presente en el form tras `Scan`). En los tres casos, solo se emiten Tabs.
- **`usarStepsAfter` en `EmitirTabsTrasSlot`**: `PasteBatch` pasa `true` para ejecutar `stepsAfter` del campo (acciones complejas tras paste, ej.: desplegar dropdown). `Scan` pasa `false` porque al escanear un form lleno no se necesitan interacciones adicionales.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:

  **BORRADOS** (redundantes / QUÉ puro):
  - `DefaultCaptureField` — bloque `; --- Helper top-level: ...` (6 líneas) eliminado. Era narrativa histórica ("Sleep ampliados respecto al draft inicial"). Reemplazado por 2 líneas WHY (debouncing 80ms, OS serialization ClipWait).
  - `ResetState` — `; --- Helper interno: limpia queue/actionLog/... ---` (1 línea) eliminado. Nombre del método es autoexplicativo.
  - `AutoAdvance` — `; --- Helper privado: setea targetSlot al proximo "" cyclico... ---` (1 línea) eliminado. Ídem.
  - `EjecutarPreScanSteps` — `; --- Helper: ejecuta preScanSteps (o prePasteSteps como fallback). ---` (1 línea) eliminado. Redundante con el nombre.
  - `EjecutarPrePasteSteps` — bloque `; --- Helper: ejecuta schema.prePasteSteps con sleep entre pasos. ...` (6 líneas). Eliminado todo excepto la NOTA de boundary (liberación de modificadores), que se conservó como 1 línea WHY.
  - `EmitirTabsTrasSlot` — bloque `; --- Helper: emite navegacion entre el slot actual y el siguiente. ...` (5 líneas). Colapsado a 2 líneas WHY (usarStepsAfter=true vs false).
  - `HeaderScan` (Scan) — bloque `; --- HeaderScan: pre-popula queue... PRECONDICION: ...` (11 líneas). Colapsado a 2 líneas WHY (precondición de cursor).
  - `PasteBatch` comentario `extraTabsAfterSlot` — `; Tabs extra opcionales (ej. template field entre Account e Invoice date). / ; Se respeta abortFlag entre cada Tab.` (2 líneas) eliminado. Redundante con el mismo bloque en Scan.

  **REESCRITOS** (QUÉ → WHY, banner `---` → inline):
  - `Abort()` — `; --- Senial de freno... Llamada externa... NO toca queue/actionLog/state...` (4 líneas) → 2 líneas: split de responsabilidad entre Abort (flag) y Reset (state), idempotencia.
  - `SetExtraTabsAfter()` — `; --- Configura tabs extra...` (4 líneas) → 2 líneas: WHY (campos opcionales intercalados), semántica count=0.
  - `PushForce()` — `; --- PushForce: clean + push SIN validar...` (5 líneas) → 2 líneas: WHY del bypass parcial (validate sí, clean no).
  - `ClearSlot()` — `; --- ClearSlot: borra el valor...` (5 líneas) → 1 línea: WHY de no ejecutar validador (intención explícita del operador vs. push vacío).
  - `Scan` bloque `extraTabsAfterSlot` — `; Tabs extra opcionales... Mismo bloque que en PasteBatch...` (3 líneas) → 1 línea: WHY de duplicación (alineación de cursor).

  **CONSERVADOS sin cambio** (WHY no-obvio confirmado):
  - Banner principal `; === CaptureEngine - motor de captura schema-driven ===` (líneas 4-55): referencia canónica de estado interno y contratos. No es redundante con el .md porque es la única fuente in-code del contrato.
  - Inline fields `abortFlag` y `extraTabsAfterSlot` en declaración de clase (líneas 83-84).
  - Bloque `extraTabsBackup` en `Scan` (3 líneas): WHY del orden caller→Scan→ResetState.
  - Bloque "clipboard fantasma" en `Scan` (2 líneas): WHY del bug corregido (sobreescribir vs. skip).
  - Inline en `Scan`: `; Si val tenia algo pero cleaner lo rechazo`: WHY de preservar valor previo.
  - Bloque "Tres razones para SKIP" en `PasteBatch` (4 líneas): WHY enumerado, no redundante.

### Fase 3 — dead code
- [x] Auditado 2026-05-12
- Borrados: **ninguno** — no hay símbolo con 0 refs absolutas en todo el repo.
- Candidatos para review senior:
  - **`PreloadedCount` (getter)** — 0 refs en producción (QuickEntry.ahk + Lib/ + Schemas/). Solo 2 refs en Tests/ (`Test_CaptureEngine.ahk:296, 386`). Por criterio especial, tests son válidos → NO es dead code. DUDOSO si el getter fue pensado para exposición externa (HUD, log) y nunca llegó a usarse en prod. Decisión: conservar; si en el siguiente ciclo sigue sin ref en prod, evaluar eliminación.

- Clasificación completa (18 símbolos auditados):

  | Símbolo | Refs prod (QE+Lib+Schemas) | Refs Tests | Veredicto |
  |---|---|---|---|
  | `DefaultCaptureField` (fn libre) | 1 (default param en `Scan`) | 0 | USADO |
  | `Arm` | QE:40,136,191 · MH:899 | Test_CE, Test_AH, Test_TF | USADO |
  | `Reset` | QE:186,207 | Test_CE | USADO |
  | `Abort` | QE:206 | Test_CE | USADO |
  | `SetExtraTabsAfter` | QE:41,138,192,270 · MH:848 | Test_CE | USADO |
  | `JumpTo` | MH:669,680,690,705,773 | Test_CE, Test_AH, Test_TF | USADO |
  | `PushRaw` | QE:82 | Test_CE, Test_AH | USADO |
  | `PushManual` | MH:774 | Test_CE | USADO |
  | `PushForce` | MH:706 | Test_CE | USADO |
  | `SkipCurrent` | QE:130 | Test_CE, Test_AH, Test_TF | USADO |
  | `Undo` | QE:225 | Test_CE | USADO |
  | `ClearSlot` | MH:765 | Test_CE | USADO |
  | `ExpectedFor` | MH:612 · TF:35 | Test_CE, Test_AH | USADO |
  | `Scan` | QE:291 | Test_CE | USADO |
  | `PasteBatch` | QE:181 | Test_CE | USADO |
  | `NextSlot` (getter) | MH:512,613,659 · TF:31,66 | Test_CE, Test_AH, Test_TF | USADO |
  | `IsComplete` (getter) | QE:124 · TF:27,64 | Test_CE, Test_AH, Test_TF | USADO |
  | `FilledCount` (getter) | QE:151 · MH:513,891 · TF:28,33 | Test_CE, Test_AH, Test_TF | USADO |
  | `PreloadedCount` (getter) | **0** | Test_CE:296,386 | DUDOSO (ver arriba) |

- Nota: el archivo fuente no fue modificado. Sintaxis validada implícitamente (sin cambios → sin riesgo de regresión sintáctica).

### Fase 5 — polish
- [x] Auditado 2026-05-12
- Cambios aplicados: **ninguno** — archivo ya cumple todos los criterios del polish pass.
  - Trailing whitespace: 0 líneas afectadas.
  - Blank lines 3+ consecutivas: ninguna encontrada.
  - Indentación: 100 % espacios, sin tabs; continuaciones de Map() multi-línea alineadas visualmente (no son error de indentación).
  - Trailing newline: único `LF` al final (`\x7D\x0A\x7D\x0A`).
  - Comentarios huérfanos: ninguno — todos los comentarios standalone tienen contexto inmediato (función siguiente o bloque adyacente).
- El archivo no fue modificado. Sintaxis validada implícitamente (sin cambios → sin riesgo de regresión sintáctica).

### Fase 6 — design alignment
- [x] Aplicado 2026-05-12
- Cambios aplicados:
  - `Lib/CaptureEngine.ahk:260` — `ClearSlot` actionLog Map ahora incluye `"type", "clear"` para alinearse con spec `2026-05-10-quickestEntry-ui-cleanup-design.md §2.4`. Habilita que un futuro `Undo()` distinga clears de pushes para UI feedback. Backward-compatible: el Undo actual ignora el campo, no rompe nada.
  - `Tests/Test_CaptureEngine.ahk` — +1 assert verificando que el field `"type"="clear"` está presente. Conteo: 218 → 219 → total repo 756 → 757.

## Ideas de simplificación pendientes (input para plan posterior)

- `PushRaw` y `PushForce` comparten el 80 % del cuerpo (clean → log → write → delete preloaded → AutoAdvance); podrían unificarse con un parámetro `skipValidation := false` para eliminar la duplicación.
- Los cuatro helpers privados `EjecutarPrePasteSteps`, `EjecutarPreScanSteps`, `EmitirTabsTrasSlot` y `AutoAdvance` no forman parte del contrato público pero están expuestos (AHK v2 no tiene `private`); documentarlos con prefijo `_` o mover a funciones internas top-level reduciría la superficie pública aparente.
- `DefaultCaptureField` es una función libre top-level que solo se usa como default de `captureFieldFn` en `Scan`. Convertirla en un método estático de `CaptureEngine` o en una función interna del archivo eliminaría la dependencia implícita de runtime del engine.
