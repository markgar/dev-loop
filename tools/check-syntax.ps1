# check-syntax.ps1 — Parse-check all PowerShell source files in the repo
$repoRoot = Split-Path $PSScriptRoot -Parent
$files = @(Get-ChildItem -Path (Join-Path $repoRoot 'src') -Recurse -Include '*.ps1','*.psm1')
# Include the launcher script at repo root
$launcher = Join-Path $repoRoot 'dev-loop.ps1'
if (Test-Path $launcher) { $files += Get-Item $launcher }
$hasErrors = $false
foreach ($f in $files) {
    $path = $f.FullName
    $relativePath = $path.Substring($repoRoot.Length + 1)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $hasErrors = $true
        Write-Host "ERRORS in $relativePath" -ForegroundColor Red
        foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }
    } else {
        Write-Host "OK: $relativePath" -ForegroundColor Green
    }
}
if ($hasErrors) { exit 1 }
