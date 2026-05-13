# Asignet QuickEntry

[![tests](https://github.com/Alex-vaz1/QuickEntryV1.11/actions/workflows/tests.yml/badge.svg?branch=develop)](https://github.com/Alex-vaz1/QuickEntryV1.11/actions/workflows/tests.yml)

Herramienta de productividad para acelerar la carga de facturas en Asignet.

## Problema

Cargar el header de cada factura requiere copiar 9 campos de la fuente al formulario uno por uno: ubicar dato → copiar → click en el form → pegar → repetir. ~27 acciones de mouse, 9 cambios de contexto entre mirar el formulario y la factura.

## Solución

Captura batch schema-driven con AutoHotkey v2:
- El operador copia los 9 campos en orden mientras lee la factura.
- Un tooltip flotante guía qué campo viene siguiente y muestra el último cargado en negrita visual.
- Al final, un solo hotkey pega todo con Tab entre campos.
- Validaciones aritméticas (suma de Past due, Total) detectan errores ANTES del paste.
- Mensajes de error usan el nombre del campo (ej. `Past due inválido: suma debe ser 500.00`).

## Resultado estimado

| Métrica | Antes | Después | Ahorro |
|---|---|---|---|
| Tiempo por factura | ~100s | ~54s | ~46% |
| Acciones al formulario | ~27 | 2 | ~93% |
| Cambios de contexto | 9 | 1 | ~89% |
| Errores aritméticos | post-submit (rework) | en captura (auto) | eliminados |


## Documentación

| Documento | Para quién |
|---|---|
| [docs/MANUAL_USUARIO.md](docs/MANUAL_USUARIO.md) | Operadores que cargan facturas (uso día a día) |
| [docs/PERSONALIZACION_HOTKEYS.md](docs/PERSONALIZACION_HOTKEYS.md) | Cualquier usuario que quiera cambiar las teclas a su gusto |
| [docs/GUIA_TECNICA.md](docs/GUIA_TECNICA.md) | Desarrolladores: arquitectura, libs, decisiones de diseño |
| [docs/AGREGAR_EMPRESA.md](docs/AGREGAR_EMPRESA.md) | Adaptar QuickEntry a otra empresa o formulario |

## Arquitectura (SOLID)

```
QuickEntry.ahk          ← entry point (~190 líneas, solo wiring)
Lib/                    ← módulos puros + clases
  Cleaners.ahk          ← S: solo limpieza OCR (fechas, precios, texto)
  Validators.ahk        ← S: validadores + builders (ValidarSumaTol, etc.)
  Schema.ahk            ← I: contratos Campo / InvoiceSchema
  CaptureEngine.ahk     ← D: depende del INTERFACE InvoiceSchema
  TooltipFormatter.ahk  ← S: formato visual del tooltip
  ManualInputGui.ahk    ← S: GUI ^+e para tipear manualmente
  PegadoEspecial.ahk    ← S: single-paste con limpieza inline
Schemas/                ← O: una empresa por archivo
  AsignetHeaderV1.ahk
  _Plantilla_NuevaEmpresa.ahk
docs/                   ← manual usuario, guía técnica, etc.
Tests/                  ← TDD, 500+ asserts automatizados
  runner.ps1            ← corre toda la suite en un comando
```

## Hotkeys principales

| Tecla | Acción |
|---|---|
| `Ctrl+Shift+A` | Armar captura / Omitir slot actual |
| `Ctrl+Shift+S` | Soltar (paste batch de toda la cola) |
| `Ctrl+Shift+R` | Reset (cancelar captura sin pegar) |
| `Ctrl+Shift+U` | Undo (descartar último valor) |
| `Ctrl+Shift+E` | Entrada manual (toggle GUI para tipear) |
| `Ctrl+Shift+V` | Pegado especial (single, con limpieza OCR) |

> Para personalizar las teclas, ver [docs/PERSONALIZACION_HOTKEYS.md](docs/PERSONALIZACION_HOTKEYS.md).

## Cómo correr

```
AutoHotkey64.exe QuickEntry.ahk
```

## Tests

```powershell
powershell -ExecutionPolicy Bypass -File Tests\runner.ps1
```

Output esperado: 6 archivos PASS, 500+ asserts, exit 0.

## Stack técnico

- AutoHotkey v2.0 (sin dependencias externas)
- TDD con asserts custom (500+ asserts, < 2s ejecución total)
- PowerShell para test runner

## Decisiones de diseño

- **Schema declarativo en lugar de código imperativo por campo.** Una empresa nueva = un archivo nuevo en `Schemas/`. La lógica del motor (`CaptureEngine`) no cambia.
- **Validators puros + builders.** `ValidarSumaTol([5, 6])` retorna un closure (`.Bind()`) — no hace falta tocar el motor para sumar slots distintos.
- **Errores con nombre del campo** El operador no piensa en "slot 7", piensa en "Past due".
- **Tooltip de dos líneas con `▶ valor ◀`.** Línea 1 = qué viene; línea 2 = qué acabás de cargar (con marca visual fácil de revisar a ojo).

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para el flow de branches (`feature/* → develop → main`), Conventional Commits y cómo correr los tests localmente.
