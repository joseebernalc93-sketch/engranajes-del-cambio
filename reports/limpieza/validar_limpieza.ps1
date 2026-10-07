$ErrorActionPreference = 'Stop'
$engine = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
$cases = @(
    @{Name='phase_one_smoke_test'; Args=@()},
    @{Name='wheelwright_forge_test'; Args=@()},
    @{Name='rope_puzzle_test'; Args=@()},
    @{Name='lumber_puzzle_test'; Args=@()},
    @{Name='mill_repair_test'; Args=@()},
    @{Name='mill_operation_controls_test'; Args=@()},
    @{Name='boat_travel_test'; Args=@()},
    @{Name='passenger_coach_test'; Args=@()},
    @{Name='five_puzzles_pause_test'; Args=@()},
    @{Name='chapter_journal_flow_test'; Args=@()},
    @{Name='chapter_journal_flow_test'; Args=@('--read-chapter')},
    @{Name='session_flow_test'; Args=@()},
    @{Name='session_flow_test'; Args=@('--read-session')}
)
$results = @()
foreach ($case in $cases) {
    $label = $case.Name + $(if ($case.Args.Count) { '_read' } else { '' })
    $outputPath = Join-Path (Get-Location).Path "reports/limpieza/$label.log"
    $errorPath = Join-Path (Get-Location).Path "reports/limpieza/$label.err"
    $arguments = @('--headless','--path','tmp/cart_validation_project',"res://tests/$($case.Name).tscn")
    if ($case.Args.Count) { $arguments += '--'; $arguments += $case.Args }
    $runner = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath -PassThru
    if (-not $runner.WaitForExit(90000)) {
        $engines = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'Godot_v4.7.2-stable_win64.exe' -and $_.CommandLine -like '*tmp/cart_validation_project*' -and $_.CommandLine.Contains("res://tests/$($case.Name).tscn") }
        foreach ($process in $engines) { Stop-Process -Id $process.ProcessId }
        throw "La prueba $label superó el límite; revisar su log."
    }
    $combined = [IO.File]::ReadAllText($outputPath) + [IO.File]::ReadAllText($errorPath)
    $passed = $combined -match '\bOK\b' -and $combined -notmatch 'SCRIPT ERROR|ERROR:|FAILED|Assertion failed'
    $results += [pscustomobject]@{Test=$label; Passed=$passed}
    $results | ConvertTo-Json | Set-Content -LiteralPath reports/limpieza/pruebas.json -Encoding UTF8
    if (-not $passed) { Get-Content -LiteralPath $outputPath -Encoding UTF8; Get-Content -LiteralPath $errorPath -Encoding UTF8; throw "Fallo en $label" }
    Write-Output "OK: $label"
}
Write-Output "VALIDACIÓN COMPLETA: $($results.Count) comprobaciones aprobadas."
