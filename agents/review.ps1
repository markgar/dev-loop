# review.ps1 — Senior SWE code review, fix, and capture learnings
# Usage: .\review.ps1 -SpecFile <path> -ProjectDir <path> -RunDir <path>

param(
    [Parameter(Mandatory)]
    [string]$SpecFile,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [Parameter(Mandatory)]
    [string]$RunDir,

    [Parameter(Mandatory)]
    [string]$LogFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Work from the target project directory
Push-Location $ProjectDir

try {
    $SpecsDir = Split-Path $SpecFile -Parent

    # ── Logging ───────────────────────────────────────────────────────
    function Log { param([string]$Message, [string]$Color = 'White')
        Write-Host $Message -ForegroundColor $Color
        "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $LogFile -Append
    }

    Log "========== REVIEW PHASE ==========" Yellow
    Log "Reviewing spec: $SpecFile" DarkGray
    $constitutionPath = Join-Path $SpecsDir 'CONSTITUTION.md'
    $devLoopRoot = Split-Path $RunDir -Parent
    & copilot -p @"
Before reviewing, read the project constitution at $constitutionPath — its Project Principles are inviolable constraints. Flag any code that violates them.

The spec being implemented is at: $SpecFile
Focus your review on the code changes related to this spec.

Look at the codebase and act like a Senior SWE. You don't let anything go. You know SOLID, SRP, DIP, and all the best practices for architecture and software engineering. Focus primarily on recently changed code, but flag systemic issues if you spot them. Review the code and fix it to be the way it really should be. When you're done, generalize what you learned into $devLoopRoot\ENGINEERING_STANDARDS.md so the builder can reference it on future builds. Only add generic findings, not one-off bug fixes. If the file already exists, update it. Merge duplicates. Also, if your review changes architecture, key conventions, or workflow, update .github/copilot-instructions.md to match — keep that file minimal (project identity, architecture rules, code conventions, workflow only). Finally, ensure the project has minimal but current documentation: a README.md (what it does, how to install, how to use), and if a CHANGELOG.md exists keep it up to date. Don't over-document — just enough for a new contributor to get oriented. Also ensure .gitignore covers all tooling and build artifacts for the project's language/framework (e.g., .pytest_cache/, dist/, build/, .venv/, *.egg-info/, node_modules/, bin/, obj/, etc.) — add missing patterns if needed. If you add new patterns to .gitignore, check whether any matching files are already tracked by git. If so, remove them from tracking with ``git rm --cached <path>`` (this removes them from git without deleting them from disk). Git commit your changes and push to the remote when done.
"@ --yolo 2>&1 | ForEach-Object { Write-Host $_; $_ | Out-File -FilePath $LogFile -Append }
    if ($LASTEXITCODE -ne 0) { Log "REVIEW FAILED (exit $LASTEXITCODE)" Red; exit 1 }
}
catch {
    $errMsg = "FATAL [review]: $_"
    Write-Host $errMsg -ForegroundColor Red
    "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $LogFile -Append
    throw
}
finally {
    Pop-Location
}
