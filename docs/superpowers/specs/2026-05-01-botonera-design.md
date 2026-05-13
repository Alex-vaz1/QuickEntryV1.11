# Botonera Design Spec

**Fecha:** 2026-05-01
**Autor (operador):** Ale
**Estado:** Draft → en revisión

---

## 1. Goal (una frase)

Una **launcher GUI persistente** con secciones (Wayfast / Web / Tools) que sirva como **esqueleto extensible** para futuras automatizaciones del rol de parser de facturas, manteniendo independencia total de QuickEntry.

## 2. Por qué existe

El próximo rol implica operar **Wayfast** (parser interno de Asignet) además del flujo web manual actual. La botonera tiene tres propósitos en orden de importancia:

1. **Andamio mental**: cuando el operador descubra un patrón repetitivo en Wayfast, debe poder agregar un botón con fricción mínima (tres líneas en una clase).
2. **Centralizar utilities transversales** (limpieza de clipboard, regex tester, JSON pretty-print, snippets, process timer) que hoy se hacen con tools externas o no se hacen.
3. **Lanzar QuickEntry** desde un solo lugar visible — quitar el atajo de tener QuickEntry corriendo todo el tiempo cuando no se está cargando facturas.

## 3. Arquitectura (una mirada)

**Decisión clave:** *Sections como clases* (Enfoque 1 del brainstorming). Cada sección es una clase auto-contenida; la botonera principal monta las tres secciones en una `Tab3` control.

```
QuickEntry.ahk        ← intacto, sigue funcionando
Lib/                  ← intacto, NO modificar
Botonera/             ← nueva subcarpeta autocontenida
  Botonera.ahk        ← entry point (~80 líneas, solo wiring)
  Lib/                ← módulos privados (copia + nuevos)
    Cleaners.ahk           ← copia de ../../Lib/Cleaners.ahk (snapshot)
    SectionWayfast.ahk     ← clase: scaffold con placeholder + ejemplos
    SectionWeb.ahk         ← clase: launch QuickEntry + URLs
    SectionTools.ahk       ← clase: 5 utilities elegidas
    Widgets/               ← popups reusables invocados desde botones
      RegexTester.ahk
      JsonPretty.ahk
      SnippetsManager.ahk
      ProcessTimer.ahk
  Tests/
    runner.ps1             ← copia adaptada
    Test_*.ahk             ← uno por widget no-trivial
```

**Independencia:** la subcarpeta `Botonera/` es un proyecto AHK paralelo. No hace `#Include` cross-folder. Si necesita código de la raíz, lo **copia** (snapshot). Esto previene que un cambio en `../Lib/Cleaners.ahk` rompa la botonera o viceversa.

## 4. Stack técnico

- AutoHotkey v2.0
- INI para persistencia (`Botonera/botonera.ini`)
- Tests: PowerShell runner copiado de QuickEntry, asserts custom
- **Sin dependencias externas** (sin Ditto, sin PowerToys, sin OCR engine)
- Light theme alineado con QuickEntry (`F8FAFC` bg) por consistencia visual

## 5. Componentes (responsabilidad por archivo)

### 5.1 `Botonera.ahk` (entry point)

Responsabilidad única: **wiring**. Crea `MainGui`, instancia las 3 sections, registra hotkey global de show/hide (ej. `Ctrl+Shift+B`), persiste posición de ventana en INI.

No conoce qué botones tiene cada sección. No tiene lógica de negocio.

### 5.2 `MainGui` (clase, en `Lib/MainGui.ahk`)

Construye la ventana raíz con un `Tab3` de tres pestañas. Cada sección se le pasa el `Tab3` y se monta en su pestaña.

API mínima:
```
MainGui(sections := [SectionWayfast(), SectionWeb(), SectionTools()])
.Show()
.Hide()
.Toggle()
```

### 5.3 `SectionWayfast`, `SectionWeb`, `SectionTools` (clases)

Contrato común (interfaz implícita):

```
class Section {
    title := ""              ; texto del tab ("Wayfast", "Web", "Tools")
    Build(tabCtrl, tabIndex) ; agrega controles dentro del tab
    RegisterHotkeys()        ; registra sus hotkeys o noop
    OnShow()                 ; opcional: refresca estado al mostrar
    __Delete()               ; cleanup de timers/handlers
}
```

Esto es el **punto de extensión**: agregar una sección nueva es crear una clase que respete este contrato y registrarla en `Botonera.ahk`.

### 5.4 `SectionWayfast` (scaffold)

**Inicio: deliberadamente vacío** salvo:

- Un texto de cabecera: *"Acá van los atajos de Wayfast a medida que los descubras."*
- Un botón placeholder *"Agregar nuevo botón…"* que abre un Edit pidiendo nombre + acción simple (URL, comando, snippet de teclas), guarda en `botonera.ini` sección `[Wayfast.UserButtons]`. Renderiza esos botones de usuario al iniciar.
- Un comentario en código (`; TODO: agregar más botones especializados`) marcando la zona de extensión.

Esto cumple "andamio mental" sin hardcodear cosas que aún no conocemos.

### 5.5 `SectionWeb`

- Botón **"Launch QuickEntry"** → si ya hay instancia corriendo (chequeo `WinExist("QuickEntry ahk_class AutoHotkeyGUI")` o equivalente al título de su MainHud), enfocar esa ventana; sino, `Run("../QuickEntry.ahk")`. Tooltip de feedback ("Ya estaba corriendo" / "Iniciado").
- 1-2 botones de URL frecuente (Asignet web, intranet) — la lista exacta vive en INI para que el usuario edite sin tocar código.

### 5.6 `SectionTools`

Cinco botones, cada uno abre su widget propio:

| Botón | Widget | Descripción |
|---|---|---|
| **Limpiar Clipboard** | inline (sin popup) | Lee `A_Clipboard`, aplica `Cleaners.NormalizarPrecio` o detecta tipo, sobrescribe clipboard, tooltip de confirmación |
| **Snippets** | `SnippetsManager.ahk` | Popup con lista de snippets persistidos en INI, doble-click copia al clipboard |
| **Regex Tester** | `RegexTester.ahk` | Popup con dos Edit (pattern, texto), muestra matches resaltados; on-change re-evalúa |
| **JSON Pretty** | `JsonPretty.ahk` | Popup con dos Edit (input/output), botón "Format" indenta con 2 espacios. Detecta JSON inválido y muestra mensaje. |
| **Timer** | `ProcessTimer.ahk` | Popup con Start/Stop, Edit para nombre de tarea. Al Stop registra `(tarea, segundos, timestamp)` en `botonera.ini` sección `[Timer.History]`. Lista las últimas 10. |

## 6. Data flow

### 6.1 Persistencia (INI único: `botonera.ini`)

```ini
[Window]
x=...
y=...
visible=1

[Wayfast.UserButtons]
1.label=Login Wayfast
1.action=url|http://internal.wayfast/

[Web.Urls]
1.label=Asignet
1.url=https://...

[Snippets]
1.label=Email firma
1.text=Saludos`r`nAle

[Timer.History]
1.task=Carga factura X
1.seconds=87
1.timestamp=2026-05-01T14:30:00
```

### 6.2 Clipboard (anti-race)

- Acceso a `A_Clipboard` solo desde botones explícitos del usuario, nunca por timers.
- Anti-reentrance flag global (`g_clipboardBusy := false`) en `Botonera.ahk`. El botón "Limpiar Clipboard" lo setea a `true` antes de tocar `A_Clipboard` y lo limpia después.
- No hay `OnClipboardChange` en la botonera (eso es territorio de QuickEntry).

### 6.3 Hotkeys

- **Ctrl+Shift+B**: toggle show/hide de la ventana principal
- Cada sección puede registrar hotkeys propios desde `RegisterHotkeys()`. La botonera no centraliza hotkey routing.

## 7. Error handling

- Cada widget tiene su propio `try/catch` donde corresponda. No hay error global silenciador.
- Errores de INI (archivo corrupto, claves faltantes): se loguea a `botonera.log`, se usan defaults, no se propaga al usuario salvo que sea crítico.
- Botones de operaciones largas (Timer en curso, p.ej.) deshabilitan UI durante la operación para evitar dobles clicks.

## 8. Testing strategy

Tests automatizados de los **módulos puros** (sin GUI):

- `Cleaners.ahk` → tests heredados de QuickEntry (suite copia-adaptada)
- `JsonPretty` lógica de format → puro, testeable
- `SnippetsManager` storage (read/write INI) → testeable
- `ProcessTimer` registro de history → testeable

Las **secciones GUI no se testean automáticamente** (igual que MainHud en QuickEntry); se validan con smoke-launch (`/validate` exit 0 + arrancar/cerrar sin error).

Target inicial: **>50 asserts**, ALL TESTS PASSED.

## 9. Extension points (lo que diferencia esta spec)

El "esqueleto para futuras automatizaciones" se materializa en **3 puntos de extensión claros**:

1. **Agregar botón a sección existente** (caso 80%): editar la clase `SectionXxx.ahk`, agregar 3 líneas en `Build()` + handler. Sin tocar `Botonera.ahk`.
2. **Agregar widget reusable** (caso 15%): nuevo archivo en `Lib/Widgets/`, lo invoca un botón de cualquier sección.
3. **Agregar sección entera** (caso 5%): nueva clase que respete el contrato `Section`, registrarla en `Botonera.ahk`.

Cada uno tiene un **ejemplo en código** que sirve como template (el botón placeholder de Wayfast es el caso 1; `RegexTester` es el caso 2; las 3 sections existentes son el caso 3).

## 10. Out of scope (explícito)

- **No reemplaza QuickEntry**. Sigue corriendo aparte.
- **No comparte código vía `#Include`** con la raíz Asignet. Solo copias snapshot.
- **No es multi-empresa hoy** (no hay schema-driven aún para Wayfast porque no se conoce).
- **No tiene OCR** ni captura de pantalla (Bloque D del brainstorm rechazado).
- **No tiene login helpers** ni manejo de credenciales (Bloque C parcial: solo URLs públicas).
- **No tiene diff de textos**, ni validator tester, ni observation log persistente (Bloque B/E rechazado en parte). Si surgen como necesidad real, se suman después.

## 11. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Drift entre `Lib/Cleaners.ahk` (raíz) y `Botonera/Lib/Cleaners.ahk` (copia) | Acepto el drift como costo del aislamiento. Documentar el origen del snapshot en un comentario al tope del archivo copiado. |
| Botón "Agregar nuevo botón" de Wayfast crece feo si pasa de 10 botones de usuario | Si llega a ese punto, refactorizar a Enfoque 2 (plugin loader) — eso es trabajo futuro, no hoy. |
| `Tab3` de AHK v2 tiene quirks con resize | Tamaño fijo de ventana al inicio; sin resize. Si más adelante se quiere resize, agregarlo entonces. |
| Hotkey global `Ctrl+Shift+B` choca con hotkey de QuickEntry o de otra app | Confirmar con Ale que `Ctrl+Shift+B` está libre. Si no, elegir otra combinación antes de implementar. |

## 12. Cómo se va a sentir usar la botonera (UX)

1. Arranca la botonera al login de Windows (igual que QuickEntry).
2. Está oculta. Aparece con `Ctrl+Shift+B`.
3. Ventana ~500x400 px, tres tabs: **Wayfast** | **Web** | **Tools**.
4. Tab Wayfast: por ahora un texto y un botón "Agregar". Crece con el tiempo.
5. Tab Web: dos botones (Launch QuickEntry, Asignet web) + edit-link en INI para sumar más.
6. Tab Tools: cinco botones, cada uno abre un popup chico (no modal).
7. Cerrar ventana = ocultar (no destruir). Persiste posición.
8. `Ctrl+Shift+B` la oculta si está visible.
