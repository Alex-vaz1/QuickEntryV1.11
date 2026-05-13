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
    $p = Start-Process -FilePath $ahk -ArgumentList @('/ErrorStdOut=utf-8', $t.FullName) `
         -RedirectStandardOutput $out -RedirectStandardError $err -Wait -NoNewWindow -PassThru

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

    $crashed = (-not $hasSummary) -or ($p.ExitCode -ne 0)
    $assertsFailed = ($failures -gt 0)

    if (-not $crashed -and -not $assertsFailed) {
        Write-Host ("PASS  {0,-32} {1}" -f $t.Name, $tail) -ForegroundColor Green
    } else {
        $reason = if ($crashed) { "CRASH (exit=$($p.ExitCode), no summary)" } else { "FAIL ($failures asserts)" }
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
