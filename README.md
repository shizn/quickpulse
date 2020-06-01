# Script files to provisition a VM for a quick pulse

The scripts on this repository will provision in an Azure Subscription a virtual machine with the required tools to run a quickpulse study.

Two resource groups will be created LABRG123 and QPRG123 (Note: the 123 id will change at each deployment). The VM for the participants to use is in the QPRG123 resource group and have MSI permissions on the LABRG123 resource group.

The VM deployed is runnig Windows Server 2019, Datacenter edition. Once the VM has been deployed we use the `Run-AzCommand` to execute PowerShell scripts on the target VM to install the needed tools.

End to end scripts available:

- [Azure Functions Environment](./createQuickPulse-Functions.ps1)
- [AKS Environment](./createQuickPulse-AKS.ps1)
- [Azure MySQL Environment](./createQuickPulse-MySQL.ps1)

We currently have the following scripts:

- [InstallPowerShell.ps1](./tools/InstallPowerShell.ps1) - PowerShell 7
- [InstallAz.ps1](./tools/InstallAz.ps1) - Install Azure PowerShell modules
- [InstallModule.ps1](./tools/InstallModule.ps1) - Install a Specific version of a PowerShell module available in the PowerShell gallery
- [AddTranscript.ps1](./tools/AddTranscript.ps1) - Enable PowerShell transcript
- [InstallDotNetCore.ps1](./tools/InstallDotnetCore.ps1) - Install dotnet Core
- [InstallVSCode.ps1](./tools/InstallVSCode.ps1) - Install VSCode
- [InstallChrome.ps1](./tools/InstallChrome.ps1) - Install Chrome
- [InstallFunctionsTools.ps1](./tools/InstallFunctionsTools.ps1) - Install Azure Functions core tools

In preview:

- [ChromeSettings.ps1](./tools/ChromeSettings.ps1) - Define the default settings for Chrome

## Pre-requisite

In order to run the scripts, you will need:

- PowerShell 7: [Install PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7)
- Latest Azure PowerShell module: [Install Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)

## Execute the script

Launch `PowerShell 7` and execute the script using a command similar to this:

```powershell
.\createQuickpulse-Functions.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000
```

Where 00000000-0000-0000-0000-000000000000 is the subscription Id where you want the lab to be deployed.

## Help and support

Please [open an issue](https://github.com/dcaro/quickpulse/issues/new/choose).
