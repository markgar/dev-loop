# plan.ps1 — Plan generation phase using GitHub Copilot CLI
# Usage: .\plan.ps1 -SpecFile <path> -RunDir <path>

param(
    [Parameter(Mandatory)]
    [string]$SpecFile,

    [Parameter(Mandatory)]
    [string]$RunDir,

    [Parameter(Mandatory)]
    [string]$LogFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Work from the target project's git root so copilot sees the real project
$_projectRoot = (git -C (Split-Path $SpecFile -Parent) rev-parse --show-toplevel 2>$null)
if (-not $_projectRoot) { Write-Host "Could not find git root for $SpecFile" -ForegroundColor Red; exit 1 }
Push-Location $_projectRoot

try {
    $specBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SpecFile)
    $SpecsDir = Split-Path $SpecFile -Parent
    $constitutionPath = Join-Path $SpecsDir 'CONSTITUTION.md'

    # ── Logging ───────────────────────────────────────────────────────
    function Log { param([string]$Message, [string]$Color = 'White')
        Write-Host $Message -ForegroundColor $Color
        "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $LogFile -Append
    }

    Log "========== INITIAL PLAN: $specBaseName ==========" Blue
    Log "Spec file : $SpecFile" DarkGray

    $planOutputFile = Join-Path $RunDir "plan-$specBaseName.md"

    & copilot -p @"
You are a planning agent. Turn the input spec into a short, scannable checklist of tasks. Each task = one git commit.

Before planning, read the project constitution at $constitutionPath — its Project Principles are inviolable constraints. If a task would violate a principle, redesign the task.

The spec you are planning is at: $SpecFile

SCOPE CONSTRAINT: Only consider these sources:
1. The spec file above (the ONLY spec you are planning).
2. The constitution file.
3. Any existing code in the repository.
Do NOT read, reference, or plan for any other spec files.

OUTPUT FORMAT — follow this strictly:
- Use Markdown with a single H1 title line.
- Each task is a GitHub-flavored checkbox: ``- [ ] **Task N: Short title** — one-sentence description``
- Under each task, indent a few bullet points covering: what to build, key files, key test scenarios. Be terse.
- NO prose paragraphs, NO section headers per task, NO acceptance-criteria cross-references, NO constitution justifications.
- Keep the entire plan concise — no filler.
- End with a one-line dependency note only if tasks aren't purely sequential.

OUTPUT INSTRUCTIONS: Write your complete plan to $planOutputFile
Also print the plan to stdout.
"@ --yolo 2>&1 | ForEach-Object { Write-Host $_; $_ | Out-File -FilePath $LogFile -Append }
    if ($LASTEXITCODE -ne 0) { Log "PLAN FAILED (exit $LASTEXITCODE)" Red; exit 1 }

    if (Test-Path $planOutputFile) {
        Log "Plan output saved to: $planOutputFile" DarkGray
        Log "---------- Initial Plan Contents (DEBUG) ----------" Cyan
        Get-Content $planOutputFile | ForEach-Object { Log $_ }
        Log "---------- End Initial Plan (DEBUG) ----------" Cyan
    } else {
        Log "Warning: copilot did not write plan output file at $planOutputFile" Yellow
    }
}
catch {
    $errMsg = "FATAL [plan]: $_"
    Write-Host $errMsg -ForegroundColor Red
    "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $LogFile -Append
    throw
}
finally {
    Pop-Location
}
