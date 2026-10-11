param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$cleanupRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$manifestPath = Join-Path $PSScriptRoot 'manifest_2026-10-11.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.workspace -ne $cleanupRoot) { throw 'Manifest workspace mismatch.' }
$obsoleteAssets = @(
    'intro_02_pixel_v1.png', 'intro_03_pixel_v1.png', 'intro_04_pixel_v1.png',
    'iron_mission_parts_pixel_v1.png', 'london_industrial_depot_v1.png',
    'mine_yard_pixel_v1.png', 'mine_yard_pixel_v2.png'
)
$reviewedFiles = [Collections.Generic.List[string]]::new()
foreach ($entry in $manifest.files) {
    $relative = [string]$entry.path
    $absolute = [IO.Path]::GetFullPath((Join-Path $cleanupRoot $relative))
    if (-not $absolute.StartsWith($cleanupRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Target outside workspace: $relative"
    }
    $allowed = $relative -match '^(output|tmp)/' -or $relative -match '^reports/.*\.(log|err)$'
    if ($relative -match '^assets/phase2/([^/]+)$') {
        $allowed = ($Matches[1] -replace '\.import$', '') -in $obsoleteAssets
    }
    if (-not $allowed -or $relative -match '(^|/)\.gdignore$|^tmp/cart_validation_project/') {
        throw "Unapproved cleanup location: $relative"
    }
    # Validate every ancestor, so a junction cannot redirect a reviewed file elsewhere.
    $ancestor = Split-Path -Parent $absolute
    while ($ancestor -ne $cleanupRoot) {
        if ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to traverse a directory link: $ancestor"
        }
        $ancestor = Split-Path -Parent $ancestor
    }
    $item = Get-Item -LiteralPath $absolute -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Expected a regular file: $relative"
    }
    if ((Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash -ne $entry.sha256) {
        throw "File changed since review: $relative"
    }
    $reviewedFiles.Add($absolute)
}
if (-not $Apply) {
    Write-Output "Verified $($reviewedFiles.Count) files. Use -Apply to execute this reviewed manifest."
    return
}
# Individual regular files only; never recursively remove a folder or follow a link.
foreach ($absolute in $reviewedFiles) {
    Remove-Item -LiteralPath $absolute -Force
}
Write-Output "Removed $($reviewedFiles.Count) reviewed files."
