# plan-eval.ps1 — Review a generated plan against its spec and update the plan in-place
# Usage: .\plan-eval.ps1 -SpecFile <path> -ProjectDir <path> -RunDir <path>

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
    $specBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SpecFile)
    $planFile = Join-Path $RunDir "plan-$specBaseName.md"

    # ── Logging ───────────────────────────────────────────────────────
    function Log { param([string]$Message, [string]$Color = 'White')
        Write-Host $Message -ForegroundColor $Color
        "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $LogFile -Append
    }

    Log "========== PLAN REVIEW: $specBaseName ==========" Blue

    if (-not (Test-Path $planFile)) {
        Log "Plan file not found: $planFile" Red
        exit 1
    }

    & copilot -p @"
You are a plan-evaluation agent. Your job is to review a generated implementation plan against its spec and **fix the plan in-place**.

The plan to review and update is at: $planFile
The spec it must satisfy is at: $SpecFile

SCOPE CONSTRAINT: You must only consider these sources of information:
1. The plan file above — this is the ONLY plan you are reviewing.
2. The spec file above — this is the ONLY spec you are reviewing against.
3. Any existing code in the repository.
Do NOT read, reference, or consider any other spec files. Other specs are out of scope for this evaluation session.

Read both files, then evaluate the plan on these criteria:

1. **Completeness** — Does the plan cover every requirement in the spec? Identify any spec requirements missing from the plan.
2. **Ordering** — Are the tasks sequenced correctly? Are dependencies respected so earlier tasks don't rely on work from later tasks?
3. **Task coherence** — Does each task make sense as a single, buildable unit (roughly one git commit)? Are any tasks too large, too small, or unclear?
4. **Scope fidelity** — Does the plan stay within the boundaries of this spec, without pulling in work from other specs or adding unrequested features?

ACTION:
- If the plan has issues on ANY criterion, **edit $planFile directly** to fix them — add missing tasks, reorder, split/merge tasks, remove out-of-scope work. Preserve the plan's existing format.
- If the plan is already correct on all criteria, leave it unchanged.
- Do NOT create any new files. The plan file is the only output.
"@ --yolo 2>&1 | ForEach-Object { Write-Host $_; $_ | Out-File -FilePath $LogFile -Append }
    if ($LASTEXITCODE -ne 0) { Log "PLAN EVALUATION FAILED (exit $LASTEXITCODE)" Red; exit 1 }

    Log "Plan review complete: $planFile" DarkGray
}
catch {
    $errMsg = "FATAL [plan-eval]: $_"
    Write-Host $errMsg -ForegroundColor Red
    "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $LogFile -Append
    throw
}
finally {
    Pop-Location
}
