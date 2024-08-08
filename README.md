# SYNOPSIS

Copies an Azure VM's OS disk to a storage account.

## EXAMPLE

    PS> .\AzCopyVHD.ps1 -ResourceGroupName "MyResourceGroup" -VMName "MyVM" -StorageAccountName "MyStorageAccount" -StorageContainerName "MyContainer" -DestinationFileName "MyVHD.vhd"

## DESCRIPTION

This script copies an Azure VM's OS disk to a storage account. 
The script generates a Shared Access Signature (SAS) for the OS disk, 
copies the disk to the storage account, and then revokes the SAS.

## NOTES

You may need additional Azure permissions in order to be able to run this script.  
At a minimum you need:

1. Read access to the VM OS disk
2. Permission to generate an SAS token for the VM OS disk.
3. Permission to read/fetch the storage account key.
4. Permission to write to the storage account.

## Parameters

### -ResourceGroupName

The name of the resource group, as a string, as shown in the azure portal

### -VMName

The name of the virtual machine, as a string, as shown in the azure portal

### -SasExpiryDuration

(Optional) The duration in seconds for which the SAS token will be valid, default is 28800 seconds (8 hours)
This is revoked after completion of the script, but is not revoked on failure.

### -StorageAccountName

The name of the storage account where the disk image will be copied, as a string, as shown in the azure portal

### -StorageContainerName

The name of the storage container where the disk image will be copied, as a string, as shown in the azure portal

### -DestinationFileName

The name of the VHD file to which the disk image will be copied, as a string, must end with .vhd

### -NoConfirm

(Optional) If specified, the script will not prompt for confirmation before proceeding

