# Tests/runner.ps1 - corre todos los Test_*.ahk y reporta pass/fail.
# Detecta:
#   - exit != 0 (raro: AHK suele exitear 0 incluso en errores no manejados)
#   - falta de linea "=== N tests, F failures ===" (crash silencioso)
#   - F > 0 (asserts fallaron)
$ahk = $env:AHK_V2
if (-not $ahk) {
    $ahk = @(
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
        "C:\Users\Usuario\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $ahk) { throw "AutoHotkey v2 no encontrado. Definí `$env:AHK_V2` o instala AHK v2." }
$testDir = $PSScriptRoot
$tests = Get-ChildItem -Path $testDir -Filter "Test_*.ahk" | Sort-Object Name
$totalFail = 0
$totalAsserts = 0
foreach ($t in $tests) {
    $out = Join-Path $env:TEMP "$($t.BaseName).out"
    $err = Join-Path $env:TEMP "$($t.BaseName).err"
    if (Test-Path $out) { Remove-Item $out -Force }
    if (Test-Path $err) { Remove-Item $err -Force }
    Write-Host -NoNewline ("RUN   {0,-32} " -f $t.Name)
    # Usamos [Diagnostics.Process] directo (no Start-Process) para tener ExitCode
    # confiable tras WaitForExit con timeout. PS 5.1 Start-Process + NoNewWindow + PassThru
    # no rastrea ExitCode despues de un timeout.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ahk
    $psi.Arguments = "/ErrorStdOut=utf-8 `"$($t.FullName)`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    # Lectura async de stdout/stderr para evitar deadlock por buffer lleno.
    $stdoutTask = $p.StandardOutput.ReadToEndAsync()
    $stderrTask = $p.StandardError.ReadToEndAsync()
    # Per-test timeout: 60s. Tests reales corren en <1s; este timeout solo dispara en CI
    # cuando algun test queda colgado en headless (esperando clipboard/key/GUI).
    $timedOut = -not $p.WaitForExit(60000)
    if ($timedOut) {
        try { $p.Kill() } catch {}
        Start-Sleep -Milliseconds 200  # dar tiempo a que los streams flushen tras Kill
        Write-Host "TIMEOUT" -ForegroundColor Yellow
    } else {
        Write-Host ("done (exit={0})" -f $p.ExitCode)
    }
    # Persistir stdout/stderr a archivo (el codigo abajo los lee asi).
    Set-Content -Path $out -Value $stdoutTask.Result -NoNewline -Encoding UTF8
    Set-Content -Path $err -Value $stderrTask.Result -NoNewline -Encoding UTF8
    $exitCode = if ($timedOut) { -1 } else { $p.ExitCode }

    $tail = ""
    $asserts = 0
    $failures = 0
    $hasSummary = $false
    if (Test-Path $out) {
        $content = Get-Content $out -Raw
        if ($content) {
            $summaryLine = ($content -split "`n" | Where-Object { $_ -match "tests,\s+\d+\s+failures" } | Select-Object -Last 1)
            if ($summaryLine) {
                $tail = $summaryLine.Trim()
                $hasSummary = $true
                if ($tail -match "(\d+)\s+tests,\s+(\d+)\s+failures") {
                    $asserts = [int]$matches[1]
                    $failures = [int]$matches[2]
                    $totalAsserts += $asserts
                }
            }
        }
    }

    $crashed = (-not $hasSummary) -or ($exitCode -ne 0) -or $timedOut
    $assertsFailed = ($failures -gt 0)

    if (-not $crashed -and -not $assertsFailed) {
        Write-Host ("PASS  {0,-32} {1}" -f $t.Name, $tail) -ForegroundColor Green
    } else {
        $reason = if ($timedOut) {
            "TIMEOUT (60s, killed) - test colgado en headless"
        } elseif ($crashed) {
            "CRASH (exit=$exitCode, no summary)"
        } else {
            "FAIL ($failures asserts)"
        }
        Write-Host ("FAIL  {0,-32} {1}" -f $t.Name, $reason) -ForegroundColor Red
        if (Test-Path $out) {
            (Get-Content $out -Raw) -split "`n" | Where-Object { $_ -match "^FAIL" } | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
        }
        if (Test-Path $err) {
            $errContent = Get-Content $err -Raw
            if ($errContent) { Write-Host "      STDERR: $errContent" -ForegroundColor Red }
        }
        $totalFail++
    }
}
Write-Host ""
Write-Host "Total asserts: $totalAsserts"
if ($totalFail -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$totalFail TEST FILE(S) FAILED" -ForegroundColor Red
    exit 1
}
