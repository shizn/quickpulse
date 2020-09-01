# Script to create a secure quick pulse environment
[CmdletBinding()]
param ( 
  [Parameter()]
  [String]
  $SubscriptionId,

  [Parameter()]
  [String]
  $Owner,

  [Parameter()]
  [Alias("VMPassword")]
  [String]
  $VMPasswordClear,

  [Parameter()]
  [String]
  $labname
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Output "Subscription used $SubscriptionId"
Select-AzSubscription -SubscriptionId $SubscriptionId
$Id = Get-Random -Maximum 999 -Minimum 100 
#$Characters = 'abcdefghkmnprstuvwxyz23456789$%&?*+#'
#$VMPasswordClear = (-join ($Characters.ToCharArray() | Get-Random -Count 12)).ToString()
$VMPassword = ConvertTo-SecureString "$VMPasswordClear" -AsPlainText -Force 
$VMResourceGroup = "QPRG${Id}"
$LabResourceGroup = "LABRG${Id}"
$Location = 'Westus2'
$VMName = "QPVM${Id}" 
$VMUSer = 'azureuser'
$VMSize = 'Standard_DS2_v2'
$VMCredential = New-Object System.Management.Automation.PSCredential ( $VMUser, $VMPassword)
$VMPublicIpName = "QPVMIp${Id}"
$Tags = @{ owner="${Owner}"; lab="${labname}${Id}"}
# $MyIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

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

$VMNic = New-AzNetworkInterface -Name "$VMName-nic" -ResourceGroupName $VMResourceGroup -Location $Location -SubnetId $VNet.Subnets[0].Id `
            -PublicIpAddressId $PublicIp.Id -NetworkSecurityGroupId $nsg.Id -Tag $Tags

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


# Create a user identity for the lab participant 
$participantName = "labparticipant${Id}"
New-AzUserAssignedIdentity -ResourceGroupName $VMResourceGroup -Name $participantName
$participantId = (Get-AzUserAssignedIdentity -ResourceGroupName $VMResourceGroup -Name $participantName).Id
$participantClientId = (Get-AzUserAssignedIdentity -ResourceGroupName $VMResourceGroup -Name $participantName).ClientId
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $VMResourceGroup -Name $participantName).PrincipalId

Update-AzVM -ResourceGroupName $VMResourceGroup -VM $ParticipantVM -IdentityType UserAssigned -IdentityId $participantId

# Assign contributor role to the subscription
# New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName "Owner" -Scope "/subscriptions/$SubscriptionId"
New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName "Contributor" -Scope "/subscriptions/$SubscriptionId"

Write-Output "Installing PowerShell"
# Install PowerShell 7
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallPowerShell.ps1'
Start-Sleep 10

# Install Az Module in PowerShell 7
Write-Output "Installing Az module"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallAz.ps1'
Start-Sleep 10 

# Install Az.ManagedServiceIdentity module 
Write-Output "Installing ManagedServiceIdentity module"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallModule.ps1' -Parameter @{ModuleName = "Az.ManagedServiceIdentity"; ModuleVersion = "0.7.3"}
Start-Sleep 10 

# Install Azure CLI
Write-Output "Installing Azure CLI"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallAzCLI.ps1'
Start-Sleep 10

# Install VSCode 
Write-Output "Installing VSCode"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallVSCode.ps1'

Start-Sleep 10

# Install Python 
Write-Output "Installing Python"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallPython.ps1'
Start-Sleep 10

# Install Chrome
Write-Output "Installing Chrome"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallChrome.ps1'
Start-Sleep 10

# Copy master preferences 
Write-Output "Configuring Chrome HomePage"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/ChromeSettings.ps1' -Parameter @{ChromeHomePage = "https://docs.microsoft.com/en-us/azure/app-service/tutorial-python-postgresql-app?tabs=bash%2Cclone"}
Start-Sleep 10

# Install Git
Write-Output "Installing Git"
Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallGit.ps1'
Start-Sleep 10

# Assign JIT Policy to VM
$JitPolicy = (@{ id="/subscriptions/$SubscriptionId/resourceGroups/$VMResourceGroup/providers/Microsoft.Compute/virtualMachines/$VMName" 
                 ports=(@{ number=22; protocol="*"; allowedSourceAddressPrefix=@("*"); maxRequestAccessDuration="PT3H"}, @{ number=3389; protocol="*"; allowedSourceAddressPrefix=@("*"); maxRequestAccessDuration="PT3H"})})
$JitPolicyArr=@($JitPolicy)
Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location $Location -Name "default" -ResourceGroupName $VMResourceGroup -VirtualMachine $JitPolicyArr

$VMPublicIpAddress =  (Get-AzPublicIpAddress -Name $VMPublicIpName -ResourceGroupName $VMResourceGroup).IpAddress

Write-Output "
Virtual Machine user:     $VMUser`
Virtual Machine Password: $VMPasswordClear`
ResourceGroup:            $VMResourceGroup`
VM PublicIP:              $VMPublicIpAddress`
Connect to Azure using:   Connect-AzAccount -Identity -AccountId $participantClientId
"

Write-Output( "Script completed in " + $stopwatch.Elapsed.TotalSeconds + "seconds" )
