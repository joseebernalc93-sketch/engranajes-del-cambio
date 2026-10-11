param([string]$GodotExecutable = 'godot')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$validationRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'tmp/cart_validation_project'))
if (-not $validationRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Validation must stay inside this workspace.' }
[IO.Directory]::CreateDirectory($validationRoot) | Out-Null
$validationCache = Join-Path $validationRoot '.godot'
if (Test-Path -LiteralPath $validationCache) {
    if ((Get-Item -LiteralPath $validationCache -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Validation must use its own .godot cache, not a directory link to the active project.'
    }
}
$encoding = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $projectRoot 'tmp/.gdignore'), '', $encoding)
[IO.File]::WriteAllText((Join-Path $validationRoot '.gdignore'), '', $encoding)
foreach ($folder in @('assets','scenes','scripts','shaders','tests','output')) {
    $source = Join-Path $projectRoot $folder
    [IO.Directory]::CreateDirectory($source) | Out-Null
    $target = Join-Path $validationRoot $folder
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Junction -Path $target -Value $source | Out-Null
    } else {
        $item = Get-Item -LiteralPath $target -Force
        if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or [IO.Path]::GetFullPath([string]$item.Target) -ne [IO.Path]::GetFullPath($source)) { throw "Unexpected validation directory: $target" }
    }
}
[IO.File]::WriteAllText((Join-Path $projectRoot 'output/.gdignore'), '', $encoding)
$configuration = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot'))
$configuration = $configuration -replace '(?m)^config/name=.*$', 'config/name="EngranajesDelCambio_CleanupValidation"'
[IO.File]::WriteAllText((Join-Path $validationRoot 'project.godot'), $configuration, $encoding)
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination (Join-Path $validationRoot 'icon.svg')
& $GodotExecutable --headless --path $validationRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot resource import failed.' }
Write-Output 'Validation project ready. Player saves use a separate application directory.'
