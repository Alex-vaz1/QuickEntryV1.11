# CI/CD GitHub Actions setup desde 0 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (en sesión, secuencial, mayoría de tasks son comandos shell + un par de archivos). Steps usan checkbox (`- [ ]`) syntax.

**Goal:** Crear el repo `Alex-vaz1/QuickEntryV1.11` desde cero, importar el estado actual con un initial commit limpio que sigue Conventional Commits, configurar GitHub Actions para correr los 796 asserts en cada push/PR sobre Windows runner, configurar branch protection (develop → main flow con review obligatoria), y dejar templates y docs alineados a la convención.

**Architecture:** GitHub Flow extendido con `develop` como integration branch y `main` como production:
- Direct push a `develop`/`main` **bloqueado** por branch protection.
- Feature branches → PR a `develop` → 1 review + CI green → merge.
- PR `develop` → `main` (release) → 1 review + CI green + PR source check → merge.
- CI: 1 workflow Windows (`tests`) + 1 workflow Linux (`pr-source-check` solo para PRs a main).

**Tech Stack:** GitHub Actions (windows-latest + ubuntu-latest), gh CLI 2.x para automatización, AutoHotkey 2.0.18 instalado en runner via zip download, Conventional Commits convention.

**Repo destino:** `https://github.com/Alex-vaz1/QuickEntryV1.11` (privado, ya existe pero asumimos vacío — si tiene contenido, Task 1 lo confirma).

**Tests target:** 796 asserts pasando (igual al baseline local post-Fase-8).

---

## Decisiones tomadas

| Decisión | Valor | Razón |
|---|---|---|
| gh CLI | install via winget + `gh auth login` interactivo | Acelera 10x branch protection + repo ops |
| Git history | **1 initial commit** + commits convencionales para CI setup y futuro | La historia de Fases 0-8 vive en `docs/superpowers/plans/` y `docs/files/INDEX.md`. Reconstruir 8 commits artificiales no agrega valor. |
| Default branch | `develop` (no `main`) | Forzar el flow develop→main; nadie pushea directo a main |
| Branch protection | Strict en ambos (require PR + 1 review + status check) | El user pidió "cada push requiera PR" y "cada PR requiere review + tests" |
| PR a main | Solo desde `develop` o `hotfix/*` (enforced en CI) | Convenir el flow develop→main automáticamente |
| Conventional Commits | `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build` | Estándar de la industria; soporta release automation futura |
| Runner OS | Windows (AHK only) | AHK no corre en Linux/macOS. Wine es frágil. |
| AHK version | 2.0.18 (pinned) | Reproducible. Actualizar con un PR de un solo commit cuando haga falta. |
| Minutos GHA | Free tier privado: 2000 Linux equiv/mes; Windows 2x = ~1000 Windows min ≈ ~200-300 CI runs | Si se queda corto, opción "self-hosted runner" mencionada al final |

---

## File Structure (estado final post-plan)

```
QuickEntryV1.11/
├── .github/
│   ├── workflows/
│   │   ├── tests.yml                 ← NEW: CI Windows (corre runner.ps1)
│   │   └── pr-source-check.yml       ← NEW: bloquea PRs a main que no vienen de develop/hotfix
│   ├── pull_request_template.md      ← NEW: checklist para todo PR
│   └── branch-protection/            ← NEW: payloads JSON para reaplicar protección
│       ├── develop.json
│       └── main.json
├── .gitignore                         ← NEW: ignora _archive zips, %TEMP%, OS noise
├── CONTRIBUTING.md                    ← NEW: flow de contribución develop→main
├── README.md                          ← MOD: agrega badge de CI + link a CONTRIBUTING
└── (todo el resto del repo igual: QuickEntry.ahk, Lib/, Schemas/, Tests/, docs/)
```

---

## Task 0: instalar y autenticar gh CLI

**Files:** ninguno (operación sobre la máquina).

- [ ] **Step 0.1: chequear si gh ya está instalado**

```powershell
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) { "Ya instalado: $($gh.Source)" } else { "No instalado" }
```

- [ ] **Step 0.2: si no, instalar via winget**

```powershell
winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
# Refrescar PATH en la sesión actual sin reiniciar:
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
gh --version
```
Expected: `gh version 2.x.x ...`.

- [ ] **Step 0.3: autenticar (manual — humano hace esto, 30 segundos)**

```powershell
gh auth login
# Choices:
#   1) GitHub.com
#   2) HTTPS
#   3) Y (authenticate Git with creds)
#   4) Login with a web browser
#   5) Copy code -> paste in browser -> authorize
```

- [ ] **Step 0.4: verificar auth + permisos**

```powershell
gh auth status
gh api user --jq .login
```
Expected: `alex-vaz1` o `Alex-vaz1`.

---

## Task 1: inspeccionar repo remoto

**Files:** ninguno.

- [ ] **Step 1.1: ver metadata + branches**

```powershell
gh repo view Alex-vaz1/QuickEntryV1.11 --json name,defaultBranchRef,visibility,isEmpty,description,createdAt
gh api repos/Alex-vaz1/QuickEntryV1.11/git/refs/heads 2>&1
```
Expected:
- Si está vacío: `isEmpty: true` y refs vacíos.
- Si tiene contenido: lista de branches + último commit.

- [ ] **Step 1.2: si NO está vacío, clonar a temp para inspeccionar**

```powershell
$tmp = "$env:TEMP\qe-remote-inspect"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
gh repo clone Alex-vaz1/QuickEntryV1.11 $tmp
Get-ChildItem $tmp
cd $tmp
git log --oneline -20
cd -
```

- [ ] **Step 1.3: decisión**

Si está vacío (esperado): continuar a Task 2.
Si tiene contenido inesperado: PARAR y consultar humano. Opciones: (a) borrar repo y recrear, (b) force-push, (c) mergear.

---

## Task 2: backup local + git init

**Files:**
- Create: `_archive/2026-05-12-post-fase8.zip`
- Create: `.git/` (via `git init`)

- [ ] **Step 2.1: backup del estado actual**

```powershell
$exclude = @('_archive', '.git')
$items = Get-ChildItem -Path . | Where-Object { $_.Name -notin $exclude }
Compress-Archive -Path $items -DestinationPath _archive/2026-05-12-post-fase8.zip -CompressionLevel Optimal -Force
$z = Get-Item _archive/2026-05-12-post-fase8.zip
"Backup: $($z.Length) bytes"
```
Expected: > 300KB.

- [ ] **Step 2.2: git init + config local**

```powershell
git init
git config user.email "alex-vaz1@users.noreply.github.com"
git config user.name "Alex Vaz"
git symbolic-ref HEAD refs/heads/main
```
Expected: `Initialized empty Git repository in ...\.git\`.

---

## Task 3: `.gitignore`

**Files:**
- Create: `.gitignore`

- [ ] **Step 3.1: escribir `.gitignore`**

```
# Backup snapshots locales (no se versionan; histórico en /_archive)
_archive/*.zip

# OS noise
Thumbs.db
ehthumbs.db
Desktop.ini
.DS_Store

# Logs locales del usuario (Logger.ahk escribe a APPDATA, pero por si acaso)
*.log

# IDE / editor
.vscode/
.idea/
*.swp
*.swo

# Tests temporales
QuickEntry_Test_*/

# AHK binaries (si alguien copia el exe al repo por error)
AutoHotkey*.exe
AutoHotkey*.zip
```

---

## Task 4: initial commit + push a `main`

**Files:** (commit captura todo el árbol actual).

- [ ] **Step 4.1: agregar remote**

```powershell
git remote add origin https://github.com/Alex-vaz1/QuickEntryV1.11.git
git remote -v
```
Expected: `origin  https://github.com/.../QuickEntryV1.11.git (fetch)` y (push).

- [ ] **Step 4.2: staging + verificar qué entra**

```powershell
git add .
git status --short | Select-Object -First 30
"---"
git status --short | Measure-Object -Line
```
Expected: ~80-100 archivos staged. Inspeccionar la salida — nada raro tipo `events.log` o `_archive/*.zip`.

- [ ] **Step 4.3: initial commit con mensaje convencional**

```powershell
git commit -m "chore: initial import of QuickEntry V1.11 post-cleanup

State: post-Fase-8 (cleanup + simplificacion + critical fixes + bug LoadLast).
796 asserts pasando en 10 archivos de test. 14 archivos productivos validados.

Historial de cleanup en docs/superpowers/plans/ y docs/files/INDEX.md.
"
git log --oneline
```
Expected: 1 commit en `main`.

- [ ] **Step 4.4: push a `main`**

```powershell
git push -u origin main
```
Expected: branch `main` creado en remote. Si pide credenciales y no las dio gh auth → fix con `gh auth setup-git`.

---

## Task 5: crear branch `develop`

**Files:** ninguno (operación git).

- [ ] **Step 5.1: crear develop desde main + push**

```powershell
git checkout -b develop
git push -u origin develop
```
Expected: `develop` branch creado en remote.

- [ ] **Step 5.2: cambiar default branch del repo a develop**

```powershell
gh repo edit Alex-vaz1/QuickEntryV1.11 --default-branch develop
gh repo view Alex-vaz1/QuickEntryV1.11 --json defaultBranchRef --jq .defaultBranchRef.name
```
Expected: `develop`.

---

## Task 6: workflow `tests.yml`

**Files:**
- Create: `.github/workflows/tests.yml`

- [ ] **Step 6.1: escribir el workflow YAML**

```yaml
name: tests

on:
  push:
    branches: [develop, main]
  pull_request:
    branches: [develop, main]

# Cancel viejos runs del mismo PR cuando se pushea nuevo commit
concurrency:
  group: tests-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  tests:
    name: AHK v2 tests (Windows)
    runs-on: windows-latest
    timeout-minutes: 10

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install AutoHotkey v2 (pinned 2.0.18)
        shell: pwsh
        run: |
          $version = "2.0.18"
          $url = "https://www.autohotkey.com/download/2.0/AutoHotkey_${version}.zip"
          Write-Host "Downloading $url"
          Invoke-WebRequest -Uri $url -OutFile "$env:RUNNER_TEMP/ahk.zip" -UseBasicParsing
          Expand-Archive -Path "$env:RUNNER_TEMP/ahk.zip" -DestinationPath "$env:RUNNER_TEMP/ahk" -Force
          $ahk = "$env:RUNNER_TEMP/ahk/AutoHotkey64.exe"
          if (-not (Test-Path $ahk)) {
              Write-Host "AutoHotkey64.exe no encontrado. Archivos en el zip:"
              Get-ChildItem "$env:RUNNER_TEMP/ahk" -Recurse | ForEach-Object { Write-Host "  $($_.FullName)" }
              throw "AHK install fallido"
          }
          "AHK_V2=$ahk" | Out-File -FilePath $env:GITHUB_ENV -Append
          & $ahk /Version

      - name: Verify runner.ps1 discovery picks up AHK_V2
        shell: pwsh
        run: |
          Write-Host "AHK_V2 = $env:AHK_V2"
          if (-not (Test-Path $env:AHK_V2)) { throw "AHK_V2 no apunta a archivo existente" }

      - name: Run test suite
        shell: pwsh
        run: |
          powershell -ExecutionPolicy Bypass -File Tests/runner.ps1

      - name: Upload test outputs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-outputs
          path: |
            ${{ runner.temp }}/Test_*.out
            ${{ runner.temp }}/Test_*.err
          if-no-files-found: ignore
          retention-days: 7
```

---

## Task 7: workflow `pr-source-check.yml`

**Files:**
- Create: `.github/workflows/pr-source-check.yml`

- [ ] **Step 7.1: escribir el workflow**

```yaml
name: pr-source-check

on:
  pull_request:
    branches: [main]

jobs:
  check-source-branch:
    name: PR to main from develop only
    runs-on: ubuntu-latest
    timeout-minutes: 2
    steps:
      - name: Source branch must be develop or hotfix/*
        run: |
          src="${{ github.head_ref }}"
          echo "Source branch: $src"
          if [ "$src" = "develop" ] || [[ "$src" == hotfix/* ]]; then
            echo "OK: PR source '$src' allowed for main"
            exit 0
          fi
          echo "::error::PRs to main solo permitidas desde 'develop' o 'hotfix/*'. Source fue '$src'."
          exit 1
```

---

## Task 8: PR template + CONTRIBUTING

**Files:**
- Create: `.github/pull_request_template.md`
- Create: `CONTRIBUTING.md`

- [ ] **Step 8.1: PR template**

`.github/pull_request_template.md`:

```markdown
## Resumen

<!-- 1-3 líneas: qué cambia y por qué. -->

## Tipo de cambio

- [ ] `feat`: feature nuevo
- [ ] `fix`: bug fix
- [ ] `refactor`: refactor sin cambio de comportamiento
- [ ] `chore`: tooling, deps, infra
- [ ] `docs`: solo docs
- [ ] `test`: solo tests
- [ ] `ci`: workflows / Actions
- [ ] `perf`: mejora de performance medida

## Checklist

- [ ] Tests pasan localmente (`powershell -ExecutionPolicy Bypass -File Tests/runner.ps1`)
- [ ] Sintaxis validada en los archivos modificados (`AutoHotkey64.exe /validate <file>`)
- [ ] Mensaje de commit sigue Conventional Commits (`<type>(<scope>): <description>`)
- [ ] Si toca código productivo: registrado en `docs/files/<archivo>.md` bitácora
- [ ] Si toca specs/docs: links coherentes, sin referencias obsoletas

## Cómo testear

<!-- Pasos manuales para reproducir / verificar. -->

## Notas para el reviewer

<!-- Cualquier contexto extra: decisiones de diseño, alternativas descartadas, refactors diferidos. -->
```

- [ ] **Step 8.2: CONTRIBUTING.md**

```markdown
# Contribuyendo a QuickEntry

Guía corta para el área de data entry y devs internos.

## Flow de branches

```
feature/* → develop → main
hotfix/*  →           main
```

- **`main`**: producción. Solo recibe merges desde `develop` o `hotfix/*` (forzado por `pr-source-check` workflow).
- **`develop`**: integración. Default branch del repo. Acá viven las features mientras se prueban.
- **`feature/<descripcion-corta>`**: feature aislada en development. Branch desde `develop`.
- **`hotfix/<bug>`**: fix urgente que va directo a `main` saltándose `develop`. Después rebase a develop también.

## Cómo contribuir

1. Pull último `develop`:
   ```powershell
   git checkout develop
   git pull
   ```

2. Crear feature branch:
   ```powershell
   git checkout -b feature/mi-cambio
   ```

3. Hacer cambios. Correr tests locales:
   ```powershell
   powershell -ExecutionPolicy Bypass -File Tests/runner.ps1
   ```
   Expected: `Total asserts: 796` (o más si agregaste tests).

4. Commits con [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat(captureengine): add ClearSlot type field
   fix(mainhud): LoadLast preserves templateMode
   docs(manual): document continuous capture mode
   ci: pin AutoHotkey to 2.0.18 in workflow
   ```

   Tipos válidos: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`, `perf`, `style`.
   Scope (opcional): el módulo afectado (`captureengine`, `mainhud`, `cleaners`, etc.).

5. Push + open PR a `develop`:
   ```powershell
   git push -u origin feature/mi-cambio
   gh pr create --base develop --fill
   ```

6. CI corre automáticamente. Esperar `tests` green. Pedir review (1 aprobación mínima).

7. Merge a `develop` cuando esté aprobado.

## Release (develop → main)

Cuando `develop` está estable:

```powershell
gh pr create --base main --head develop --title "release: <fecha o tag>" --body "..."
```

- `tests` workflow + `pr-source-check` workflow deben pasar.
- Necesita 1 aprobación.
- Después del merge, opcionalmente taggear (`git tag v1.x` + `git push --tags`).

## Reglas duras

- **No push directo** a `develop` o `main`. Branch protection lo rechaza.
- **No merge sin CI green**. El check `tests` es obligatorio.
- **No merge sin review**. 1 aprobación mínima.
- **No PR a main desde feature/***. Solo `develop` o `hotfix/*`. El workflow `pr-source-check` lo enforza.
- **Conventional Commits obligatorio** para PR titles (los commits internos del PR son libres; el merge usa el PR title como commit message).

## Tests

El runner (`Tests/runner.ps1`) discovera AHK via:
1. `$env:AHK_V2` si está seteada.
2. `%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe`
3. `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`
4. Fallback path histórico del autor.

Si tu AHK está en otro lado:
```powershell
$env:AHK_V2 = "C:\ruta\a\AutoHotkey64.exe"
powershell -ExecutionPolicy Bypass -File Tests/runner.ps1
```
```

---

## Task 9: docs updates (README + GUIA_TECNICA + MANUAL)

**Files:**
- Modify: `README.md` (agrega CI badge + link CONTRIBUTING)
- Modify: `docs/GUIA_TECNICA.md` (nota sobre CI en sección "Tests")
- Modify: `docs/MANUAL_USUARIO.md` (link a CONTRIBUTING si reporta bug)

- [ ] **Step 9.1: README badge + sección Contributing**

Leer `README.md` actual y agregar al tope, antes del primer `#` o título:

```markdown
[![tests](https://github.com/Alex-vaz1/QuickEntryV1.11/actions/workflows/tests.yml/badge.svg?branch=develop)](https://github.com/Alex-vaz1/QuickEntryV1.11/actions/workflows/tests.yml)

```

Y al final del archivo agregar:

```markdown

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para el flow de branches, convención de commits, y cómo correr los tests localmente.
```

- [ ] **Step 9.2: GUIA_TECNICA sección Tests**

En `docs/GUIA_TECNICA.md` sección "## Tests", al final de la sección agregar:

```markdown

### Integración continua

Cada push a `develop`/`main` y cada PR contra esas branches dispara automáticamente el workflow [`tests.yml`](../.github/workflows/tests.yml) en GitHub Actions. El runner es Windows con AutoHotkey 2.0.18 pinned. PRs no se pueden mergear sin `tests` green ni sin 1 review aprobada.

PRs a `main` adicionalmente disparan [`pr-source-check.yml`](../.github/workflows/pr-source-check.yml) que rechaza PRs cuya source branch no sea `develop` o `hotfix/*`.

Ver [CONTRIBUTING.md](../CONTRIBUTING.md) para el flow completo.
```

- [ ] **Step 9.3: MANUAL_USUARIO ¿bugs?**

En `docs/MANUAL_USUARIO.md`, al final agregar:

```markdown

## Reportar un bug

Abrí un issue en https://github.com/Alex-vaz1/QuickEntryV1.11/issues con:
- Pasos para reproducir.
- Schema actual (`%APPDATA%\QuickEntry\config.ini`).
- Adjuntar `%APPDATA%\QuickEntry\events.log` si existe.

Para devs: ver [CONTRIBUTING.md](../CONTRIBUTING.md) para fixear y mandar PR.
```

---

## Task 10: commit + push toda la setup de CI a develop

**Files:** (commit captura todo lo agregado en Tasks 6-9).

- [ ] **Step 10.1: stage + verificar**

```powershell
git checkout develop
git add .github/ .gitignore CONTRIBUTING.md README.md docs/GUIA_TECNICA.md docs/MANUAL_USUARIO.md
git status --short
```
Expected: archivos de `.github/`, `.gitignore`, `CONTRIBUTING.md`, README + docs modificados.

- [ ] **Step 10.2: commit (conventional)**

```powershell
git commit -m "ci: setup GitHub Actions workflows and contribution conventions

- workflows/tests.yml: Windows runner, AHK v2.0.18 pinned, runs Tests/runner.ps1
- workflows/pr-source-check.yml: enforces main only accepts PRs from develop or hotfix/*
- .github/pull_request_template.md: standard PR checklist
- CONTRIBUTING.md: branch flow, conventional commits, local test instructions
- README.md: CI badge + contributing link
- docs/GUIA_TECNICA.md: CI integration section
- docs/MANUAL_USUARIO.md: bug report instructions
"
```

- [ ] **Step 10.3: push a develop**

```powershell
git push origin develop
gh run watch  # opcional: monitorear el run en vivo
```

Esperar a que `tests` workflow termine en green. Si falla, ver outputs.

- [ ] **Step 10.4: verificar run green**

```powershell
gh run list --branch develop --limit 3
gh run view --log-failed 2>$null  # solo si hubo fail
```
Expected: status `success` en el run más reciente del workflow `tests`.

---

## Task 11: branch protection rules

**Files:**
- Create: `.github/branch-protection/develop.json`
- Create: `.github/branch-protection/main.json`

Estos JSONs quedan committeados como source-of-truth de la config (si alguien edita protección via web por error, se puede reaplicar con un comando).

- [ ] **Step 11.1: payload para develop**

`.github/branch-protection/develop.json`:

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["AHK v2 tests (Windows)"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "required_conversation_resolution": true
}
```

- [ ] **Step 11.2: payload para main**

`.github/branch-protection/main.json`:

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["AHK v2 tests (Windows)", "PR to main from develop only"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
```

(Nota: los `contexts` son los `name:` de cada job en los workflows. `tests.yml` tiene `name: AHK v2 tests (Windows)`. `pr-source-check.yml` tiene `name: PR to main from develop only`. Verificar match exacto.)

- [ ] **Step 11.3: commitear los JSONs + aplicar protección**

```powershell
git add .github/branch-protection/
git commit -m "chore(github): add branch protection JSON payloads for develop and main"
git push origin develop

gh api -X PUT repos/Alex-vaz1/QuickEntryV1.11/branches/develop/protection `
  --input .github/branch-protection/develop.json

gh api -X PUT repos/Alex-vaz1/QuickEntryV1.11/branches/main/protection `
  --input .github/branch-protection/main.json
```

- [ ] **Step 11.4: verificar protección activa**

```powershell
gh api repos/Alex-vaz1/QuickEntryV1.11/branches/develop/protection --jq '{enforce_admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count, checks: .required_status_checks.contexts}'
gh api repos/Alex-vaz1/QuickEntryV1.11/branches/main/protection --jq '{enforce_admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count, checks: .required_status_checks.contexts}'
```
Expected: ambos con `enforce_admins: true`, `reviews: 1`, `checks` listados correctamente.

---

## Task 12: smoke test del flow completo

**Files:** (commit + PR en feature branch de prueba).

- [ ] **Step 12.1: crear feature branch + cambio trivial**

```powershell
git checkout develop
git pull origin develop
git checkout -b feature/ci-smoke-test

# Cambio trivial: agregar comentario al CONTRIBUTING
Add-Content CONTRIBUTING.md "`n<!-- CI smoke test 2026-05-12 -->"
git add CONTRIBUTING.md
git commit -m "test: smoke test CI workflow trigger"
git push -u origin feature/ci-smoke-test
```

- [ ] **Step 12.2: abrir PR a develop + verificar workflow corre**

```powershell
gh pr create --base develop --head feature/ci-smoke-test `
  --title "test: CI smoke test" `
  --body "Verifica que el workflow tests.yml dispara en PR + bloquea merge sin review."

gh pr checks --watch
```
Expected: `tests` job corre y termina success (~3-5 min).

- [ ] **Step 12.3: verificar que NO se puede mergear sin review**

```powershell
gh pr merge --auto --squash
```
Expected: error sobre "review required" o queda en auto-merge waiting.

- [ ] **Step 12.4: aprobar + mergear (humano)**

Vos abrís el PR en web, hacés "Approve", después:

```powershell
gh pr merge --squash --delete-branch
```
Expected: merge a develop exitoso, feature branch borrada.

- [ ] **Step 12.5: probar develop → main release flow**

```powershell
git checkout develop
git pull origin develop
gh pr create --base main --head develop `
  --title "release: initial production push (post-Fase-8)" `
  --body "Primer release a main con CI configurado. Tests: 796/796 ✅."
gh pr checks --watch
```
Expected: ambos workflows (`tests` + `pr-source-check`) en green.

- [ ] **Step 12.6: aprobar + mergear release**

Web UI → Approve → 

```powershell
gh pr merge --merge  # NO squash para release: queremos preservar el "release" commit
```

- [ ] **Step 12.7: verificar tag opcional**

```powershell
git checkout main
git pull origin main
git tag -a v1.11.0 -m "Initial release post-Fase-8"
git push origin v1.11.0
```

---

## Task 13: cierre + INDEX update

**Files:**
- Modify: `docs/files/INDEX.md` (agregar Fase 9 / CI setup)

- [ ] **Step 13.1: update INDEX.md tabla**

Agregar fila a "Estado por fase":

```markdown
| 9 | CI/CD GitHub Actions (Conventional Commits, develop→main, branch protection) | 🟢 completa |
```

Y al final del "Resumen de cleanup" agregar bloque:

```markdown
**Fase 9 — CI/CD GitHub Actions setup (2026-05-12).** Plan: [`2026-05-12-cicd-github-actions-plan.md`](../superpowers/plans/2026-05-12-cicd-github-actions-plan.md). Backup: `_archive/2026-05-12-post-fase8.zip`.

- **Repo**: `https://github.com/Alex-vaz1/QuickEntryV1.11` (privado).
- **Default branch**: `develop`. `main` reservado para producción.
- **Workflows**: `.github/workflows/tests.yml` (Windows, AHK 2.0.18, corre los 796 asserts) + `.github/workflows/pr-source-check.yml` (Linux, enforza develop→main).
- **Branch protection**: develop y main ambos con require-PR + 1 review + status check + enforce_admins. PRs a main solo desde develop o hotfix/*.
- **Convenciones**: Conventional Commits. PR template + CONTRIBUTING.md.
- **Smoke test**: feature branch → PR → review → merge a develop → PR develop→main → release.
- **Asserts**: 796/796 ✅ (sin cambios funcionales, solo infra).
```

- [ ] **Step 13.2: commitear el update vía PR (no direct push)**

```powershell
git checkout develop
git pull origin develop
git checkout -b docs/index-fase-9
git add docs/files/INDEX.md
git commit -m "docs(index): register Fase 9 CI/CD setup"
git push -u origin docs/index-fase-9
gh pr create --base develop --fill --title "docs(index): register Fase 9"
```

(Esto es el primer PR "real" usando el flow nuevo — sirve como walkthrough adicional del proceso.)

---

## Self-review checklist

1. **Spec coverage:**
   - ✅ "cada push automatic" → workflow `on: push: branches: [develop, main]`
   - ✅ "cada push requiera PR" → branch protection require PR + enforce_admins
   - ✅ "cada PR requiera review" → 1 approving review
   - ✅ "tests de github actions" → `tests` workflow es required status check
   - ✅ "pushear primero a develop y despues a main" → default branch develop + pr-source-check para main
   - ✅ Conventional Commits → PR template + CONTRIBUTING.md
   - ✅ Repo desde 0 → Task 4 initial commit
   - ✅ gh CLI install → Task 0
   - ✅ Docs updated → Task 9

2. **Placeholder scan:** sin TBD. Cada step tiene comando exacto o contenido completo.

3. **Type consistency:**
   - `name:` del job en `tests.yml` = `"AHK v2 tests (Windows)"` → mismo string en `develop.json` y `main.json` contexts.
   - `name:` del job en `pr-source-check.yml` = `"PR to main from develop only"` → mismo en `main.json`.
   - Repo path `Alex-vaz1/QuickEntryV1.11` consistente.

---

## Notas operativas

- **Costo Actions**: privado + Windows runner 2x. ~2-3 min/run. Free tier ~1000 Windows min/mes = ~300-400 runs/mes. Si te quedás corto: configurá un **self-hosted runner** en una PC del área (gratis, ilimitado): `gh api repos/.../actions/runners/registration-token` + script de install Windows. Mencionado al final por si lo necesitás más adelante.
- **AHK 2.0.18 pin**: actualizar = un PR `chore(ci): bump AutoHotkey to 2.0.19` cuando salga release nuevo y se quiera adoptar.
- **Branch protection bypass**: si quedás bloqueado por una emergencia, `gh api -X DELETE repos/.../branches/main/protection` temporalmente. Volver a aplicar con el JSON committeado al terminar. Eso es lo que hace el JSON-in-repo: source of truth reaplicable.
- **Si gh auth falla**: alternativa con PAT en `%USERPROFILE%\.config\gh\hosts.yml`. `gh auth login --with-token < token.txt` para automatización pura.
- **Rollback**: si algo se rompe a medio camino, restaurar de `_archive/2026-05-12-post-fase8.zip` + `gh repo delete Alex-vaz1/QuickEntryV1.11 --yes` + recrear.

---

## Pendientes para próximos ciclos (NO en este plan)

- **Dependabot** o **Renovate** para actualizar GHA actions versions automáticamente.
- **CODEOWNERS** file para auto-asignar reviewers según área.
- **release-please** o **semantic-release** para autotag/changelog desde Conventional Commits.
- **Self-hosted runner** si free tier se queda corto.
- **Linter de commits** (`commitlint`) como pre-commit hook local.
- Los 11 Important del senior review original (callback injection MainHud, `INSTALL.md`, versionado visible, etc).
