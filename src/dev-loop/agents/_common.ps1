# _common.ps1 — Shared utilities for dev-loop agent scripts
# Dot-source this file at the top of each agent: . "$PSScriptRoot\_common.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Log {
    param(
        [Parameter(Mandatory)][string]$LogFile,
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
    "$(Get-Date -Format 'HH:mm:ss') $Message" | Out-File -FilePath $LogFile -Append
}

function Invoke-Copilot {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$Model,
        [Parameter(Mandatory)][string]$LogFile
    )
    $copilotArgs = @('-p', $Prompt, '--yolo')
    if ($Model) { $copilotArgs += '--model'; $copilotArgs += $Model }
    & copilot @copilotArgs 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $line = "[STDERR] $_"
            Write-Host $line -ForegroundColor Yellow
            $line | Out-File -FilePath $LogFile -Append
        }
        else {
            Write-Host $_
            $_ | Out-File -FilePath $LogFile -Append
        }
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Copilot exited with code $LASTEXITCODE"
    }
}

function Get-GitInstruction {
    param([switch]$Push)
    if ($Push) { 'then git commit your work and push to the remote' }
    else { 'then git commit your work' }
}

function Get-AgentPath {
    param(
        [Parameter(Mandatory)][string]$SpecFile,
        [Parameter(Mandatory)][string]$RunDir
    )
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SpecFile)
    $specsDir = Split-Path $SpecFile -Parent
    @{
        SpecBaseName = $baseName
        SpecsDir = $specsDir
        ConstitutionPath = Join-Path $specsDir 'CONSTITUTION.md'
        PlanFile = Join-Path $RunDir "plan-$baseName.md"
        DevLoopRoot = Split-Path $RunDir -Parent
    }
}

function Write-AgentError {
    param(
        [Parameter(Mandatory)][string]$AgentName,
        [Parameter(Mandatory)]$ErrorRecord,
        [Parameter(Mandatory)][string]$LogFile
    )
    $errMsg = "FATAL [$AgentName]: $ErrorRecord"
    Write-Host $errMsg -ForegroundColor Red
    "$(Get-Date -Format 'HH:mm:ss') $errMsg" | Out-File -FilePath $LogFile -Append
}

function Invoke-AgentBlock {
    param(
        [Parameter(Mandatory)][string]$AgentName,
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$LogFile,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    Push-Location $ProjectDir
    try {
        . $Action
    }
    catch {
        Write-AgentError -AgentName $AgentName -ErrorRecord $_ -LogFile $LogFile
        throw
    }
    finally {
        Pop-Location
    }
}
