# cycle-analysis.ps1 — Analyze a DTSX package to determine its load/cycle strategy
# Usage: .\cycle-analysis.ps1 -DtsxPath <path> -ProjectDir <path> -RunDir <path> -LogFile <path>
# Outputs: cycle-analysis.md in RunDir

param(
    [Parameter(Mandatory)]
    [string]$DtsxPath,

    [Parameter(Mandatory)]
    [string]$ProjectDir,

    [Parameter(Mandatory)]
    [string]$RunDir,

    [Parameter(Mandatory)]
    [string]$LogFile,

    [string]$Model
)

. "$PSScriptRoot\..\agents\_common.ps1"

Invoke-AgentBlock -AgentName 'cycle-analysis' -ProjectDir $ProjectDir -LogFile $LogFile -Action {

    Log -LogFile $LogFile "========== CYCLE ANALYSIS ==========" Blue
    Log -LogFile $LogFile "DTSX package : $DtsxPath" DarkGray

    if (-not (Test-Path $DtsxPath)) {
        throw "DTSX file not found: $DtsxPath"
    }

    $analysisFile = Join-Path $RunDir 'cycle-analysis.md'

    Invoke-Copilot -LogFile $LogFile -Model $Model -Prompt @"
You are an SSIS migration analyst. Your job is to examine a DTSX package and determine how it loads data — its cycle strategy.

Open and read the DTSX package at: $DtsxPath

This is an SSIS package stored as XML. Examine its structure thoroughly:

1. **Control Flow** — Look at all tasks, containers (For Each Loop, For Loop, Sequence), and precedence constraints.
2. **Data Flow Tasks** — For each data flow, examine sources, transformations, and destinations.
3. **Connection Managers** — What databases, files, or services does it connect to?
4. **Variables & Parameters** — Look for date range variables, last-run timestamps, watermark columns, or row count trackers.
5. **Expressions & Configurations** — Check for dynamic SQL, parameterized queries, or config-driven date filters.
6. **SQL Commands** — Read any embedded SQL in OLE DB Sources, Execute SQL Tasks, etc. Look for WHERE clauses that filter by date, modified timestamp, or incremental keys.

Based on your analysis, determine the **cycle strategy**. Common SSIS patterns include:

- **Full Load** — Truncate-and-reload every run. No date filtering, no watermarks. The entire dataset is replaced each execution.
- **Incremental Load (Watermark)** — Uses a high-water mark (last modified date, max ID, etc.) to pull only new/changed rows since the last run. Often stored in a control table or variable.
- **Incremental Load (CDC)** — Uses Change Data Capture or Change Tracking to identify inserts, updates, and deletes.
- **Initial + Incremental** — First run does a full load, subsequent runs use incremental logic. Often controlled by a flag variable or control table row count.
- **Snapshot / SCD** — Slowly Changing Dimension patterns (Type 1 overwrites, Type 2 history rows).
- **Partitioned Load** — Loads data by partition (e.g., by date range, region) using a loop container.

Write your findings to: $analysisFile

Use this structure for the document:

``````markdown
# Cycle Analysis: <package name>

## Summary
One-paragraph summary of what this package does and its cycle strategy.

## Cycle Strategy
- **Pattern**: <Full Load | Incremental (Watermark) | Incremental (CDC) | Initial + Incremental | Snapshot/SCD | Partitioned | Other>
- **Frequency Assumption**: <What the package structure suggests about run frequency>
- **Idempotent**: <Yes/No — can it safely re-run without duplicating data?>

## Data Sources
| Source | Type | Connection | Query/Table | Filters |
|--------|------|------------|-------------|---------|
| ... | OLE DB / Flat File / etc. | Connection manager name | Table or SQL | Date filter, watermark, etc. |

## Data Destinations
| Destination | Type | Connection | Table | Load Method |
|-------------|------|------------|-------|-------------|
| ... | OLE DB / Flat File / etc. | Connection manager name | Target table | Truncate+Insert / Merge / Append / SCD |

## Control Flow Overview
Describe the execution order: what runs first, what loops, what's conditional. Note any Execute SQL Tasks that set up staging, truncate tables, or update watermarks.

## Incremental Logic (if applicable)
- **Watermark column**: <column name or N/A>
- **Watermark storage**: <control table, variable, package config, or N/A>
- **Filter mechanism**: <WHERE clause, Lookup transform, Conditional Split, or N/A>
- **Post-load update**: <How the watermark advances after a successful load>

## Variables & Parameters
List all package variables and parameters, noting which ones control cycle behavior.

## Key Observations
Bullet points on anything notable: error handling patterns, transaction scopes, event handlers, logging, retry logic, or patterns that will need special attention during PySpark migration.
``````

SCOPE CONSTRAINT: Only read the DTSX file specified above. Do not read or modify any other files in the repository except to write the analysis document.
"@

    if (Test-Path $analysisFile) {
        Log -LogFile $LogFile "Cycle analysis written to: $analysisFile" Green
    }
    else {
        Log -LogFile $LogFile "WARNING: Cycle analysis file was not created at $analysisFile" Yellow
    }
}
