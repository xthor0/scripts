param(
    [Parameter(Mandatory = $true)][String] $cluster
)

# array to store results
$results = @()

# grab all VMs from $cluster
write-host "Retrieving VM list from cluster $($cluster)..."
$vmArr = Get-Cluster $cluster | Get-VM

# filter out VMs that have "windows" in the guestid
foreach ($vm in $vmArr) {
  write-host "VM: $($vm)"
  $environment = $vm | Get-Annotation -name Environment
  $group = $vm | Get-Annotation -name Group
  $primaryOwner = $vm | Get-Annotation -name 'Primary Owner'
  $secondaryOwner = $vm | Get-Annotation -name 'Secondary Owner'

  write-host "Environment: $($environment)"
  write-host "Group: $($group)"
  write-host "Primary Owner: $($primaryOwner)"
  write-host "Secondary Owner: $($secondaryOwner)"
}
