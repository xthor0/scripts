param(
    [Parameter(Mandatory = $true)][String] $ipaddress
)

write-host "Retrieving all VMs... please wait..."
$vmlist = Get-VM

write-host "Searching all VMs for IP address: $($ipaddress)"

foreach ($vm in $vmlist) {
  # write-host "Processing $($vm)..."
  $guestinfo = Get-VMGuest $vm
  foreach ($guestip in $guestinfo.IPAddress) {
    if ($guestip -eq $ipaddress) {
      write-host "Found IP on VM: $($vm)"
      write-host -nonewline "."
    } else {
      # write-host "No Match: $($guestip)"
      write-host -nonewline "."
    }
  }
}
