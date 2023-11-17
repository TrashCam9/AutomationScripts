function New-VSphereTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Datastore,
        [Parameter(Mandatory=$true)]
        [Decimal]$DiskGB,
        [Parameter(Mandatory=$true)]
        [string]$DiskStorageFormat,
        [Parameter(Mandatory=$true)]
        [Decimal]$MemoryGB,
        [Parameter(Mandatory=$true)]
        [int]$NumCPU,
        [Parameter(Mandatory=$true)]
        [string]$GuestId,
        [Parameter(Mandatory=$true)]
        [string]$VMHost,
        [Parameter(Mandatory=$false)]
        [string]$ISOPath,
        [Parameter(Mandatory=$false)]
        [string]$ISODestinationPath
    )
    try{
        New-VM -Name $Name -VMHost $VMHost -Datastore $Datastore -DiskGB $DiskGB -DiskStorageFormat $DiskStorageFormat -MemoryGB $MemoryGB -NumCPU $NumCPU -GuestId $GuestId -CD
        Copy-DataStoreItem $ISOPath -Destination $ISODestinationPath
        $ISO = Get-Item $ISODestinationPath
        $filePathString = $ISOPath + $ISODestinationPath.Split("\")[-1]
        $file = Get-Item $filePathString
        $ISOfile = join-path $ISO.DataStoreFullPath $file.name
        Get-CDDrive -VM $Name | Set-CDDrive -ISOPath $ISOfile -StartConnected $True -Confirm $False
        #TODO: BUSCA SI SE PUEDE AUTOMATIZAR LA INSTALACION DEL OS
    }catch{
        Write-Host "An error occurred:"
        Write-Host $_
    }
    

}

function New-VSphereVMs-From-Template {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Template,
        [Parameter(Mandatory=$true)]
        [string]$VMHost,
        [Parameter(Mandatory=$true)]
        [int]$NumOfVMs,
        [Parameter(Mandatory=$false)]
        [bool]$PowerOn = $false
    )

    try{
        $temp = Get-Template $Template
        $vmh = Get-VMHost $VMHost

        If($temp.ExtensionData.Config.Hardware.MemoryMB*$NumOfVMs -gt $vmh.MemoryTotalMB){
            Write-Error "Not enough memory on $vmh to create $NumOfVMs VMs"
            Break
        }

        $HD = $temp | Get-HardDisk
        $DS = Get-Datastore -Name $temp.ExtensionData.Config.DatastoreURL.name -VMHost $vmh

        If($HD.CapacityGB * $NumOfVMs -gt $DS.FreeSpaceGB){
            Write-Error "Not enough storage on $DS to create $NumOfVMs VMs"
            Break
        }

        For($i = 0; $i -le $NumOfVMs; $i++){
            $VMName = $Name + $i
            New-VM -Name $VMName -Template $temp -VMHost $vmh

            if($PowerOn){
                Start-VM -VM $VMName
            }
        }
    }catch{
        Write-Host "An error occurred:"
        Write-Host $_
    }
}
