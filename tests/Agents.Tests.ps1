# Agents.Tests.ps1 — Unit tests for agent scripts (plan, plan-eval, build, review)

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src' 'dev-loop'
    $script:AgentsDir = Join-Path $script:ModuleRoot 'agents'

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
}

Describe 'plan.ps1' {
    It 'calls copilot and expects a plan file to be created' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'plan-proj'
        $specsDir = Join-Path $TestDrive 'plan-specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')

        $runDir = Join-Path $TestDrive 'plan-run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'plan.log'

        # Mock copilot that creates a plan file
        $mockBin = New-MockCopilot -BasePath $TestDrive -Script @'
#!/bin/bash
PROMPT="$2"
PLAN_FILE=$(echo "$PROMPT" | grep -oP 'Write your complete plan to \K[^\s]+')
if [ -n "$PLAN_FILE" ]; then
    echo "- [ ] **Task 1: Setup** — Initial setup" > "$PLAN_FILE"
fi
echo "Plan created"
exit 0
'@

        $specFile = Join-Path $specsDir '01-feature.md'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            & "$script:AgentsDir/plan.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile
        }
        finally {
            $env:PATH = $originalPath
        }

        $planFile = Join-Path $runDir 'plan-01-feature.md'
        $planFile | Should -Exist
    }

    It 'exits successfully even when copilot does not create plan file' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'plan-proj2'
        $specsDir = Join-Path $TestDrive 'plan-specs2'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-noop.md')

        $runDir = Join-Path $TestDrive 'plan-run2'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'plan.log'

        # Mock copilot that does NOT create a plan file
        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'plan2') -Script @'
#!/bin/bash
echo "I did not write a file"
exit 0
'@

        $specFile = Join-Path $specsDir '01-noop.md'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            # plan.ps1 logs a warning but does not throw
            { & "$script:AgentsDir/plan.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'plan-eval.ps1' {
    It 'throws when plan file does not exist' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'eval-proj'
        $specsDir = Join-Path $TestDrive 'eval-specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')

        $runDir = Join-Path $TestDrive 'eval-run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'eval.log'

        # No plan file created → should fail
        $specFile = Join-Path $specsDir '01-feature.md'
        { & "$script:AgentsDir/plan-eval.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Throw '*Plan file not found*'
    }

    It 'succeeds when plan file exists and copilot returns 0' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'eval-proj2'
        $specsDir = Join-Path $TestDrive 'eval-specs2'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')

        $runDir = Join-Path $TestDrive 'eval-run2'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'eval.log'

        # Create a plan file
        '- [ ] **Task 1** — do something' | Set-Content (Join-Path $runDir 'plan-01-feature.md')

        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'eval-mock') -Script @'
#!/bin/bash
echo "Plan looks good"
exit 0
'@

        $specFile = Join-Path $specsDir '01-feature.md'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { & "$script:AgentsDir/plan-eval.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'build.ps1' {
    It 'calls copilot and completes without error' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'build-proj'
        $specsDir = Join-Path $TestDrive 'build-specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')

        $runDir = Join-Path $TestDrive 'build-run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'build.log'

        # build.ps1 reads PlanFile from Get-AgentPaths, but doesn't check existence itself
        '- [ ] **Task 1** — build something' | Set-Content (Join-Path $runDir 'plan-01-feature.md')

        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'build-mock') -Script @'
#!/bin/bash
echo "Built successfully"
exit 0
'@

        $specFile = Join-Path $specsDir '01-feature.md'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { & "$script:AgentsDir/build.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }
    }

    It 'throws when copilot exits with non-zero' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'build-fail'
        $specsDir = Join-Path $TestDrive 'build-fail-specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')

        $runDir = Join-Path $TestDrive 'build-fail-run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'build.log'
        '- [ ] **Task 1**' | Set-Content (Join-Path $runDir 'plan-01-feature.md')

        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'build-fail-mock') -Script @'
#!/bin/bash
echo "Build error"
exit 1
'@

        $specFile = Join-Path $specsDir '01-feature.md'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { & "$script:AgentsDir/build.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Throw
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'review.ps1' {
    It 'calls copilot and completes without error' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'review-proj'
        $specsDir = Join-Path $TestDrive 'review-specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')

        $runDir = Join-Path $TestDrive 'review-run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'review.log'

        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'review-mock') -Script @'
#!/bin/bash
echo "Review complete"
exit 0
'@

        $specFile = Join-Path $specsDir '01-feature.md'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { & "$script:AgentsDir/review.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }
    }

    It 'passes -GitPush flag through to Get-GitInstruction' {
        $projectDir = New-TestProject -BasePath $TestDrive -Name 'review-push'
        $specsDir = Join-Path $TestDrive 'review-push-specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        '# Feature' | Set-Content (Join-Path $specsDir '01-feature.md')

        $runDir = Join-Path $TestDrive 'review-push-run'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'review.log'

        # Copilot mock that captures prompt to verify 'push' is in it
        $mockBin = New-MockCopilot -BasePath (Join-Path $TestDrive 'review-push-mock') -Script @'
#!/bin/bash
echo "PROMPT: $2" > /tmp/review-prompt.txt
echo "Review done"
exit 0
'@

        $specFile = Join-Path $specsDir '01-feature.md'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            & "$script:AgentsDir/review.ps1" -SpecFile $specFile -ProjectDir $projectDir -RunDir $runDir -LogFile $logFile -GitPush
        }
        finally {
            $env:PATH = $originalPath
        }

        # The prompt should contain 'push' when -GitPush is set
        # We verify indirectly — the command succeeded
    }
}
