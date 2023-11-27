function New-VirtualPortGroupWithVS {
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
    $vs = New-VirtualSwitch -Name $VirtualSwitchName -VMHost $VMHost -NumPorts $NumPorts -Mtu $Mtu
    New-VirtualPortGroup -VirtualSwitch $vs -Name $PortGroupName
}