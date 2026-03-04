# preflight.ps1 — Discover specs, constitution check
# Usage: .\preflight.ps1 -SpecsDir <path> -RunDir <path>
# Outputs: spec-discovery.json (spec list) in RunDir

param(
    [Parameter(Mandatory)]
    [string]$SpecsDir,

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
$_projectRoot = (git -C $SpecsDir rev-parse --show-toplevel 2>$null)
if (-not $_projectRoot) { Write-Host "Could not find git root for $SpecsDir" -ForegroundColor Red; exit 1 }
Push-Location $_projectRoot

try {
    # ── Logging ───────────────────────────────────────────────────────
    function Log { param([string]$Message, [string]$Color = 'White')
        Write-Host $Message -ForegroundColor $Color
        "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $LogFile -Append
    }

    Log "========== PRE-FLIGHT CHECK ==========" Blue

    # ── 1. Discover specs ─────────────────────────────────────────────
    Log "--- Spec Discovery ---" Blue
    Log "Specs directory : $SpecsDir" DarkGray

    $specFiles = Get-ChildItem -Path $SpecsDir -Filter '*.md' |
        Where-Object { $_.Name -match '^\d{2}-' } |
        Sort-Object Name

    if ($specFiles.Count -eq 0) {
        Log "No numbered spec files (NN-*.md) found in $SpecsDir — nothing to do." Yellow
        exit 1
    }

    Log "Found $($specFiles.Count) spec(s):" DarkGray

    $specs = @()
    foreach ($sf in $specFiles) {
        Log "  - $($sf.Name)" DarkGray
        $specs += @{
            name = $sf.BaseName
            file = $sf.FullName
        }
    }

    $discoveryFile = Join-Path $RunDir 'spec-discovery.json'
    $specs | ConvertTo-Json -Depth 2 | Set-Content -Path $discoveryFile -Encoding UTF8
    Log "Discovery written to: $discoveryFile" Green

    # ── 2. Constitution check ────────────────────────────────────────
    Log "--- Constitution Check ---" Blue

    $constitutionPath = Join-Path $SpecsDir 'CONSTITUTION.md'
    if (-not (Test-Path $constitutionPath)) {
        Log "No CONSTITUTION.md found at $constitutionPath — skipping constitution check." Yellow
        Log "Pre-flight complete (no constitution)." Green
        exit 0
    }

    $findingsFile = Join-Path $RunDir 'preflight-findings.md'

    & copilot -p @"
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
"@ --yolo 2>&1 | ForEach-Object { Write-Host $_; $_ | Out-File -FilePath $LogFile -Append }

    if (Test-Path $findingsFile) {
        Log "Pre-flight findings saved to: $findingsFile" Yellow
        Log "Review the findings and update CONSTITUTION.md before running the dev-loop." Yellow
        exit 1
    }

    Log "Pre-flight complete." Green
    exit 0
}
catch {
    $errMsg = "FATAL [preflight]: $_"
    Write-Host $errMsg -ForegroundColor Red
    "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $LogFile -Append
    throw
}
finally {
    Pop-Location
}
