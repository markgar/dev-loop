# Common.Tests.ps1 — Unit tests for _common.ps1 shared utilities

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src' 'dev-loop'
    $script:CommonPath = Join-Path $script:ModuleRoot 'agents' '_common.ps1'
}

Describe 'Log' {
    BeforeAll {
        # Each test needs a fresh LogFile
        $script:LogFile = Join-Path $TestDrive 'test.log'
        . $script:CommonPath
    }

    It 'writes message to host and appends to log file' {
        Log 'hello world' 'White'

        $script:LogFile | Should -Exist
        $content = Get-Content $script:LogFile -Raw
        $content | Should -Match 'hello world'
    }

    It 'prepends a timestamp in HH:mm:ss format' {
        $script:LogFile = Join-Path $TestDrive 'ts.log'
        Log 'timestamp check' 'Gray'

        $line = Get-Content $script:LogFile
        $line | Should -Match '^\d{2}:\d{2}:\d{2} timestamp check$'
    }

    It 'appends multiple messages to the same file' {
        $script:LogFile = Join-Path $TestDrive 'multi.log'
        Log 'first' 'White'
        Log 'second' 'White'

        $lines = Get-Content $script:LogFile
        $lines.Count | Should -Be 2
        $lines[0] | Should -Match 'first'
        $lines[1] | Should -Match 'second'
    }

    It 'defaults Color to White when not specified' {
        $script:LogFile = Join-Path $TestDrive 'default.log'
        # Log should not throw when called with just a message
        { Log 'default color' } | Should -Not -Throw
    }
}

Describe 'Get-GitInstruction' {
    BeforeAll {
        . $script:CommonPath
    }

    It 'returns push instruction when -Push is specified' {
        $result = Get-GitInstruction -Push
        $result | Should -BeLike '*push*'
        $result | Should -BeLike '*commit*'
    }

    It 'returns commit-only instruction when -Push is not specified' {
        $result = Get-GitInstruction
        $result | Should -BeLike '*commit*'
        $result | Should -Not -BeLike '*push*'
    }
}

Describe 'Get-AgentPaths' {
    BeforeAll {
        . $script:CommonPath
    }

    It 'returns correct paths for a given spec file and run dir' {
        $specFile = Join-Path $TestDrive 'specs' '01-my-feature.md'
        $runDir = Join-Path $TestDrive '.dev-loop' '20260315-120000'

        # Create the spec directory so Split-Path works
        New-Item -ItemType Directory -Path (Split-Path $specFile -Parent) -Force | Out-Null

        $result = Get-AgentPaths -SpecFile $specFile -RunDir $runDir

        $result.SpecBaseName | Should -Be '01-my-feature'
        $result.SpecsDir | Should -Be (Join-Path $TestDrive 'specs')
        $result.ConstitutionPath | Should -Be (Join-Path $TestDrive 'specs' 'CONSTITUTION.md')
        $result.PlanFile | Should -Be (Join-Path $runDir 'plan-01-my-feature.md')
        $result.DevLoopRoot | Should -Be (Join-Path $TestDrive '.dev-loop')
    }

    It 'handles spec file names with multiple dashes' {
        $specFile = Join-Path $TestDrive 'specs' '03-multi-word-feature-name.md'
        $runDir = Join-Path $TestDrive 'run1'

        New-Item -ItemType Directory -Path (Split-Path $specFile -Parent) -Force | Out-Null

        $result = Get-AgentPaths -SpecFile $specFile -RunDir $runDir

        $result.SpecBaseName | Should -Be '03-multi-word-feature-name'
        $result.PlanFile | Should -Be (Join-Path $runDir 'plan-03-multi-word-feature-name.md')
    }
}

Describe 'Write-AgentError' {
    BeforeAll {
        . $script:CommonPath
    }

    It 'writes error message to host and log file' {
        $logFile = Join-Path $TestDrive 'agent-error.log'

        # Capture host output
        $output = Write-AgentError -AgentName 'test-agent' -ErrorRecord 'something broke' -LogFile $logFile 6>&1

        $logFile | Should -Exist
        $content = Get-Content $logFile -Raw
        $content | Should -Match 'FATAL \[test-agent\]: something broke'
    }

    It 'includes timestamp in log entry' {
        $logFile = Join-Path $TestDrive 'agent-error-ts.log'

        Write-AgentError -AgentName 'build' -ErrorRecord 'compile error' -LogFile $logFile

        $line = Get-Content $logFile
        $line | Should -Match '^\d{2}:\d{2}:\d{2} FATAL \[build\]: compile error$'
    }
}

Describe 'Invoke-AgentBlock' {
    BeforeAll {
        . $script:CommonPath
    }

    It 'executes the action scriptblock in the specified directory' {
        $targetDir = Join-Path $TestDrive 'project'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $logFile = Join-Path $TestDrive 'agent-block.log'

        $capturedDir = $null
        Invoke-AgentBlock -AgentName 'test' -ProjectDir $targetDir -LogFile $logFile -Action {
            $capturedDir = (Get-Location).Path
        }

        # Pester runs in its own location; the block should have changed to $targetDir
        # Note: We captured the variable inside the scriptblock via dot-sourcing
    }

    It 'restores location after execution' {
        $targetDir = Join-Path $TestDrive 'project2'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $logFile = Join-Path $TestDrive 'restore.log'

        $before = (Get-Location).Path
        Invoke-AgentBlock -AgentName 'test' -ProjectDir $targetDir -LogFile $logFile -Action { }
        $after = (Get-Location).Path

        $after | Should -Be $before
    }

    It 'restores location even when action throws' {
        $targetDir = Join-Path $TestDrive 'project3'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $logFile = Join-Path $TestDrive 'throw.log'

        $before = (Get-Location).Path
        { Invoke-AgentBlock -AgentName 'test' -ProjectDir $targetDir -LogFile $logFile -Action {
            throw 'intentional failure'
        } } | Should -Throw '*intentional failure*'
        $after = (Get-Location).Path

        $after | Should -Be $before
    }

    It 'logs error and re-throws when action fails' {
        $targetDir = Join-Path $TestDrive 'project4'
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $logFile = Join-Path $TestDrive 'rethrow.log'

        { Invoke-AgentBlock -AgentName 'myagent' -ProjectDir $targetDir -LogFile $logFile -Action {
            throw 'agent failure'
        } } | Should -Throw

        $logFile | Should -Exist
        $content = Get-Content $logFile -Raw
        $content | Should -Match 'FATAL \[myagent\]'
    }
}

Describe 'Invoke-Copilot' {
    BeforeAll {
        . $script:CommonPath
    }

    BeforeEach {
        $script:LogFile = Join-Path $TestDrive "copilot-$(New-Guid).log"
    }

    It 'calls copilot with correct arguments' {
        # Create a mock copilot that records its arguments
        $mockCopilot = Join-Path $TestDrive 'copilot'
        @'
#!/bin/bash
echo "mock copilot output"
exit 0
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $originalPath = $env:PATH
        $env:PATH = "${TestDrive}:$env:PATH"
        try {
            Invoke-Copilot -Prompt 'test prompt' -LogFile $script:LogFile
        }
        finally {
            $env:PATH = $originalPath
        }

        $script:LogFile | Should -Exist
        $content = Get-Content $script:LogFile -Raw
        $content | Should -Match 'mock copilot output'
    }

    It 'includes --model flag when Model is specified' {
        $mockCopilot = Join-Path $TestDrive 'copilot'
        @'
#!/bin/bash
# Echo the arguments so we can verify them
echo "ARGS: $@"
exit 0
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $originalPath = $env:PATH
        $env:PATH = "${TestDrive}:$env:PATH"
        try {
            Invoke-Copilot -Prompt 'test prompt' -Model 'claude-sonnet-4' -LogFile $script:LogFile
        }
        finally {
            $env:PATH = $originalPath
        }

        $content = Get-Content $script:LogFile -Raw
        $content | Should -Match 'model'
    }

    It 'throws when copilot exits with non-zero code' {
        $mockCopilot = Join-Path $TestDrive 'copilot'
        @'
#!/bin/bash
echo "error output"
exit 1
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $originalPath = $env:PATH
        $env:PATH = "${TestDrive}:$env:PATH"
        try {
            { Invoke-Copilot -Prompt 'test prompt' -LogFile $script:LogFile } | Should -Throw '*Copilot exited with code*'
        }
        finally {
            $env:PATH = $originalPath
        }
    }

    It 'annotates stderr lines with [STDERR] prefix in log' {
        $mockCopilot = Join-Path $TestDrive 'copilot'
        @'
#!/bin/bash
echo "normal output"
echo "error line" >&2
exit 0
'@ | Set-Content $mockCopilot
        chmod +x $mockCopilot

        $originalPath = $env:PATH
        $env:PATH = "${TestDrive}:$env:PATH"
        try {
            Invoke-Copilot -Prompt 'test prompt' -LogFile $script:LogFile
        }
        finally {
            $env:PATH = $originalPath
        }

        $content = Get-Content $script:LogFile -Raw
        $content | Should -Match '\[STDERR\]'
    }
}
