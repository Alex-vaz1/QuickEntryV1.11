# Asignet — CLAUDE.md

## Proyecto

Dos apps AHK v2 hermanas en este repo:
- **QuickEntry** (`QuickEntry.ahk`): herramienta madura para carga manual de header de facturas. NO modificar sin pedido explícito. ~700 asserts pasando.
- **Botonera** (`Botonera/`): sibling app, launcher con tabs (Wayfast/Web/Tools) para el rol de parser.

## Stack y rutas

- AutoHotkey v2.0 (sin v1)
- AutoHotkey64.exe en: `C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe`
- Test runner: `powershell -ExecutionPolicy Bypass -File <Tests>\runner.ps1`
- Validación sintaxis: `AutoHotkey64.exe /ErrorStdOut=utf-8 /validate <script>`

## ⚠️ Referencia AHK v2 FUNDAMENTAL: ClautoHotkey

`C:\Users\Usuario\Desktop\Studies\Trabajos\Asignet\ClautoHotkey\` es la **knowledge base canónica** de AHK v2. Contiene módulos de instrucción estructurados con anti-patterns, V1→V2 breaking changes, API quick-references y patrones validados.

**OBLIGATORIO consultar ANTES de:**
- Invocar `superpowers:brainstorming` para features AHK v2
- Invocar `superpowers:writing-plans` para features AHK v2
- Implementar GUIs nuevas, classes complejas, ListView/TreeView, error handling
- Resolver dudas sobre sintaxis o patrones AHK v2

**Procedimiento de consulta (keyword-driven, no leer la carpeta entera):**

1. **Siempre primero**: leé `ClautoHotkey/Modules/Module_Instructions.md` (módulo primario con framework cognitivo y standards generales).

2. **Después, según keywords del request**, leé los módulos específicos:

   | Keywords en el request | Módulo a leer |
   |---|---|
   | class, inheritance, extends, factory | `Module_Classes.md` |
   | gui, window, dialog, ListView, TreeView | `Module_GUI.md` |
   | error, try, catch, debug, exception | `Module_Errors.md` |
   | map, object, HasProp, descriptor | `Module_Objects.md` |
   | array, list, collection, sort | `Module_Arrays.md` |
   | string, regex, text, format | `Module_TextProcessing.md` |
   | data, Map, storage, nested | `Module_DataStructures.md` |
   | backtick, escape, quote, path | `Module_Escapes.md` |
   | property, DefineProp, getter, setter | `Module_DynamicProperties.md` |
   | prototype, ObjSetBase, decorator | `Module_ClassPrototyping.md` |

3. Si el request matchea varios keywords, leé **todos** los módulos relevantes. Cada uno tiene tablas V1→V2, API quick-ref, anti-patterns, y SEE ALSO cross-references.

4. Si el request es trivial (un fix de una línea, un rename, un commit message), **podés saltear** este paso. Aplicá criterio.

**En el reporte / handoff, mencioná explícitamente**:

> "Consulté `ClautoHotkey/Modules/Module_Instructions.md` + `Module_<X>.md`, `Module_<Y>.md`. Los patterns aplicados son los de esos módulos."

Esto deja trazabilidad de las fuentes y evita "AHK v2 alucinado".

## Excepciones donde Asignet pisa a ClautoHotkey

ClautoHotkey es referencia general; Asignet tiene reglas propias que la pisan:

- **Light theme**, no dark mode (`F8FAFC` bg). ClautoHotkey/CLAUDE.md dice "Dark Mode mandatory: Always use Lib/DarkModeModular.ahk" — eso NO aplica acá.
- **Paths**: `C:\Users\Usuario\...` (no `C:\Users\uphol\...` como dice ClautoHotkey).
- **Estructura del repo**: `Lib/`, `Schemas/`, `Tests/`, `docs/`, `Botonera/` (no `/Modules/`, `/AHK_Notes/`, `/Scripts/` como ClautoHotkey).

Regla: **donde Asignet contradice a ClautoHotkey, Asignet manda** (código productivo). **Donde no contradice, seguí ClautoHotkey**.

## Convenciones AHK v2 (resumen Asignet-specific)

- Pure OOP: NO `new` keyword, `Map()` para storage, `.Bind(this)` para callbacks
- Tests con `_AssertHelpers.ahk` (asserts custom, exit code via `ReportarYSalir()`)
- Light theme: bg `F8FAFC`, fg labels `1F2937`, fg dim `9CA3AF`
- Fuentes: Segoe UI para labels, Cascadia Mono para valores numéricos
- Errores: nunca `try/catch` vacío. Mensajes específicos al usuario.

## Aislamiento entre apps

QuickEntry y Botonera **NO comparten código vía `#Include` cross-folder**. Si Botonera necesita algo de `Lib/` raíz, hace **snapshot copy** a `Botonera/Lib/` con header `; SNAPSHOT COPY from <origen> on <fecha>`.

## Workflow Claude Code

- Specs: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- Plans: `docs/superpowers/plans/YYYY-MM-DD-<feature>-plan.md`
- Dev logs: `docs/dev-log/YYYY-MM-DD.md` (on-command, no automático)
- Tests siempre TDD para módulos puros; smoke-only para clases GUI
- Implementación de planes: `superpowers:subagent-driven-development` (dispatch)
