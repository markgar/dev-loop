# dev-loop.ps1 — Manifest-driven Plan → Build → Review → Test loop
# Usage: .\dev-loop.ps1 -SpecsDir <path> -ProjectDir <path>

param(
    [Parameter(Mandatory)]
    [string]$SpecsDir,

    [Parameter(Mandatory)]
    [string]$ProjectDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$SpecsDir = (Resolve-Path $SpecsDir).Path
$ProjectDir = (Resolve-Path $ProjectDir).Path

Push-Location $PSScriptRoot

try {

    # ── Tracking directory setup ──────────────────────────────────────
    $trackingRoot = Join-Path $ProjectDir '.dev-loop'
    if (-not (Test-Path $trackingRoot)) {
        New-Item -ItemType Directory -Path $trackingRoot | Out-Null
        Write-Host "Created tracking directory: $trackingRoot" -ForegroundColor DarkGray  # Log not available yet
    }

    # Derive a timestamp for this run and create the run directory
    $RunTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $runDir = Join-Path $trackingRoot $RunTimestamp
    New-Item -ItemType Directory -Path $runDir | Out-Null
    Write-Host "Run directory: $runDir" -ForegroundColor DarkGray  # Log not available yet

    # ── Branch setup (isolate work in the target project) ─────────────
    $branchName = 'dev-loop'
    $currentBranch = (git -C $ProjectDir branch --show-current 2>$null)
    if ($currentBranch -ne $branchName) {
        # Create or switch to the dev-loop branch
        $branchExists = git -C $ProjectDir branch --list $branchName 2>$null
        if ($branchExists) {
            git -C $ProjectDir checkout $branchName
        } else {
            git -C $ProjectDir checkout -b $branchName
        }
        Write-Host "On branch: $branchName" -ForegroundColor Green  # Log not available yet
    } else {
        Write-Host "Already on branch: $branchName" -ForegroundColor Green  # Log not available yet
    }

    # ── Logging setup ─────────────────────────────────────────────────
    $logFile = Join-Path $runDir 'dev-loop.log'
    function Log { param([string]$Message, [string]$Color = 'White')
        Write-Host $Message -ForegroundColor $Color
        "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $logFile -Append
    }
    Log "Logging to: $logFile" DarkGray

    # ── Manifest helpers ──────────────────────────────────────────────
    $manifestFile = Join-Path $runDir 'manifest.json'

    function Read-Manifest {
        Get-Content $manifestFile -Raw | ConvertFrom-Json
    }

    function Save-Manifest($m) {
        $m | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestFile -Encoding UTF8
    }

    function Start-Phase($specName, $phaseName) {
        $m = Read-Manifest
        $spec = $m.specs | Where-Object { $_.name -eq $specName }
        $spec.phases.$phaseName.started = (Get-Date -Format 'o')
        Save-Manifest $m
        Log "  Started $phaseName for $specName" DarkYellow
    }

    function Stamp-Phase($specName, $phaseName) {
        $m = Read-Manifest
        $spec = $m.specs | Where-Object { $_.name -eq $specName }
        $spec.phases.$phaseName.completed = (Get-Date -Format 'o')
        Save-Manifest $m
        Log "  Stamped $phaseName for $specName" Green
    }

    # ── Pre-flight (discovers specs, constitution check) ────────────
    $preflightLog = Join-Path $runDir 'preflight.log'
    Log "Preflight log: $preflightLog" DarkGray
    & "$PSScriptRoot\agents\preflight.ps1" -SpecsDir $SpecsDir -ProjectDir $ProjectDir -RunDir $runDir -LogFile $preflightLog
    if ($LASTEXITCODE -ne 0) { exit 1 }

    # ── Build manifest from preflight discovery ───────────────────────
    $discoveryFile = Join-Path $runDir 'spec-discovery.json'
    if (-not (Test-Path $discoveryFile)) {
        Log "No spec-discovery.json found after preflight — cannot continue." Red
        exit 1
    }

    $discovered = Get-Content $discoveryFile -Raw | ConvertFrom-Json
    $phaseNames = @('plan', 'plan-eval', 'build', 'review', 'test')

    $specs = @()
    foreach ($d in $discovered) {
        $phases = [ordered]@{}
        foreach ($p in $phaseNames) {
            $phases[$p] = [ordered]@{ started = $null; completed = $null }
        }
        $specs += @{
            name   = $d.name
            file   = $d.file
            phases = $phases
        }
    }

    $manifest = @{
        runId    = (Split-Path $runDir -Leaf)
        specsDir = $SpecsDir
        phases   = $phaseNames
        specs    = $specs
    }

    Save-Manifest $manifest
    Log "Manifest written to: $manifestFile" Green

    # ── Manifest-driven spec loop ─────────────────────────────────────
    $manifest = Read-Manifest
    $phaseOrder = @('plan', 'plan-eval', 'build', 'review', 'test')

    Log "========== STARTING SPEC LOOP ($($manifest.specs.Count) spec(s)) ==========" Cyan

    foreach ($spec in $manifest.specs) {
        $specName = $spec.name
        $specFile = $spec.file

        Log "────────── SPEC: $specName ──────────" Cyan
        $specLogFile = Join-Path $runDir "$specName.log"
        Log "Spec log: $specLogFile" DarkGray

        foreach ($phase in $phaseOrder) {
            # Skip phases that are already completed
            if ($spec.phases.$phase.completed) {
                Log "  [$phase] already completed at $($spec.phases.$phase.completed) — skipping" DarkGreen
                continue
            }

            Log "  [$phase] starting..." Yellow

            switch ($phase) {
                'plan' {
                    Start-Phase $specName 'plan'
                    & "$PSScriptRoot\agents\plan.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile
                    if ($LASTEXITCODE -ne 0) { Log "PLAN FAILED for $specName" Red; exit 1 }
                    Stamp-Phase $specName 'plan'
                }
                'plan-eval' {
                    Start-Phase $specName 'plan-eval'
                    & "$PSScriptRoot\agents\plan-eval.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile
                    if ($LASTEXITCODE -ne 0) { Log "PLAN-EVAL FAILED for $specName" Red; exit 1 }
                    Stamp-Phase $specName 'plan-eval'
                }
                'build' {
                    Start-Phase $specName 'build'
                    # Loop build until all plan tasks are checked off
                    $planFile = Join-Path $runDir "plan-$specName.md"
                    $buildIteration = 0
                    while ($true) {
                        $planContent = Get-Content $planFile -Raw
                        if ($planContent -notmatch '- \[ \]') {
                            Log "  All plan tasks complete for $specName" Green
                            break
                        }
                        $buildIteration++
                        Log "  [build] iteration $buildIteration — unchecked tasks remain" Yellow
                        & "$PSScriptRoot\agents\build.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile
                        if ($LASTEXITCODE -ne 0) { Log "BUILD FAILED for $specName (iteration $buildIteration)" Red; exit 1 }
                    }
                    Stamp-Phase $specName 'build'
                }
                'review' {
                    Start-Phase $specName 'review'
                    & "$PSScriptRoot\agents\review.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile
                    if ($LASTEXITCODE -ne 0) { Log "REVIEW FAILED for $specName" Red; exit 1 }
                    Stamp-Phase $specName 'review'
                }
                'test' {
                    # DISABLED — uncomment to re-enable test phase
                    # Start-Phase $specName 'test'
                    # & "$PSScriptRoot\agents\test.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile
                    # if ($LASTEXITCODE -ne 0) { Log "TEST FAILED for $specName" Red; exit 1 }
                    # Stamp-Phase $specName 'test'
                    Log "  [test] SKIPPED (disabled)" DarkGray
                }
            }
        }

        Log "  All phases complete for $specName" Green
    }

    Log "========== ALL SPECS COMPLETE ==========" Magenta
}
catch {
    $errMsg = "FATAL [dev-loop]: $_"
    Write-Host $errMsg -ForegroundColor Red
    if ($logFile -and (Test-Path (Split-Path $logFile))) {
        "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $logFile -Append
    }
    throw
}
finally {
    Pop-Location
}
