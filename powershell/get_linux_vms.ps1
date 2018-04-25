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
  if ($vm.GuestId -like "windows*") {
    write-host "Found a Windows VM: $($vm.Name)"
  } else {
    write-host "Found a non-Windows VM: $($vm.Name)"

    # guest info
    $vmGuest = Get-VMGuest $vm

    # custom fields - there's gotta be a better way, but...
    $environment = $vm | Get-Annotation -name Environment
    $group = $vm | Get-Annotation -name Group
    $primaryOwner = $vm | Get-Annotation -name 'Primary Owner'
    $secondaryOwner = $vm | Get-Annotation -name 'Secondary Owner'

    # store the results in a custom object
    $results += [pscustomobject][ordered]@{
      Name = $vm.Name
      RAM = $vm.MemoryGB
      CPU = $vm.NumCpu
      IPAddr = $vmGuest.IPAddress[0]
      OS = $vmGuest.OSFullName
      HostName = $vmGuest.HostName
      Notes = $vm.Notes
      Environment = $environment
      Group = $group
      PrimaryOwner = $primaryOwner
      SecondaryOwner = $secondaryOwner
    }
  }
}

# CSV to write results to
$CSV = "c:\users\benjamin.brown\Desktop\$($cluster)-Results.csv"

# make sure CSV does not exist
if(![System.IO.File]::Exists($CSV)){
  $results | Export-CSV -notypeinformation $CSV
} else {
  write-host "Sorry, CSV $($CSV) already exists - won't clobber it."
}
