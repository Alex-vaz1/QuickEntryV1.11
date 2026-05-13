---
file: Lib/AutoCalculator.ahk
last_review: 2026-05-12
status: active
---

# `Lib/AutoCalculator.ahk`

## Propósito

GUI popup flotante que parsea números tipeados o pegados por el usuario, los normaliza con `NormalizarPrecio()` y muestra la suma en tiempo real. Se activa desde `MainHud` como calculadora auxiliar para verificar subtotales antes de confirmar un header. Implementa single-instance: si ya hay una ventana abierta, la trae al frente en lugar de crear una nueva.

## API pública

### Clases

- **`AutoCalculator()`** — calculadora numérica GUI de suma acumulada, single-instance
  - **Propiedades**:
    - `gui` — handle de la instancia `Gui`; `""` antes de la primera llamada a `Build()`
    - `inputEdit` — control `Edit` multilinea donde el usuario pega/tipea números
    - `resultsCtrl` — control `Edit` de solo-lectura (editable) con los números normalizados, uno por línea
    - `totalCtrl` — control `Text` que muestra el total formateado con 2 decimales
    - `suppressResultsChange` — flag booleano para suprimir el handler `OnResultsEdited` mientras `Recalculate()` escribe `resultsCtrl`
  - **Métodos**:
    - `Show() → void` — muestra la ventana; si ya existe y está visible la trae al frente, de lo contrario llama a `Build()`
      - Llamado desde: `Lib/MainHud.ahk:935` (dentro de `OnAutoCalc`, instancia lazy)
      - Llama a: `WinExist()`, `this.gui.Show()`, `this.inputEdit.Focus()`, `this.Build()`
    - `Build() → void` — crea los controles GUI, registra eventos, llama a `g.Show("AutoSize")`; almacena handles en las propiedades de la clase
      - Llamado desde: `this.Show()`
      - Llama a: `Gui()`, `g.Add()`, `g.SetFont()`, `g.BackColor`, `g.MarginX/Y`, `g.OnEvent()`, `.OnEvent("Change", ...)`, `.SetFont()`, `g.Show()`
    - `Recalculate() → void` — lee `inputEdit.Value`, extrae tokens con `ExtractNumberTokens()`, normaliza cada uno con `NormalizarPrecio()`, acumula la suma y escribe `resultsCtrl` y `totalCtrl`; usa `suppressResultsChange` + `SetTimer` para evitar re-entradas
      - Llamado desde: handler `Change` de `inputEdit` (registrado en `Build()`)
      - Llama a: `this.ExtractNumberTokens()`, `NormalizarPrecio()`, `Number()`, `Format()`, `SetTimer()`
    - `OnResultsEdited() → void` — recalcula el total leyendo las líneas de `resultsCtrl` directamente; tolera texto suelto en la línea tomando solo el primer token numérico; no opera si `suppressResultsChange` es verdadero
      - Llamado desde: handler `Change` de `resultsCtrl` (registrado en `Build()`)
      - Llama a: `StrSplit()`, `this.ExtractNumberTokens()`, `NormalizarPrecio()`, `Number()`, `Format()`
    - `Clear() → void` — vacía `inputEdit`, `resultsCtrl` y resetea `totalCtrl` a `"0.00"`; devuelve el foco a `inputEdit`
      - Llamado desde: botón "Clear" vía handler `Click` en `Build()`
      - Llama a: (solo acceso a propiedades de controles AHK)
    - `CopyTotal() → void` — copia `totalCtrl.Value` al portapapeles y muestra un `ToolTip` auto-descartable a 1500 ms
      - Llamado desde: botón "Copy Total" vía handler `Click` en `Build()`
      - Llama a: `A_Clipboard`, `ToolTip()`, `SetTimer()`
    - `Hide() → void` — oculta la ventana sin destruirla; preserva el estado para la próxima apertura
      - Llamado desde: botón "Cerrar", eventos `Close` y `Escape` de la GUI (registrados en `Build()`)
      - Llama a: `this.gui.Hide()`
    - `ExtractNumberTokens(text) → Array` — aplica un regex de dos ramas en alternación sobre `text` y retorna todos los tokens numéricos encontrados como array de strings recortados
      - Llamado desde: `this.Recalculate()`, `this.OnResultsEdited()`
      - Llama a: `RegExMatch()`, `StrLen()`, `Trim()`

### Funciones libres

Ninguna. Toda la lógica está encapsulada en la clase `AutoCalculator`.

## Dependencias

- **#Include directos**: `Cleaners.ahk` (línea 2; importa `NormalizarPrecio()`)
- **Incluido por**: `Lib/MainHud.ahk` (línea 5: `#Include "AutoCalculator.ahk"`)
- **Globales que define**:
  - `AUTOCALC_BG := "F8FAFC"` — color de fondo de la ventana (light theme, alineado con MainHud)
  - `AUTOCALC_FG_LABEL := "1F2937"` — color de texto principal para labels
  - `AUTOCALC_FG_DIM := "9CA3AF"` — color de texto secundario / instrucciones
  - `AUTOCALC_FG_NUMBER := "1E40AF"` — color Asignet blue para la lista de números reconocidos
  - `AUTOCALC_FG_TOTAL := "15803D"` — color verde para el total
  - `AUTOCALC_FONT_VALUE := "Cascadia Mono"` — fuente para valores numéricos
  - `AUTOCALC_FONT_LABEL := "Segoe UI"` — fuente para labels
- **Globales que usa (leídas)**:
  - `AUTOCALC_BG` (definida en este mismo archivo, línea 13)
  - `AUTOCALC_FG_LABEL` (líneas 47, 53, 61, 74)
  - `AUTOCALC_FG_DIM` (líneas 57, 66)
  - `AUTOCALC_FG_NUMBER` (línea 69)
  - `AUTOCALC_FG_TOTAL` (línea 77)
  - `AUTOCALC_FONT_VALUE` (líneas 61, 69, 77)
  - `AUTOCALC_FONT_LABEL` (líneas 47, 53, 57, 66, 74)
- **Símbolos externos invocados**:
  - `NormalizarPrecio(token)` (de `Lib/Cleaners.ahk`) — normaliza cada token a string numérico limpio o `""`

## Notas técnicas (WHY no-obvio)

- **`suppressResultsChange` + `SetTimer(-50)`**: cuando `Recalculate()` escribe en `resultsCtrl`, AHK dispara el evento `Change` de ese control, lo que invocaría `OnResultsEdited()` y re-ejecutaría el cálculo sobre los mismos datos. El flag previene la re-entrada; el timer a -50 ms lo baja en el siguiente tick del message loop en lugar de inmediatamente, garantizando que la escritura al control haya terminado antes de que el flag vuelva a `false`.

- **`ExtractNumberTokens` — alternación en el regex**: el patrón `i)\$?-?(?:[\d,]+\.\d{2}|\d[\d.,]*)(?:\s*CR)?` tiene dos ramas. La rama izquierda (`[\d,]+\.\d{2}`) es **estricta con exactamente 2 decimales** y tiene prioridad; esto permite desambiguar texto OCR concatenado del tipo `"12.3456.789.00"` en tres tokens (`12.34`, `56.78`, `9.00`) en vez de capturarlo como un único token malformado. Sin la prioridad de rama la regex general `\d[\d.,]*` capturaría el string completo y `NormalizarPrecio` no podría recuperarlo.

- **`OnResultsEdited` toma solo el primer token de cada línea**: el usuario puede anotar texto junto a un número en `resultsCtrl` (ej.: `"9   <- 9 de abril"`). El diseño deliberado es tolerante: solo se toma `tokens[1]` por línea, permitiendo que el usuario borre o corrija números del OCR directamente en la lista sin tener que volver al input original.

- **Single-instance via `WinExist("ahk_id ...")`**: no se usa un `Mutex` ni un objeto global externo. La condición `IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)` es suficiente porque `AutoCalculator` se instancia una sola vez en `MainHud.OnAutoCalc` (variable local que es reutilizada entre invocaciones gracias al closure de AHK v2). Si la instancia fuera recreada en cada llamada el `IsObject` fallaría y se crearía una ventana nueva.

- **`-DPIScale` en `Gui()`**: se desactiva el escalado DPI de AHK para que las posiciones absolutas de los controles (px hardcoded en `Build()`) sean reproducibles en monitores de alta densidad. Sin esta flag el layout se desacomoda en pantallas 4K o con Windows DPI > 100%.

- **Paleta alineada con MainHud**: las constantes `AUTOCALC_*` replican los mismos valores hexadecimales que `MAINHUD_*` para mantener coherencia visual sin importar `MainHud.ahk` (que no es `#Include`-ado aquí).

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - `Lib/AutoCalculator.ahk:51` — borrado: `; --- Header ---` — razón: banner decorativo puro; el bloque `g.Add("Text", ...)` que le sigue lo hace evidente
  - `Lib/AutoCalculator.ahk:59` — borrado: `; --- Input multilinea ---` — razón: banner decorativo; `+Multi +WantReturn` en la llamada siguiente ya lo dice
  - `Lib/AutoCalculator.ahk:64` — borrado: `; --- Resultado: lista de numeros parseados ---` — razón: banner redundante con el label `resultsLbl` que aparece inmediatamente
  - `Lib/AutoCalculator.ahk:72` — borrado: `; --- Total ---` — razón: banner decorativo, el nombre del control y del label son suficientes
  - `Lib/AutoCalculator.ahk:79` — borrado: `; --- Botones ---` — razón: banner decorativo; los tres `g.Add("Button", ...)` siguientes son autoexplicativos
  - `Lib/AutoCalculator.ahk:116` — borrado: `; Render results (suprimir OnResultsEdited durante la escritura)` — razón: "Render results" es QUÉ puro; el WHY del suppress ya está documentado en la sección Notas técnicas del .md
  - `Lib/AutoCalculator.ahk:129` — borrado: `; Render total` — razón: QUÉ puro; la asignación `this.totalCtrl.Value := Format(...)` lo dice por sí sola

### Fase 3 — dead code
- [x] Auditado 2026-05-12

#### Resumen de clasificación (14 símbolos auditados)

| Símbolo | Tipo | Clasificación | Refs externas |
|---|---|---|---|
| `AUTOCALC_BG` | global | USADO | leída en línea 45 (Build) |
| `AUTOCALC_FG_LABEL` | global | USADO | leída en líneas 46, 51, 55, 62, 69 |
| `AUTOCALC_FG_DIM` | global | USADO | leída en líneas 55, 62 |
| `AUTOCALC_FG_NUMBER` | global | USADO | leída en línea 65 |
| `AUTOCALC_FG_TOTAL` | global | USADO | leída en línea 72 |
| `AUTOCALC_FONT_VALUE` | global | USADO | leída en líneas 58, 65, 72 |
| `AUTOCALC_FONT_LABEL` | global | USADO | leída en líneas 46, 51, 55, 62, 69 |
| `AutoCalculator` (clase) | class | USADO | instanciada en `Lib/MainHud.ahk:859` |
| `Show()` | método | USADO | llamado desde `Lib/MainHud.ahk:860` |
| `Build()` | método | USADO | llamado desde `Show()` |
| `Recalculate()` | método | USADO | handler Change de `inputEdit` (registrado en Build) |
| `OnResultsEdited()` | método | USADO | handler Change de `resultsCtrl` (registrado en Build) |
| `Clear()` | método | USADO | handler Click de btnClear (registrado en Build) |
| `CopyTotal()` | método | USADO | handler Click de btnCopy (registrado en Build) |
| `Hide()` | método | USADO | handler Click de btnClose + eventos Close/Escape (Build) |
| `ExtractNumberTokens()` | método | USADO | llamado desde `Recalculate()` y `OnResultsEdited()` |
| `suppressResultsChange` | propiedad | USADO | leída/escrita en `Recalculate()` y `OnResultsEdited()` |

#### AUTOCALC_FG_INVALID — CONFIRMADO AUSENTE

Grep cruzado en todos los `.ahk` del repo: **0 ocurrencias**. La global no existe en el archivo fuente actual — no fue introducida en el commit (o fue eliminada antes de la auditoría formal). Solo aparecía referenciada en docs `.md`.

- Acción: retirada la entrada de "Globales que define" en este `.md` y eliminadas las tres referencias en `docs/files/INDEX.md` (tabla Globals línea 108, nota línea 131, nota "Inconsistencias" línea 217).

#### Borrados del archivo fuente (0)

Ninguno. El archivo ya estaba limpio: `AUTOCALC_FG_INVALID` no figuraba en el `.ahk` al momento de la auditoría.

#### Candidatos DUDOSOS para review senior (0)

Sin candidatos. Todos los símbolos presentes en el archivo fuente tienen al menos un lector confirmado por grep.

### Fase 5 — polish

- [x] Auditado 2026-05-12
- Cambios aplicados: ninguno. El archivo ya cumplía todos los criterios: sin trailing whitespace, sin secuencias de 3+ líneas en blanco, indentación consistente a 4 espacios, y un único LF final. 0 cambios al fuente.

## Ideas de simplificación pendientes (input para plan posterior)

- Las constantes de paleta `AUTOCALC_*` podrían consolidarse en un módulo de tema compartido con `MainHud`, eliminando la duplicación con `MAINHUD_*` (hoy tienen los mismos valores hexadecimales).
- `ExtractNumberTokens` es una función pura sin dependencias de estado; podría moverse a `Lib/Cleaners.ahk` junto a `NormalizarPrecio` para centralizar toda la lógica de parsing numérico en un solo módulo.
- El layout de `Build()` usa coordenadas absolutas px. Parametrizar márgenes/anchos como constantes locales (`W_CTRL := 400`, `X_MARGIN := 16`) reduciría la deuda si el layout necesita ajustarse.
