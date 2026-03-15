# preflight.ps1 — Discover specs, constitution check
# Usage: .\preflight.ps1 -SpecsDir <path> -ProjectDir <path> -RunDir <path>
# Outputs: spec-discovery.json (spec list) in RunDir

param(
    [Parameter(Mandatory)]
    [string]$SpecsDir,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [Parameter(Mandatory)]
    [string]$RunDir,

    [Parameter(Mandatory)]
    [string]$LogFile,

    [string]$Model
)

. "$PSScriptRoot\_common.ps1"

Invoke-AgentBlock -AgentName 'preflight' -ProjectDir $ProjectDir -LogFile $LogFile -Action {

    Log -LogFile $LogFile "========== PRE-FLIGHT CHECK =========="  Blue

    # ── 1. Discover specs ─────────────────────────────────────────────
    Log -LogFile $LogFile "--- Spec Discovery ---" Blue
    Log -LogFile $LogFile "Specs directory : $SpecsDir" DarkGray

    $specFiles = @(Get-ChildItem -Path $SpecsDir -Filter '*.md' |
            Where-Object { $_.Name -match '^\d{2}-' } |
            Sort-Object Name)

    if ($specFiles.Count -eq 0) {
        Log -LogFile $LogFile "No numbered spec files (NN-*.md) found in $SpecsDir — nothing to do." Yellow
        Log -LogFile $LogFile "Are you using spec-kit style specs? See https://github.com/github/spec-kit" Yellow
        throw "No numbered spec files found in $SpecsDir"
    }

    Log -LogFile $LogFile "Found $($specFiles.Count) spec(s):" DarkGray

    $specs = @()
    foreach ($sf in $specFiles) {
        Log -LogFile $LogFile "  - $($sf.Name)" DarkGray
        $specs += @{
            name = $sf.BaseName
            file = $sf.FullName
        }
    }

    $discoveryFile = Join-Path $RunDir 'spec-discovery.json'
    $specs | ConvertTo-Json -Depth 2 | Set-Content -Path $discoveryFile -Encoding UTF8
    Log -LogFile $LogFile "Discovery written to: $discoveryFile" Green

    # ── 2. Constitution check ────────────────────────────────────────
    Log -LogFile $LogFile "--- Constitution Check ---" Blue

    $constitutionPath = Join-Path $SpecsDir 'CONSTITUTION.md'
    if (-not (Test-Path $constitutionPath)) {
        Log -LogFile $LogFile "No CONSTITUTION.md found at $constitutionPath — skipping constitution check." Yellow
        Log -LogFile $LogFile "Are you using spec-kit style specs? See https://github.com/github/spec-kit" Yellow
        Log -LogFile $LogFile "Pre-flight complete (no constitution)." Green
        return
    }

    $findingsFile = Join-Path $RunDir 'preflight-findings.md'

    Invoke-Copilot -LogFile $LogFile -Model $Model -Prompt @"
You are a pre-flight reviewer. Your job is to review a project constitution and make sure it does not interfere with how the dev-loop operates.

A constitution can say ANYTHING about the product itself — constraints, architecture, naming conventions, quality gates, implementation preferences, whatever the author wants. That's all fair game.

The ONE thing a constitution must NOT do is dictate dev-loop process:
- **Spec inventory or cross-references** — lists of spec files, dependency graphs, build orders. An agent reading the constitution should not discover what other specs exist or what order to build them.
- **Process instructions** — how specs are structured, how amendments work, how the build loop operates, how to iterate. The dev-loop owns its own process.
- **Spec templates or layouts** — what sections a spec should have, what format specs follow. That's dev-loop tooling, not a product concern.

If the constitution talks about the product, leave it alone — even if it's very specific. Only flag things that step on the dev-loop's process.

Review the constitution at: $constitutionPath

For each finding, report:
- **Severity: HIGH or LOW**
- The specific text that violates the above rules
- Which category it falls into (spec inventory, process instruction, or spec template)
- Why it's a problem (how it could interfere with dev-loop operation)

SEVERITY GUIDELINES:
- **HIGH** — The text will actively mislead an autonomous agent, cause it to refuse valid approaches, or inject scope/structure it should not know about. These are blocking problems.
- **LOW** — The text is suboptimal or slightly out of lane, but an autonomous agent would still produce correct output. These are advisory only.

SCOPE CONSTRAINT: Only read the constitution file. Do not read any other files.

OUTPUT RULES:
- If you find ZERO issues, or only LOW-severity issues: print exactly "PREFLIGHT: PASS" to stdout. Do NOT create any files.
- If you find any HIGH-severity issues: write ALL findings (both HIGH and LOW) to $findingsFile and print "PREFLIGHT: FINDINGS" as the first line of that file, followed by each finding. Also print the findings to stdout.
"@

    if (Test-Path $findingsFile) {
        Log -LogFile $LogFile "Pre-flight findings saved to: $findingsFile" Yellow
        Log -LogFile $LogFile "Review the findings and update CONSTITUTION.md before running the dev-loop." Yellow
        throw "Pre-flight findings require review: $findingsFile"
    }

    Log -LogFile $LogFile "Pre-flight complete." Green
    return
}
