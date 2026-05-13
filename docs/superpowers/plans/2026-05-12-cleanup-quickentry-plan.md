# Cleanup QuickEntry para review senior — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task with parallel dispatch. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dejar el código de QuickEntry listo para review por un senior developer y para uso interno productivo del área de data entry. Tres ejes: (1) inventariar cada archivo con `.md` propio, (2) borrar lo innecesario (mapping M720 personal, comentarios redundantes, código muerto sin referencias), (3) registrar cada cambio en los `.md` para trazabilidad. La simplificación (re-tocar firmas inter-archivo, refactor) **se escribe en un plan posterior** una vez que este cleanup esté aprobado.

**Architecture:** 5 fases secuenciales con paralelización agresiva dentro de cada fase via subagent-driven-development. Tests corren solo 3 veces (baseline, post-Fase 1, post-Fase 3) — validación de sintaxis por archivo via `/validate` durante el resto. Snapshot zip al inicio como red de seguridad (no hay git). Toda modificación queda registrada en `docs/files/<archivo>.md`.

**Tech Stack:** AutoHotkey v2.0, runner.ps1 con asserts custom, PowerShell. AHK path: `C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe`. Plan posterior consultará `ClautoHotkey/Modules/Module_Instructions.md` + `Module_Classes.md` + `Module_GUI.md` una sola vez al inicio (esta fase de cleanup no requiere consulta de ClautoHotkey, son borrados puros).

**Baseline asserts:** **756** pasando en 7 archivos de test (140 + 218 + 188 + 43 + 35 + 77 + 55). Persistido en `_archive/2026-05-12-pre-cleanup/test-baseline.txt`. Target post-cleanup: **756** (igual: cleanup no cambia comportamiento).

**Pre-fix aplicado durante Task 0.2:** `Tests/runner.ps1:6` tenía path AHK hardcoded a `C:\Users\Usuario\...` (cuenta del autor original). Cambiado a discovery portable: `$env:AHK_V2` con fallback a `$env:LOCALAPPDATA\...`, `C:\Program Files\...`, y el path original. Esto destrabó el test gate y es prerequisito para senior review de uso interno. Registrado también en `docs/files/Tests/runner.md` (Task 0.5 lo agrega al inventario).

**Git:** repo **no** es git. Snapshot zip reemplaza a `git reset` para rollback.

---

## File Structure (estado final del repo)

```
QuickEntry-quickestEntryV1.11/
├── QuickEntry.ahk                ← MOD: handlers XButton/Wheel + banner M720 borrados (Fase 1)
├── Lib/                          ← MOD: cleanup comentarios + dead code en los 9 módulos
│   ├── AutoCalculator.ahk
│   ├── CaptureEngine.ahk
│   ├── Cleaners.ahk
│   ├── HudLayout.ahk
│   ├── MainHud.ahk
│   ├── PegadoEspecial.ahk
│   ├── Schema.ahk
│   ├── TooltipFormatter.ahk
│   └── Validators.ahk
├── Schemas/                      ← MOD: cleanup en 2 archivos
│   ├── AsignetHeaderV1.ahk
│   └── _Plantilla_NuevaEmpresa.ahk
├── Tests/                        ← MOD: cleanup comentarios en specs (asserts no se tocan)
│   ├── _AssertHelpers.ahk
│   ├── Test_AsignetHeader.ahk
│   ├── Test_CaptureEngine.ahk
│   ├── Test_Cleaners.ahk
│   ├── Test_HudLayout.ahk
│   ├── Test_Schema.ahk
│   ├── Test_TooltipFormatter.ahk
│   ├── Test_Validators.ahk
│   └── runner.ps1
├── M720.ahk.bak                  ← DELETE (Fase 1)
├── M720_Lib.ahk.bak              ← DELETE (Fase 1)
├── Test_M720_Lib.ahk.bak         ← DELETE (Fase 1)
├── docs/
│   ├── files/                    ← NEW (Fase 0)
│   │   ├── INDEX.md
│   │   ├── QuickEntry.md
│   │   ├── Lib/<modulo>.md       (×9)
│   │   ├── Schemas/<schema>.md   (×2)
│   │   ├── Tests/<test>.md       (×8)
│   │   └── _bak/<bak>.md         (×3, se borran junto con los .bak al final)
│   └── superpowers/
│       └── plans/
│           ├── 2026-05-12-cleanup-quickentry-plan.md    ← este plan
│           └── 2026-05-12-cleanup-quickentry-final.md   ← reporte final (Fase 4)
└── _archive/                     ← NEW (Fase 0)
    ├── 2026-05-12-pre-cleanup.zip
    └── 2026-05-12-pre-cleanup/
        └── test-baseline.txt
```

---

## Template de `docs/files/<archivo>.md`

Este es **el template canónico** que cada subagente debe emitir al crear su `.md` en Task 0.5 y que cada subagente de Fase 1/2/3 actualiza en la sección "Bitácora de cleanup".

```markdown
---
file: <ruta relativa del archivo fuente>
last_review: 2026-05-12
status: active  # active | deprecated | to-delete
---

# `<ruta relativa>`

## Propósito
<1-3 frases: qué hace este archivo, por qué existe>

## API pública

### Clases
- **`NombreClase(constructorParams)`** — descripción 1 línea
  - **Propiedades**: `propA`, `propB`, ...
  - **Métodos**:
    - `metodo(params) → tipoRetorno` — qué hace en 1 línea
      - Llamado desde: `<archivo>:<lineas>`, ...
      - Llama a: `<simbolo externo>`, ...

### Funciones libres
- **`funcion(params) → retorno`** — descripción 1 línea
  - Llamado desde: `<archivo>:<lineas>`, ...
  - Llama a: `<simbolos externos>`, ...

## Dependencias

- **#Include directos**: `<archivo>`, ...
- **Incluido por**: `<archivo>`, ...
- **Globales que define**: `nombre := valor` — propósito
- **Globales que usa (leídas)**: `nombre` (definida en `<archivo>`)
- **Símbolos externos invocados**: `Func()` (de `<archivo>`), ...

## Notas técnicas (WHY no-obvio)
<bullets sobre invariantes, race conditions, workarounds AHK v2, timings críticos. Esto NO se borra durante cleanup — es la parte que justifica los comentarios "buenos">

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (vacío si no aplica)

### Fase 2 — comentarios
- [ ] Auditado
- Cambios aplicados:
  - `<archivo>:<linea-original>` — borrado: `<snippet>` — razón: redundante / banner / código comentado / TODO viejo
  - ...

### Fase 3 — dead code
- [ ] Auditado
- Borrados (0 referencias en producción + tests):
  - `<simbolo>` en `<archivo>:<linea>` — razón: sin callers, sin tests
- Candidatos para review senior (NO borrados):
  - `<simbolo>` en `<archivo>:<linea>` — razón de duda: <X>

## Ideas de simplificación pendientes (input para plan posterior)
- <bullets libres: refactors propuestos, firmas que cambiaría, oportunidades de DRY, etc>
```

---

## Fase 0 — snapshot, baseline, inventario, grafo

Esta fase **no toca código productivo**. Objetivo: red de seguridad + radiografía completa del repo antes de cortar.

### Task 0.1: Snapshot pre-cleanup en `_archive/`

**Files:**
- Create: `_archive/2026-05-12-pre-cleanup.zip`

- [ ] **Step 1: Crear directorio `_archive/`**

```powershell
New-Item -ItemType Directory -Force -Path _archive
```

- [ ] **Step 2: Zipear el repo completo (excluir `_archive` y `.git` si existieran)**

```powershell
$exclude = @('_archive', '.git')
$items = Get-ChildItem -Path . | Where-Object { $_.Name -notin $exclude }
Compress-Archive -Path $items -DestinationPath _archive/2026-05-12-pre-cleanup.zip -CompressionLevel Optimal -Force
```

- [ ] **Step 3: Verificar zip presente y > 100 KB**

```powershell
$z = Get-Item _archive/2026-05-12-pre-cleanup.zip
"Size: $($z.Length) bytes"
if ($z.Length -lt 100000) { throw "Zip demasiado chico — revisá inputs" }
```
Expected: `Size: <numero> bytes` con valor > 100000.

---

### Task 0.2: Test baseline

**Files:**
- Create: `_archive/2026-05-12-pre-cleanup/test-baseline.txt`

- [ ] **Step 1: Crear subdirectorio para outputs de baseline**

```powershell
New-Item -ItemType Directory -Force -Path _archive/2026-05-12-pre-cleanup
```

- [ ] **Step 2: Correr `Tests/runner.ps1` y capturar salida**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1 *> _archive/2026-05-12-pre-cleanup/test-baseline.txt
$exit = $LASTEXITCODE
"runner exit: $exit" | Add-Content _archive/2026-05-12-pre-cleanup/test-baseline.txt
```
Expected: `runner exit: 0` + línea final `ALL TESTS PASSED` + `Total asserts: <N>` con N ≈ 700-750.

- [ ] **Step 3: Anotar N de asserts en este plan**

Editar este archivo: reemplazar `Baseline asserts: TBD` por `Baseline asserts: <N>` extrayendo de `test-baseline.txt`.

---

### Task 0.3: Crear estructura `docs/files/` + INDEX

**Files:**
- Create: `docs/files/INDEX.md`
- Create directorios: `docs/files/Lib/`, `docs/files/Schemas/`, `docs/files/Tests/`, `docs/files/_bak/`

- [ ] **Step 1: Crear directorios**

```powershell
@('docs/files', 'docs/files/Lib', 'docs/files/Schemas', 'docs/files/Tests', 'docs/files/_bak') |
  ForEach-Object { New-Item -ItemType Directory -Force -Path $_ }
```

- [ ] **Step 2: Escribir `docs/files/INDEX.md` con el siguiente contenido**

```markdown
# Inventario de archivos — QuickEntry

> Generado durante cleanup pre-producción (Plan: `docs/superpowers/plans/2026-05-12-cleanup-quickentry-plan.md`).
> Cada archivo fuente tiene su `.md` con API, dependencias, y bitácora de cleanup.

## Estado por fase

| Fase | Descripción | Estado |
|---|---|---|
| 0 | Inventario + grafo de dependencias | 🟡 en progreso |
| 1 | Quitar mapping M720 (.bak + handlers mouse) | ⚪ pendiente |
| 2 | Quitar comentarios innecesarios | ⚪ pendiente |
| 3 | Quitar código muerto (conservador + anotado) | ⚪ pendiente |
| 4 | Handoff senior + plan de simplificación | ⚪ pendiente |

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
- [`Tests/Test_AsignetHeader.md`](Tests/Test_AsignetHeader.md)
- [`Tests/Test_CaptureEngine.md`](Tests/Test_CaptureEngine.md)
- [`Tests/Test_Cleaners.md`](Tests/Test_Cleaners.md)
- [`Tests/Test_HudLayout.md`](Tests/Test_HudLayout.md)
- [`Tests/Test_Schema.md`](Tests/Test_Schema.md)
- [`Tests/Test_TooltipFormatter.md`](Tests/Test_TooltipFormatter.md)
- [`Tests/Test_Validators.md`](Tests/Test_Validators.md)

## Archivos legacy (a borrar en Fase 1)
- [`_bak/M720.md`](_bak/M720.md) — `M720.ahk.bak`
- [`_bak/M720_Lib.md`](_bak/M720_Lib.md) — `M720_Lib.ahk.bak`
- [`_bak/Test_M720_Lib.md`](_bak/Test_M720_Lib.md) — `Test_M720_Lib.ahk.bak`

## Grafo de dependencias
<a llenar por Task 0.4>

## Resumen de cleanup
<a llenar por Fase 4>
```

---

### Task 0.4: Generar grafo de dependencias (subagente)

**Files:**
- Modify: `docs/files/INDEX.md` (sección "Grafo de dependencias")

- [ ] **Step 1: Dispatch 1 subagente con el siguiente prompt**

```
Tarea: generar el grafo de dependencias entre archivos AHK del repo QuickEntry.

Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11

Archivos a analizar:
- QuickEntry.ahk
- Lib/*.ahk (9 archivos)
- Schemas/*.ahk (2 archivos)
- Tests/*.ahk (8 archivos: 7 Test_* + _AssertHelpers.ahk)

Para cada archivo extraer:
1. Líneas `#Include "..."` → arista "incluye"
2. `global <var>` → declaración de global (anotar variable + archivo)
3. Llamadas a funciones libres definidas en OTROS archivos (grep cruzado por nombre)
4. Instanciación de clases definidas en OTROS archivos

Salida: editar docs/files/INDEX.md sección "Grafo de dependencias" agregando:

### Edges (#Include)
- `QuickEntry.ahk` → `Lib/Cleaners.ahk`, `Lib/Validators.ahk`, ... (listar todas las #Include directas)
- `Lib/MainHud.ahk` → `Lib/HudLayout.ahk`, ... etc

### Globals
| Variable | Definida en | Leída en |
|---|---|---|
| `engine` | QuickEntry.ahk:35 | QuickEntry.ahk, ... |
| `hud` | QuickEntry.ahk:36 | ... |
| (etc, una fila por global) |

### Cross-file callers/callees
- `CaptureEngine` (clase): instanciada en QuickEntry.ahk:35; métodos llamados desde QuickEntry.ahk y Lib/MainHud.ahk
- `PegadoEspecial()`: definida en Lib/PegadoEspecial.ahk; llamada desde QuickEntry.ahk:57, QuickEntry.ahk:92
- (etc)

NO modificar código fuente. Solo escribir el .md. Reportar al volver: cuántas edges, cuántas globals, cuántos cross-file calls.
```

- [ ] **Step 2: Revisar el grafo manualmente**

Leer la sección "Grafo de dependencias" en `docs/files/INDEX.md`. Validar que:
- `QuickEntry.ahk` tiene `#Include` a las 9 dependencias esperadas.
- Las globals `engine`, `hud`, `pegadoEnCurso`, `AUTO_CALCULAR_TOTALES_OMITIDOS`, `HOTKEY_OMITIR` están presentes y sus consumidores son los esperados.
- Si algo falta, re-despachar el subagente con el gap señalado.

---

### Task 0.5: Crear los 23 `.md` por archivo (PARALLEL, 23 subagentes)

**Files (todos Create):**
- `docs/files/QuickEntry.md`
- `docs/files/Lib/AutoCalculator.md`
- `docs/files/Lib/CaptureEngine.md`
- `docs/files/Lib/Cleaners.md`
- `docs/files/Lib/HudLayout.md`
- `docs/files/Lib/MainHud.md`
- `docs/files/Lib/PegadoEspecial.md`
- `docs/files/Lib/Schema.md`
- `docs/files/Lib/TooltipFormatter.md`
- `docs/files/Lib/Validators.md`
- `docs/files/Schemas/AsignetHeaderV1.md`
- `docs/files/Schemas/_Plantilla_NuevaEmpresa.md`
- `docs/files/Tests/_AssertHelpers.md`
- `docs/files/Tests/Test_AsignetHeader.md`
- `docs/files/Tests/Test_CaptureEngine.md`
- `docs/files/Tests/Test_Cleaners.md`
- `docs/files/Tests/Test_HudLayout.md`
- `docs/files/Tests/Test_Schema.md`
- `docs/files/Tests/Test_TooltipFormatter.md`
- `docs/files/Tests/Test_Validators.md`
- `docs/files/Tests/runner.md`  ← documenta `Tests/runner.ps1` (único PS del repo, modificado en pre-fix Task 0.2)
- `docs/files/_bak/M720.md`
- `docs/files/_bak/M720_Lib.md`
- `docs/files/_bak/Test_M720_Lib.md`

- [ ] **Step 1: Dispatch 22 subagentes en paralelo (un mensaje con 22 Agent calls)**

Prompt template para cada subagente (sustituir `<TARGET>` por la ruta del archivo fuente y `<MD_OUT>` por la ruta del .md de salida):

```
Tarea: inventariar un archivo AHK v2 y emitir su .md siguiendo el template canónico.

Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11

Archivo a inventariar: <TARGET>
Archivo de salida: <MD_OUT>

Pasos:
1. Read <TARGET> completo.
2. Grep cruzado en QuickEntry.ahk, Lib/, Schemas/, Tests/ para encontrar:
   - Quién hace #Include de <TARGET>.
   - Quién llama cada función pública / instancia cada clase pública.
3. Extraer:
   - Clases con sus métodos públicos (firmas exactas) + propiedades.
   - Funciones libres con su firma exacta.
   - #Include directos (a otros archivos del repo).
   - Globales declaradas (`global <name>`) y globales leídas (sin declararlas).
   - Notas técnicas: timings de Sleep, workarounds de foco/clipboard, race conditions, gotchas de AHK v2 que el código ya documenta o que vos detectes.
4. Escribir <MD_OUT> usando EXACTAMENTE el template del plan
   `docs/superpowers/plans/2026-05-12-cleanup-quickentry-plan.md` sección
   "Template de docs/files/<archivo>.md".
5. Las secciones "Bitácora de cleanup" deben quedar inicializadas con checkboxes
   sin marcar y sin entradas (placeholders del template).
6. La sección "Ideas de simplificación pendientes" puede tener 0-3 bullets si
   detectás algo claro y de bajo riesgo (no obligatorio en esta fase). NO ejecutes
   simplificaciones todavía, solo anotalas.

Restricciones:
- NO modificar el archivo fuente.
- NO inventar APIs: si una función no existe, no la pongas.
- Firmas exactas: copiar de la definición real, no parafrasear.
- Para archivos de Tests/: en "API pública" listar los assert-helpers o describir
  qué cubre cada bloque de tests (no inventar).
- Para los .bak: status: deprecated. En "Propósito" indicar qué hacía,
  por qué se discontinuó (mapping de un mouse personal Logitech M720),
  y qué cubre hoy QuickEntry.ahk + el resto del Lib que reemplaza esa funcionalidad.

Reportar al volver: ruta del .md creado, conteo de líneas, lista de símbolos públicos encontrados.
```

- [ ] **Step 2: Verificar los 22 .md existen y tienen sustancia**

```powershell
$expected = @(
  'docs/files/QuickEntry.md',
  'docs/files/Lib/AutoCalculator.md', 'docs/files/Lib/CaptureEngine.md',
  'docs/files/Lib/Cleaners.md', 'docs/files/Lib/HudLayout.md',
  'docs/files/Lib/MainHud.md', 'docs/files/Lib/PegadoEspecial.md',
  'docs/files/Lib/Schema.md', 'docs/files/Lib/TooltipFormatter.md',
  'docs/files/Lib/Validators.md',
  'docs/files/Schemas/AsignetHeaderV1.md', 'docs/files/Schemas/_Plantilla_NuevaEmpresa.md',
  'docs/files/Tests/_AssertHelpers.md', 'docs/files/Tests/Test_AsignetHeader.md',
  'docs/files/Tests/Test_CaptureEngine.md', 'docs/files/Tests/Test_Cleaners.md',
  'docs/files/Tests/Test_HudLayout.md', 'docs/files/Tests/Test_Schema.md',
  'docs/files/Tests/Test_TooltipFormatter.md', 'docs/files/Tests/Test_Validators.md',
  'docs/files/_bak/M720.md', 'docs/files/_bak/M720_Lib.md', 'docs/files/_bak/Test_M720_Lib.md'
)
$missing = $expected | Where-Object { -not (Test-Path $_) }
if ($missing) { throw "Faltan: $($missing -join ', ')" }
$expected | ForEach-Object {
  $lines = (Get-Content $_).Count
  if ($lines -lt 30) { Write-Warning "$_ tiene solo $lines lineas — revisar" }
}
"OK: 22 .md presentes"
```
Expected: `OK: 22 .md presentes` sin warnings de líneas < 30 (cada .md debería tener al menos 30 líneas con la API y dependencias).

- [ ] **Step 3: Revisión manual rápida (spot-check)**

Abrir 3 .md al azar (`Lib/MainHud.md`, `Lib/CaptureEngine.md`, `QuickEntry.md`) y validar que la sección "API pública" matchea la realidad del código.

---

## Fase 1 — quitar mapping M720 (.bak + handlers mouse en QuickEntry.ahk)

Decisión: el mapping M720 no va a producción porque era para un mouse personal del autor original. Esto incluye los 3 `.bak` legacy **y** los handlers `XButton1::`, `XButton2::`, `WheelRight::`, `WheelLeft::` en `QuickEntry.ahk:46-71`. `PegadoEspecial()` queda en su lugar (es funcionalidad core, no mapping M720), y el hotkey de teclado `^+v::DoPegadoEspecial()` se conserva.

### Task 1.1: Documentar contenido de `.bak` antes de borrarlos

**Files:**
- Modify: `docs/files/_bak/M720.md`
- Modify: `docs/files/_bak/M720_Lib.md`
- Modify: `docs/files/_bak/Test_M720_Lib.md`

- [ ] **Step 1: Dispatch 1 subagente que enriquezca los 3 .md de _bak**

```
Tarea: verificar que los 3 .bak no contienen funcionalidad útil ausente del código vivo, y documentar la equivalencia en sus .md.

Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11

Archivos a comparar:
- M720.ahk.bak ↔ QuickEntry.ahk (entry actual)
- M720_Lib.ahk.bak ↔ Lib/Cleaners.ahk + Lib/Validators.ahk + Lib/PegadoEspecial.ahk
- Test_M720_Lib.ahk.bak ↔ Tests/Test_Cleaners.ahk + Tests/Test_Validators.ahk

Para cada .bak, leelo entero y enumerá:
1. Funciones / handlers / clases que existen en el .bak.
2. Para cada uno: ¿existe equivalente en el código vivo? Listar el reemplazo (archivo:linea) o marcar "DESCONTINUADO sin reemplazo".

Editar cada docs/files/_bak/<nombre>.md sección "Propósito" y agregar una tabla:

| Símbolo del .bak | Estado | Reemplazo en código vivo |
|---|---|---|
| `FormatearFecha()` | ✅ migrado | `Lib/Cleaners.ahk: ...` |
| `XButton2::PegadoEspecial()` | ❌ removido | (se quita en Fase 1.3 — mapping de mouse personal) |
| ... |

Status del .md: deprecated (ya estaba), tras esta tarea sigue deprecated.

CRITERIO DE BLOQUEO: si encontrás un símbolo en el .bak SIN reemplazo Y que parezca útil
(ej: una validación, un cleaner, un formato que no está en el código vivo), NO borres nada
y reportá ese símbolo en la respuesta. El usuario decide si rescatarlo antes de Fase 1.2.

Reportar al volver: cantidad de símbolos por .bak, cuántos sin reemplazo (debería ser 0 o solo handlers de mouse M720).
```

- [ ] **Step 2: Si el subagente reportó símbolos sin reemplazo distintos de "handler M720", PARAR**

El humano decide. Default si todo el contenido del .bak está cubierto o es mapping personal: avanzar a Task 1.2.

---

### Task 1.2: Borrar los 3 `.bak`

**Files:**
- Delete: `M720.ahk.bak`
- Delete: `M720_Lib.ahk.bak`
- Delete: `Test_M720_Lib.ahk.bak`

- [ ] **Step 1: Borrar los 3 archivos**

```powershell
Remove-Item M720.ahk.bak, M720_Lib.ahk.bak, Test_M720_Lib.ahk.bak -Force
```

- [ ] **Step 2: Verificar que no quedan referencias residuales**

```powershell
Get-ChildItem -Recurse -Include *.ahk, *.md, *.ps1 |
  Select-String -Pattern 'M720' -CaseSensitive:$false |
  Where-Object { $_.Path -notmatch '_bak|cleanup-quickentry' }
```
Expected: 0 matches (las únicas referencias permitidas son en los .md de `_bak/` y en este plan).

- [ ] **Step 3: Marcar los 3 .md de `_bak` como `status: to-delete`**

```powershell
'docs/files/_bak/M720.md', 'docs/files/_bak/M720_Lib.md', 'docs/files/_bak/Test_M720_Lib.md' |
  ForEach-Object {
    (Get-Content $_ -Raw) -replace 'status: deprecated', 'status: to-delete' |
      Set-Content $_ -NoNewline
  }
```

- [ ] **Step 4: Registrar el cambio en `INDEX.md`**

En `docs/files/INDEX.md` sección "Estado por fase", cambiar fila Fase 1 a `🟡 en progreso`.
En sección "Archivos legacy", agregar al final:
```
**2026-05-12:** los 3 .bak fueron borrados del filesystem. Los .md
de `_bak/` se conservan como histórico hasta el cierre del Plan.
```

---

### Task 1.3: Quitar handlers M720 (XButton/Wheel) de `QuickEntry.ahk`

**Files:**
- Modify: `QuickEntry.ahk` (borrar `:46-71`, ~26 líneas incluyendo banner)
- Modify: `docs/files/QuickEntry.md` (bitácora Fase 1)

- [ ] **Step 1: Editar `QuickEntry.ahk` borrando el bloque `46-71`**

Buscar este bloque exacto y borrarlo entero:

```autohotkey
; ====================================================================
; MAPEOS DE BOTONES DE MOUSE (opcional - solo si tu mouse los tiene)
; XButton1/2 = botones laterales | WheelLeft/Right = tilt de la rueda
; ====================================================================
XButton1::
{
    SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}"
    Sleep 20
    SendInput "^c"
}

XButton2::PegadoEspecial()

WheelRight::
{
    SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}{LWin up}{RWin up}"
    Sleep 20
    SendInput "#+t"
}

WheelLeft::
{
    SendInput "{Blind}{LShift up}{RShift up}{LCtrl up}{RCtrl up}"
    Sleep 20
    SendInput "^+|"
}

```

Después del borrado, la sección "PEGADO ESPECIAL via teclado" debe quedar inmediatamente después de la sección "Singletons" (con su banner `; ====...` intacto).

- [ ] **Step 2: Validar sintaxis del archivo editado**

```powershell
& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate QuickEntry.ahk
```
Expected: exit 0, sin output de error.

- [ ] **Step 3: Registrar en `docs/files/QuickEntry.md` bitácora Fase 1**

Editar `docs/files/QuickEntry.md` sección "Bitácora de cleanup > Fase 1 — m720":
```markdown
### Fase 1 — m720
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - `QuickEntry.ahk:46-71` — borrados handlers `XButton1::`, `XButton2::`,
    `WheelRight::`, `WheelLeft::` + banner "MAPEOS DE BOTONES DE MOUSE".
    Razón: mapping personal de un mouse Logitech M720; el plan de producción
    no incluye periféricos no estándar. `PegadoEspecial()` queda accesible
    por `^+v::DoPegadoEspecial()` (línea 76).
```

Si la sección "API pública" del .md mencionaba `XButton1::` / `XButton2::` / `WheelRight::` / `WheelLeft::`, removerlos.

---

### Task 1.4: Test gate Fase 1

- [ ] **Step 1: Correr el runner completo**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1
```
Expected: `Total asserts: <baseline-N>` igual al baseline, `ALL TESTS PASSED`, exit 0.

- [ ] **Step 2: Si fallan asserts, rollback**

```powershell
git status 2>$null  # confirma que no es git
# Restaurar QuickEntry.ahk desde el zip
Expand-Archive -Path _archive/2026-05-12-pre-cleanup.zip -DestinationPath _rollback -Force
Copy-Item _rollback/QuickEntry.ahk QuickEntry.ahk -Force
Remove-Item _rollback -Recurse -Force
```
Después del rollback: re-revisar el diff de Task 1.3 línea por línea con el humano antes de retentar.

- [ ] **Step 3: Marcar Fase 1 cerrada en INDEX.md**

En `docs/files/INDEX.md`, fila Fase 1: `🟢 completa`.

---

## Fase 2 — quitar comentarios innecesarios (PARALLEL por archivo)

**Alcance**: 12 archivos productivos (`QuickEntry.ahk` + 9 `Lib/` + 2 `Schemas/`) + 8 archivos de test = **20 archivos**.

**Política aprobada (criterio aplicado por cada subagente)**:
- **Borrar**: redundantes que re-explican código obvio, banners decorativos sin info, código comentado (`; viejo := ...`), TODOs/FIXMEs estancados, narrativa histórica ("antes hacíamos X").
- **Conservar**: comentarios que explican WHY no-obvio — workarounds de foco/clipboard, timings de Sleep con razón documentada, race conditions, gotchas AHK v2, invariantes, contratos no inferibles del código.
- **Re-escribir**: comentarios que explican QUÉ → o se borran (si el nombre del símbolo lo cuenta) o se reformulan al WHY.

**Salida obligatoria**: cada borrón/reescritura queda registrada en `docs/files/<archivo>.md` sección "Bitácora de cleanup > Fase 2".

### Task 2.1: Dispatch 20 subagentes en paralelo

**Files:**
- Modify (cada subagente edita 2 archivos: el `.ahk` y su `.md`):
  - `QuickEntry.ahk` + `docs/files/QuickEntry.md`
  - `Lib/AutoCalculator.ahk` + `docs/files/Lib/AutoCalculator.md`
  - `Lib/CaptureEngine.ahk` + `docs/files/Lib/CaptureEngine.md`
  - `Lib/Cleaners.ahk` + `docs/files/Lib/Cleaners.md`
  - `Lib/HudLayout.ahk` + `docs/files/Lib/HudLayout.md`
  - `Lib/MainHud.ahk` + `docs/files/Lib/MainHud.md`
  - `Lib/PegadoEspecial.ahk` + `docs/files/Lib/PegadoEspecial.md`
  - `Lib/Schema.ahk` + `docs/files/Lib/Schema.md`
  - `Lib/TooltipFormatter.ahk` + `docs/files/Lib/TooltipFormatter.md`
  - `Lib/Validators.ahk` + `docs/files/Lib/Validators.md`
  - `Schemas/AsignetHeaderV1.ahk` + `docs/files/Schemas/AsignetHeaderV1.md`
  - `Schemas/_Plantilla_NuevaEmpresa.ahk` + `docs/files/Schemas/_Plantilla_NuevaEmpresa.md`
  - `Tests/_AssertHelpers.ahk` + `docs/files/Tests/_AssertHelpers.md`
  - `Tests/Test_AsignetHeader.ahk` + `docs/files/Tests/Test_AsignetHeader.md`
  - `Tests/Test_CaptureEngine.ahk` + `docs/files/Tests/Test_CaptureEngine.md`
  - `Tests/Test_Cleaners.ahk` + `docs/files/Tests/Test_Cleaners.md`
  - `Tests/Test_HudLayout.ahk` + `docs/files/Tests/Test_HudLayout.md`
  - `Tests/Test_Schema.ahk` + `docs/files/Tests/Test_Schema.md`
  - `Tests/Test_TooltipFormatter.ahk` + `docs/files/Tests/Test_TooltipFormatter.md`
  - `Tests/Test_Validators.ahk` + `docs/files/Tests/Test_Validators.md`

- [ ] **Step 1: Dispatch 20 subagentes (un mensaje con 20 Agent calls)**

Prompt template (sustituir `<TARGET>` y `<MD_OUT>`):

```
Tarea: limpiar comentarios innecesarios en un archivo AHK v2, registrar cada borrón en su .md.

Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11

Archivo fuente: <TARGET>
Archivo .md asociado: <MD_OUT>

Criterio (estrictamente):

BORRAR comentarios que:
- Re-explican código obvio (ej: `i++ ; incrementar i`).
- Son banners decorativos puros sin información (ej: `; ====`, `; ---` solos).
- Son código comentado (`; foo := bar`) sin contexto vivo.
- Son TODOs/FIXMEs sin fecha ni dueño.
- Cuentan narrativa histórica que ya no aplica ("antes hacíamos X, pero...").
- Repiten lo que dice un nombre de función/variable claro.

CONSERVAR comentarios que:
- Explican WHY no-obvio: workarounds de foco/clipboard, timings de Sleep con
  razón, race conditions, invariantes, gotchas AHK v2 (escapes, KeyWait, Blind),
  contratos pre/post-condición que no se infieren del código.
- Documentan formato de input/output de funciones públicas si no es evidente.
- Llevan fecha de incident report o referencia a un bug específico.

RE-ESCRIBIR comentarios:
- Si explica QUÉ (lo que el código hace) en vez de WHY → o borrar (si el nombre
  ya lo cuenta) o reformular en una línea al WHY.

BANNER DECORATIVO ÚTIL: si un `; ===` separa secciones funcionales claras
(ej: "; --- Hotkeys ---" sobre un bloque de hotkeys), MANTENERLO si y solo si
mejora navegabilidad. Si el archivo tiene 6+ banners, dejar máximo 3 (los más útiles).

NO TOCAR:
- Headers de archivo (las primeras ~10 líneas con propósito del archivo).
- Comentarios SNAPSHOT que indican origen ("; SNAPSHOT COPY from ..." — Asignet convention).
- `; ====================================================================` SOLO si está
  delimitando secciones reales del archivo Y el archivo es grande (>200 líneas).
- Strings, regex, ni nombres de variables.

Pasos:
1. Read <TARGET> completo.
2. Identificar cada línea con `;` que matchee BORRAR.
3. Editar el archivo eliminando esos comentarios. Si quedan líneas en blanco
   redundantes (3+ seguidas), colapsar a 1.
4. Validar sintaxis tras cada bloque de edits significativo:
   `& "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 /validate <TARGET>`
   Exit code 0 obligatorio. Si falla, hacer rollback de tu último edit.
5. Para CADA borrón, agregar una entrada a <MD_OUT> sección "Bitácora de cleanup > Fase 2 — comentarios" con el formato:
   `- \`<archivo>:<linea-original>\` — borrado: \`<snippet, max 60 chars>\` — razón: <redundante|banner|código comentado|TODO viejo|narrativa>`
   Si reescribiste un comentario, formato:
   `- \`<archivo>:<linea-original>\` — reescrito: de \`<viejo>\` a \`<nuevo>\` — razón: QUÉ→WHY`
   Marcar el checkbox `- [x] Auditado 2026-05-12`.
6. NO tocar el comportamiento del código. NO borrar líneas que no son comentarios.
7. NO tocar tests assertions, NO renombrar funciones.

Reportar al volver:
- Líneas borradas (count).
- Comentarios reescritos (count).
- Sintaxis validada (sí/no).
- Cualquier comentario dudoso que dejaste intacto y querés que el humano revise.
```

- [ ] **Step 2: Verificación post-dispatch**

```powershell
# Validar sintaxis de los 12 archivos productivos
$prod = @(
  'QuickEntry.ahk',
  'Lib/AutoCalculator.ahk', 'Lib/CaptureEngine.ahk', 'Lib/Cleaners.ahk',
  'Lib/HudLayout.ahk', 'Lib/MainHud.ahk', 'Lib/PegadoEspecial.ahk',
  'Lib/Schema.ahk', 'Lib/TooltipFormatter.ahk', 'Lib/Validators.ahk',
  'Schemas/AsignetHeaderV1.ahk', 'Schemas/_Plantilla_NuevaEmpresa.ahk'
)
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$failures = @()
foreach ($f in $prod) {
  & $ahk /ErrorStdOut=utf-8 /validate $f *> $null
  if ($LASTEXITCODE -ne 0) { $failures += $f }
}
if ($failures) { throw "Sintaxis falló en: $($failures -join ', ')" }
"OK: 12 archivos productivos validados"
```
Expected: `OK: 12 archivos productivos validados`.

```powershell
# Validar sintaxis de los 8 archivos de test
$tests = Get-ChildItem Tests -Filter "*.ahk" | ForEach-Object { $_.FullName }
foreach ($f in $tests) {
  & $ahk /ErrorStdOut=utf-8 /validate $f *> $null
  if ($LASTEXITCODE -ne 0) { throw "Sintaxis falló en: $f" }
}
"OK: tests validados"
```
Expected: `OK: tests validados`.

- [ ] **Step 3: Spot-check de 3 bitácoras**

Abrir `docs/files/Lib/MainHud.md`, `docs/files/Lib/CaptureEngine.md`, `docs/files/QuickEntry.md` y verificar que la sección "Bitácora de cleanup > Fase 2" tiene entradas concretas (no quedó vacía). Si está vacía: el subagente decidió no borrar nada en ese archivo → revisar manualmente.

- [ ] **Step 4: Marcar Fase 2 en INDEX.md**

En `docs/files/INDEX.md`, fila Fase 2: `🟢 completa`. Sin test run intermedio (cambios = solo comentarios, riesgo de break = 0; sintaxis ya validada).

---

## Fase 3 — quitar rastros de funcionalidad no usada (conservador + anotado)

**Política aprobada**: el subagente borra solo lo que tiene **0 referencias** en producción + tests. Cualquier símbolo dudoso (param con default jamás pasado, método invocado en string dinámico, branch difícil de probar) **se anota en el `.md`** como "candidato para review senior" y NO se borra.

### Task 3.1: Análisis de uso por archivo (PARALLEL, 12 subagentes — solo productivos, no tests)

**Files:**
- Modify (cada subagente edita 2 archivos: el `.ahk` productivo y su `.md`):
  - Los 12 archivos productivos enumerados en Task 2.1.

- [ ] **Step 1: Dispatch 12 subagentes en paralelo**

Prompt template:

```
Tarea: detectar y borrar funcionalidad no usada en un archivo AHK v2 (modo conservador), anotar dudas en su .md.

Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11

Archivo fuente: <TARGET>
Archivo .md asociado: <MD_OUT>

Pasos:

1. Read <TARGET> completo. Listar TODOS los símbolos definidos:
   - Funciones libres con su nombre exacto.
   - Métodos públicos de clases (no privados con prefijo `_` si no son llamados externamente).
   - Properties con setter/getter custom.
   - Parámetros con default value (`func(x, y := 0)` → param `y`).
   - Branches `if/else` claramente muertos (condiciones imposibles, `if (false)`).

2. Para cada símbolo de la lista:
   a. Buscar referencias en: QuickEntry.ahk, Lib/*.ahk, Schemas/*.ahk, Tests/*.ahk.
      Comando: grep recursivo case-sensitive del nombre exacto.
   b. Excluir self-references (línea de la definición).
   c. Clasificar:
      - USADO: 1+ referencias externas.
      - NO USADO (0 refs): elegible para borrar.
      - DUDOSO: 0 refs detectadas PERO uno o más de:
        - El símbolo es un método llamado dinámicamente (ej: `obj.%name%()`)
        - Es un callback registrado en SetTimer/OnEvent/OnClipboardChange
        - Es un parámetro de una función pública que podría ser llamada por código externo (no del repo, ej: a futuro)
        - Es un branch defensivo (early-return en condiciones de error)

3. Acción según clasificación:
   - USADO: no tocar.
   - NO USADO: borrar la definición + bloque entero. Validar sintaxis post-edit con
     `/validate`. Si rompe sintaxis (ej: dejó un trailing brace huérfano), hacer rollback.
   - DUDOSO: NO TOCAR el código. Anotar en <MD_OUT> sección "Bitácora de cleanup > Fase 3
     > Candidatos para review senior" con formato:
     `- \`<simbolo>\` en \`<archivo>:<linea>\` — razón de duda: <descripción 1 línea> — bandera roja si: <qué buscar para confirmar uso>`

4. Para cada borrón aplicado, anotar en <MD_OUT> "Bitácora de cleanup > Fase 3 > Borrados":
   `- \`<simbolo>\` en \`<archivo>:<linea-original>\` — razón: sin callers ni tests`

5. Marcar checkbox `- [x] Auditado 2026-05-12` en sección Fase 3 del .md.

6. NO tocar:
   - Constructores de clases (siempre se "usan" implícitamente).
   - Hotkeys (líneas con `::`).
   - Headers `#Include`, `#Requires`.
   - El método `Show()` de MainHud (sí se llama desde QuickEntry.ahk).
   - Cualquier símbolo cuya remoción te haga sentir < 90% seguro: ponerlo en DUDOSO.

7. NO ejecutar tests todavía (lo hace el test gate).

Reportar al volver:
- Símbolos USADO (count).
- Símbolos NO USADO borrados (count + lista).
- Símbolos DUDOSO anotados (count + lista corta).
- Sintaxis validada (sí/no).
```

- [ ] **Step 2: Verificar sintaxis post-edits**

```powershell
$prod = @(
  'QuickEntry.ahk',
  'Lib/AutoCalculator.ahk', 'Lib/CaptureEngine.ahk', 'Lib/Cleaners.ahk',
  'Lib/HudLayout.ahk', 'Lib/MainHud.ahk', 'Lib/PegadoEspecial.ahk',
  'Lib/Schema.ahk', 'Lib/TooltipFormatter.ahk', 'Lib/Validators.ahk',
  'Schemas/AsignetHeaderV1.ahk', 'Schemas/_Plantilla_NuevaEmpresa.ahk'
)
$ahk = "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$failures = @()
foreach ($f in $prod) {
  & $ahk /ErrorStdOut=utf-8 /validate $f *> $null
  if ($LASTEXITCODE -ne 0) { $failures += $f }
}
if ($failures) { throw "Sintaxis falló en: $($failures -join ', ')" }
"OK: 12 productivos validados post-Fase 3"
```
Expected: `OK: 12 productivos validados post-Fase 3`.

---

### Task 3.2: Test gate Fase 3

- [ ] **Step 1: Correr runner.ps1 completo**

```powershell
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1
```
Expected: `Total asserts: <baseline-N>` igual al baseline, `ALL TESTS PASSED`, exit 0.

- [ ] **Step 2: Si fallan asserts**

```powershell
# Ver qué archivo rompió
Get-Content $env:TEMP\Test_*.out | Select-String "FAIL"
```

Identificar qué subagente borró de más. Rollback solo el archivo culpable desde el zip:
```powershell
Expand-Archive -Path _archive/2026-05-12-pre-cleanup.zip -DestinationPath _rollback -Force
Copy-Item _rollback/<archivo-culpable> <archivo-culpable> -Force
Remove-Item _rollback -Recurse -Force
```
Después aplicar **solo** los borrados de Fase 2 (comentarios) al archivo rescatado — los de Fase 3 quedan revertidos. Re-correr runner.

- [ ] **Step 3: Marcar Fase 3 en INDEX.md**

En `docs/files/INDEX.md`, fila Fase 3: `🟢 completa`.

---

## Fase 4 — handoff senior + plan de simplificación posterior

### Task 4.1: Borrar los `.md` de `_bak/` y el directorio

**Files:**
- Delete: `docs/files/_bak/M720.md`, `docs/files/_bak/M720_Lib.md`, `docs/files/_bak/Test_M720_Lib.md`
- Delete: directorio `docs/files/_bak/`

- [ ] **Step 1: Borrar los 3 .md de _bak**

```powershell
Remove-Item docs/files/_bak/* -Force
Remove-Item docs/files/_bak -Force
```
(Quedan referenciados en este plan + en el zip de Fase 0 si alguien los necesita históricos.)

- [ ] **Step 2: Quitar la sección "Archivos legacy" de `docs/files/INDEX.md`**

Reemplazar el bloque "## Archivos legacy (a borrar en Fase 1)" + las 3 viñetas + la nota "2026-05-12: los 3 .bak..." por:
```markdown
## Archivos legacy
Removidos en Fase 1 — ver `_archive/2026-05-12-pre-cleanup.zip` para el histórico.
```

---

### Task 4.2: Generar reporte de cierre del cleanup

**Files:**
- Create: `docs/superpowers/plans/2026-05-12-cleanup-quickentry-final.md`

- [ ] **Step 1: Dispatch 1 subagente que recolecte estadísticas**

```
Tarea: emitir el reporte final del cleanup de QuickEntry para handoff al senior.

Working dir: C:\Users\avazquez\Downloads\QuickEntry-quickestEntry\QuickEntry-quickestEntryV1.11

Recolectar:
1. Conteo total de líneas borradas en código fuente (diff de tamaño antes/después
   por archivo). Comparar contra `_archive/2026-05-12-pre-cleanup.zip`:
   ```powershell
   Expand-Archive -Path _archive/2026-05-12-pre-cleanup.zip -DestinationPath _diff -Force
   # comparar Get-Item .Length por archivo
   ```
2. Conteo total de comentarios borrados (sumar entradas de Fase 2 en cada .md).
3. Conteo total de símbolos muertos borrados (sumar entradas de Fase 3 > Borrados).
4. Lista completa de "candidatos para review senior" (todos los Fase 3 > Candidatos).
5. Confirmación de asserts: leer test-baseline.txt y comparar con runner actual.

Escribir docs/superpowers/plans/2026-05-12-cleanup-quickentry-final.md con:

# Reporte final — cleanup QuickEntry

## Resumen ejecutivo
- Líneas borradas: X (de Y → Z)
- Comentarios borrados: A
- Símbolos muertos borrados: B
- Asserts antes/después: M / N (debe ser igual)
- Candidatos pendientes para review: C

## Cambios por archivo
<tabla: archivo | líneas antes | líneas después | comentarios borrados | símbolos borrados>

## Candidatos para review senior
<lista, agrupada por archivo, copiada de las bitácoras Fase 3 de cada .md>

## Ideas de simplificación recogidas
<lista agregada de la sección "Ideas de simplificación pendientes" de cada .md, agrupada por archivo>

## Próximo paso
Plan de simplificación: TODO — se escribe con `/superpowers:writing-plans` consumiendo este reporte como spec.

Limpiar el directorio _diff al terminar:
   `Remove-Item _diff -Recurse -Force`
```

- [ ] **Step 2: Revisar el reporte manualmente**

Leer el archivo generado. Validar que los conteos parecen sanos (no negativos, no absurdos). Si algo no cuadra, pedir al subagente que regenere.

- [ ] **Step 3: Marcar Fase 4 en INDEX.md y cerrar**

En `docs/files/INDEX.md`, fila Fase 4: `🟢 completa`. Agregar al pie del archivo:
```markdown
---
**Cleanup cerrado: 2026-05-12.** Reporte: [`2026-05-12-cleanup-quickentry-final.md`](../superpowers/plans/2026-05-12-cleanup-quickentry-final.md).
```

---

### Task 4.3: Handoff al senior + arranque del plan posterior

- [ ] **Step 1: Presentar al usuario**

Mostrar el reporte `2026-05-12-cleanup-quickentry-final.md` y el contenido de `docs/files/INDEX.md` al usuario. Esperar feedback / aprobación senior.

- [ ] **Step 2: Si aprueba, iniciar plan de simplificación**

Consultar **una sola vez** (decisión #11 del usuario):
- `ClautoHotkey/Modules/Module_Instructions.md` (canónico)
- `ClautoHotkey/Modules/Module_Classes.md` (MainHud, CaptureEngine son clases)
- `ClautoHotkey/Modules/Module_GUI.md` (HUD con controles, ListView)

Invocar `/superpowers:writing-plans` con el siguiente input:
```
Spec: docs/superpowers/plans/2026-05-12-cleanup-quickentry-final.md secciones
"Candidatos para review senior" + "Ideas de simplificación recogidas".

Objetivo: simplificar el código limpio post-cleanup. Tocar firmas inter-archivo
donde reduzca acoplamiento. Aplicar patrones canónicos de ClautoHotkey/Module_Classes.md
y Module_GUI.md. Sin agregar features.

Restricciones:
- Por archivo, secuencial (no paralelo) — un cambio puede romper conexiones a otros.
- Tests deben pasar después de CADA archivo modificado.
- Cada cambio se anota en docs/files/<archivo>.md sección "Bitácora de cleanup"
  agregando una sección "Fase 5 — simplificación".

Archivo destino del nuevo plan:
docs/superpowers/plans/2026-05-XX-simplify-quickentry-plan.md
```

---

## Resumen de paralelización

| Fase | Tasks | Paralelismo | Test runs |
|---|---|---|---|
| 0 | 5 (snapshot, baseline, scaffold, grafo, 22 .md) | Task 0.5 = 22 subagentes en paralelo | 1 (baseline) |
| 1 | 4 (doc .bak, borrar .bak, editar QuickEntry, gate) | Task 1.1 = 1 subagente | 1 (post-Fase 1) |
| 2 | 1 (cleanup comentarios) | 20 subagentes en paralelo | 0 (solo `/validate`) |
| 3 | 2 (análisis + edits, gate) | Task 3.1 = 12 subagentes en paralelo | 1 (post-Fase 3) |
| 4 | 3 (limpiar `_bak/`, reporte, handoff) | Task 4.2 = 1 subagente | 0 |

**Total test runs: 3** (baseline + 2 gates). Total subagentes dispatched: ~56 (la mayoría en paralelo).

---

## Self-review checklist (completado al escribir este plan)

1. **Spec coverage:**
   - ✅ "Crear .md para cada file con sus funciones y qué hace cada archivo incluidos los .bak" → Task 0.5 (22 .md, incluye 3 .bak).
   - ✅ "Verificar que se borren comentarios innecesarios" → Fase 2.
   - ✅ "Borrar rastros de funcionalidades no usadas" → Fase 3 (conservador + anotado).
   - ✅ "Quitar lo relacionado al mapping de m720" → Fase 1 (.bak + handlers XButton/Wheel, decisión #1 = b).
   - ✅ "Cada cosa quitada debe quedar registrada en los nuevos .md" → bitácora Fase 1/2/3 en cada .md, requerida por cada subagente prompt.
   - ✅ "Más de un .md, al menos uno para la principal" → 22 .md + INDEX.
   - ✅ "Plan para simplificar después" → Task 4.3 (plan separado, decisión #10 = b).
   - ✅ "Ideas para simplificar tocando parámetros de funciones conectadas" → sección "Ideas de simplificación pendientes" en cada .md + agregada en reporte final.
   - ✅ "Listo para senior developer" → Task 4.3 handoff.

2. **Placeholder scan:** ningún TODO sin contenido, ningún "fill in details". Las únicas líneas con `TBD` son el conteo de baseline asserts (Task 0.2 lo completa) y la fecha del plan de simplificación (depende de la aprobación senior).

3. **Type consistency:**
   - "Bitácora de cleanup" tiene el mismo nombre en el template, en los prompts de Fase 1/2/3 y en el reporte final.
   - "Candidatos para review senior" idem (consistente entre template y prompt de Fase 3).
   - "Ideas de simplificación pendientes" idem.
   - Status del .md (`active` / `deprecated` / `to-delete`) consistente entre template y Task 1.2.
   - Las 22 rutas de .md están enumeradas explícitamente en Task 0.5 y verificadas en Step 2.

---

## Notas operativas para el ejecutor del plan

- **No es git repo.** Snapshot zip es la red de seguridad. Si algo se rompe y no hay forma de identificar al culpable, restaurar el zip completo y reintentar la fase desde el inicio.
- **AHK64 path es fijo**: `C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe`. Convención Asignet (CLAUDE.md), no `uphol`.
- **Light theme**: ninguna fase toca styling, por lo que la regla "no dark mode" no aplica.
- **Tests son verdad** (~700 asserts). Cualquier rollback se gatilla por test failure, no por preferencia estética.
- Si un subagente reporta < 5 borrones en un archivo de 200+ líneas durante Fase 2, está siendo demasiado conservador — re-despachar con instrucción "más agresivo en banners decorativos".
- Si un subagente reporta > 0 borrones en Fase 3 sobre un método de `MainHud` que es llamado desde `QuickEntry.ahk`, el grep cruzado falló — revisar el grafo de Task 0.4 y re-correr.
