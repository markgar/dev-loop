# plan.ps1 — Plan generation phase using GitHub Copilot CLI
# Usage: .\plan.ps1 -SpecFile <path> -ProjectDir <path> -RunDir <path>

param(
    [Parameter(Mandatory)]
    [string]$SpecFile,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [Parameter(Mandatory)]
    [string]$RunDir,

    [Parameter(Mandatory)]
    [string]$LogFile,

    [string]$Model
)

. "$PSScriptRoot\_common.ps1"

Invoke-AgentBlock -AgentName 'plan' -ProjectDir $ProjectDir -LogFile $LogFile -Action {
    $paths = Get-AgentPath -SpecFile $SpecFile -RunDir $RunDir
    $constitutionPath = $paths.ConstitutionPath
    $planOutputFile = $paths.PlanFile

    Log -LogFile $LogFile "========== INITIAL PLAN: $($paths.SpecBaseName) =========="  Blue
    Log -LogFile $LogFile "Spec file : $SpecFile" DarkGray

    Invoke-Copilot -LogFile $LogFile -Model $Model -Prompt @"
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
"@

    if (Test-Path $planOutputFile) {
        Log -LogFile $LogFile "Plan output saved to: $planOutputFile" DarkGray
        Log -LogFile $LogFile "---------- Initial Plan Contents (DEBUG) ----------" Cyan
        Get-Content $planOutputFile | ForEach-Object { Log -LogFile $LogFile $_ }
        Log -LogFile $LogFile "---------- End Initial Plan (DEBUG) ----------" Cyan
    }
    else {
        Log -LogFile $LogFile "Warning: copilot did not write plan output file at $planOutputFile" Yellow
    }
}
