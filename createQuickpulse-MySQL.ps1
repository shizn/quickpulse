# Script to create a secure quick pulse environment

param (
  [string] $SubscriptionId
)

Write-Output "Subscription used $SubscriptionId"
Select-AzSubscription -SubscriptionId $SubscriptionId
$Id = Get-Random -Maximum 999 -Minimum 100 
#$Characters = 'abcdefghkmnprstuvwxyz23456789$%&?*+#'
#$VMPasswordClear = (-join ($Characters.ToCharArray() | Get-Random -Count 12)).ToString()
$VMPasswordClear = "AComplexP@ssw0rd!"
$VMPassword = ConvertTo-SecureString "$VMPasswordClear" -AsPlainText -Force 
$VMResourceGroup = "QPRG${Id}"
$LabResourceGroup = "LABRG${Id}"
$Location = 'EastUS'
$VMName = "QPVM${Id}" 
$VMUSer = 'azureuser'
$VMSize = 'Standard_DS2_v2'
$VMCredential = New-Object System.Management.Automation.PSCredential ( $VMUser, $VMPassword)
$VMPublicIpName = "QPVMIp${Id}"
$Tags = @{ owner="dcaro"; lab="mysql${Id}"}
$MyIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

Write-Output "
Virtual Machine user:     $VMUser`
Virtual Machine Password: $VMPasswordClear`
ResourceGroup:            $VMResourceGroup
"

# Create the Resource Groups
New-AzResourceGroup -Name $VMResourceGroup -Location $Location -Tag $Tags
$LabRG = New-AzResourceGroup -Name $LabResourceGroup -Location $Location -Tag $Tags

# Create the Virtual Network
$SubnetConfig = New-AzVirtualNetworkSubnetConfig -Name 'default' -AddressPrefix 10.0.1.0/24
$VNet = New-AzVirtualNetwork -ResourceGroupName $VMResourceGroup -Location $Location `
  -Name MYvNET -AddressPrefix 10.0.0.0/16 -Subnet $SubnetConfig -Tag $Tags
  
# Allow and secure remote access 
$PublicIp = New-AzPublicIpAddress -Name $VMPublicIpName -ResourceGroupName $VMResourceGroup -Location $Location -AllocationMethod Dynamic -Tag $Tags

# $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name "AllowRDP"  -Protocol Tcp `
#   -Direction Inbound -Priority 100 -SourceAddressPrefix $MyIP -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 `
# -Access Allow 
# $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $VMResourceGroup -Location $location -Name "$VMName-nsg" -SecurityRules $nsgRuleRDP -Tag $Tags

$VMNic = New-AzNetworkInterface -Name "$VMName-nic" -ResourceGroupName $VMResourceGroup -Location $Location -SubnetId $VNet.Subnets[0].Id `
            -PublicIpAddressId $PublicIp.Id -Tag $Tags #-NetworkSecurityGroupId $nsg.Id

$VMConfig = New-AzVMConfig -Name $VMName -VMSize $VMSize -IdentityType SystemAssigned -Tags $Tags | `
                     Set-AzVMOperatingSystem -Windows -Credential $VMCredential -ComputerName $VMName | `
                     Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus '2016-Datacenter' -Version latest | `
                     Add-AzVMNetworkInterface -Id $VMNic.Id

New-AzVM -ResourceGroupName $VMResourceGroup -Location $Location -VM $VMConfig -Tag $Tags

$timeout = New-TimeSpan -Minutes 5
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
while ( ((Get-AzVM -Name $VMName -ResourceGroupName $VMResourceGroup).Identity.PrincipalId -eq "") -and ($stopwatch.Elapsed -lt $timeout) ) {
    Write-Output "VM $VMName not ready for role assignment..."
    Start-Sleep -Seconds 5
}

$ParticipantVM = Get-AzVM -Name $VMName -ResourceGroupName $VMResourceGroup
# Assign permissions to the UX study resourcegroup
New-AzRoleAssignment -ObjectId $ParticipantVM.Identity.PrincipalId -RoleDefinitionName "Contributor" -Scope $LabRG.ResourceId

Write-Output "Installing PowerShell"
# Install PowerShell 7
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './InstallPowerShell.ps1'
If ($InvokeCommandResult.Status -eq "Succeeded")
{
  Write-Output "Installation succeded. ${InvokeCommandResult.Value[0].Message}"
}
else
{ 
  Write-Error "Issue encountered while installing Az: ${InvokeCommandResult.Value[1].Message}"
  Break
}
Start-Sleep 10 

# Install Az Module in PowerShell 7
Write-Output "Installing Az module"
$Script = '& "C:\Program Files\PowerShell\7\pwsh.exe" -c "Install-Module -Scope AllUsers -Name Az -Force"'
Out-File -FilePath ./VMScript.ps1 -InputObject $Script 
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './VMScript.ps1'
Start-Sleep 10 

# Install Az.MySQL module 
Write-Output "Installing MySQL module"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './InstallModule.ps1' -Parameter @{ModuleName = "Az.MySQL"; ModuleVersion = "0.1.0"}
Start-Sleep 10 

# Add start-Transcript
Write-Output "Adding transcript"
$Script = '& "C:\Program Files\PowerShell\7\pwsh.exe" -c "Add-Content -Path \`"C:\Program Files\PowerShell\7\profile.ps1\`" -Value Start-Transcript"'
Out-File -FilePath ./VMScript.ps1 -InputObject $Script 
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './VMScript.ps1'
Start-Sleep 10

# Install Chrome
Write-Output "Installing Chrome"
$Script = '& "C:\Program Files\PowerShell\7\pwsh.exe" -c {$LocalTempDir = $env:TEMP; $ChromeInstaller = "ChromeInstaller.exe"; (new-object    System.Net.WebClient).DownloadFile("http://dl.google.com/chrome/install/375.126/chrome_installer.exe", "$LocalTempDir\$ChromeInstaller"); & "$LocalTempDir\$ChromeInstaller" /silent /install; $Process2Monitor =  "ChromeInstaller"; Do { $ProcessesFound = Get-Process | ?{$Process2Monitor -contains $_.Name} | Select-Object -ExpandProperty Name; If ($ProcessesFound) { "Still running: $($ProcessesFound -join ", ")" | Write-Host; Start-Sleep -Seconds 2 } else { rm "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose } } Until (!$ProcessesFound)}'
Out-File -FilePath ./VMScript.ps1 -InputObject $Script 
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './VMScript.ps1'
Start-Sleep 10

# Copy master preferences 
Write-Output "Configuring Chrome HomePage"
$Script = '& "C:\Program Files\PowerShell\7\pwsh.exe" -c {@{homepage="https://docs.microsoft.com/en-us/azure/mysql/quickstart-create-mysql-server-database-using-azure-powershell" } | ConvertTo-Json | Out-File -FilePath "C:\Program Files (x86)\Google\Chrome\Application\master_preferences" }'
Out-File -FilePath ./VMScript.ps1 -InputObject $Script 
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './VMScript.ps1'

# Assign JIT Policy to VM
$JitPolicy = (@{ id="/subscriptions/$SubscriptionId/resourceGroups/$VMResourceGroup/providers/Microsoft.Compute/virtualMachines/$VMName" 
                 ports=(@{ number=22; protocol="*"; allowedSourceAddressPrefix=@("*"); maxRequestAccessDuration="PT3H"}, @{ number=3389; protocol="*"; allowedSourceAddressPrefix=@("*"); maxRequestAccessDuration="PT3H"})})
$JitPolicyArr=@($JitPolicy)
Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location $Location -Name "default" -ResourceGroupName $VMResourceGroup -VirtualMachine $JitPolicyArr

Write-Output "
Virtual Machine user:     $VMUser`
Virtual Machine Password: $VMPasswordClear`
ResourceGroup:            $VMResourceGroup`
VM PublicIP:              $PublicIP
"

# Install VSCode 
Write-Output "Installing VSCode"
$Script = '& "C:\Program Files\PowerShell\7\pwsh.exe" -c "Install-Script Install-VSCode -Scope AllUsers -Force; Install-VSCode.ps1"'
Out-File -FilePath ./VMScript.ps1 -InputObject $Script 
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './VMScript.ps1'
