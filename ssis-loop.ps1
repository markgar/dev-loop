# ssis-loop.ps1 — Entry point for SSIS migration analysis
# Usage: .\ssis-loop.ps1 -DtsxPath <path> -ProjectDir <path> [-Model <model>]

param(
    [Parameter(Mandatory)]
    [string]$DtsxPath,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [string]$Model
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Resolve paths ─────────────────────────────────────────────────
$DtsxPath   = (Resolve-Path $DtsxPath).Path
$ProjectDir = (Resolve-Path $ProjectDir).Path

# ── Source shared utilities ───────────────────────────────────────
. "$PSScriptRoot/src/dev-loop/agents/_common.ps1"

Assert-GhAuth

# ── Tracking directory setup ──────────────────────────────────────
$trackingRoot = Join-Path $ProjectDir '.dev-loop'
if (-not (Test-Path $trackingRoot)) {
    New-Item -ItemType Directory -Path $trackingRoot | Out-Null
    Write-Host "Created tracking directory: $trackingRoot" -ForegroundColor DarkGray
}

# ── Ensure .dev-loop/ is in .gitignore ────────────────────────────
$gitignorePath  = Join-Path $ProjectDir '.gitignore'
$devLoopPattern = '.dev-loop/'
$needsEntry     = $true
if (Test-Path $gitignorePath) {
    $lines = Get-Content $gitignorePath
    if ($lines -contains $devLoopPattern) { $needsEntry = $false }
}
if ($needsEntry) {
    Add-Content -Path $gitignorePath -Value "`n$devLoopPattern"
    Write-Host "Added .dev-loop/ to .gitignore" -ForegroundColor DarkGray
}

# ── Run directory & logging ───────────────────────────────────────
$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir       = Join-Path $trackingRoot $runTimestamp
New-Item -ItemType Directory -Path $runDir | Out-Null
Write-Host "Run directory: $runDir" -ForegroundColor DarkGray

$logFile = Join-Path $runDir 'ssis-loop.log'
Log -LogFile $logFile "SSIS migration analysis started" Cyan
Log -LogFile $logFile "DTSX: $DtsxPath" DarkGray
Log -LogFile $logFile "Project: $ProjectDir" DarkGray

# ── Run cycle-analysis agent ─────────────────────────────────────
$modelArgs = @{}
if ($Model) { $modelArgs['Model'] = $Model }

try {
    & "$PSScriptRoot/src/dev-loop/ssis-agents/cycle-analysis.ps1" `
        -DtsxPath   $DtsxPath `
        -ProjectDir $ProjectDir `
        -RunDir     $runDir `
        -LogFile    $logFile `
        @modelArgs

    Log -LogFile $logFile "SSIS cycle analysis complete" Green
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
