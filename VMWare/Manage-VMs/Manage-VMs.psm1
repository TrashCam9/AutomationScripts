function Mount-ISOFile {
    <#
    .SYNOPSIS
        Function to mount iso file to VM
    .PARAMETER Name
        Name of the VM
    .PARAMETER ISOLocalPath
        Local path of the ISO file
    .PARAMETER ISODestinationPath
        Destination path of the ISO file.
        Hint: Use PSDrive vmstore:/ to get the path of the datastore
    #>
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

function Move-VMs {
    <#
    .SYNOPSIS
        Function migrate VMs to another host
    .PARAMETER VMs
        Array with the name of the VMs
    .PARAMETER MigrationType
        Name of the migration type
    .PARAMETER TargetNet
        Name of the target network
    .PARAMETER TargetDatastore
        Name of the target datastore
    .PARAMETER TargetResourcePool
        Name of the target resource pool
    .PARAMETER TargetFolder
        Name of the target folder
    .PARAMETER MobilityGroupName
        Name of the mobility group
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array] $VMs,
        [Parameter(Mandatory=$true)]
        [string] $MigrationType,
        [Parameter(Mandatory=$true)]
        [string] $TargetNet,
        [Parameter(Mandatory=$true)]
        [string] $TargetDatastore,
        [Parameter(Mandatory=$true)]
        [string] $TargetResourcePool,
        [Parameter(Mandatory=$true)]
        [string] $TargetFolder,
        [Parameter(Mandatory=$true)]
        [string] $MobilityGroupName
    )

    $targetSite = Get-HCXSite -Destination
    $sourceSite = Get-HCXSite -Source
    $tgtDatastore = Get-HCXDatastore -Site $targetSite -Name $TargetDatastore
    $targetContainer = Get-HCXContainer -Site $targetSite -Type "ResourcePool" -Name $TargetResourcePool
    $tgtFolder = Get-HCXContainer -Site $targetSite -Type Folder -Name $TargetFolder

    $mobilityGroupConfig = New-HCXMobilityGroupConfiguration -SourceSite $sourceSite -DestinationSite $targetSite

    $hcxMigrations = @()
    foreach ($vm in $VMs) {
        $hcxVm = Get-HCXVM -Name $vm
        $srcNet = $hcxVm.Network[0]
	    $tgtNetowrk = Get-HCXNetwork -Type NsxtSegment -Name $TargetNet -Site $TargetSite
	    $networkMap = New-HCXNetworkMapping -SourceNetwork $srcNet -DestinationNetwork $tgtNetowrk
        $hcxMigration = New-HCXMigration -VM $hcxVm `
        -MigrationType $MigrationType `
        -SourceSite $sourceSite `
        -DestinationSite $targetSite `
        -DiskProvisionType SameAsSource `
        -RetainMac $true `
        -TargetComputeContainer $targetContainer `
        -TargetDatastore $tgtDatastore `
        -NetworkMapping $networkMap `
        -Folder $tgtFolder `
        -MobilityGroupMigration

        $hcxMigrations += $hcxMigration
    }

    $mobilityGroup = New-HCXMobilityGroup -Name $MobilityGroupName -Migration $hcxMigrations -GroupConfiguration $mobilityGroupConfig

    Test-HCXMobilityGroup -MobilityGroup $mobilityGroup

    Start-HCXMobilityGroupMigration -MobilityGroup $mobilityGroup
}


function Start-VMsFromTemplate {
    <#
    .SYNOPSIS
        Function to turn on VMs created from a template
    .PARAMETER TemplateName
        Name of the template
    .PARAMETER VMHost
        Name of the VMHost
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $TemplateName,
        [Parameter(Mandatory=$true)]
        [string] $VMHost
    )
    try{
        $deployementEvents = Get-DeployementEventsFromTemplate -TemplateName $TemplateName -VMHost $VMHost
        for ($i = 0; $i -lt $deployementEvents.Count; $i++) {
            $vm = Get-VM -Name $deployementEvents[$i].Vm.Name
            if ($vm.PowerState -eq "PoweredOff"){
                $vm | Start-VM -Confirm:$false
            }
        }
        Write-Host "Turned on $($deployementEvents.Count) VMs with template name $TemplateName on host $VMHost"
    }catch{
        Write-Host "An error occurred:"
        Write-Host $_
    }
}

function Stop-VMsFromTemplate {
    <#
    .SYNOPSIS
        Function to turn off VMs created from a template
    .PARAMETER TemplateName
        Name of the template
    .PARAMETER VMHost
        Name of the VMHost
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $TemplateName,
        [Parameter(Mandatory=$true)]
        [string] $VMHost
    )
    try{
        $deployementEvents = Get-DeployementEventsFromTemplate -TemplateName $TemplateName -VMHost $VMHost
        for ($i = 0; $i -lt $deployementEvents.Count; $i++) {
            Stop-VM-With-Name -Name $deployementEvents[$i].Vm.Name
        }
        Write-Host "Turned off $($deployementEvents.Count) VMs with template name $TemplateName on host $VMHost"
    }catch{
        Write-Host "An error occurred:"
        Write-Host $_
    }
}

function Stop-VMWithName{
    <#
    .SYNOPSIS
        Function to stop a VM with a given name
    .PARAMETER Name
        Name of the VM
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name
    )
    $vm = Get-VM -Name $Name
    if ($null -eq $vm){
        Write-Host "No VM found with name $Name"
        Break
    }
    if ($vm.PowerState -eq "PoweredOn"){
        $vm | Stop-VM -Confirm:$false
    }
}

function Get-DeployementEventsFromTemplate{
    <#
    .SYNOPSIS
        Function to get a list of deployement events from a template
    .PARAMETER TemplateName
        Name of the template
    .PARAMETER VMHost
        Name of the VMHost
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $TemplateName, 
        [Parameter(Mandatory=$true)]
        [string] $VMHost
    )
    $deployementEvents = Get-VM | Get-VIEvent | Where-Object -FilterScript {($_ -is [vmware.vim.VmDeployedEvent]) -and ($_.SrcTemplate.Name -eq $TemplateName) -and ($_.Host.Name -eq $VMHost)}
    If ($deployementEvents.Count -eq 0){
        Write-Host "No VMs found with template name $TemplateName on host $VMHost"
    }
    return $deployementEvents
}
function Remove-VSphereVMsFromTemplate{
    <#
    .SYNOPSIS
        Function to delete VMs created from a template
    .PARAMETER TemplateName
        Name of the template
    .PARAMETER VMHost
        Name of the VMHost
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $TemplateName, 
        [Parameter(Mandatory=$true)]
        [string] $VMHost
    )
    try{
        $deployementEvents = Get-DeployementEventsFromTemplate -TemplateName $TemplateName -VMHost $VMHost
        for ($i = 0; $i -lt $deployementEvents.Count; $i++) {
            Stop-VM-With-Name -Name $deployementEvents[$i].Vm.Name
            $vm | Remove-VM -DeletePermanently -Confirm:$false
        }
        Write-Host "Removed $($deployementEvents.Count) VMs with template name $TemplateName on host $VMHost"
    
    }catch{
        Write-Host "An error occurred:"
        Write-Host $_
    }

}

function New-VSphereVMsFromTemplate {
    <#
    .SYNOPSIS
        Function to create VMs from a template
    .PARAMETER Name
        Name of the VM
    .PARAMETER Template
        Name of the template
    .PARAMETER VMHost
        Name of the VMHost
    .PARAMETER NumOfVMs
        Number of VMs to create
    .PARAMETER PowerOn
        Power on the VMs after creation
    #>
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
