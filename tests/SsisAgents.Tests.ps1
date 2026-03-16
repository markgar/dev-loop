# SsisAgents.Tests.ps1 — Unit tests for SSIS migration agent scripts

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src' 'dev-loop'
    $script:SsisAgentsDir = Join-Path $script:ModuleRoot 'ssis-agents'

    function New-TestProject {
        param([string]$BasePath, [string]$Name)
        $projectDir = Join-Path $BasePath $Name
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        Push-Location $projectDir
        git init --quiet 2>$null
        git config user.email 'test@test.com'
        git config user.name 'Test'
        Pop-Location
        return $projectDir
    }

    function New-MockCopilot {
        param([string]$BasePath, [string]$Script)
        $mockBin = Join-Path $BasePath 'mockbin'
        New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
        $mockCopilot = Join-Path $mockBin 'copilot'
        $Script | Set-Content $mockCopilot
        chmod +x $mockCopilot
        return $mockBin
    }

    function New-MinimalDtsx {
        param([string]$Path)
        @'
<?xml version="1.0"?>
<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts"
  DTS:refId="Package" DTS:ObjectName="TestPackage">
  <DTS:ConnectionManagers>
    <DTS:ConnectionManager DTS:refId="Package.ConnectionManagers[OleDbSource]"
      DTS:ObjectName="OleDbSource" DTS:DTSID="{00000000-0000-0000-0000-000000000001}">
    </DTS:ConnectionManager>
  </DTS:ConnectionManagers>
  <DTS:Executables>
    <DTS:Executable DTS:refId="Package\DFT Load Data"
      DTS:ObjectName="DFT Load Data"
      DTS:ExecutableType="Microsoft.Pipeline">
    </DTS:Executable>
  </DTS:Executables>
</DTS:Executable>
'@ | Set-Content $Path
    }
}

Describe 'cycle-analysis.ps1' {
    It 'throws when DTSX file does not exist' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'cycle-proj'
        $runDir = Join-Path $TestDrive 'cycle-run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'cycle.log'

        $fakeDtsx = Join-Path $TestDrive 'nonexistent.dtsx'

        { & "$script:SsisAgentsDir/cycle-analysis.ps1" `
            -DtsxPath $fakeDtsx `
            -ProjectDir $projectDir `
            -RunDir $runDir `
            -LogFile $logFile } | Should -Throw '*DTSX file not found*'
    }

    It 'calls copilot and reports when analysis file is created' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'cycle-proj2'
        $runDir = Join-Path $TestDrive 'cycle-run2'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'cycle.log'

        $dtsxFile = Join-Path $TestDrive 'test-package.dtsx'
        New-MinimalDtsx -Path $dtsxFile

        $analysisFile = Join-Path $runDir 'cycle-analysis.md'

        # Mock copilot that creates the analysis file — use string concat to embed path in single-quoted heredoc
        $mockScript = @'
#!/bin/bash
echo "# Cycle Analysis: TestPackage" > "
'@ + $analysisFile + @'
"
echo "Analysis complete"
exit 0
'@
        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'cycle-mock') -Script $mockScript

        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { & "$script:SsisAgentsDir/cycle-analysis.ps1" `
                -DtsxPath $dtsxFile `
                -ProjectDir $projectDir `
                -RunDir $runDir `
                -LogFile $logFile } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }

        $analysisFile | Should -Exist
        Get-Content $analysisFile -Raw | Should -Match 'Cycle Analysis'
    }

    It 'completes without error even when copilot does not create analysis file' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'cycle-proj3'
        $runDir = Join-Path $TestDrive 'cycle-run3'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'cycle.log'

        $dtsxFile = Join-Path $TestDrive 'test-package2.dtsx'
        New-MinimalDtsx -Path $dtsxFile

        # Mock copilot that does NOT create the analysis file
        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'cycle-mock2') -Script @'
#!/bin/bash
echo "I analyzed but did not write a file"
exit 0
'@

        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { & "$script:SsisAgentsDir/cycle-analysis.ps1" `
                -DtsxPath $dtsxFile `
                -ProjectDir $projectDir `
                -RunDir $runDir `
                -LogFile $logFile } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }
    }

    It 'throws when copilot exits non-zero' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'cycle-proj4'
        $runDir = Join-Path $TestDrive 'cycle-run4'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'cycle.log'

        $dtsxFile = Join-Path $TestDrive 'test-package3.dtsx'
        New-MinimalDtsx -Path $dtsxFile

        # Mock copilot that fails
        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'cycle-mock3') -Script @'
#!/bin/bash
echo "Something went wrong" >&2
exit 1
'@

        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { & "$script:SsisAgentsDir/cycle-analysis.ps1" `
                -DtsxPath $dtsxFile `
                -ProjectDir $projectDir `
                -RunDir $runDir `
                -LogFile $logFile } | Should -Throw '*Copilot exited with code 1*'
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}
