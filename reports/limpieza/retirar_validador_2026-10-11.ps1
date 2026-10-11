$ErrorActionPreference = 'Stop'
$cleanupRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$temporaryRoot = [IO.Path]::GetFullPath((Join-Path $cleanupRoot 'tmp/cart_validation_project'))
if (-not $temporaryRoot.StartsWith($cleanupRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Validation directory must stay inside the project.'
}
$active = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -like '*Godot*' -and $_.CommandLine -and
    ($_.CommandLine.Replace('\', '/') -like '*tmp/cart_validation_project*')
})
if ($active.Count) { throw 'A validation process is still running; do not clean its directory.' }
if (-not (Test-Path -LiteralPath $temporaryRoot)) { return }
$stack = [Collections.Generic.Stack[string]]::new()
$stack.Push($temporaryRoot)
$files = [Collections.Generic.List[string]]::new()
$directories = [Collections.Generic.List[string]]::new()
$links = [Collections.Generic.List[string]]::new()
while ($stack.Count) {
    $directory = $stack.Pop()
    $directories.Add($directory)
    foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
        $absolute = [IO.Path]::GetFullPath($item.FullName)
        if (-not $absolute.StartsWith($temporaryRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Target escapes validation directory: $absolute"
        }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # Links point back into source folders; remove the link itself, never its contents.
            $expectedTarget = [IO.Path]::GetFullPath((Join-Path $cleanupRoot $item.Name))
            if ($item.Name -notin @('assets','scenes','scripts','tests','shaders','output') -or
                [IO.Path]::GetFullPath([string]$item.Target[0]) -ne $expectedTarget) {
                throw "Unexpected directory link: $absolute"
            }
            $links.Add($absolute)
        } elseif ($item.PSIsContainer) {
            $stack.Push($absolute)
        } else {
            $files.Add($absolute)
        }
    }
}
$size = ($files | ForEach-Object { (Get-Item -LiteralPath $_ -Force).Length } | Measure-Object -Sum).Sum
$record = [ordered]@{directory=$temporaryRoot;files=@($files);unlinked_directories=@($links);bytes=$size}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'validador_retirado_2026-10-11.json') -Encoding UTF8
foreach ($file in $files) { Remove-Item -LiteralPath $file -Force }
foreach ($link in $links) { [IO.Directory]::Delete($link, $false) }
foreach ($directory in ($directories | Sort-Object Length -Descending)) {
    [IO.Directory]::Delete($directory, $false)
}
Write-Output "Removed temporary validator: $($files.Count) files, $($links.Count) links. Source directories preserved."
