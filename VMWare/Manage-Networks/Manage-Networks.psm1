function New-VirtualPortGroupWithVS {
    <#
    .SYNOPSIS
        Function to create a new virtual port group with a virtual switch
    .PARAMETER VirtualSwitchName
        Name of the VirtualSwitch
    .PARAMETER VMHost
        Name of the VMHost
    .PARAMETER NumPorts
        Number of ports
    .PARAMETER Mtu
        MTU
    .PARAMETER PortGroupName
        Name of the port group
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $VirtualSwitchName,
        [Parameter(Mandatory=$true)]
        [string] $VMHost,
        [Parameter(Mandatory=$true)]
        [Int32] $NumPorts,
        [Parameter(Mandatory=$true)]
        [Int32] $Mtu,
        [Parameter(Mandatory=$true)]
        [string] $PortGroupName
    )
    try{
        $vs = New-VirtualSwitch -Name $VirtualSwitchName -VMHost $VMHost -NumPorts $NumPorts -Mtu $Mtu
        New-VirtualPortGroup -VirtualSwitch $vs -Name $PortGroupName
    }catch{
        Write-Host "An error occurred:"
        Write-Host $_
    }
    
}

