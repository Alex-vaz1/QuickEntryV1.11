---
file: Tests/runner.ps1
last_review: 2026-05-12
status: active
---

# `Tests/runner.ps1`

## Propósito

Script PowerShell que orquesta la ejecución de todos los archivos `Test_*.ahk`
del directorio `Tests/`. Reporta PASS/FAIL por archivo, parsea el summary de
asserts emitido por cada test, y termina con exit code 0 (todo OK) o 1 (al menos
un archivo falló o crasheó). Es el único archivo PowerShell del repo.

## API pública

> Este archivo no expone clases ni funciones: es un script de ejecución lineal.
> A continuación se describe su flujo completo y las variables clave.

### Flujo del script

1. **Discovery de AHK v2** — Determina el ejecutable a usar consultando, en orden:
   - Variable de entorno `$env:AHK_V2` (override portable, recomendado para CI).
   - Fallback 1: `$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe`
   - Fallback 2: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`
   - Fallback 3: `C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` (path del autor original, conservado como último recurso).
   - Si ninguno existe, lanza `throw` con mensaje accionable.

2. **Colección de tests** — `Get-ChildItem -Filter "Test_*.ahk"` sobre `$PSScriptRoot`,
   ordenados por nombre (`Sort-Object Name`) para ejecución determinista.

3. **Loop por archivo** — Para cada `Test_*.ahk`:
   - Lanza `Start-Process` con `-RedirectStandardOutput` y `-RedirectStandardError`
     a archivos temporales en `$env:TEMP` (nombres `<BaseName>.out` / `<BaseName>.err`).
   - Espera exit (`-Wait -PassThru`).
   - Lee el `.out` buscando la línea `=== N tests, F failures ===` (summary emitido
     por `_AssertHelpers.ahk:ReportarYSalir()`).
   - Clasifica el resultado:
     - **PASS**: `$hasSummary = $true` Y `$p.ExitCode -eq 0` Y `$failures -eq 0`.
     - **CRASH**: `$hasSummary = $false` O `$p.ExitCode -ne 0`. Indica que AHK
       terminó antes de imprimir el summary (syntax error, excepción no manejada,
       o `Exit` prematuro).
     - **FAIL**: summary encontrado, pero `$failures -gt 0` (asserts fallaron).

4. **Salida por consola** — `Write-Host` coloreado:
   - PASS: verde, formato `PASS  <nombre,-32> <summary-line>`.
   - FAIL/CRASH: rojo, con detalle de líneas `FAIL` del `.out` y contenido de `.err`.

5. **Totales y exit code**:
   - `$totalAsserts` acumula el N de cada summary.
   - Si `$totalFail -eq 0`: imprime `ALL TESTS PASSED`, `exit 0`.
   - Si `$totalFail -gt 0`: imprime `<N> TEST FILE(S) FAILED`, `exit 1`.

### Variables clave

| Variable | Tipo | Rol |
|---|---|---|
| `$ahk` | `string` | Ruta al ejecutable `AutoHotkey64.exe`, resuelta via discovery |
| `$testDir` | `string` | `$PSScriptRoot` — directorio donde vive el script |
| `$tests` | `FileInfo[]` | Archivos `Test_*.ahk` encontrados, ordenados |
| `$totalFail` | `int` | Contador de archivos que fallaron o crashearon |
| `$totalAsserts` | `int` | Suma de asserts de todos los archivos que produjeron summary |
| `$hasSummary` | `bool` | `$true` si la línea `=== N tests, F failures ===` fue encontrada |
| `$out` / `$err` | `string` | Paths temporales en `$env:TEMP` para stdout/stderr de cada test |

## Dependencias

- **#Include directos**: ninguno (es PowerShell, no AHK).
- **Incluido por**: ninguno. Se invoca desde la línea de comandos:
  `powershell -ExecutionPolicy Bypass -File Tests/runner.ps1`
- **Globales que define**: N/A.
- **Globales que usa (leídas)**: `$env:AHK_V2` (override de path AHK), `$env:LOCALAPPDATA`,
  `$env:TEMP`, `$PSScriptRoot` (built-ins de PowerShell).
- **Ejecuta**: todos los `Tests/Test_*.ahk` vía `Start-Process AutoHotkey64.exe`.
  Depende implícitamente de `Tests/_AssertHelpers.ahk` (incluido por cada Test_*.ahk)
  para que los tests emitan el summary `=== N tests, F failures ===`.
- **Símbolos externos invocados**: `Test-Path`, `Remove-Item`, `Start-Process`,
  `Get-Content`, `Write-Host` (cmdlets estándar de PowerShell).

## Notas técnicas (WHY no-obvio)

- **AHK siempre exitea 0**: AHK v2 raramente devuelve exit code != 0 ante errores en
  tiempo de ejecución (excepciones no manejadas, `MsgBox` sin respuesta de usuario en
  modo headless). Por eso el script usa la presencia de la línea summary como señal
  primaria de crash silencioso (`$hasSummary`). El exit code es solo señal secundaria.

- **stderr redirigido separado**: se redirige stderr a `<BaseName>.err` porque AHK
  con `/ErrorStdOut=utf-8` escribe errores de compilación/sintaxis a stderr, no stdout.
  Sin esta redirección, los errores de sintaxis de un test caerían a la consola del
  runner sin ser capturados y el archivo parecería crashear limpiamente.

- **Archivos temporales purgados antes de cada run**: se borra `$out` y `$err` al inicio
  del loop (si existen) para evitar que una corrida anterior envenene la lectura. Sin
  esto, un crash que no produce ningún `.out` nuevo podría leer el summary de la
  ejecución anterior y reportar PASS falsamente.

- **`-NoNewWindow`**: necesario en entornos donde PowerShell corre dentro de otro host
  (CI, terminal embebido). Sin este flag, cada `Start-Process` abriría una ventana
  separada de consola que interfiere con la captura de output.

- **`Select-Object -Last 1` sobre el summary**: si un test imprime múltiples líneas
  que matchean el regex `tests,\s+\d+\s+failures` (posible si el test corre subtests
  anidados o _AssertHelpers escribe líneas intermedias), toma la última, que es la
  definitiva.

- **Pre-fix Task 0.2 (2026-05-12)**: la línea 6 original tenía el path AHK hardcodeado
  a `C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe`. Esto
  bloqueaba el test gate en cualquier máquina que no fuera la del autor original.
  Se cambió al discovery portable actual (`$env:AHK_V2` + fallbacks) como prerequisito
  para el senior review.

## Bitácora de cleanup

### Pre-fix aplicado (Task 0.2 — 2026-05-12)

- [x] Registrado 2026-05-12
- Cambios aplicados:
  - `Tests/runner.ps1:6` — path AHK hardcodeado a `C:\Users\Usuario\...` reemplazado
    por discovery portable: `$env:AHK_V2` con fallback a `$env:LOCALAPPDATA\...`,
    `C:\Program Files\...`, y el path original como último recurso.
    Razón: prerequisito para senior review — el runner no podía ejecutarse en ninguna
    máquina distinta a la del autor original.

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados: (no aplica — runner.ps1 no contiene handlers M720)

### Fase 2 — comentarios
- [ ] Auditado
- Cambios aplicados:

### Fase 3 — dead code
- [ ] Auditado
- Borrados (0 referencias en producción + tests):
- Candidatos para review senior (NO borrados):

## Ideas de simplificación pendientes (input para plan posterior)

- El bloque de clasificación CRASH/FAIL/PASS podría extraerse a una función
  `Invoke-AhkTest` que devuelva un objeto con propiedades `Passed`, `Asserts`,
  `Failures`, `CrashReason` — haría el loop principal más legible y facilitaría
  agregar modos (ej: `--filter Test_Cleaners`).
- La lógica de discovery de AHK (`$env:AHK_V2` + fallbacks) es candidata a
  extraerse a un snippet compartido si otros scripts PS del repo necesitan AHK
  en el futuro (hoy es el único).
- El formato de salida coloreado (`Write-Host` con `-ForegroundColor`) podría
  separarse de la lógica de evaluación para facilitar un modo `--quiet` o
  `--json` sin duplicar la lógica de PASS/FAIL.
