# Personalización de Hotkeys

Guía para que cada usuario adapte las teclas de QuickEntry a su gusto, sin necesidad de saber AutoHotkey.

---

## Antes que nada: ¿qué es una "hotkey"?

Una **hotkey** (o "atajo de teclado") es una combinación de teclas que dispara una acción. Por ejemplo, `Ctrl+C` copia, `Ctrl+V` pega. QuickEntry agrega sus propias hotkeys (`Ctrl+Shift+A`, etc.) para armar capturas, pegar batches, etc.

En el archivo `QuickEntry.ahk`, las hotkeys se definen con una sintaxis cortita usando símbolos en lugar de los nombres completos de las teclas.

---

## La tabla de equivalencias (clave de todo)

| Símbolo | Tecla |
|:---:|---|
| `^` | **Ctrl** |
| `+` | **Shift** |
| `!` | **Alt** |
| `#` | **Win** (la tecla con el logo de Windows) |
| `::` | "ejecuta esto cuando se presione" |

Las **letras** se escriben tal cual (`a`, `b`, `s`, etc.). No importa si las escribís en mayúscula o minúscula — `a` y `A` son lo mismo a menos que combines con `+` (Shift).

### Ejemplos de lectura

| Lo que ves en el código | Cómo se lee | Qué tenés que apretar |
|---|---|---|
| `^c` | Ctrl + C | Ctrl y C |
| `^+a` | Ctrl + Shift + A | Ctrl, Shift y A juntos |
| `!s` | Alt + S | Alt y S |
| `^!t` | Ctrl + Alt + T | Ctrl, Alt y T |
| `#e` | Win + E | Tecla Windows y E |
| `^+!r` | Ctrl + Shift + Alt + R | Las 3 modificadoras y R |
| `F8` | F8 | Solo la tecla F8 |
| `^F12` | Ctrl + F12 | Ctrl y F12 |

**Regla mnemónica:** los símbolos van **antes** de la tecla principal, sin espacios. El **orden no importa** entre los modificadores: `^+a` y `+^a` son lo mismo.

---

## Hotkeys actuales de QuickEntry

| En el código | Lectura | Qué hace |
|---|---|---|
| `^+a` | Ctrl+Shift+A | Armar / Omitir |
| `^+h` | Ctrl+Shift+H | HeaderScan (leer form ya cargado) |
| `^+s` | Ctrl+Shift+S | Soltar (paste batch) |
| `^+r` | Ctrl+Shift+R | Reset |
| `^+u` | Ctrl+Shift+U | Undo |
| `^+e` | Ctrl+Shift+E | Entrada manual (toggle GUI) |
| `^+v` | Ctrl+Shift+V | Pegado especial |

---

## Cómo cambiar una hotkey paso a paso

### 1. Abrí `QuickEntry.ahk` con un editor de texto

Bloc de notas, Notepad++, VS Code, lo que tengas. **No uses Word** ni nada que reformatee texto.

### 2. Buscá la línea de la hotkey que querés cambiar

Las hotkeys aparecen al inicio de su bloque, terminadas en `::`. Por ejemplo:

```ahk
; --- ^+a: armar / omitir ---
^+a::
{
    ; ... código que se ejecuta ...
}
```

### 3. Cambiá solo la parte ANTES del `::`

Por ejemplo, para cambiar `Ctrl+Shift+A` por `Alt+Q`:

**Antes:**
```ahk
; --- ^+a: armar / omitir ---
^+a::
```

**Después:**
```ahk
; --- !q: armar / omitir ---
!q::
```

> Actualizá también el comentario de arriba (la línea con `; ---`) para que diga la nueva tecla — esto es solo para que el código sea legible.

### 4. ¡IMPORTANTE! Si cambiás `^+a`, actualizá también `HOTKEY_OMITIR`

Cerca del inicio de `QuickEntry.ahk` está esta línea:

```ahk
global HOTKEY_OMITIR := "^+a"
```

Esta cadena es lo que aparece en el tooltip cuando un copy es inválido (`Input inválido, recopia o ^+a para omitir`). Si cambiaste el binding, actualizá también esta cadena para que el tooltip siga reflejando la verdad:

```ahk
global HOTKEY_OMITIR := "Alt+Q"
```

> Esto **solo afecta** al binding `^+a`. Las demás hotkeys no necesitan tener una variable equivalente.

### 5. Guardá y reiniciá el script

- Click derecho en el ícono H verde de la bandeja → **Reload Script**.
- O cerrá y volvé a abrir `QuickEntry.ahk`.

### 6. Probá la nueva hotkey

Apretala y verificá que el tooltip aparezca / la acción se dispare como esperabas.

---

## Recomendaciones para elegir hotkeys

### ✅ Buenas opciones

- **`Ctrl+Shift+letra`** — el patrón actual. Difícil que choque con atajos del sistema o del navegador.
- **`Alt+letra`** — corto y rápido, pero ojo: muchos programas usan `Alt+letra` para acceder a menús (en el navegador, `Alt+F` abre el menú File).
- **`Win+letra`** — pocas chances de choque (Windows reserva pocas: `Win+E`, `Win+R`, `Win+L`, `Win+D`).
- **Teclas de función (`F2`–`F12`)** — pero verificá que no las use el navegador (`F5` recarga, `F11` pantalla completa, `F12` DevTools).

### ❌ Evitá

- **`Ctrl+letra` solo** (sin Shift): pisa los atajos universales (`Ctrl+C`, `Ctrl+V`, `Ctrl+S`, `Ctrl+Z`, etc.).
- **`Ctrl+Shift+T`**: en navegadores reabre la última pestaña cerrada, vas a tener choques.
- **`Ctrl+Shift+N`**: nueva ventana incógnito en Chrome/Edge.
- **`Win+L`**: bloquea la sesión de Windows. Catastrófico si lo apretás por error.
- Combinaciones de **3+ teclas físicamente difíciles** de hacer con una mano.

---

## Hotkeys con teclas especiales (avanzado)

Si querés usar teclas que no son letras, acá van algunas equivalencias útiles:

| Lo que querés | Sintaxis |
|---|---|
| Tecla Enter | `Enter` |
| Tecla Espacio | `Space` |
| Tecla Tab | `Tab` |
| Teclas de función | `F1`, `F2`, …, `F12` |
| Flechas | `Up`, `Down`, `Left`, `Right` |
| Numpad | `Numpad0`, `Numpad1`, …, `NumpadEnter` |
| Tecla Esc | `Escape` |

**Ejemplo:** disparar el reset con `Ctrl+F4`:
```ahk
^F4::
{
    ; ... código de reset ...
}
```

---

## Errores comunes

| Lo que hiciste | Lo que pasa | Cómo arreglarlo |
|---|---|---|
| Olvidaste el `::` después de la tecla | Error al cargar el script: "expected `::`..." | Agregá `::` al final de la línea de la hotkey. |
| Pusiste un espacio entre el modificador y la tecla (`^ +a`) | Error al cargar | Sin espacios: `^+a`. |
| Cambiaste `^+a` pero olvidaste actualizar `HOTKEY_OMITIR` | El tooltip de error sigue diciendo "recopia o ^+a" pero no funciona | Actualizá la línea `global HOTKEY_OMITIR := "..."`. |
| Elegiste una hotkey que ya usa Windows o el navegador | Algunas veces dispara, otras no, o dispara la acción del otro programa | Cambiala a otra combinación menos popular. |
| Dos hotkeys distintas con el mismo binding | El script tira error al recargar | Solo un bloque por combinación de teclas. |

---

## Rollback (volver a las hotkeys originales)

Si rompiste algo y querés volver al estado de fábrica, las hotkeys originales son:

```ahk
global HOTKEY_OMITIR := "^+a"

^+v::DoPegadoEspecial()
^+a::DoArmOrSkip()
^+h::DoHeaderScan()
^+s::DoSoltar()
^+r::DoReset()
^+u::DoUndo()
^+e::hud.OpenInlineEditOnCurrentSlot()
```

---

## Ayuda

Si después de cambiar una hotkey el script no carga o se comporta raro:
1. Revisá la sintaxis (`^` `+` `!` `#` antes de la letra, sin espacios, `::` al final).
2. Verificá que no hayas dejado dos hotkeys con la misma combinación.
3. Pedile a quien mantiene QuickEntry que te ayude — tener este manual a mano hace la conversación 5x más rápida.
