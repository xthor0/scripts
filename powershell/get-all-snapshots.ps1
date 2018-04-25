param(
    [Parameter(Mandatory = $true)][String] $cluster
)

$vmlist = Get-Cluster $cluster | get-vm

foreach ($vm in $vmlist) {

        $snaps = get-snapshot -vm $vm
        
        if ($snaps.Count -gt 0) {
                write-host "VM: $($vm.Name)"
                write-host "Snapshot name: $($snaps.Name)"
                write-host "Snapshot creation date: $($snaps.Created)"
                write-host
        }
 
}

