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
    .PARAMETER PlanAgent
        Optional custom agent name to pass to the plan phase.
        When specified, the plan agent runs with --agent <name>.
    .PARAMETER PlanEvalAgent
        Optional custom agent name to pass to the plan-eval phase.
        When specified, the plan-eval agent runs with --agent <name>.
    .PARAMETER BuildAgent
        Optional custom agent name to pass to the build phase (e.g. 'my-custom-agent').
        When specified, the build agent runs with --agent <name>.
    .PARAMETER ReviewAgent
        Optional custom agent name to pass to the review phase.
        When specified, the review agent runs with --agent <name>.
    .PARAMETER Resume
        Name of a previous run directory (e.g. '20260321-143022') under .dev-loop/ to resume.
        Skips preflight and reuses the existing manifest, picking up from the first incomplete phase.
    .EXAMPLE
        Invoke-DevLoop -SpecsDir ./specs -ProjectDir ~/my-project -GitPush
    .EXAMPLE
        Invoke-DevLoop -SpecsDir ./specs -ProjectDir ~/my-project -Model claude-sonnet-4
    .EXAMPLE
        Invoke-DevLoop -SpecsDir ./specs -ProjectDir ~/my-project -BuildAgent my-custom-agent
    .EXAMPLE
        Invoke-DevLoop -SpecsDir ./specs -ProjectDir ~/my-project -Resume 20260321-143022
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$SpecsDir,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
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

    . "$script:ModuleRoot\agents\_common.ps1"

    Assert-GhAuth

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

        # ── Run directory: resume existing or create new ────────────────
        if ($Resume) {
            $runDir = Join-Path $trackingRoot $Resume
            if (-not (Test-Path $runDir)) {
                throw "Resume directory '$runDir' does not exist. Check the name and try again."
            }
            $manifestFile = Join-Path $runDir 'manifest.json'
            if (-not (Test-Path $manifestFile)) {
                throw "Resume directory '$runDir' has no manifest.json — cannot resume."
            }
            Write-Host "Resuming run: $runDir" -ForegroundColor Yellow
        }
        else {
            $RunTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $runDir = Join-Path $trackingRoot $RunTimestamp
            New-Item -ItemType Directory -Path $runDir | Out-Null
            Write-Host "Run directory: $runDir" -ForegroundColor DarkGray
        }

        # ── Logging setup ─────────────────────────────────────────────────
        $LogFile = Join-Path $runDir 'dev-loop.log'
        Log -LogFile $LogFile "Logging to: $LogFile" DarkGray

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
            Log -LogFile $LogFile "  Started $phaseName for $specName" DarkYellow
        }

        function Complete-Phase($specName, $phaseName) {
            $m = Read-Manifest
            $spec = $m.specs | Where-Object { $_.name -eq $specName }
            $spec.phases.$phaseName.completed = (Get-Date -Format 'o')
            Save-Manifest $m
            Log -LogFile $LogFile "  Completed $phaseName for $specName" Green
        }

        # ── Pre-flight & manifest ─────────────────────────────────────
        $modelArgs = @{}
        if ($Model) { $modelArgs['Model'] = $Model }

        if ($Resume) {
            Log -LogFile $LogFile "Resuming — skipping preflight, reusing existing manifest" Yellow
        }
        else {
            $preflightLog = Join-Path $runDir 'preflight.log'
            Log -LogFile $LogFile "Preflight log: $preflightLog" DarkGray

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
                    name = $d.name
                    file = $d.file
                    phases = $phases
                }
            }

            $manifest = @{
                runId = (Split-Path $runDir -Leaf)
                specsDir = $SpecsDir
                phases = $phaseNames
                specs = $specs
            }

            Save-Manifest $manifest
            Log -LogFile $LogFile "Manifest written to: $manifestFile" Green
        }

        # ── Manifest-driven spec loop ─────────────────────────────────────
        $manifest = Read-Manifest
        $phaseOrder = @('plan', 'plan-eval', 'build', 'review')

        Log -LogFile $LogFile "========== STARTING SPEC LOOP ($($manifest.specs.Count) spec(s)) =========="  Cyan

        foreach ($spec in $manifest.specs) {
            $specName = $spec.name
            $specFile = $spec.file

            Log -LogFile $LogFile "────────── SPEC: $specName ──────────" Cyan
            $specLogFile = Join-Path $runDir "$specName.log"
            Log -LogFile $LogFile "Spec log: $specLogFile" DarkGray

            foreach ($phase in $phaseOrder) {
                # Skip phases that are already completed
                if ($spec.phases.$phase.completed) {
                    Log -LogFile $LogFile "  [$phase] already completed at $($spec.phases.$phase.completed) — skipping" DarkGreen
                    continue
                }

                Log -LogFile $LogFile "  [$phase] starting..." Yellow

                switch ($phase) {
                    'plan' {
                        Start-Phase $specName 'plan'
                        $planArgs = @{}
                        if ($Model) { $planArgs['Model'] = $Model }
                        if ($PlanAgent) { $planArgs['Agent'] = $PlanAgent }
                        & "$script:ModuleRoot\agents\plan.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile @planArgs
                        if ($LASTEXITCODE -ne 0) { throw "PLAN FAILED for $specName" }
                        Complete-Phase $specName 'plan'
                    }
                    'plan-eval' {
                        Start-Phase $specName 'plan-eval'
                        $planEvalArgs = @{}
                        if ($Model) { $planEvalArgs['Model'] = $Model }
                        if ($PlanEvalAgent) { $planEvalArgs['Agent'] = $PlanEvalAgent }
                        & "$script:ModuleRoot\agents\plan-eval.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile @planEvalArgs
                        if ($LASTEXITCODE -ne 0) { throw "PLAN-EVAL FAILED for $specName" }
                        Complete-Phase $specName 'plan-eval'
                    }
                    'build' {
                        Start-Phase $specName 'build'
                        $planFile = Join-Path $runDir "plan-$specName.md"
                        $buildIteration = 0
                        $maxBuildIterations = 20
                        while ($true) {
                            $planContent = Get-Content $planFile -Raw
                            if ($planContent -notmatch '- \[ \]') {
                                Log -LogFile $LogFile "  All plan tasks complete for $specName" Green
                                break
                            }
                            $buildIteration++
                            if ($buildIteration -gt $maxBuildIterations) {
                                throw "BUILD exceeded $maxBuildIterations iterations for $specName — possible infinite loop"
                            }
                            Log -LogFile $LogFile "  [build] iteration $buildIteration — unchecked tasks remain" Yellow
                            $buildArgs = @{}
                            if ($Model) { $buildArgs['Model'] = $Model }
                            if ($BuildAgent) { $buildArgs['Agent'] = $BuildAgent }
                            & "$script:ModuleRoot\agents\build.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile -GitPush:$GitPush @buildArgs
                            if ($LASTEXITCODE -ne 0) { throw "BUILD FAILED for $specName (iteration $buildIteration)" }
                        }
                        Complete-Phase $specName 'build'
                    }
                    'review' {
                        Start-Phase $specName 'review'
                        $reviewArgs = @{}
                        if ($Model) { $reviewArgs['Model'] = $Model }
                        if ($ReviewAgent) { $reviewArgs['Agent'] = $ReviewAgent }
                        & "$script:ModuleRoot\agents\review.ps1" -SpecFile $specFile -ProjectDir $ProjectDir -RunDir $runDir -LogFile $specLogFile -GitPush:$GitPush @reviewArgs
                        if ($LASTEXITCODE -ne 0) { throw "REVIEW FAILED for $specName" }
                        Complete-Phase $specName 'review'
                    }
                }
            }

            Log -LogFile $LogFile "  All phases complete for $specName" Green

            if ($PauseBetweenSpecs -gt 0) {
                Log -LogFile $LogFile "  Pausing ${PauseBetweenSpecs}s before next spec (Ctrl+C to stop)..." DarkYellow
                Start-Sleep -Seconds $PauseBetweenSpecs
            }
        }

        Log -LogFile $LogFile "========== ALL SPECS COMPLETE =========="  Magenta
    }
    catch {
        $errMsg = "FATAL [dev-loop]: $_"
        if ($LogFile) {
            Log -LogFile $LogFile $errMsg Red
        }
        else {
            Write-Host $errMsg -ForegroundColor Red
        }
        throw
    }
    finally {
        Pop-Location
    }
}

Export-ModuleMember -Function Invoke-DevLoop
