# Contribuyendo a QuickEntry

Guía corta para el área de data entry y devs internos.

## Flow de branches

```
feature/* → develop → main
hotfix/*  →           main
```

- **`main`**: producción. Solo recibe merges desde `develop` o `hotfix/*` (forzado por workflow `pr-source-check`).
- **`develop`**: integración. Default branch del repo. Acá viven las features mientras se prueban.
- **`feature/<descripcion-corta>`**: feature aislada en desarrollo. Branch desde `develop`.
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

5. Push + abrir PR a `develop`:
   ```powershell
   git push -u origin feature/mi-cambio
   # Web UI: github.com/Alex-vaz1/QuickEntryV1.11 → "Compare & pull request"
   ```

6. CI corre automáticamente. Esperar `tests` green. Pedir 1 review.

7. Merge a `develop` cuando esté aprobado.

## Release (develop → main)

Cuando `develop` está estable:

- En web UI: New Pull Request, base `main`, compare `develop`. Título `release: <fecha>`.
- Esperar que `tests` + `pr-source-check` pasen.
- 1 aprobación mínima.
- Merge. Opcionalmente taggear:
  ```powershell
  git checkout main
  git pull
  git tag -a v1.x.y -m "Release v1.x.y"
  git push origin v1.x.y
  ```

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
