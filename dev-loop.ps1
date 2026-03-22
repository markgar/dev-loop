# dev-loop.ps1 — Thin launcher for the dev-loop module
# Usage: .\dev-loop.ps1 -SpecsDir <path> -ProjectDir <path> [-GitPush]

param(
    [Parameter(Mandatory)]
    [string]$SpecsDir,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [switch]$GitPush,

    [string]$Model,

    [string]$PlanAgent,

    [string]$PlanEvalAgent,

    [string]$BuildAgent,

    [string]$ReviewAgent,

    [string]$Resume,

    [int]$PauseBetweenSpecs = 0
)

Import-Module "$PSScriptRoot/src/dev-loop/dev-loop.psd1" -Force

$modelArgs = @{}
if ($Model) { $modelArgs['Model'] = $Model }
if ($PlanAgent) { $modelArgs['PlanAgent'] = $PlanAgent }
if ($PlanEvalAgent) { $modelArgs['PlanEvalAgent'] = $PlanEvalAgent }
if ($BuildAgent) { $modelArgs['BuildAgent'] = $BuildAgent }
if ($ReviewAgent) { $modelArgs['ReviewAgent'] = $ReviewAgent }
if ($Resume) { $modelArgs['Resume'] = $Resume }
if ($PauseBetweenSpecs -gt 0) { $modelArgs['PauseBetweenSpecs'] = $PauseBetweenSpecs }

try {
    Invoke-DevLoop -SpecsDir $SpecsDir -ProjectDir $ProjectDir -GitPush:$GitPush @modelArgs
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
