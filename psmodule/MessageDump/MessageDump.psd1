@{
    RootModule        = 'MessageDump.psm1'
    ModuleVersion     = '1.4.0'
    GUID              = 'a3f7b2c1-8d4e-4f6a-9b0c-1e2d3f4a5b6c'
    Author            = 'Cishoon'
    Description       = 'Message Dump - Copy last command and output to clipboard'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('_md_main')
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('clipboard', 'command', 'output', 'copy', 'productivity')
            LicenseUri = 'https://github.com/Cishoon/md/blob/main/LICENSE'
            ProjectUri = 'https://github.com/Cishoon/md'
        }
    }
}
