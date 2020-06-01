# Install the function core tools v3
& "C:\Program Files\PowerShell\7\pwsh.exe" -c "Invoke-WebRequest http://github.com/Azure/azure-functions-core-tools/releases/download/3.0.2358/func-cli-3.0.2358-x64.msi -OutFile ./func-cli-3.0.2358-x64.msi; msiexec /qn /l* funccli-log.txt /i func-cli-3.0.2358-x64.msi"
