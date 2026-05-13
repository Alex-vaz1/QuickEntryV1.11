# Cómo agregar una empresa nueva a QuickEntry

Esta guía te lleva paso a paso por el proceso de adaptar QuickEntry a un formulario distinto (otra empresa, otro tipo de factura, otra sección del sistema).

> Pre-requisito: leé primero la sección "Por qué los Schemas son el corazón del sistema" en [GUIA_TECNICA.md](GUIA_TECNICA.md). Vas a editar un schema; conviene saber qué es.

---

## El concepto en una frase

Toda la lógica específica de un formulario vive en **un único archivo declarativo** dentro de `Schemas/`. El motor (`CaptureEngine`, `TooltipFormatter`) no sabe ni le importa qué empresa es. Cambiar de empresa = escribir un archivo nuevo.

---

## Paso 1: Copiar la plantilla

```bash
copy Schemas\_Plantilla_NuevaEmpresa.ahk Schemas\<NombreEmpresa>HeaderV1.ahk
```

Por convención: `<NombreEmpresa>HeaderV1.ahk` (ej. `EmpresaXHeaderV1.ahk`). El `V1` te deja espacio para versionar si el formulario cambia más adelante.

## Paso 2: Renombrar la función constructora

Dentro del archivo, vas a ver:
```ahk
CrearMiEmpresaHeaderV1()
{
    fields := [ ... ]
    return InvoiceSchema("MiEmpresa Header v1", fields)
}
```

Renombrá la función y el `name` del schema:
```ahk
CrearEmpresaXHeaderV1()
{
    fields := [ ... ]
    return InvoiceSchema("EmpresaX Header v1", fields)
}
```

## Paso 3: Editar la lista `fields`

Cada fila de la lista es un `Campo(...)`. Acomodalas según el formulario destino, **en el orden exacto en que aparecen los inputs en el form**.

```ahk
fields := [
    ; #  name              clean                validate                  tabs  skipPaste  expectedFn   expectedDeps
    Campo("Folio",          CleanPasoPegado,    ValidarNoVacio,           1,    false),
    Campo("Cliente",        CleanRaw,           ValidarNoVacio,           1,    true),    ; lupa
    Campo("Fecha",          CleanPasoPegado,    ValidarFechaEstricta,     2,    false),   ; campo doble
    Campo("Subtotal",       CleanPasoPegado,    ValidarNumero,            1,    false),
    Campo("IVA",            CleanPasoPegado,    ValidarNumero,            1,    false),
    Campo("Total",          CleanPasoPegado,    ValidarSumaTol([4, 5]),   1,    false,
          (cola) => EsperadoSuma([4, 5], cola), [4, 5])  ; muestra breakdown en tooltip
]
```

### Reglas prácticas para cada columna

| Columna | Qué poner |
|---|---|
| `name` | Lo que verás en el tooltip y en los errores. Coincidí con el label del formulario para que el operador no se confunda. |
| `clean` | `LimpiarComoPegadoEspecial` por default (maneja fechas, precios y texto). Para texto puro (nombres, IDs alfanuméricos) usá un passthrough como `CleanRaw`. Si necesitás algo nuevo, agregalo a `Lib/Cleaners.ahk`. |
| `validate` | Elegí del catálogo (`ValidarNoVacio`, `ValidarNumero`, `ValidarFechaEstricta`, `ValidarSumaTol(...)`) o escribí uno nuevo en `Lib/Validators.ahk`. |
| `tabsAfter` | Contá los Tabs entre el campo actual y el siguiente cuando navegás el form a mano. Lo más común es `1`. Si entre dos inputs hay un read-only o un control extra, usá `2`. |
| `skipPaste` | `true` solo si el campo es de tipo lupa/búsqueda donde el operador hace click manual sobre el resultado. El motor manda los Tabs pero no pega valor. |
| `expectedFn` y `expectedDeps` | Solo si el campo es derivado (suma de otros). **Van siempre juntos.** Sin `expectedDeps` el cálculo funciona pero perdés el breakdown visual en el tooltip. |

### `ordenPegado` y `prePasteSteps` (en el `InvoiceSchema(...)`)

| Param | Cuándo usarlo |
|---|---|
| `ordenPegado: Array<Integer>` | Si el form tiene los inputs en distinto orden que el orden de lectura del operador. Default `[1..N]`. Ejemplo Asignet: el operador copia 9 campos en orden aritmético (Past due después de Previous balance + Past payments para validar la suma) pero el form los muestra como `[1, 2, 3, 4, 7, 5, 6, 8, 9]`. |
| `prePasteSteps: Array<String>` | Pasos `SendInput` a ejecutar ANTES del primer paste (form vacío). Útil para navegar desde el tope de la página hasta el primer input, abrir un dropdown de tipo de factura, etc. Cada string es una directiva (`"{Tab 13}"`, `"{Enter}"`, `"{Up}"`, `"Texto literal"`). 150ms entre pasos. |
| `preScanSteps: Array<String>` | Pasos de navegación para HeaderScan (form ya lleno). Si vacío, usa `prePasteSteps`. **Necesario cuando el form lleno tiene distinto tab-order que el vacío** — por ejemplo, campos readonly que no son tab stops cuando tienen valor. |

**Ejemplo Asignet** (declarado en `Schemas/AsignetHeaderV1.ahk`):
```ahk
ordenPegado := [1, 2, 3, 4, 7, 5, 6, 8, 9]

; Form vacío: "Type of Document" es tab stop, hay que escribir "Invoice"
prePasteSteps := [
    "{Tab 13}",   ; baja desde el tope al dropdown de tipo
    "{Enter}",    ; abre el dropdown
    "{Up 2}",     ; sube 2 (asegura tope)
    "{Down}",     ; baja a "Invoice"
    "{Enter}",    ; selecciona
    "{Tab}",      ; al input de tipo (text)
    "Invoice",    ; escribe el tipo
    "{Tab}"       ; al input de Account number, listo para slot 1
]

; Form lleno: "Type of Document" es readonly (no es tab stop),
; asi que {Tab} tras el dropdown va directo a Account #
preScanSteps := [
    "{Tab 13}",
    "{Enter}",
    "{Up 2}",
    "{Down}",
    "{Enter}",
    "{Tab}",
    "{Tab}"
]

return InvoiceSchema("Asignet Header v1", fields, ordenPegado, prePasteSteps, preScanSteps)
```

### Ejemplos de cleaners locales que ya tiene la plantilla

```ahk
PlantCleanRaw(raw) => raw                                ; passthrough
PlantCleanPaso(raw) => LimpiarComoPegadoEspecial(raw)    ; default
PlantCleanForzarNeg(raw)                                 ; para campos siempre negativos (egresos)
{
    limpio := LimpiarComoPegadoEspecial(raw)
    return (limpio = "") ? "" : ForzarNegativo(limpio)
}
```

Renombrálos con prefijo de tu empresa si vas a tener múltiples schemas conviviendo, para evitar choques de nombres.

### Helpers de "esperado" (opcional)

Si tu formulario tiene campos calculados, copiá el helper `EsperadoSuma` de `AsignetHeaderV1.ahk` y creá funciones por cada campo derivado:

```ahk
ExpectedSlotTotal(cola) => EsperadoSuma([4, 5], cola)  ; Total = Subtotal + IVA
```

## Paso 4: Cambiar el entry point

En `QuickEntry.ahk`, dos líneas a tocar:

```ahk
#Include "Schemas\AsignetHeaderV1.ahk"
; ...
global engine := CaptureEngine(CrearAsignetHeaderV1(), AUTO_CALCULAR_TOTALES_OMITIDOS)
```

Cambialas a:
```ahk
#Include "Schemas\EmpresaXHeaderV1.ahk"
; ...
global engine := CaptureEngine(CrearEmpresaXHeaderV1(), AUTO_CALCULAR_TOTALES_OMITIDOS)
```

> Si vas a soportar varias empresas en simultáneo, hablalo: hay opciones (selector con hotkey, perfil por usuario, scripts separados) y cada una tiene tradeoffs.

## Paso 5: Crear el test del schema

Copiá `Tests/Test_AsignetHeader.ahk` a `Tests/Test_EmpresaXHeader.ahk` y adaptá los asserts:

```ahk
; ====================================================================
; Tests del schema EmpresaXHeaderV1
; ====================================================================

#Include "..\Lib\Schema.ahk"
#Include "..\Schemas\EmpresaXHeaderV1.ahk"
#Include "_AssertHelpers.ahk"

schema := CrearEmpresaXHeaderV1()

; Estructura
AssertEq(schema.Length, 6, "schema tiene 6 campos")
AssertEq(schema.Field(1).name, "Folio", "slot 1 = Folio")
; ... más asserts por cada campo ...

; Limpieza por slot
AssertEq(schema.Field(3).clean.Call("15-09-2026"), "09/15/2026", "Fecha clean")
; ...

; Validaciones
AssertEq(schema.Field(2).validate.Call("", []), "valor vacio", "Cliente no vacío rechaza vacío")
AssertEq(schema.Field(6).validate.Call("150.00", ["", "", "", "100.00", "50.00", ""]),
         "", "Total OK con suma exacta")
; ...

ReportarYSalir()
```

> El runner `Tests/runner.ps1` levanta automáticamente cualquier `Test_*.ahk` nuevo. No hace falta registrarlo.

## Paso 6: Correr la suite

```powershell
powershell -ExecutionPolicy Bypass -File Tests\runner.ps1
```

Esperás algo como:
```
PASS  Test_AsignetHeader.ahk           === 107 tests, 0 failures ===
PASS  Test_EmpresaXHeader.ahk          === 50 tests, 0 failures ===
PASS  Test_CaptureEngine.ahk           === 73 tests, 0 failures ===
...
ALL TESTS PASSED
```

Si algo falla, el runner te dice qué archivo y qué assert.

## Paso 7: Registrar el schema en QuickEntry.ahk

Abrí `QuickEntry.ahk`. Agregá el `#Include` del nuevo schema arriba (junto con los otros Includes):

```ahk
#Include "Schemas\EmpresaXHeaderV1.ahk"
```

Después localizá el bloque `global SCHEMA_REGISTRY := Map(...)` y agregá una entrada:

```ahk
global SCHEMA_REGISTRY := Map(
    "AsignetHeaderV1", CrearAsignetHeaderV1,
    "EmpresaXHeaderV1", CrearEmpresaXHeaderV1  ; ← tu empresa nueva
)
```

## Paso 8: Activar el schema en config.ini

El operador elige qué schema usar editando `%APPDATA%\QuickEntry\config.ini` (creá el archivo si no existe):

```ini
[General]
Schema=EmpresaXHeaderV1
```

Sin INI o con un nombre desconocido, QuickEntry usa `AsignetHeaderV1` por default y muestra un MsgBox de advertencia + escribe `WARN schema_unknown` al `events.log`.

## Paso 9: Probar end-to-end

1. Cargá `QuickEntry.ahk` (doble-click o `AutoHotkey64.exe QuickEntry.ahk`).
2. Verificá que el title del HUD diga `QuickEntry — CAPTURA ACTIVA (Ctrl+C guarda al slot)`.
3. Abrí el formulario en el navegador.
4. `Ctrl+Shift+A` → el HUD muestra `Busca "Folio" (1/6)`.
5. Copiá los campos de prueba en orden, verificá que el HUD avance bien.
6. Click en el primer input del form → `Ctrl+Shift+S` → verificá que pegue todo en orden con los Tabs correctos.

Si los Tabs caen en el lugar incorrecto, ajustá el `tabsAfter` del campo problemático y volvé a probar.

---

## Casos especiales

### Campo que siempre es egreso (negativo forzado)

```ahk
Campo("Descuento",  PlantCleanForzarNeg, ValidarNumero, 1, false),
```

`PlantCleanForzarNeg` ya está en la plantilla — toma cualquier número y le antepone `-` si es positivo.

### Campo de lupa con dropdown

Pegás el texto como filtro pero el operador hace click manual sobre el resultado:

```ahk
Campo("Cliente", CleanRaw, ValidarNoVacio, 1, false),
```

> `skipPaste=false` acá significa que **sí** se pega el texto (el filtro de la lupa lo necesita). Si tu lupa no acepta paste y el operador escribe a mano siempre, usá `skipPaste=true`.

### Campo derivado con tolerancia más laxa

`ValidarSumaTol(slotsIndices, tol := 0.01)` toma una tolerancia opcional. Si tu sistema redondea fuerte:

```ahk
Campo("Total", CleanPasoPegado, ValidarSumaTol([4, 5], 1.00), 1, false,
      (cola) => EsperadoSuma([4, 5], cola), [4, 5]),
```

### Validar sumas restando (no solo sumando)

`ValidarSumaTol` suma. Si necesitás `Total = Bruto - Descuento`, el truco es que el cleaner del descuento ya devuelve negativo (`ForzarNegativo`), así que sumar `Bruto + Descuento_negativo` da `Bruto - Descuento`. Ver cómo `Past payments` se trata en `AsignetHeaderV1.ahk`.

### Múltiples versiones del mismo formulario

Si la empresa cambia el formulario y querés mantener compatibilidad:
- Creá `Schemas/EmpresaXHeaderV2.ahk` (no toques V1).
- Ofrecé un selector en `QuickEntry.ahk` (constante en el header, hotkey, etc.).

---

## Errores comunes al crear schemas

| Síntoma | Causa | Fix |
|---|---|---|
| El test del schema crashea con `slot fuera de rango` | `expectedDeps` o `ValidarSumaTol` apuntan a un slot que no existe | Verificá los índices (1-based, máximo = `schema.Length`). |
| Reordenaste campos y las validaciones dan error | Los índices en `expectedDeps`/`ValidarSumaTol` no se reordenaron solos | Actualizá manualmente los índices. |
| El tooltip dice "esperado: " pero el cálculo está vacío | El `expectedFn` retorna `""` cuando algún slot dependiente todavía no se cargó | Es esperado — el esperado solo se muestra cuando todos los operandos están en la cola. |
| El paste deja un Tab de más al final | Estás contando `tabsAfter` del último slot | Se ignora; no es bug. Si necesitás un Tab final (para mover foco al botón Submit, ej.) se hace de otra forma — pedí ayuda. |
| El batch pega bien pero un campo de lupa queda con texto basura | Pusiste `skipPaste=false` cuando debería ser `true` (el form necesita click manual) | Cambialo a `skipPaste=true`. |
| Los nombres de los campos chocan entre dos schemas | Usaste prefijos genéricos | Renombrá los cleaners locales con prefijo de la empresa (`EmpresaXCleanPaso` en vez de `PlantCleanPaso`). |

---

## Ayuda

- Estructura del contrato `Campo`: ver [GUIA_TECNICA.md § Lib/Schema.ahk](GUIA_TECNICA.md).
- Catálogo de cleaners y validators: `Lib/Cleaners.ahk`, `Lib/Validators.ahk`.
- Cómo testea el motor sin runtime AHK real: ver `Tests/Test_CaptureEngine.ahk` (mock schemas con cleaners/validators inyectados).
