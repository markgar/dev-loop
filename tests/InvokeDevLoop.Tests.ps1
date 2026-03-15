# InvokeDevLoop.Tests.ps1 — Integration tests for Invoke-DevLoop manifest flow

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src' 'dev-loop'
    $script:ModulePath = Join-Path $script:ModuleRoot 'dev-loop.psd1'
}

Describe 'Invoke-DevLoop parameter validation' {
    BeforeAll {
        Import-Module $script:ModulePath -Force
    }

    AfterAll {
        Remove-Module dev-loop -ErrorAction SilentlyContinue
    }

    It 'throws when SpecsDir does not exist' {
        { Invoke-DevLoop -SpecsDir '/nonexistent/path' -ProjectDir $TestDrive } | Should -Throw
    }

    It 'throws when ProjectDir does not exist' {
        $specsDir = Join-Path $TestDrive 'specs'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null

        { Invoke-DevLoop -SpecsDir $specsDir -ProjectDir '/nonexistent/path' } | Should -Throw
    }

    It 'throws when ProjectDir is not a git repository' {
        $specsDir = Join-Path $TestDrive 'specs'
        $projectDir = Join-Path $TestDrive 'project'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

        { Invoke-DevLoop -SpecsDir $specsDir -ProjectDir $projectDir } | Should -Throw '*not a git repository*'
    }

    It 'throws when copilot CLI is not on PATH' {
        $specsDir = Join-Path $TestDrive 'specs2'
        $projectDir = Join-Path $TestDrive 'project2'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $projectDir '.git') -Force | Out-Null

        # Ensure copilot is not found
        Mock -ModuleName dev-loop Get-Command { $null } -ParameterFilter { $Name -eq 'copilot' }

        { Invoke-DevLoop -SpecsDir $specsDir -ProjectDir $projectDir } | Should -Throw '*Copilot CLI*'
    }

    It 'throws when -GitPush is specified but no remote is configured' {
        $specsDir = Join-Path $TestDrive 'specs3'
        $projectDir = Join-Path $TestDrive 'project3'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

        # Initialize a real git repo with no remote
        Push-Location $projectDir
        try {
            git init --quiet 2>$null
            git config user.email 'test@test.com'
            git config user.name 'Test'
        }
        finally {
            Pop-Location
        }

        # Mock copilot as available
        Mock -ModuleName dev-loop Get-Command { @{ Name = 'copilot' } } -ParameterFilter { $Name -eq 'copilot' }

        { Invoke-DevLoop -SpecsDir $specsDir -ProjectDir $projectDir -GitPush } | Should -Throw '*no git remote*'
    }
}

Describe 'Invoke-DevLoop tracking directory setup' {
    BeforeAll {
        Import-Module $script:ModulePath -Force
    }

    AfterAll {
        Remove-Module dev-loop -ErrorAction SilentlyContinue
    }

    It 'creates .dev-loop tracking directory' {
        $specsDir = Join-Path $TestDrive 'specs-track'
        $projectDir = Join-Path $TestDrive 'project-track'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

        # Create a spec file so preflight can find something
        '# Spec' | Set-Content (Join-Path $specsDir '01-test.md')

        # Init git repo
        Push-Location $projectDir
        try {
            git init --quiet 2>$null
            git config user.email 'test@test.com'
            git config user.name 'Test'
        }
        finally {
            Pop-Location
        }

        # Mock copilot as available
        Mock -ModuleName dev-loop Get-Command { @{ Name = 'copilot' } } -ParameterFilter { $Name -eq 'copilot' }

        # The preflight agent will run and call copilot, which will fail
        # But .dev-loop and .gitignore should be created before that
        try { Invoke-DevLoop -SpecsDir $specsDir -ProjectDir $projectDir } catch { }

        $trackingDir = Join-Path $projectDir '.dev-loop'
        $trackingDir | Should -Exist

        # .gitignore should contain .dev-loop/
        $gitignore = Join-Path $projectDir '.gitignore'
        $gitignore | Should -Exist
        $content = Get-Content $gitignore -Raw
        $content | Should -Match '\.dev-loop/'
    }
}

Describe 'Invoke-DevLoop manifest creation' {
    BeforeAll {
        Import-Module $script:ModulePath -Force
    }

    AfterAll {
        Remove-Module dev-loop -ErrorAction SilentlyContinue
    }

    It 'creates a valid manifest.json after preflight completes' {
        $specsDir = Join-Path $TestDrive 'specs-mf'
        $projectDir = Join-Path $TestDrive 'project-mf'
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

        '# Spec A' | Set-Content (Join-Path $specsDir '01-feature-a.md')
        '# Spec B' | Set-Content (Join-Path $specsDir '02-feature-b.md')

        # Init git repo
        Push-Location $projectDir
        try {
            git init --quiet 2>$null
            git config user.email 'test@test.com'
            git config user.name 'Test'
        }
        finally {
            Pop-Location
        }

        # Create a mock copilot that always succeeds and exits 0
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
            # This will complete preflight (mock copilot says PASS) and proceed.
            # Plan phase will also "succeed" (copilot exits 0) but won't create a plan file,
            # so the build phase won't find a plan file and will fail.
            # We catch and ignore since we're testing manifest creation.
            try { Invoke-DevLoop -SpecsDir $specsDir -ProjectDir $projectDir } catch { }
        }
        finally {
            $env:PATH = $originalPath
        }

        # Find the run directory (timestamped)
        $trackingDir = Join-Path $projectDir '.dev-loop'
        $runDirs = Get-ChildItem $trackingDir -Directory
        $runDirs.Count | Should -BeGreaterOrEqual 1

        $manifestFile = Join-Path $runDirs[0].FullName 'manifest.json'
        $manifestFile | Should -Exist

        $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
        $manifest.specs.Count | Should -Be 2
        $manifest.specs[0].name | Should -Be '01-feature-a'
        $manifest.specs[1].name | Should -Be '02-feature-b'
        $manifest.phases | Should -Contain 'plan'
        $manifest.phases | Should -Contain 'build'
        $manifest.phases | Should -Contain 'review'
    }
}
