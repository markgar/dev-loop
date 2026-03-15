@{
    Severity = @('Error', 'Warning', 'Information')

    IncludeDefaultRules = $true

    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }

        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter      = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize     = 4
        }

        PSUseConsistentWhitespace = @{
            Enable                          = $true
            CheckInnerBrace                 = $true
            CheckOpenBrace                  = $true
            CheckOpenParen                  = $true
            CheckOperator                   = $true
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator                  = $true
            CheckParameter                  = $false
        }

        PSAlignAssignmentStatement = @{
            Enable         = $false
            CheckHashtable = $false
        }
    }

    ExcludeRules = @(
        # Allow Write-Host for console output in agent scripts
        'PSAvoidUsingWriteHost'
        # BOM is unnecessary for modern tooling and harmful on Linux
        'PSUseBOMForUnicodeEncodedFile'
        # Agent params are consumed inside scriptblocks — not a real unused-parameter issue
        'PSReviewUnusedParameter'
        # Internal helpers, not user-facing cmdlets
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
