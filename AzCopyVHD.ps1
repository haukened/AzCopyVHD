<#PSScriptInfo

.VERSION 1.0

.GUID e97fdded-667a-4bf3-a54c-7500f786c109

.AUTHOR David Haukeness

.COPYRIGHT (c) 2024 David Haukeness

.LICENSEURI https://www.github.com/haukened/AzCopyVHD/LICENSE

.PROJECTURI https://www.github.com/haukened/AzCopyVHD

.RELEASENOTES First Release.

#>

#requires -version 7

<#
    .SYNOPSIS
    Copies an Azure VM's OS disk to a storage account.

    .DESCRIPTION
    This script copies an Azure VM's OS disk to a storage account. 
    The script generates a Shared Access Signature (SAS) for the OS disk, 
    copies the disk to the storage account, and then revokes the SAS.

    .NOTES
    You may need additional Azure permissions in order to be able to run this script.  
    At a minimum you need:
    1. Read access to the VM OS disk
    2. Permission to generate an SAS token for the VM OS disk.
    3. Permission to read/fetch the storage account key.
    4. Permission to write to the storage account.

    .PARAMETER ResourceGroupName
    The name of the resource group, as a string, as shown in the azure portal

    .PARAMETER VMName
    The name of the virtual machine, as a string, as shown in the azure portal

    .PARAMETER SasExpiryDuration
    (Optional) The duration in seconds for which the SAS token will be valid, default is 28800 seconds (8 hours)
    This is revoked after completion of the script, but is not revoked on failure.

    .PARAMETER StorageAccountName
    The name of the storage account where the disk image will be copied, as a string, as shown in the azure portal

    .PARAMETER StorageContainerName
    The name of the storage container where the disk image will be copied, as a string, as shown in the azure portal

    .PARAMETER DestinationFileName
    The name of the VHD file to which the disk image will be copied, as a string, must end with .vhd

    .PARAMETER NoConfirm
    (Optional) If specified, the script will not prompt for confirmation before proceeding

    .EXAMPLE
    PS> .\AzCopyVHD.ps1 -ResourceGroupName "MyResourceGroup" -VMName "MyVM" -StorageAccountName "MyStorageAccount" -StorageContainerName "MyContainer" -DestinationFileName "MyVHD.vhd"
#>

param (
    #Provide the name of your resource group where the VM is located
    [Parameter(Mandatory)][string]$ResourceGroupName,
    # Provide the name of the virtual machine
    [Parameter(Mandatory)][string]$VMName,
    #Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 3600.
    #Know more about SAS here: https://docs.microsoft.com/en-us/Az.Storage/storage-dotnet-shared-access-signature-part-1
    [Parameter()][int]$SasExpiryDuration = 28800,
    #Provide storage account name where you want to copy the disk image.
    [Parameter(Mandatory)][string]$StorageAccountName,
    #Name of the storage container where the downloaded disk image will be stored
    [Parameter(Mandatory)][string]$StorageContainerName,
    #Provide the name of the VHD file to which disk image will be copied.
    [Parameter(Mandatory)][string]$DestinationFileName,
    # NoConfirm
    [Parameter()][switch]$NoConfirm = $false
)

$ErrorActionPreference = "Stop"

# Validate that the destination VHD file name ends with .vhd
if ($DestinationFileName -notlike "*.vhd") {
    Write-Error "Destination file name must end with .vhd"
    exit
}

# Connect to Azure
$Context = Get-AzContext  
if (!$Context)   
{  
    Connect-AzAccount  
} 

# Get the current subscription
$SubscriptionId = (Get-AzContext).Subscription.Id
$SubscriptionName = (Get-AzContext).Subscription.Name
Write-Host -ForegroundColor Yellow "Currently signed into $SubscriptionName ($SubscriptionId)"

# get the region
$Region = (Get-AzResourceGroup -Name $ResourceGroupName).Location
Write-Host "Using azure region $Region (inherited from $ResourceGroupName)"

# Get the OS disk of the VM
$VMOSDiskName = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName).StorageProfile.OsDisk.Name
Write-Host "OS disk Name: $VMOSDiskName"

if (!$NoConfirm) {
    Write-Host -ForegroundColor Yellow "This script will copy the OS disk of the VM $VMName to the storage account $StorageAccountName in the container $StorageContainerName as $DestinationFileName"
    $Response = $(Write-Host -ForegroundColor Yellow -NoNewline "Do you want to continue? (Y/N)"; Read-Host)
    if ($Response -ne "Y" -and $Response -ne "y") {
        Write-Host -ForegroundColor Red "Exiting..."
        exit
    }
}

# Disable the display of secrets warning
Update-AzConfig -DisplaySecretsWarning $false | Out-Null

# Get the storage account key
Write-Host "Getting storage account key..."
$StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Value[0]

#Generate the SAS for the snapshot
Write-Host "Generating one time secure access link (valid for $SasExpiryDuration seconds)..." 
$SAS = Grant-AzDiskAccess -ResourceGroupName $ResourceGroupName -DiskName $VMOSDiskName -DurationInSecond $SasExpiryDuration -Access Read

#Create the context for the storage account which will be used to copy snapshot to the storage account 
$DestinationContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

# Re-Enable the display of secrets warning
Update-AzConfig -DisplaySecretsWarning $true | Out-Null

#Copy the snapshot to the storage account 
Write-Host "Copying VHD to storage account..."
$StartTime = Get-Date
$CopyResult = Copy-AzStorageBlob -AbsoluteUri $SAS.AccessSAS -DestContainer $StorageContainerName -DestContext $DestinationContext -DestBlob $DestinationFileName -Force
$EndTime = Get-Date
$CopyDuration = New-TimeSpan -Start $StartTime -End $EndTime
Write-Host "$($CopyResult.Name) $($CopyResult.Length) bytes copied in $($CopyDuration.TotalSeconds) seconds"
Write-Host "Revoking secure access link..."
Revoke-AzDiskAccess -ResourceGroupName $ResourceGroupName -DiskName $VMOSDiskName
Write-Host "Complete!"