@{
    # Module identity
    RootModule        = 'dev-loop.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '32c17d8f-3241-4f4e-b961-f2c2f2aed684'

    # Metadata
    Author            = 'Mark Garner'
    Description       = 'Automated development loop powered by GitHub Copilot CLI. Processes numbered spec files through plan, build, review, and test phases using autonomous agents.'
    PowerShellVersion = '7.0'

    # Exports
    FunctionsToExport = @('Invoke-DevLoop')
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    # Gallery metadata
    PrivateData = @{
        PSData = @{
            Tags       = @('copilot', 'automation', 'dev-loop', 'codegen', 'agents')
            LicenseUri = ''   # TODO: Add license URI before publishing
            ProjectUri = ''   # TODO: Add project URI before publishing
        }
    }
}
