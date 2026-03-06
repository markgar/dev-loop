# dev-loop.ps1 — Thin launcher for the dev-loop module
# Usage: .\dev-loop.ps1 -SpecsDir <path> -ProjectDir <path> [-GitPush]

param(
    [Parameter(Mandatory)]
    [string]$SpecsDir,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [switch]$GitPush,

    [string]$Model
)

Import-Module "$PSScriptRoot/src/dev-loop/dev-loop.psd1" -Force

$modelArgs = @{}
if ($Model) { $modelArgs['Model'] = $Model }

try {
    Invoke-DevLoop -SpecsDir $SpecsDir -ProjectDir $ProjectDir -GitPush:$GitPush @modelArgs
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
