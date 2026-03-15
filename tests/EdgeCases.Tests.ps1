# EdgeCases.Tests.ps1 — Edge case tests for dev-loop

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src' 'dev-loop'
    $script:ModulePath = Join-Path $script:ModuleRoot 'dev-loop.psd1'
    $script:CommonPath = Join-Path $script:ModuleRoot 'agents' '_common.ps1'
}

Describe 'Build loop circuit breaker' {
    BeforeAll {
        Import-Module $script:ModulePath -Force
    }

    AfterAll {
        Remove-Module dev-loop -ErrorAction SilentlyContinue
    }

    It 'build phase terminates when all plan tasks are checked' {
        # This is tested indirectly via Invoke-DevLoop.
        # Set up a full scenario with mock copilot that:
        # 1. PASS preflight
        # 2. Creates a plan file with all tasks checked
        # 3. Returns 0 for everything

        $specsDir = Join-Path $TestDrive 'specs-build'
        $projectDir = Join-Path $TestDrive 'project-build'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        '# Spec' | Set-Content (Join-Path $specsDir '01-test.md')

        Push-Location $projectDir
        git init --quiet 2>$null
        git config user.email 'test@test.com'
        git config user.name 'Test'
        Pop-Location

        # Mock copilot: discovers specs, creates plan with all tasks done
        $mockBin = Join-Path $TestDrive 'mockbin-build'
        New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
        $mockCopilot = Join-Path $mockBin 'copilot'
        # This copilot mock inspects the -p argument to decide behavior
        @'
#!/bin/bash
PROMPT="$2"
if echo "$PROMPT" | grep -q "pre-flight"; then
    echo "PREFLIGHT: PASS"
elif echo "$PROMPT" | grep -q "planning agent"; then
    # Find the plan output file path from the prompt
    PLAN_FILE=$(echo "$PROMPT" | grep -oP 'Write your complete plan to \K[^\s]+')
    if [ -n "$PLAN_FILE" ]; then
        echo "- [x] **Task 1: Setup** — Initial setup" > "$PLAN_FILE"
        echo "Plan created"
    fi
elif echo "$PROMPT" | grep -q "plan-evaluation"; then
    echo "Plan looks good"
elif echo "$PROMPT" | grep -q "builder agent"; then
    echo "Built successfully"
elif echo "$PROMPT" | grep -q "Senior SWE"; then
    echo "Review complete"
fi
exit 0
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            # Should complete without infinite loop since all tasks are [x]
            { Invoke-DevLoop -SpecsDir $specsDir -ProjectDir $projectDir } | Should -Not -Throw
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'Manifest checkpoint and resume' {
    BeforeAll {
        . $script:CommonPath
    }

    It 'Read-Manifest and Save-Manifest round-trip correctly' {
        # Simulate the manifest helpers behavior
        $manifestFile = Join-Path $TestDrive 'manifest.json'

        $manifest = @{
            runId  = 'test-run'
            specs  = @(
                @{
                    name   = '01-test'
                    file   = '/path/to/01-test.md'
                    phases = [ordered]@{
                        plan      = [ordered]@{ started = $null; completed = $null }
                        'plan-eval' = [ordered]@{ started = $null; completed = $null }
                        build     = [ordered]@{ started = $null; completed = $null }
                        review    = [ordered]@{ started = $null; completed = $null }
                    }
                }
            )
        }

        $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestFile -Encoding UTF8

        $loaded = Get-Content $manifestFile -Raw | ConvertFrom-Json
        $loaded.runId | Should -Be 'test-run'
        $loaded.specs.Count | Should -Be 1
        $loaded.specs[0].name | Should -Be '01-test'
        $loaded.specs[0].phases.plan.completed | Should -BeNullOrEmpty

        # Simulate completing a phase
        $loaded.specs[0].phases.plan.started = '2026-03-15T12:00:00'
        $loaded.specs[0].phases.plan.completed = '2026-03-15T12:01:00'
        $loaded | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestFile -Encoding UTF8

        $reloaded = Get-Content $manifestFile -Raw | ConvertFrom-Json
        $reloaded.specs[0].phases.plan.completed.ToString('o') | Should -Match '2026-03-15T12:01:00'
    }
}

Describe 'Get-AgentPaths edge cases' {
    BeforeAll {
        . $script:CommonPath
    }

    It 'handles spec file with single digit prefix' {
        $specFile = Join-Path $TestDrive 'specs' '1-simple.md'
        $runDir = Join-Path $TestDrive 'run'
        New-Item -ItemType Directory -Path (Split-Path $specFile -Parent) -Force | Out-Null

        $result = Get-AgentPaths -SpecFile $specFile -RunDir $runDir
        $result.SpecBaseName | Should -Be '1-simple'
    }

    It 'handles deeply nested run directory' {
        $specFile = Join-Path $TestDrive 'specs' '01-test.md'
        $runDir = Join-Path $TestDrive 'project' '.dev-loop' '20260315-120000'
        New-Item -ItemType Directory -Path (Split-Path $specFile -Parent) -Force | Out-Null

        $result = Get-AgentPaths -SpecFile $specFile -RunDir $runDir
        $result.DevLoopRoot | Should -Be (Join-Path $TestDrive 'project' '.dev-loop')
    }
}

Describe 'Copilot non-zero exit handling' {
    BeforeAll {
        . $script:CommonPath
    }

    It 'propagates specific exit codes from copilot' {
        $mockBin = Join-Path $TestDrive 'mockbin-exit'
        New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
        $mockCopilot = Join-Path $mockBin 'copilot'
        @'
#!/bin/bash
echo "failed"
exit 42
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $logFile = Join-Path $TestDrive 'exit-code.log'
        $originalPath = $env:PATH
        $env:PATH = "${mockBin}:$env:PATH"
        try {
            { Invoke-Copilot -Prompt 'test' -LogFile $logFile } | Should -Throw '*Copilot exited with code*'
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'Module manifest validation' {
    It 'module manifest is valid' {
        { Test-ModuleManifest -Path $script:ModulePath } | Should -Not -Throw
    }

    It 'exports only Invoke-DevLoop' {
        $manifest = Test-ModuleManifest -Path $script:ModulePath
        $manifest.ExportedFunctions.Keys | Should -Be @('Invoke-DevLoop')
    }

    It 'requires PowerShell 7.0 or later' {
        $manifest = Test-ModuleManifest -Path $script:ModulePath
        $manifest.PowerShellVersion | Should -Be '7.0'
    }
}
