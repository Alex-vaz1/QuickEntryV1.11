# Manual de Usuario — Asignet QuickEntry

Guía rápida para cargar headers de facturas en Asignet usando QuickEntry.

---

## Qué es QuickEntry

QuickEntry es una herramienta interna que automatiza la carga del **header de cada factura** en el sistema Asignet. En vez de copiar y pegar 9 campos uno por uno, vos copiás los 9 valores en orden mientras revisás la factura, y un solo hotkey los pega todos juntos en el formulario.

**Beneficios concretos:**
- ~46% menos tiempo por factura (~100s → ~54s).
- ~93% menos clicks/acciones de mouse sobre el formulario.
- Las **validaciones aritméticas** (Past due = Previous balance + Past payments, etc.) se chequean **antes** de pegar — los errores aparecen en captura, no después de submit.
- Los mensajes de error usan el **nombre del campo** (ej: `Past due inválido: suma debe ser 500.00`), no números.

---

## Antes de empezar

1. Tener **AutoHotkey v2** instalado.
2. Tener `QuickEntry.ahk` corriendo. Doble-click sobre el archivo o:
   ```
   AutoHotkey64.exe QuickEntry.ahk
   ```
   Vas a ver el ícono de AHK (un H verde) en la bandeja del sistema. Eso significa que las hotkeys están activas.

3. Tener el **OCR de la factura** disponible (la app interna ya lo provee).

---

## Hotkeys

| Tecla | Qué hace |
|---|---|
| `Ctrl+Shift+A` | **Armar captura.** Resetea la cola y empieza a escuchar copys. Si ya está armado: **omite el slot actual**. |
| `Ctrl+Shift+H` | **HeaderScan.** Lee los campos del formulario ya cargado (Ctrl+A / Ctrl+C en cada input) y pre-popula la cola. Los campos ya leídos se saltean al pegar. |
| `Ctrl+Shift+S` | **Soltar (paste batch).** Pega los 9 valores en orden, con Tab entre cada uno. |
| `Ctrl+Shift+R` | **Reset.** Cancela la captura sin pegar nada. |
| `Ctrl+Shift+U` | **Undo.** Descarta el último valor cargado. |
| `Ctrl+Shift+E` | **Entrada manual.** Abre una ventanita para tipear el slot actual sin copiar. |
| `Ctrl+Shift+V` | **Pegado especial.** Pega el contenido del clipboard limpiándolo (fechas, precios). Funciona fuera de captura. |

> ¿Querés cambiar las teclas? Mirá [PERSONALIZACION_HOTKEYS.md](PERSONALIZACION_HOTKEYS.md).

---

## Flujo de trabajo paso a paso

### 1. Posicionate
Abrí el formulario de carga de factura en Asignet (en el navegador). Tené la factura/OCR a la vista en la otra mitad de la pantalla o en otro monitor.

### 2. Armá la captura
Cuando arrancás QuickEntry, **el HUD principal queda al frente** (light theme, esquina configurable). El HUD ya está **armado para capturar** desde el primer copy — no necesitás disparar nada. La primera fila te dice qué campo viene primero:

```
Busca "Account number" (1/9)
```

`Ctrl+Shift+A` cumple **tres roles** según el estado:
- **HUD oculto o minimizado** → lo restaura al frente (sin tocar la cola).
- **Captura activa con slot pendiente** → **omite** el slot actual (push `""` o autocalc).
- **Captura no activa** (después de Reset) → re-arma + muestra el HUD.

### 3. Copiá los 9 campos en orden
Mirá la factura, copiá (Ctrl+C) cada valor en el orden que pide el tooltip. Después de cada copy, el tooltip avanza y muestra dos líneas:

- **Línea 1:** próximo campo a buscar (`Busca "X" (x/n)` donde `x` = cantidad de slots **llenos**, no el slot actual).
- **Línea 2:** lo que acabás de cargar, con marca visual: `▶ ACC-12345 ◀ (Account number)` — valor primero, nombre del campo entre paréntesis.

Para los campos calculados (Past due, Invoice Total Including PastDue), el tooltip muestra el **valor esperado** y los **operandos** que lo componen, así verificás antes de copiar:
```
Busca "Past due" (6/9) - esperado: 500.00
Previous balance: 1000.00
Past Total Payments: -500.00
```

> **Autocalc activado por default:** si omitís Past due o Invoice Total con `Ctrl+Shift+A`, QuickEntry les pone la suma calculada en vez de dejarlos vacíos. Mirá el `esperado: X.XX` antes de omitir y verificá que coincide con la factura.

### 4. Cuando algo sale mal

| Situación | Solución |
|---|---|
| Copiaste algo que no es lo que querías | `Ctrl+Shift+U` deshace el último valor. El cursor vuelve a ese slot. |
| Quisiste copiar pero el OCR falló (texto basura) | Tooltip dice `Input inválido, recopia o Ctrl+Shift+A para omitir`. Recopiás el correcto, o presionás `Ctrl+Shift+A` para dejar el slot vacío y seguir. |
| El valor existe pero el OCR lo lee mal y no podés corregirlo desde la fuente | `Ctrl+Shift+E` abre **inline edit** sobre la fila del slot actual del HUD. Tipeás el valor + Enter (commit) o Esc (cancelar). Si el valor no valida, el Edit queda abierto en rojo; Enter de nuevo sin cambiar valor abre `¿Forzar igual?` (Yes = `PushForce` sin validar). |
| Querés volver a un slot que omitiste o cargar uno fuera de orden | **Click en el nombre del slot** (columna izquierda) en el HUD → cursor salta a ese slot. Próximo copy lo llena. Si querés editar el valor directamente, **click en la columna VALOR** → abre inline edit ahí. |
| Querés editar un slot ya lleno | **Click en la columna VALOR** del slot lleno → inline edit con el valor precargado. Enter commit, Esc cancel. Si el slot estaba preloaded (por HeaderScan), el commit hace `PushForce` (bypass del cleaner). |
| La validación aritmética falla (ej. Past due no suma) | Tooltip muestra `Past due inválido: suma debe ser 500.00`. Revisás en la factura cuál de los slots previos está mal, hacés Undo o usás el picker para volver a ese slot, recorregís. |
| Cancelar todo y empezar de cero | `Ctrl+Shift+R`. |
| Querés cerrar el HUD sin cerrar QuickEntry | El botón **×** de la ventana solo **oculta** el HUD; el script sigue corriendo con los hotkeys activos. Para restaurarlo: `Ctrl+Shift+A` (o cualquier nuevo `Ctrl+C` con captura activa). Para cerrar QuickEntry completo, hay que cerrarlo desde la bandeja del sistema (System Tray, ícono verde de AHK → click derecho → Exit). |

### 5. Pegar en el formulario
Cuando el tooltip diga `Listo 9/9 - cola llena - Ctrl+Shift+S para pegar, Ctrl+Shift+E para revisar`:
1. Hacé click en el primer input del formulario (Account number).
2. Apretá **`Ctrl+Shift+S`**.
3. QuickEntry pega los 9 campos en orden, con Tab entre cada uno.

> **Campos con lupa (Account number, Corp name):** después del paste, el sistema los muestra como filtros de búsqueda. Hacé click manual en el resultado correcto antes de continuar (eso ya lo hacías antes; QuickEntry no cambia esa parte).

### 5.1. Modo captura continua (auto-rearm)

QuickEntry corre en **modo captura continua** por default: después de `Ctrl+Shift+S` (paste batch), el engine se rearma automáticamente y queda listo para la próxima factura **sin que tengas que volver a armar**. El flujo es:

1. Copiás los 9 campos de la factura A.
2. `Ctrl+Shift+S` → pega los 9 valores en el form.
3. Acomodás los campos con lupa, hacés submit en el form de Asignet.
4. **Sin tocar QuickEntry**, copiás los 9 campos de la factura B. El HUD ya está armado, los acepta directamente.
5. `Ctrl+Shift+S` de nuevo, y así para cada factura.

**Cuándo necesitás pausar la captura**:
- Vas a copiar algo no relacionado con la factura (URL, email, número de tracking).
- Apretá `Ctrl+Shift+R` (reset). El engine pausa hasta el próximo `Ctrl+Shift+A`.

> **Importante:** mientras la captura esté activa, cualquier `Ctrl+C` que hagas se intentará pushear al slot actual. Si el cleaner lo rechaza (input inválido), aparece tooltip de error y la cola no avanza — pero el operador nuevo se puede confundir. Si vas a copiar texto que no es del header de la factura, **pausá con `Ctrl+Shift+R`** primero.

### Alternativa: HeaderScan (leer un formulario ya cargado)

Si el formulario ya tiene datos (por ejemplo, para verificar o corregir una factura existente):

1. Posicioná el cursor al **tope de la página** (mismo punto de partida que para pegar).
2. Apretá **`Ctrl+Shift+H`**.
3. QuickEntry navega el formulario campo por campo, lee cada valor con Ctrl+A / Ctrl+C, y los carga en la cola.
4. Los campos que ya tenían valor quedan marcados como **preloaded** — al pegar con `Ctrl+Shift+S`, esos campos se saltean (solo se mandan los Tabs, sin re-pegar).
5. El tooltip muestra el primer campo vacío para que completes lo que falte.

> **Tip:** después del scan, podés corregir cualquier slot con el picker (`Ctrl+Shift+E`) o con Undo (`Ctrl+Shift+U`). Si editás un slot preloaded, deja de ser preloaded y se pegará normalmente.

### 6. Repetí

Para la siguiente factura, simplemente volvé al paso 2 (`Ctrl+Shift+A`).

---

## Mejores prácticas

- **Copiá en el orden del formulario.** Los campos los podés saltear con `Ctrl+Shift+A` (omitir) o `Ctrl+Shift+E` (picker para elegir slot exacto). Si saltaste algunos, después podés volver con el picker — al llenarlos, el cursor auto-avanza al **próximo slot vacío**, no al siguiente sequential.
- **Revisá la línea 2 del tooltip.** Las flechas `▶ ◀` rodean el valor (`▶ ACC-1234 ◀ (Account number)`) para que tu ojo confirme que lo último que copiaste tiene sentido. Si ves algo raro, `Ctrl+Shift+U` y recopiá.
- **Confiá en las validaciones aritméticas.** Si Past due no suma, el sistema te lo va a marcar antes de pegar — no perdés tiempo descubriendo el error después de submit.
- **Past due e Invoice Total se autocalculan al omitir.** Si los omitís con `Ctrl+Shift+A`, QuickEntry les pone la suma de los slots que dependen (Past due = Previous + Past Total Payments; Invoice Total = Total + Past due). Verificá el `esperado: X.XX` que muestra el tooltip antes de omitir.
- **Si el OCR es desastroso para un campo puntual,** abrí el picker (`Ctrl+Shift+E`) en vez de pelear con el clipboard. El input arriba escribe el slot actual; la lista de abajo te deja saltar a otros.
- **Cuando todo está cargado, el tooltip queda persistente.** Dice `Listo 9/9 - cola llena - Ctrl+Shift+S para pegar, Ctrl+Shift+E para revisar`. Sin timer — podés tomarte tu tiempo para verificar antes de pegar, o usar el picker para revisar/editar.

---

## Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| Las hotkeys no responden | El script no está corriendo | Verificá el ícono de H verde en la bandeja. Re-ejecutá `QuickEntry.ahk`. |
| El paste se hace en el lugar equivocado | No hiciste click en el primer input antes de `Ctrl+Shift+S` | Click en Account number, después `Ctrl+Shift+S`. |
| El tooltip se queda colgado | Pasó algo inesperado durante el batch | `Ctrl+Shift+R` resetea todo. |
| El tooltip dice "Cola completa" pero no quiero pegar | Apretaste `Ctrl+Shift+A` con la cola llena | `Ctrl+Shift+R` cancela. |
| Los Tabs después del paste van mal | El formulario tiene un campo extra read-only en el medio | Hablar con quien mantiene QuickEntry — se ajusta el `tabsAfter` del campo en el schema. |

---

## Soporte

- **Cambiar hotkeys:** [PERSONALIZACION_HOTKEYS.md](PERSONALIZACION_HOTKEYS.md)
- **Cómo funciona por dentro / agregar features:** [GUIA_TECNICA.md](GUIA_TECNICA.md)
- **Adaptar a otra empresa o formulario:** [AGREGAR_EMPRESA.md](AGREGAR_EMPRESA.md)

## Reportar un bug

Abrí un issue en https://github.com/Alex-vaz1/QuickEntryV1.11/issues con:
- Pasos para reproducir.
- Schema actual (`%APPDATA%\QuickEntry\config.ini`).
- Adjuntar `%APPDATA%\QuickEntry\events.log` si existe.

Para devs: ver [CONTRIBUTING.md](../CONTRIBUTING.md) para fixear y mandar PR.
