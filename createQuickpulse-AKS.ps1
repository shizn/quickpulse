# Script to create a secure quick pulse environment
[CmdletBinding()]
param ( 
  [Parameter()]
  [String]
  $SubscriptionId,

  [Parameter()]
  [String]
  $Owner
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

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
$Tags = @{ owner="${Owner}"; lab="aks${Id}"}
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
  
# Allow remote access 
$PublicIp = New-AzPublicIpAddress -Name $VMPublicIpName -ResourceGroupName $VMResourceGroup -Location $Location -AllocationMethod Dynamic -Tag $Tags

$VMNic = New-AzNetworkInterface -Name "$VMName-nic" -ResourceGroupName $VMResourceGroup -Location $Location -SubnetId $VNet.Subnets[0].Id `
            -PublicIpAddressId $PublicIp.Id -Tag $Tags

$VMConfig = New-AzVMConfig -Name $VMName -VMSize $VMSize -IdentityType SystemAssigned -Tags $Tags | `
                     Set-AzVMOperatingSystem -Windows -Credential $VMCredential -ComputerName $VMName | `
                     Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus '2019-Datacenter' -Version latest | `
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
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallPowerShell.ps1'
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
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallAz.ps1'
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

# Add start-Transcript
Write-Output "Adding transcript"
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/AddTranscript.ps1'
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

# Install NetCore
Write-Output "Installing dotnet Core"
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallDotnetCore.ps1'
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

# Install VSCode 
Write-Output "Installing VSCode"
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallVSCode.ps1'
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

# Install Chrome
Write-Output "Installing Chrome"
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/InstallChrome.ps1'
If ($InvokeCommandResult.Status -eq "Succeeded")
{
  Write-Output "Installation succeded. ${InvokeCommandResult.Value[0].Message}"
}
else
{ 
  Write-Error "Issue encountered while installing Az: ${InvokeCommandResult.Value[1].Message}"
  Break
}
Start-Sleep 20

# Copy master preferences 
Write-Output "Configuring Chrome HomePage"
$InvokeCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $VMResourceGroup -VMName $ParticipantVM.Name -CommandId 'RunPowerShellScript' -ScriptPath './tools/ChromeSettings.ps1' -Parameter @{ChromeHomePage = "https://docs.microsoft.com/en-us/azure/aks/"}
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

Write-Output( "Script completed in " + $stopwatch.Elapsed.TotalSeconds + "seconds" )
