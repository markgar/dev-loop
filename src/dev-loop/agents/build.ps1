# build.ps1 — Pick up the next backlog story and build it
# Usage: .\build.ps1 -SpecFile <path> -ProjectDir <path> -RunDir <path>

param(
    [Parameter(Mandatory)]
    [string]$SpecFile,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [Parameter(Mandatory)]
    [string]$RunDir,

    [Parameter(Mandatory)]
    [string]$LogFile,

    [switch]$GitPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Work from the target project directory
Push-Location $ProjectDir

try {
    $specBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SpecFile)
    $SpecsDir = Split-Path $SpecFile -Parent
    $PlanFile = Join-Path $RunDir "plan-$specBaseName.md"

    # ── Logging ───────────────────────────────────────────────────────
    function Log { param([string]$Message, [string]$Color = 'White')
        Write-Host $Message -ForegroundColor $Color
        "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $LogFile -Append
    }

    Log "========== BUILD PHASE ==========" Cyan
    Log "Building spec : $SpecFile" DarkGray
    Log "Using plan    : $PlanFile" DarkGray
    $constitutionPath = Join-Path $SpecsDir 'CONSTITUTION.md'
    $devLoopRoot = Split-Path $RunDir -Parent
    $gitInstruction = if ($GitPush) { 'then git commit your work and push to the remote' } else { 'then git commit your work' }
    & copilot -p @"
You are a builder agent. Your job is to implement one spec at a time, using a plan that was already built for you.

Before building, read the project constitution at $constitutionPath — its Project Principles are inviolable constraints. Every change you make must conform to them.

The spec you are implementing is at: $SpecFile
The implementation plan is at: $PlanFile

SCOPE CONSTRAINT: You must only consider these sources of information when building:
1. The spec file above — this is the ONLY spec you are implementing.
2. The plan file above — this is the ONLY plan you are following.
3. The constitution file.
4. Any existing code in the repository.
Do NOT read, reference, or implement work from any other spec files. Other specs are out of scope for this build session.

Read the plan file above. It contains a checklist of tasks using ``- [ ]`` checkboxes. Find the first two unchecked tasks (``- [ ]``) and build them both, in order. If only one unchecked task remains, build just that one. Reference $devLoopRoot\ENGINEERING_STANDARDS.md (if it exists) for guidance. Aim for: fail-fast validation, no magic strings, immutability by default, inward-pointing dependencies, honest type signatures, and no silent fallbacks. Don't break existing functionality — run any existing tests before and after your changes. If any tests fail after your changes, fix your code until all tests pass. If your changes introduce new tooling or build artifacts that should not be tracked (e.g., .pytest_cache/, dist/, build/, .venv/, *.egg-info/, node_modules/, bin/, obj/), add the appropriate patterns to .gitignore. If you add new patterns, also run ``git rm --cached`` on any matching files already tracked by git. When you finish each task, check it off in the plan file by changing its ``- [ ]`` to ``- [x]``, $gitInstruction.
"@ --yolo 2>&1 | ForEach-Object { Write-Host $_; $_ | Out-File -FilePath $LogFile -Append }
    if ($LASTEXITCODE -ne 0) { Log "BUILD FAILED (exit $LASTEXITCODE)" Red; exit 1 }
}
catch {
    $errMsg = "FATAL [build]: $_"
    Write-Host $errMsg -ForegroundColor Red
    "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $LogFile -Append
    throw
}
finally {
    Pop-Location
}
