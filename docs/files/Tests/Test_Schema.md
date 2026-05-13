---
file: Tests/Test_Schema.ahk
last_review: 2026-05-12
last_comment_cleanup: 2026-05-12
status: active
---

# `Tests/Test_Schema.ahk`

## Propósito

Suite de tests unitarios para `Lib/Schema.ahk`. Verifica el comportamiento observable de `Campo` e `InvoiceSchema` sin depender de ningún otro módulo productivo salvo `Lib/Validators.ahk` (usado como fixture de callbacks reales). Es el único test file que ejercita la API de `Schema.ahk` directamente; el resto de las suites crean schemas inline como datos de test, no como sujeto bajo prueba.

## Cobertura declarada

### `Campo` — constructor + propiedades (líneas 11–44)

| Assert | Línea | Qué verifica |
|---|---|---|
| `c.name` == `"Mi campo"` | 12 | Constructor asigna `name` |
| `c.tabsAfter` == `1` | 13 | Default `tabsAfter = 1` |
| `c.skipPaste` == `false` | 14 | Default `skipPaste = false` |
| `c.expectedFn` == `""` | 15 | Default `expectedFn = ""` |
| `c2.tabsAfter` == `2` | 19 | `tabsAfter` custom (ctor posición 4) |
| `c2.skipPaste` == `true` | 20 | `skipPaste` custom (ctor posición 5) |
| `c2.name` == `"X"` | 21 | `name` ctor posición 1 con valor corto |
| `cTrim.clean.Call("  hola  ")` == `"hola"` | 25 | Callback `clean` delegado (Trim) |
| `cTrim.validate.Call("X", [])` == `""` | 26 | Callback `validate` ok retorna `""` |
| `cTrim.validate.Call("", [])` contiene `"vacio"` | 27 | Callback `validate` fail retorna mensaje |
| `cExp.expectedFn.Call(["10","20"])` == `"30.00"` | 32 | `expectedFn` calcula con cola suficiente |
| `cExp.expectedFn.Call(["10"])` == `""` | 33 | `expectedFn` retorna `""` si cola corta |
| `IsObject(c.expectedDeps)` == `true` | 36 | Default `expectedDeps` es objeto |
| `c.expectedDeps.Length` == `0` | 37 | Default `expectedDeps` vacío |
| `cExp.expectedDeps.Length` == `0` | 38 | Sin deps explícitos → vacío (no `expectedFn` implica deps) |
| `cDeps.expectedDeps.Length` == `2` | 42 | `expectedDeps` custom Length |
| `cDeps.expectedDeps[1]` == `1` | 43 | `expectedDeps[1]` = primer índice |
| `cDeps.expectedDeps[2]` == `2` | 44 | `expectedDeps[2]` = segundo índice |

### `InvoiceSchema` — construcción (líneas 49–74)

| Assert | Línea | Qué verifica |
|---|---|---|
| `s.name` == `"test"` | 50 | Constructor asigna `name` |
| `s.Length` == `2` | 51 | `Length` getter cuenta fields |
| `s.Field(1).name` == `"Mi campo"` | 52 | `Field(1)` retorna primer campo |
| `s.Field(2).name` == `"X"` | 53 | `Field(2)` retorna segundo campo |
| `s.Field(2).tabsAfter` == `2` | 54 | Propiedades del campo preservadas |
| `sEmpty.Length` == `0` | 58 | Schema vacío → Length 0 |
| `IsObject(s.prePasteSteps)` == `true` | 61 | Default `prePasteSteps` es objeto |
| `s.prePasteSteps.Length` == `0` | 62 | Default `prePasteSteps` vacío |
| `sPre.prePasteSteps.Length` == `3` | 66 | `prePasteSteps` custom Length 3 |
| `sPre.prePasteSteps[1]` == `"{Tab 5}"` | 67 | `prePasteSteps[1]` primer paso |
| `sPre.prePasteSteps[2]` == `"Invoice"` | 68 | `prePasteSteps[2]` segundo paso |
| `sPre.prePasteSteps[3]` == `"{Tab}"` | 69 | `prePasteSteps[3]` tercer paso |
| `s.ordenPegado.Length` == `2` | 72 | Default `ordenPegado` auto-generado |
| `s.ordenPegado[1]` == `1` | 73 | `ordenPegado` default primer slot |
| `s.ordenPegado[2]` == `2` | 74 | `ordenPegado` default segundo slot |

### `Field(slot)` — bounds (líneas 77–95)

| Assert | Línea | Qué verifica |
|---|---|---|
| `s.Field(0)` lanza `ValueError` | 79–85 | Slot 0 → fuera de rango |
| Mensaje contiene `"fuera de rango"` | 84 | Texto exacto del error |
| `s.Field(99)` lanza `ValueError` | 87–95 | Slot 99 → fuera de rango |
| Mensaje contiene `"fuera de rango"` | 94 | Texto exacto del error |

### `expectedDeps` — fixture (líneas 35–44)

Cubre el parámetro 7 del constructor de `Campo` en tres variantes: omitido (c), con `expectedFn` pero sin deps explícitos (cExp), y con deps explícitos `[1, 2]` (cDeps). Confirma que el constructor normaliza a array vacío cuando el argumento no es objeto.

## API bajo prueba

| Símbolo | Definido en | Rol en este test |
|---|---|---|
| `Campo.__New(...)` | `Lib/Schema.ahk:46` | Sujeto principal — 5 instancias distintas |
| `InvoiceSchema.__New(...)` | `Lib/Schema.ahk:71` | Sujeto principal — 4 instancias |
| `InvoiceSchema.Field(slot)` | `Lib/Schema.ahk` | Sujeto de bounds testing |
| `InvoiceSchema.Length` (getter) | `Lib/Schema.ahk` | Verificado en schema de 2 y de 0 campos |
| `ValidarNoVacio` | `Lib/Validators.ahk:19` | Fixture callback para `validate` |
| `ValidarNumero` | `Lib/Validators.ahk:24` | Fixture callback para `validate` en cExp/cDeps |
| `Trim` | AHK v2 builtin | Fixture callback para `clean` |
| `AssertEq` | `Tests/_AssertHelpers.ahk` | Assert de igualdad |
| `AssertContains` | `Tests/_AssertHelpers.ahk` | Assert de substring |
| `ReportarYSalir` | `Tests/_AssertHelpers.ahk` | Cierre del runner |

## Dependencias

- **#Include directos**:
  - `../Lib/Validators.ahk` (línea 4) — validators usados como callbacks de fixture
  - `../Lib/Schema.ahk` (línea 5) — módulo bajo prueba
  - `_AssertHelpers.ahk` (línea 6) — harness de asserts
- **#Include transitivos**: ninguno adicional (Schema.ahk y Validators.ahk son hojas del DAG).
- **Incluido por**: `Tests/runner.ps1` (discovery por glob `Test_*.ahk`).
- **Globales que usa**: `g_failures`, `g_total` (definidas en `_AssertHelpers.ahk:3-4`; escritas por `AssertEq`, `AssertContains`, `ReportarYSalir`).
- **Globales que define**: ninguna propia.
- **Símbolos externos invocados**: `IsObject()`, `ValueError`, `Format()`, `Number()` (builtins AHK v2).

## Notas técnicas (WHY no-obvio)

- **`ValidarNoVacio` y `ValidarNumero` como fixtures reales, no stubs.** El test pasa callbacks de producción al constructor de `Campo`, lo que valida simultáneamente que el contrato de firma `(val, cola) => String` es correcto. Si `Lib/Validators.ahk` cambia la firma, este test rompe, que es el comportamiento deseado.

- **`sumarFn` inline (línea 30).** La lambda local simula un `expectedFn` real sin depender de `AsignetHeaderV1.ahk`. Mantiene el test autocontenido y evita que un cambio en el schema de producción afecte la cobertura de `Campo.expectedFn`.

- **Dos `try/catch ValueError` consecutivos (líneas 77–95).** No comparten estado: si `Field(0)` no lanza, el assert `"no-throw"` falla inmediatamente y `ReportarYSalir` reporta el fallo al salir. El patrón evita dependencia entre los dos casos de borde.

- **`sPre` recibe `[1]` en posición `ordenPegado` (línea 65).** El test de `prePasteSteps` no verifica `ordenPegado` custom; usa `[1]` como placeholder mínimo para que el constructor no auto-genere el default. Esto es un side-effect del test de `prePasteSteps`, no un test de `ordenPegado`.

- **`cExp.expectedDeps.Length == 0` (línea 38).** Confirma que tener `expectedFn` no implica `expectedDeps` automáticos; son ortogonales. El constructor no infiere deps desde `expectedFn`.

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - Borrados: 0 (el archivo no tenía banners decorativos puros, código comentado ni TODOs viejos)
  - Reescritos (QUE→WHY): 9 comentarios de sub-sección
    - `; --- Campo full ctor ---` → `; --- tabsAfter y skipPaste override: verifica que ctor posiciones 4-5 pisan defaults ---`
    - `; --- Campo invoca clean / validate ---` → `; --- callbacks reales (no stubs): firma (val,cola)=>String validada en integración ---`
    - `; --- Campo expectedDeps default vacio ---` → `; --- expectedDeps default: ctor debe normalizar ausencia a array vacio, no nil ---`
    - `; --- Campo con expectedDeps ---` → `; --- expectedDeps explicit: verifica que [1,2] no se aplana ni se descarta ---`
    - `; --- Schema vacio ---` → `; --- schema sin campos: Length no puede ser undefined ni 1 por off-by-one ---`
    - `; --- prePasteSteps default vacio ---` → `; --- prePasteSteps default: igual que expectedDeps, debe ser array vacio, no nil ---`
    - `; --- prePasteSteps custom ---` → `; --- prePasteSteps custom: [1] en ordenPegado es placeholder, no sujeto del test ---`
    - `; --- ordenPegado default = [1..N] cuando no se pasa ---` → `; --- ordenPegado auto-generado: ctor crea [1..N] para no romper CaptureEngine ---`
    - `; --- Out of range tira error ---` → `; --- Field fuera de rango: ValueError con texto "fuera de rango" para catch en UI ---`
  - Conservados: 2 banners de sección (`Campo - constructor + defaults`, `InvoiceSchema`); comentario `; --- Campo con expectedFn ---` (ya mencionaba fixture inline, valor informativo suficiente)
  - Sintaxis validada: `AutoHotkey64.exe /validate` → exit 0, sin errores

### Fase 3 — dead code
- [ ] Auditado
- Borrados (0 referencias en producción + tests):
- Candidatos para review senior (NO borrados):

## Ideas de simplificación pendientes (input para plan posterior)

- Los dos bloques `try/catch ValueError` (líneas 77–95) son idénticos en estructura; podrían refactorizarse en un helper `AssertThrowsValueError(callable, expectedMsg, label)` reutilizable para suites futuras que también ejerciten `Field()` con bounds inválidos (ej. `Test_CaptureEngine.ahk`).
- La lambda `sumarFn` (línea 30) duplica lógica que ya existe en `Schemas/AsignetHeaderV1.ahk` (`EsperadoSuma`). Si el test necesita más cobertura de `expectedFn` en el futuro, podría importar directamente el schema de producción y verificar la instancia real en vez de la lambda inline; trade-off: test más acoplado vs. cobertura más realista.
- El test no verifica `stepsAfter` (parámetro 8 de `Campo`). Es el único parámetro del constructor sin cobertura en esta suite; un caso que construya un `Campo` con `stepsAfter := ["{Tab}", "{Tab}"]` y verifique `c.stepsAfter.Length == 2` completaría la cobertura del constructor.
