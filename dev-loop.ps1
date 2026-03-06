# dev-loop.ps1 — Thin launcher for the dev-loop module
# Usage: .\dev-loop.ps1 -SpecsDir <path> -ProjectDir <path> [-GitPush]

param(
    [Parameter(Mandatory)]
    [string]$SpecsDir,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [switch]$GitPush
)

Import-Module "$PSScriptRoot/src/dev-loop/dev-loop.psd1" -Force

try {
    Invoke-DevLoop -SpecsDir $SpecsDir -ProjectDir $ProjectDir -GitPush:$GitPush
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
