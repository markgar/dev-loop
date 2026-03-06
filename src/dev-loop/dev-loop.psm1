# dev-loop.psm1 — Invoke-DevLoop: manifest-driven Plan → Build → Review → Test loop

$script:ModuleRoot = $PSScriptRoot

function Invoke-DevLoop {
    <#
    .SYNOPSIS
        Automated development loop powered by GitHub Copilot CLI.
    .DESCRIPTION
        Processes numbered spec files through plan, build, review, and test phases
        using GitHub Copilot CLI agents. Each phase shells out to copilot with a
        crafted prompt. Specs are processed one at a time, all phases to completion.
    .PARAMETER SpecsDir
        Path to the directory containing numbered spec files (NN-slug.md) and optional CONSTITUTION.md.
    .PARAMETER ProjectDir
        Path to the target project directory. Must be a git repository.
    .PARAMETER GitPush
        If specified, git push is performed after each build and review phase.
    .EXAMPLE
        Invoke-DevLoop -SpecsDir ./specs -ProjectDir ~/my-project
    .PARAMETER Model
        AI model to use (e.g. claude-sonnet-4, gpt-5.1). If omitted, Copilot CLI uses its default.
        Run 'copilot --help' to see available models.
    .EXAMPLE
        Invoke-DevLoop -SpecsDir ./specs -ProjectDir ~/my-project -GitPush
    .EXAMPLE
        Invoke-DevLoop -SpecsDir ./specs -ProjectDir ~/my-project -Model claude-sonnet-4
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SpecsDir,

        [Parameter(Mandatory)]
        [string]$ProjectDir,

        [switch]$GitPush,

        [string]$Model
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8

    $SpecsDir = (Resolve-Path $SpecsDir).Path
    $ProjectDir = (Resolve-Path $ProjectDir).Path

    # ── Validate ProjectDir is a git repository ───────────────────────
    if (-not (Test-Path (Join-Path $ProjectDir '.git'))) {
        throw "ProjectDir '$ProjectDir' is not a git repository. Please run 'git init' first."
    }

    # ── Validate git remote exists when -GitPush is requested ─────────
    if ($GitPush) {
        $remotes = git -C $ProjectDir remote 2>$null
        if (-not $remotes) {
            throw "-GitPush was specified but no git remote is configured in '$ProjectDir'. Add a remote first (e.g., git remote add origin <url>)."
        }
    }

    Push-Location $script:ModuleRoot

    try {

        # ── Tracking directory setup ──────────────────────────────────────
        $trackingRoot = Join-Path $ProjectDir '.dev-loop'
        if (-not (Test-Path $trackingRoot)) {
            New-Item -ItemType Directory -Path $trackingRoot | Out-Null
            Write-Host "Created tracking directory: $trackingRoot" -ForegroundColor DarkGray
        }

        # ── Ensure .dev-loop/ is in .gitignore before any commits ─────────
        $gitignorePath = Join-Path $ProjectDir '.gitignore'
        $devLoopPattern = '.dev-loop/'
        $needsEntry = $true
        if (Test-Path $gitignorePath) {
            $lines = Get-Content $gitignorePath
            if ($lines -contains $devLoopPattern) {
                $needsEntry = $false
            }
        }
        if ($needsEntry) {
            Add-Content -Path $gitignorePath -Value "`n$devLoopPattern"
            Write-Host "Added .dev-loop/ to .gitignore" -ForegroundColor DarkGray
        }

        # Derive a timestamp for this run and create the run directory
        $RunTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $runDir = Join-Path $trackingRoot $RunTimestamp
        New-Item -ItemType Directory -Path $runDir | Out-Null
        Write-Host "Run directory: $runDir" -ForegroundColor DarkGray

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
        $modelArgs = @{}
        if ($Model) { $modelArgs['Model'] = $Model }

        & "$script:ModuleRoot\agents\preflight.ps1" -SpecsDir $SpecsDir -ProjectDir $ProjectDir -RunDir $runDir -LogFile $preflightLog @modelArgs
        if ($LASTEXITCODE -ne 0) { throw "Preflight failed." }

        # ── Build manifest from preflight discovery ───────────────────────
        $discoveryFile = Join-Path $runDir 'spec-discovery.json'
        if (-not (Test-Path $discoveryFile)) {
            throw "No spec-discovery.json found after preflight — cannot continue."
        }

        $discovered = Get-Content $discoveryFile -Raw | ConvertFrom-Json
        $phaseNames = @('plan', 'plan-eval', 'build', 'review')

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
        $phaseOrder = @('plan', 'plan-eval', 'build', 'review')

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
                        & "$script:ModuleRoot\agents\plan.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile @modelArgs
                        if ($LASTEXITCODE -ne 0) { throw "PLAN FAILED for $specName" }
                        Stamp-Phase $specName 'plan'
                    }
                    'plan-eval' {
                        Start-Phase $specName 'plan-eval'
                        & "$script:ModuleRoot\agents\plan-eval.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile @modelArgs
                        if ($LASTEXITCODE -ne 0) { throw "PLAN-EVAL FAILED for $specName" }
                        Stamp-Phase $specName 'plan-eval'
                    }
                    'build' {
                        Start-Phase $specName 'build'
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
                            & "$script:ModuleRoot\agents\build.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile -GitPush:$GitPush @modelArgs
                            if ($LASTEXITCODE -ne 0) { throw "BUILD FAILED for $specName (iteration $buildIteration)" }
                        }
                        Stamp-Phase $specName 'build'
                    }
                    'review' {
                        Start-Phase $specName 'review'
                        & "$script:ModuleRoot\agents\review.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile -GitPush:$GitPush @modelArgs
                        if ($LASTEXITCODE -ne 0) { throw "REVIEW FAILED for $specName" }
                        Stamp-Phase $specName 'review'
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
}

Export-ModuleMember -Function Invoke-DevLoop
