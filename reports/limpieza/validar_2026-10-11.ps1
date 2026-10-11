$ErrorActionPreference = 'Stop'
$cleanupRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$engine = 'F:/Descargas/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
$validationRoot = Join-Path $cleanupRoot 'tmp/cart_validation_project'
$cache = Get-Item -LiteralPath (Join-Path $validationRoot '.godot') -Force
if ($cache.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Validation requires its own cache.' }
$cases = @(
    @{Name='phase_one_smoke_test'; Args=@()},
    @{Name='phase2_factory_test'; Args=@()},
    @{Name='chapter_journal_flow_test'; Args=@()},
    @{Name='chapter_journal_flow_test'; Args=@('--read-chapter')},
    @{Name='engine_house_test'; Args=@()},
    @{Name='engine_house_test'; Args=@('--read-engine-house')},
    @{Name='iron_mission_test'; Args=@()},
    @{Name='iron_mission_test'; Args=@('--read-iron')},
    @{Name='chapter_navigation_test'; Args=@()},
    @{Name='chapter_navigation_test'; Args=@('--read-navigation')}
)
$results = @()
foreach ($case in $cases) {
    $label = $case.Name + $(if ($case.Args.Count) { '_read' } else { '' })
    $outFile = Join-Path $PSScriptRoot "2026-10-11_$label.log"
    $errFile = Join-Path $PSScriptRoot "2026-10-11_$label.err"
    $arguments = @('--headless', '--path', 'tmp/cart_validation_project', "res://tests/$($case.Name).tscn")
    if ($case.Args.Count) { $arguments += '--'; $arguments += $case.Args }
    $runner = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $cleanupRoot -WindowStyle Hidden -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
    $processHandle = $runner.Handle
    if (-not $runner.WaitForExit(60000)) { throw "Timeout in $label. Inspect the validation process before continuing." }
    $runner.WaitForExit()
    $outputText = [IO.File]::ReadAllText($outFile)
    $errorText = [IO.File]::ReadAllText($errFile)
    $combined = $outputText + $errorText
    $passed = $runner.ExitCode -eq 0 -and $combined -match '\bOK\b|\b0 failures\b|ALL CHECKS PASSED' -and $combined -notmatch 'SCRIPT ERROR|ERROR:|FAILED|Assertion failed|[1-9]\d* failures'
    $summary = @($outputText -split '\r?\n' | Where-Object { $_ -match '\bOK\b|checks|failures|PASSED' })
    $results += [pscustomobject]@{test=$label;passed=$passed;exit_code=$runner.ExitCode;summary=$summary;stderr=$errorText.Trim()}
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'pruebas_2026-10-11.json') -Encoding UTF8
    Write-Output "$label : $($summary -join ' ')"
    if (-not $passed) { throw "Validation failed in $label. See log and error file." }
}
Write-Output "All $($results.Count) validation runs passed."
