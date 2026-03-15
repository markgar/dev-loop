# Preflight.Tests.ps1 — Unit tests for the preflight agent

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src' 'dev-loop'
    $script:AgentsDir = Join-Path $script:ModuleRoot 'agents'
}

Describe 'Preflight spec discovery' {
    It 'discovers numbered spec files and writes spec-discovery.json' {
        # Set up a project dir (git repo)
        $projectDir = Join-Path $TestDrive 'project'
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        Push-Location $projectDir
        git init --quiet 2>$null
        git config user.email 'test@test.com'
        git config user.name 'Test'
        Pop-Location

        # Set up specs dir with numbered files and a non-spec file
        $specsDir = Join-Path $TestDrive 'specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature A' | Set-Content (Join-Path $specsDir '01-feature-a.md')
        '# Feature B' | Set-Content (Join-Path $specsDir '02-feature-b.md')
        'Not a spec' | Set-Content (Join-Path $specsDir 'README.md')

        # Set up run dir
        $runDir = Join-Path $TestDrive 'run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null

        $logFile = Join-Path $runDir 'preflight.log'

        # Create mock copilot that outputs PASS
        $mockBin = Join-Path $TestDrive 'mockbin'
        New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
        $mockCopilot = Join-Path $mockBin 'copilot'
        @'
#!/bin/bash
echo "PREFLIGHT: PASS"
exit 0
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            & "$script:AgentsDir/preflight.ps1" -SpecsDir $specsDir -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile
        }
        finally {
            $env:PATH = $originalPath
        }

        $discoveryFile = Join-Path $runDir 'spec-discovery.json'
        $discoveryFile | Should -Exist

        $discovered = Get-Content $discoveryFile -Raw | ConvertFrom-Json
        $discovered.Count | Should -Be 2
        $discovered[0].name | Should -Be '01-feature-a'
        $discovered[1].name | Should -Be '02-feature-b'
    }

    It 'throws when no numbered spec files exist' {
        $projectDir = Join-Path $TestDrive 'project-empty'
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        Push-Location $projectDir
        git init --quiet 2>$null
        git config user.email 'test@test.com'
        git config user.name 'Test'
        Pop-Location

        $specsDir = Join-Path $TestDrive 'empty-specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        'Not a spec' | Set-Content (Join-Path $specsDir 'README.md')

        $runDir = Join-Path $TestDrive 'run-empty'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'preflight.log'

        { & "$script:AgentsDir/preflight.ps1" -SpecsDir $specsDir -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Throw '*No numbered spec files*'
    }

    It 'skips constitution check when CONSTITUTION.md does not exist' {
        $projectDir = Join-Path $TestDrive 'project-nocon'
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        Push-Location $projectDir
        git init --quiet 2>$null
        git config user.email 'test@test.com'
        git config user.name 'Test'
        Pop-Location

        $specsDir = Join-Path $TestDrive 'specs-nocon'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')
        # Intentionally no CONSTITUTION.md

        $runDir = Join-Path $TestDrive 'run-nocon'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'preflight.log'

        # No mock copilot needed — it should skip the copilot call entirely
        # But _common.ps1 sets StrictMode, so let's ensure copilot mock is there
        # just in case future code changes. Use a safe mock.
        $mockBin = Join-Path $TestDrive 'mockbin-nocon'
        New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
        $mockCopilot = Join-Path $mockBin 'copilot'
        @'
#!/bin/bash
echo "should not be called"
exit 1
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            # Should succeed without calling copilot (no constitution to check)
            { & "$script:AgentsDir/preflight.ps1" -SpecsDir $specsDir -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }

        # Discovery should still have been written
        $discoveryFile = Join-Path $runDir 'spec-discovery.json'
        $discoveryFile | Should -Exist
    }
}
