[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ModuleName,
    [Parameter()]
    [string]
    $ModuleVersion
)

& "C:\Program Files\PowerShell\7\pwsh.exe" -c "Install-Module -Scope AllUsers -Name $ModuleName -RequiredVersion $ModuleVersion -AllowPreRelease -Force"