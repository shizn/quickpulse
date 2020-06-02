# This script installs the given version of Python 
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Version = "3.7.0"
)

& "C:\Program Files\PowerShell\7\pwsh.exe" -c "Invoke-WebRequest -Uri https://www.python.org/ftp/python/${Version}/python-${Version}.exe -OutFile .\python.exe; .\python.exe /quiet InstallAllUsers=1 PrependPath=1"
