---
file: Lib/PegadoEspecial.ahk
last_review: 2026-05-12
status: active
---

# `Lib/PegadoEspecial.ahk`

## Propósito

Implementa el "pegado inteligente": toma el clipboard actual, lo pasa por la cadena de limpieza de `Cleaners.ahk` (`LimpiarComoPegadoEspecial`), y lo pega en el campo activo restaurando el clipboard original al terminar. La global `pegadoEnCurso` actúa como mutex de un solo flag para impedir solapamiento con `CaptureEngine.PasteBatch`.

## API pública

### Funciones libres

- **`PegadoEspecial() → (void)`** — snapshot del clipboard, limpia (fecha → precio → genérico), pega vía `^v`, restaura el clipboard original.
  - Llamado desde: `QuickEntry.ahk:57` (binding `XButton2::`), `QuickEntry.ahk:92` (final de `DoPegadoEspecial`)
  - Llama a: `LimpiarComoPegadoEspecial()` (de `Lib/Cleaners.ahk`), `ClipWait()` (AHK built-in), `SendInput()` (AHK built-in)

## Dependencias

- **#Include directos**: `Cleaners.ahk`
- **Incluido por**: `QuickEntry.ahk` (línea 6 del entry point)
- **Globales que define**: `pegadoEnCurso := false` — mutex booleano que señaliza que hay una operación de pegado en curso
- **Globales que usa (leídas y escritas)**: `pegadoEnCurso` (definida en `Lib/PegadoEspecial.ahk:18`; re-declarada con `global` también en `QuickEntry.ahk:102, 179, 283` por los handlers `HandlerCaptura`/`DoSoltar`/`DoHeaderScan` para respetar el contrato)
- **Símbolos externos invocados**: `LimpiarComoPegadoEspecial()` (de `Lib/Cleaners.ahk:217`)

## Notas técnicas (WHY no-obvio)

- **`SendInput "{Blind}{LShift up}..."`** al inicio: libera modificadores (Shift, Ctrl, Alt) que podrían quedar prensados si el hotkey que disparó `PegadoEspecial()` los usaba. Sin esto, el `^v` subsiguiente puede generar un keycombo inesperado (ej. `^+v` en vez de `^v`).
- **`Sleep 30` post-liberación de modificadores**: AHK necesita un tick para que el sistema procese el `up` de los modificadores antes de enviar el siguiente `SendInput`. El valor de 30 ms es el mínimo observado en pruebas manuales para evitar el race.
- **`ClipWait(0.5, 1)`**: el argumento `1` espera cambio de datos no-texto también (archivos, imágenes). Si el clipboard no actualiza en 0,5 s se muestra `MsgBox "Error al actualizar clipboard."` y se aborta; el clipboard original ya fue capturado y se restaura en el `finally`.
- **`Sleep 150` post-`^v`**: tiempo mínimo para que la aplicación destino procese el `Paste` antes de que se restaure `A_Clipboard`. Si se restaura antes, algunas apps (ej. Adobe, SAP GUI) capturan el clipboard restaurado en lugar del `limpio`.
- **`Sleep 50` en `finally` antes de liberar `pegadoEnCurso`**: drena los eventos `OnClipboardChange` encolados por las dos asignaciones de clipboard (`limpio` + restauración). Si `pegadoEnCurso` se libera antes de que el message pump los procese, `HandlerCaptura` los interpreta como copias reales del usuario y contamina la cola de captura. El comentario en el código lo documenta explícitamente (`Lib/PegadoEspecial.ahk:52-55`).
- **`try/finally` sin `catch`**: el `finally` garantiza que `pegadoEnCurso := false` se ejecute incluso si `LimpiarComoPegadoEspecial` o `ClipWait` lanzan excepciones inesperadas, evitando que el mutex quede bloqueado indefinidamente.
- **Contrato compartido con `CaptureEngine.PasteBatch`**: `HandlerCaptura` en `QuickEntry.ahk` lee `pegadoEnCurso` antes de procesar un evento de clipboard. Si es `true`, ignora el evento. Esto crea un contrato implícito entre `PegadoEspecial.ahk` y `CaptureEngine` que no es capturado por ningún `#Include`; está documentado en el header del archivo (`Lib/PegadoEspecial.ahk:14-16`).
- **Nota histórica — PegarDosFechas / "CASO A"**: la versión legacy soportaba pegar dos fechas consecutivas con Tab entre ellas. Ese flujo nunca se usó en producción y fue eliminado para simplificar; no hay dead code residual de esa lógica en el archivo actual.
- **Formato target de fechas**: `mm/dd/aaaa` (delegado a `LimpiarComoPegadoEspecial` → `LimpiarFechaRobusta` → `FormatearFecha` en `Lib/Cleaners.ahk`). Este archivo no tiene lógica de fecha propia.
- **Sin tests directos**: las operaciones de clipboard y `SendInput` requieren sistema operativo real; la cobertura es sólo smoke (uso desde `QuickEntry.ahk`).

## Bitácora de cleanup

### Fase 1 — m720
- [ ] Auditado
- Cambios aplicados:

### Fase 2 — comentarios (2026-05-12)
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - Banner principal reescrito: primera línea pasó de descripción de QUÉ ("Snapshot del clipboard → limpiar → paste. Restaura…") a WHY ("intercepta el paste del operador para normalizar fechas/precios antes de que lleguen al campo destino, sin alterar el clipboard de sistema al terminar").
  - Descripción de `pegadoEnCurso` reescrita: de "es compartida con CaptureEngine.PasteBatch para impedir que ambos flujos se solapen" a versión que explica el WHY concreto (HandlerCaptura, copias reales, cola de captura).
  - Comentario del `Sleep 50` en `finally` (líneas 52-55): conservado íntegro — ya era WHY, documenta el drain de OnClipboardChange.
  - NOTA HISTORICA de PegarDosFechas/CASO A: conservada — es diseño documentado de feature nunca usada en producción.
  - No había banners extra, código comentado ni TODOs que borrar. Conteo de banners: 1 (cumple máx 2).

### Fase 3 — dead code (2026-05-12)
- [x] Auditado 2026-05-12
- Borrados (0 referencias en producción + tests): ninguno — el archivo tiene un único símbolo exportado (`PegadoEspecial()`) y un único global (`pegadoEnCurso`), ambos con callers activos.
- Candidatos para review senior (NO borrados): ninguno.
- Resultado: USADO 2/2 (ver conteo abajo). Sin dead code. Sin helpers internos sin uso.

### Fase 5 — simplificación
- [x] Auditado 2026-05-12
- Cambios aplicados:
  - `Lib/PegadoEspecial.ahk:18-23` — extraídas 4 constantes de timing: `PEGADO_MODIFIER_DRAIN_MS=30` (tick para que AHK procese los Shift/Ctrl/Alt up antes del siguiente SendInput), `PEGADO_CLIPBOARD_WAIT_S=0.5` (timeout de ClipWait), `PEGADO_POST_PASTE_SETTLE_MS=150` (tiempo para que la app destino consuma el ^v antes de restaurar el clipboard), `PEGADO_MUTEX_DRAIN_MS=50` (drena OnClipboardChange encolados antes de liberar pegadoEnCurso). Razón: legibilidad — los magic numbers de timing son críticos pero opacos en el cuerpo de la función.
  - Comportamiento idéntico (mismos valores numéricos).

## Ideas de simplificación pendientes (input para plan posterior)

- `pegadoEnCurso` es una global de módulo expuesta sin encapsulación: podría convertirse en una property de un objeto `PegadoEspecialState` o quedar dentro de un closure para que el contrato con `CaptureEngine` sea explícito y no dependa de coordinación por convención entre archivos.
- Considerar si `MsgBox "Error al actualizar clipboard."` es la UX correcta (interrumpe el flujo del operador); un tooltip efímero via `TooltipConError` sería consistente con el resto de la app.
