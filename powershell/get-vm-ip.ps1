write-host "Getting all VMs in SLC-PRD data center..."
$vms = Get-Cluster SLC-PRD | Get-VM
$results = @()

foreach($obj in $vms) {
  write-host "Retrieving info for VM $($obj.Name) :: "

  # feed the name to a cmdlet to grab some guest information
  $guestinfo = Get-VMGuest -VM $obj.Name

  # store the results in a custom object
  $results += [pscustomobject][ordered]@{
    Name = $obj.Name
    RAM = $obj.MemoryGB
    CPU = $obj.NumCpu
    IPAddr = $guestinfo.IPAddress[0]
    OS = $guestinfo.OSFullName
    HostName = $guestinfo.HostName
  }
}

# output results to csv
$results | export-csv -notypeinformation /Users/ben.brown/Desktop/slc-prd-vms-info.csv
