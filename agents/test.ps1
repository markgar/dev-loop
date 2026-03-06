# test.ps1 — Build and run tests across the codebase
# Usage: .\test.ps1 -SpecFile <path> -ProjectDir <path> -RunDir <path>

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
    $SpecsDir = Split-Path $SpecFile -Parent

    # ── Logging ───────────────────────────────────────────────────────
    function Log { param([string]$Message, [string]$Color = 'White')
        Write-Host $Message -ForegroundColor $Color
        "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $LogFile -Append
    }

    Log "========== TEST PHASE ==========" Green
    Log "Testing spec  : $SpecFile" DarkGray
    $constitutionPath = Join-Path $SpecsDir 'CONSTITUTION.md'
    $devLoopRoot = Split-Path $RunDir -Parent
    $gitInstruction = if ($GitPush) { 'Git commit your changes and push to the remote when done' } else { 'Git commit your changes when done' }
    & copilot -p @"
Before writing tests, read the project constitution at $constitutionPath — its Project Principles are inviolable constraints. Tests must verify conformance to these principles, not just functional correctness.

You are a senior test engineer. Look at the codebase, detect the language and test framework in use (or choose the standard one for the language), and write thorough tests for every module that has real implementation — skip stubs and empty files. Reference $devLoopRoot\ENGINEERING_STANDARDS.md (if it exists) — tests should follow the same conventions as production code. For each module, test the happy path, edge cases, and error handling. If a test directory doesn't exist, create one. If tests already exist, review them for coverage gaps and add what's missing. Then run the full test suite. If a test fails, determine the root cause. Use PLAN.md (module contracts and expected behavior) and BACKLOG.md (story requirements) as the source of truth — not the current code. If the test correctly reflects the spec'd behavior but the code is wrong, leave the test as-is and report the failure. If the test doesn't match the spec'd behavior, fix the test. Never modify production code. Keep tests focused, fast, and independent — no shared mutable state between tests. Mock external I/O (subprocess calls, disk reads, network) so tests are deterministic. If running tests produces artifacts that should not be tracked (e.g., .pytest_cache/, coverage reports, .tox/, __pycache__/), ensure they are covered in .gitignore — add missing patterns if needed. If you add new patterns, also run ``git rm --cached`` on any matching files already tracked by git. $gitInstruction.
"@ --yolo 2>&1 | ForEach-Object { Write-Host $_; $_ | Out-File -FilePath $LogFile -Append }
    if ($LASTEXITCODE -ne 0) { Log "TEST FAILED (exit $LASTEXITCODE)" Red; exit 1 }
}
catch {
    $errMsg = "FATAL [test]: $_"
    Write-Host $errMsg -ForegroundColor Red
    "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $LogFile -Append
    throw
}
finally {
    Pop-Location
}
