function Mount-ISO-File {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [string]$ISOLocalPath,
        [Parameter(Mandatory=$false)]
        [string]$ISODestinationPath
    )
    try{
        If(!([System.IO.File]::Exists($ISOLocalPath))){
            Write-Error "File $ISOLocalPath does not exist"
            Break
        }
        If([IO.Path]::GetExtension($ISOLocalPath) -ne ".iso"){
            Write-Error "File $ISOLocalPath is not an ISO file"
            Break
        }
        Copy-DataStoreItem $ISOLocalPath -Destination $ISODestinationPath
        $ISO = Get-Item $ISODestinationPath
        $file = Get-Item $ISOLocalPath
        $ISOfile = join-path $ISO.DataStoreFullPath $file.name
        New-CDDrive -VM $Name -ISOPath $ISOfile
        
    }catch{
        Write-Host "An error occurred:"
        Write-Host $_
    }
}

function Remove-VSphereVMs-From-Template{
    param(
        [Parameter(Mandatory=$true)]
        [string] $TemplateName, 
        [Parameter(Mandatory=$true)]
        [string] $VMHost
    )
    try{
        $deployementEvents = Get-VM | Get-VIEvent | Where-Object -FilterScript {($_ -is [vmware.vim.VmDeployedEvent]) -and ($_.SrcTemplate.Name -eq $TemplateName) -and ($_.Host.Name -eq $VMHost)}
        If ($deployementEvents.Count -eq 0){
            Write-Host "No VMs found with template name $TemplateName on host $VMHost"
        }Else{
            for ($i = 0; $i -lt $deployementEvents.Count; $i++) {
                $vm = Get-VM -Name $deployementEvents[$i].Vm.Name
                if ($vm.PowerState -eq "PoweredOn"){
                    $vm | Stop-VM -Confirm:$false
                }
                $vm | Remove-VM -DeletePermanently -Confirm:$false
            }
            Write-Host "Removed $($deployementEvents.Count) VMs with template name $TemplateName on host $VMHost"
        }
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

        If($NumOfVMs -lt 1){
            Write-Error "Number of VMs must be greater than 0"
            Break
        }

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
