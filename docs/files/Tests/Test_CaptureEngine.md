---
file: Tests/Test_CaptureEngine.ahk
last_review: 2026-05-12
last_comment_cleanup: 2026-05-12
status: active
---

# `Tests/Test_CaptureEngine.ahk`

## Propósito

Suite de tests de `CaptureEngine` (el motor de captura schema-driven de QuickEntry). Cubre el 100 % de la API pública del SUT: state machine, operaciones de estado puro (`PushRaw`, `PushForce`, `PushManual`, `SkipCurrent`, `Undo`, `JumpTo`, `ClearSlot`, `ExpectedFor`), operaciones con side-effects simulados (`PasteBatch`, `Scan`), integración con `AsignetHeaderV1`, mocks de `sendFn`/`sleepFn`/`captureFieldFn`, y regresiones explícitas. Es el archivo de tests más grande del repo (~900 líneas, ~38 KB).

## API pública

> Este es un archivo de tests, no un módulo de biblioteca. La "API pública" se describe como cobertura de áreas por bloque de asserts.

### Schemas inline para testing

El archivo define varios schemas mock que aíslan las variantes del SUT sin depender del schema de producción:

- **`CrearMock()`** — schema de 3 campos (`A` → `ValidarNoVacio`, `B` → `ValidarNumero`, `Suma` → `ValidarSumaTol([1,2])`) con `expectedFn` en el campo 3. Usado en la mayoría de los bloques de test de estado puro.
- **`schemaTabOnly`** — 3 campos `skipPaste=true`, `tabsAfter` progresivo (1, 2, 3). Prueba la lógica de Tabs de `PasteBatch` sin mutar `A_Clipboard`.
- **`schemaUno`** — 1 campo `skipPaste=true`, `tabsAfter=5`. Valida el caso de slot único como "last" (cero Tabs emitidos).
- **`schemaPre` / `schemaPre2` / `schemaSinPre`** — variantes con/sin `prePasteSteps`. Ejercitan el orden `prePasteSteps` → Tabs inter-slot en `PasteBatch`.
- **`schemaScan`** — 3 campos `skipPaste=false` con `prePasteSteps=["{Tab 5}"]`. Usado para todos los bloques de `Scan`.
- **`schemaSkipScan`** — 2 campos, el primero `skipPaste=true`. Verifica que `Scan` no lee slots marcados `skipPaste`.
- **`schemaPasteScan`** — 3 campos normales. Verifica que `PasteBatch` salta slots preloaded (solo Tabs) y pega manualmente los no-preloaded.
- **`schemaEmpty`** — 3 campos normales. Regresiones de `PasteBatch` sobre slots vacíos (nunca dispara `^v` en slot `""`).
- **`schemaCompare`** — 3 campos con `tabsAfter` distintos (3, 5, 1) y `prePasteSteps` de 2 pasos. Regresión de paridad Scan ↔ PasteBatch.
- **`schemaAbort`** — 3 campos `skipPaste=true`, `tabsAfter=5`. Verifica que `PasteBatch` corta en mid-loop al activar `Abort()`.
- **`schemaAbScan`** — 2 campos `skipPaste=false`. Verifica que `Scan` corta al primer campo si `Abort()` se dispara en `captureFieldFn`.
- **`schemaET` / `schemaScET`** — 3 campos `skipPaste=true`, `tabsAfter=1`. Ejercitan `SetExtraTabsAfter` en `PasteBatch` y `Scan`.

### Mocks de side-effects

- **`sendFn`** — siempre un lambda `(s) => sentXxx.Push(s)` donde `sentXxx` es el array de captura. Permite verificar exactamente qué se envía (Tabs, `^v`, `{Blind}{LShift up}...`, prePasteSteps) y en qué orden.
- **`sleepFn`** — siempre `(ms) => ""` (noop). Elimina tiempos de espera reales del loop de `PasteBatch`/`Scan`.
- **`captureFieldFn`** — tres variantes:
  - `MockCapture` (clase con índice interno): simula form con valores predefinidos; avanza el índice en cada `Read()`.
  - Lambda `() => "valor"`: retorna siempre el mismo string.
  - Lambda `() => ""`: simula campo vacío (regresión de "Scan empty borra slot").
  - `MockReadFn` (función global): dispara `Abort()` en la primera llamada; verifica que `Scan` corta antes de leer el segundo slot.
- **`SendAbortFn`** (función global): cuenta los sends y llama `Abort()` tras el segundo; verifica que `PasteBatch` corta en mid-loop.

### Cobertura por área

#### State machine (`isCapturing`, `Arm`, `Reset`)

- Engine virgen: `NextSlot=1`, `isCapturing=false`, `IsComplete=false`, `queue` pre-alocado, `FilledCount=0`.
- `Arm(clipSnapshot)`: `isCapturing=true`, `clipBackup` guardado, `NextSlot=1`, `abortFlag=false`, `extraTabsAfterSlot` limpio.
- `Reset()`: `isCapturing=false`, `queue` re-inicializado a `""`, `actionLog` vacío, `targetSlot=0`, `FilledCount=0`, `clipBackup=""`, `preloadedSlots` limpio, `abortFlag=false`.

#### `PushRaw`

- Slot 1 OK: `ok=true`, `value`, `slot`, `label`, `error=""`, `NextSlot` avanza.
- Rechazo por validador (`ValidarNumero` con `"abc"`): `ok=false`, `error` contiene `"numero"`, `NextSlot` no avanza, `FilledCount` no muta.
- Rechazo por `expectedFn` (`ValidarSumaTol` con suma incorrecta): `ok=false`, `error` contiene `"suma"` y el valor esperado calculado.
- Post-completo (`NextSlot=0`): `ok=false`, `error="cola completa"`, `slot=0`, `FilledCount` no muta.
- Tras `JumpTo`: reemplaza `queue[slot]`, registra `prevValue` en `actionLog`, `AutoAdvance` recalcula.

#### `PushForce`

- Bypassa `validate`; aplica `clean`. `ok=true`, escribe `queue[slot]`, registra en `actionLog`.
- Si `clean` devuelve `""`: rechaza igual (`ok=false`, `error` contiene `"no se reconocio"`).
- `Undo` tras `PushForce`: restaura `prevValue` vacío.
- Sobre slot preloaded: limpia `preloadedSlots[slot]`.

#### `SkipCurrent`

- Sin `autoCalcFlag`: `value=""`, `slot` correcto, `label` correcto; `queue[slot]=""`, `IsComplete=false`, `NextSlot` vuelve al mismo slot (sigue vacío).
- Con `autoCalcFlag=true` + `expectedFn`: `value` calculado (`"150.00"`), `queue[slot]` actualizado.
- Con `autoCalcFlag=true` en slot sin `expectedFn`: `value=""`.
- Post-completo (`NextSlot=0`): `slot=0`.
- Sobre slot preloaded: limpia `preloadedSlots[slot]`, `queue[slot]=""`.
- `FilledCount`: Skip sin autocalc no suma; Skip con autocalc suma (valor no vacío).

#### `Undo`

- Pop del `actionLog`; restaura `queue[slot]` al `prevValue`; `targetSlot := slot`; `NextSlot = slot`.
- Multi-undo hasta vaciar `actionLog`: `FilledCount=0`, `NextSlot=1`.
- `actionLog` vacío: `ok=false`, `slot=0`, `label=""`.
- Tras `PushForce`: restaura correctamente.

#### `ExpectedFor`

- Slot con `expectedFn`: retorna suma calculada con la cola actual (`"150.00"`).
- Slots sin `expectedFn`: `""`.
- Fuera de rango (`0`, `99`): `""`.

#### `JumpTo`

- Setea `targetSlot`; `NextSlot` cambia; `queue` y `actionLog` no mutan.
- Fuera de rango (`0`, `N+1`): lanza `ValueError`.

#### `AutoAdvance` (ciclo)

- Busca primer `""` hacia adelante (`slot+1..end`); si no, hacia atrás (`1..slot-1`); si no hay vacíos, `targetSlot=0`, `IsComplete=true`.
- Verificado con queue `["100", "", "50"]`: tras push en slot 2, no encuentra vacíos → `IsComplete`.

#### `Scan` (`HeaderScan`)

- Lee form con `captureFieldFn` slot por slot (respetando `skipPaste`); pre-popula `queue` + `preloadedSlots`.
- Slots vacíos en form: `queue[slot]=""`, no quedan en `preloadedSlots` (regresión "clipboard fantasma").
- Slots con valor: `preloadedSlots.Has(slot)=true`, `FilledCount` los cuenta.
- `PreloadedCount` correcto.
- `isCapturing=true`, `clipBackup` guardado, `NextSlot` apunta al primer vacío.
- Emite `prePasteSteps` (o `preScanSteps`) + Tabs inter-slot en `sendFn`; slot "last" no emite Tabs finales.
- Slot `skipPaste=true`: no se lee (no llama a `captureFieldFn`), no entra en `preloadedSlots`.
- Respeta `extraTabsAfterSlot` igual que `PasteBatch`.
- Corta en mid-loop si `abortFlag` se activa en `captureFieldFn` (`scanCtl["n"]=1` si abort en primer slot).

#### `PasteBatch`

- Slots no-preloaded con valor y `skipPaste=false`: emite reset de modificadores + `^v` + Tabs.
- Slots preloaded: solo Tabs (no `^v`, no clipboard write).
- Slots vacíos (`queue[i]=""`): nunca `^v` (regresión explícita con conteo de `^v`).
- Slot `skipPaste=true`: solo Tabs.
- Slot "last": nunca emite Tabs finales (0 Tabs post-paste del último slot).
- `prePasteSteps` emitidos antes de slots; orden correcto cuando hay Tabs inter-slot.
- Regresión paridad Scan ↔ PasteBatch: misma cantidad y secuencia de Tabs/prePasteSteps filtrados.
- Corta en mid-loop si `abortFlag` se activa en `sendFn` (`sentAb.Length < 10`).

#### `Abort`

- `Abort()` setea `abortFlag=true`; no toca `queue` ni `actionLog`.
- `Reset()` limpia `abortFlag=false`.
- `Arm()` limpia `abortFlag=false` (permite reusar engine sin `Reset` previo).
- Globales del test: `abortCtl` (Map con ref al engine, array sent y contador) y `scanCtl` (Map con ref y contador), declaradas con `global` dentro de `SendAbortFn` y `MockReadFn`.

#### `SetExtraTabsAfter`

- `SetExtraTabsAfter(slot, count)`: agrega entrada en `extraTabsAfterSlot`.
- `count=0`: elimina la entrada.
- `Arm()` limpia `extraTabsAfterSlot` (no es `Reset`, sino `ResetState` que Arm llama).
- Slot "last" ignora extra tabs (no hay slot siguiente que skipear).
- `PasteBatch` y `Scan` aplican los tabs extra de forma idéntica.

#### `ClearSlot`

- Borra `queue[slot]` a `""`, registra en `actionLog` (soporta `Undo`).
- No toca otros slots.
- Fuera de rango: noop, `actionLog` no crece.
- Quita el slot de `preloadedSlots`.
- `Undo` tras `ClearSlot` restaura el `prevValue`.

#### `FilledCount`

- Engine virgen y tras `Arm`: `0`.
- Crece con cada push exitoso.
- `SkipCurrent` sin autocalc: no suma (slot queda `""`).
- `SkipCurrent` con autocalc: suma (valor calculado no vacío).

#### Integración con `AsignetHeaderV1`

- `CaptureEngine(CrearAsignetHeaderV1())`: schema de 9 slots.
- `PushRaw` en slot 2 (fecha): `clean` formatea la fecha (`"Sep 15, 2026"` → `"09/15/2026"`).
- `ExpectedFor(7)` con slots 5/6 parcialmente llenos: cálculo correcto (`"500.00"`).
- `PushManual`: alias de `PushRaw`, mismo resultado.
- `PushForce("")` en slot 1 (cleaner `CleanPasoPegado`): `clean` retorna `""` → `ok=false`, `error` contiene `"no se reconocio"`.
- `PushForce` sobre slot preloaded inyectado manualmente: actualiza `queue` y limpia `preloadedSlots[1]`.

## Dependencias

- **#Include directos**: `Lib\CaptureEngine.ahk`, `Lib\Validators.ahk`, `Schemas\AsignetHeaderV1.ahk`, `_AssertHelpers.ahk`
- **Incluido por**: nadie (archivo ejecutable por el runner)
- **Globales que define**: `abortCtl` (línea 732), `scanCtl` (línea 767) — declaradas implícitamente a nivel de script; re-declaradas con `global` dentro de `SendAbortFn` y `MockReadFn` para acceso desde funciones top-level
- **Globales que usa (leídas)**: `g_failures`, `g_total` (vía `_AssertHelpers.ahk`)
- **Símbolos externos invocados**:
  - `CaptureEngine` (de `Lib/CaptureEngine.ahk`) — clase del SUT
  - `InvoiceSchema` / `Campo` (de `Lib/Schema.ahk`, transitivo vía `CaptureEngine.ahk`) — constructores de schemas mock
  - `ValidarNoVacio`, `ValidarNumero`, `ValidarSumaTol` (de `Lib/Validators.ahk`) — validadores pasados a `Campo()`
  - `CrearAsignetHeaderV1` (de `Schemas/AsignetHeaderV1.ahk`) — schema de producción para tests de integración
  - `AssertEq`, `AssertContains`, `ReportarYSalir` (de `_AssertHelpers.ahk`) — infraestructura de asserts

## Notas técnicas (WHY no-obvio)

- **`MockCapture` como clase, no fat-arrow con `++`**: el archivo documenta explícitamente que fat arrows con pre-increment (`++var`) sobre variables de script-level tienen comportamiento extraño cuando se capturan en closures en AHK v2. Por eso `MockCapture` es una clase con `idx` como propiedad de instancia — el `Read()` avanza `this.idx` sin romper el scoping.
- **`Map()` para contador mutable en mixedFn**: misma razón que el punto anterior. En lugar de `n := 0` + closure, se usa `counter := Map("n", 0)` y `counter["n"] := counter["n"] + 1` para preservar el estado entre llamadas al lambda.
- **`global abortCtl` / `global scanCtl` dentro de funciones top-level**: `SendAbortFn` y `MockReadFn` son funciones top-level (no lambdas) porque necesitan referenciarse por nombre. Para acceder a las variables de script-level, usan `global <nombre>` explícito — patrón estándar de AHK v2 para funciones que leen estado de prueba.
- **Slots `skipPaste=true` en tests de clipboard**: todos los esquemas que verifican Tabs usan `skipPaste=true` para evitar que `PasteBatch` toque `A_Clipboard` durante el test. El path Tab-only es el único path testeable sin side-effects reales.
- **Verificación de abort por recuento, no por posición exacta**: el assert de `PasteBatch` con abort es `sentAb.Length < 10` (no una longitud exacta) porque el punto de corte depende de cuándo el scheduler de AHK procesa el flag. La condición `< 10` es suficientemente laxa para ser determinista y suficientemente estricta para confirmar el corte.
- **Regresión "Scan empty borra slot"**: el test de `Scan` con `captureFieldFn` que retorna `""` verifica que `queue[slot]` se sobreescribe a `""` (no se deja un valor residual de inicialización previa). Esta es la corrección al bug de "clipboard fantasma" documentado en `Lib/CaptureEngine.md`.
- **`filtrarNav()` local en el bloque de regresión paridad**: función top-level definida a nivel de script (no lambda) para filtrar solo pasos de navegación del array `sent`. Depende de que los strings `"{Tab}"`, `"{Tab 7}"` y `"{Enter}"` sean valores literales exactos emitidos por `PasteBatch`/`Scan`.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - **Banners**: reducidos de ~25 pares a 8 pares `; ====`. Los 8 que quedan son: `Schemas inline`, `State machine`, `PushRaw / PushForce / ExpectedFor`, `Undo / JumpTo / AutoAdvance`, `SkipCurrent / FilledCount / ClearSlot`, `PasteBatch`, `Scan / HeaderScan`, `Abort`. Los sub-grupos que antes tenían banner propio (`Integración con AsignetHeaderV1`, `SetExtraTabsAfter`, `ClearSlot`, `REGRESION Scan empty val`, `Undo restaura prevValue`) pasaron a comentario de línea o comentario `; --`.
  - **BORRADOS** (redundantes / narrativa obvia / QUÉ puro):
    - Banner `; Arm` (trivial, colapsado en State machine)
    - Banner `; PushRaw 2 OK` (trivial, sin contenido WHY)
    - Banner `; PushRaw OK (slot 1)` (trivial, movido a banner unificado)
    - Banner `; SkipCurrent con autoCalc` → comentario de línea
    - Banner `; Reset` → comentario de línea
    - Banner `; Schema info expuesta` → comentario de línea
    - Banner `; PasteBatch ejecuta prePasteSteps ANTES de los slots` → comentario de línea
    - Banner `; HeaderScan respeta skipPaste` → comentario de línea
    - Banner `; PushRaw sobre slot preloaded` → comentario de línea
    - Banner `; PasteBatch skip preloaded` → comentario de línea
    - Banner `; Reset limpia preloadedSlots` → comentario de línea
    - Banner `; REGRESION: PasteBatch sobre slots vacios JAMAS dispara ^v` → comentario de línea
    - Banner `; REGRESION: Scan y PasteBatch emiten EXACTAMENTE los mismos Tabs` → comentario de línea
    - Banner `; JumpTo - setea targetSlot...` → comentario de línea
    - Banner `; Push tras JumpTo` → comentario de línea
    - Banner `; PushForce - bypassa validate` → comentario de línea
    - Banner `; FilledCount` → comentario de línea
    - `; queue = ["100", "50", ""]; NextSlot = 3` — estado que los asserts ya expresan
    - `; slot 1, prev = ""` / `; slot 2, prev = ""` — trivial
    - `; queue = ["777", "50", ""], actionLog 3 entries` — trivial
    - `; Recolectamos los sends de Scan` / `; Recolectamos los sends de PasteBatch` — trivial
    - `; El Scan debe haber cortado antes de leer el segundo slot` — duplica el assert message
    - `; --- Sin extra tabs en Scan: 2 Tabs (slot 1->2, slot 2->3) ---` → vacío (trivial)
    - `; --- Con SetExtraTabsAfter(1, 1) en Scan: 3 Tabs ---` → vacío (trivial)
    - `; Llenamos solo slot 2; slots 1 y 3 quedan ""` → simplificado
    - `; SkipCurrent cuando NO hay vacios: slot=0` + narrativa `Lleno slot 3 manualmente...` → simplificado
  - **RE-ESCRITURAS** (QUÉ → WHY):
    - `; PushRaw rechazo por validacion (slot 2 = ValidarNumero, "abc" rechazado)` → `; ValidarNumero rechaza "abc": NextSlot no avanza, FilledCount no muta`
    - `; --- Helper: mock readFn con contador interno (clase para evitar scoping issues...)` → expandido con el WHY del AHK v2 fat-arrow bug
    - `; --- Sin abort: 10 Tabs (5+5+0). Con abort tras 2 sends...` → `; Assert con < 10 (no posición exacta): el punto de corte depende del scheduler`
    - `; PasteBatch ejecuta prePasteSteps ANTES de los slots` → `; prePasteSteps se emiten antes de cualquier slot`
    - `; Scan empty val: si el campo del form esta vacio...` → `; REGRESION "clipboard fantasma": Scan con campo vacío sobreescribe queue[slot]=""`
    - `; --- Mock: captureFieldFn retorna ""...Usamos Map() en lugar de variable script-level con ++...` → WHY del bug conservado y reescrito más claro
    - `; --- ResetState/Arm limpian extraTabsAfterSlot` → `; Arm llama ResetState, que limpia extraTabsAfterSlot (template per-capture)`
    - `; --- Slot last NO recibe extra tabs (no hay slot siguiente que skipear)` → forma afirmativa corta
    - Varios comentarios `; --- X ---` → forma sin guiones dobles, más directos
  - **CONSERVADOS sin cambio**: todos los mocks con WHY documentado (`MockCapture`, `abortCtl Map`, `counter Map`, `SendAbortFn`, `MockReadFn`), schemas inline con propósito, asserts inline sobre tabsAfter, comentarios de regresión nombrada.
  - **Resultado**: 825 líneas (↓91 desde 916). Sintaxis validada con `AutoHotkey64.exe /validate`: sin errores.

### Fase 3 — dead code
- [ ] Auditado
- Borrados:
- Candidatos para review senior:

## Ideas de simplificación pendientes (input para plan posterior)

- Los schemas inline (`schemaTabOnly`, `schemaUno`, `schemaPre`, etc.) se construyen uno a uno con `InvoiceSchema`/`Campo` repetidos. Una función de fábrica `CrearSchemaSimple(nSlots, tabsAfter, skipPaste)` reduciría el boilerplate de los ~15 schemas de prueba y haría más legible qué variante controla cada bloque.
- `MockCapture` y las variantes de `captureFieldFn` (lambda constante, Map contador, función global con `global scanCtl`) podrían unificarse en una clase `MockReadFn` parametrizable (lista de valores + hook de abort opcional), evitando tres patrones distintos para el mismo concepto.
- Los bloques de regresión de abort (`PasteBatch` y `Scan`) definen funciones top-level globales (`SendAbortFn`, `MockReadFn`) con estado en `Map` de script-level. Convertirlos en instancias de una clase `AbortMock` eliminaría los dos `global abortCtl`/`scanCtl` del grafo de globals y haría el patrón reutilizable para tests de abort en otros módulos.
