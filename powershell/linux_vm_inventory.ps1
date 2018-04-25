# we don't need to limit ourselves to a cluster - let's get all the VMs
#param(
#    [Parameter(Mandatory = $true)][String] $cluster
#)

# location where you want CSV written
$base_directory = 'C:\users\benjamin.brown\onedrive'

$CSV = $base_directory + "\linux_inventory_" + $(get-date -f yyyyMMdd) + ".csv"

# make sure CSV does not exist
if([System.IO.File]::Exists($CSV)){
  write-host "Sorry, CSV $($CSV) already exists - won't clobber it."
  exit
}

# array to store results
$results = @()

$inventory_csv = $base_directory + "\" + "vm_inventory.csv"

# get current spreadsheet inventory - and store it in an array
$current_inventory = import-csv $inventory_csv

# grab all VMs from $cluster
write-host "Retrieving VM list from vCenter server $($global:DefaultVIServer.Name)..."
#$vmArr = Get-Cluster $cluster | Get-VM
$vmArr = Get-VM

# filter out VMs that have "windows" in the guestid
foreach ($vm in $vmArr) {
  if ($vm.GuestId -like "windows*") {
    write-host "Found a Windows VM: $($vm.Name)"
  } else {
    write-host "Found a non-Windows VM: $($vm.Name)"

    # guest info
    $vmGuest = Get-VMGuest $vm

    # custom fields - there's gotta be a better way, but...
    $lane = ($vm | Get-Annotation -name Environment).Environment
    $group = ($vm | Get-Annotation -name Group).Group
    $primaryOwner = ($vm | Get-Annotation -name 'Primary Owner').'Primary Owner'
    $secondaryOwner = ($vm | Get-Annotation -name 'Secondary Owner').'Secondary Owner'

    # look this VM up in the current inventory spreadsheet and append details if it exists
    foreach($server in $current_inventory) {
	if($server.IP -eq $vmGuest.IPAddress[0]) {
		$inventory_match = $server
	}
    }

    # if we already have this in inventory, use the values from spreadsheet
    # otherwise use VMguest HostName
    if($inventory_match) {
	$hostname = $inventory_match.DNS
	$notes = $inventory_match.Notes
    } else {
	$hostname = $vmGuest.HostName
	$notes = $vm.Notes
    }

    # store the results in a custom object
    $results += [pscustomobject][ordered]@{
      Name = $vm.Name
      PowerState = $vm.PowerState
      RAM = $vm.MemoryGB
      CPU = $vm.NumCpu
      IPAddr = $vmGuest.IPAddress[0]
      OS = $vmGuest.OSFullName
      HostName = $vmGuest.HostName
      Notes = $notes
      Lane = $lane
      App = $inventory_match.App
      Classification = $inventory_match.Classification
      Group = $group
      PrimaryOwner = $primaryOwner
      SecondaryOwner = $secondaryOwner
    }
  }

  # unset the inventory match so we don't accidentally re-use a previous VM's info
  if($inventory_match) { remove-variable inventory_match }
}

$results | Export-CSV -notypeinformation $CSV
write-host "Output file: $($CSV)"
