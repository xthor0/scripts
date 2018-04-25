# this script expects you to already be connected to a vCenter instance
write-host "Connected to VI server: $(([System.Uri]$global:defaultviserver.ServiceUri.AbsoluteUri).Host)"

write-host "Retrieving information for all powered-on VMs..."
$vmlist = Get-VM | where { $_.PowerState -eq "PoweredOn" } | Get-VMGuest

# array to store results
$results = @()

write-host "Finding server with the most IP addresses..."
# find the server with the most IP addresses assigned to it
$maxIPcount = 1
$vmlist | foreach-object {
	$currentIPcount = 0
	foreach($ip in $_.IPAddress) {
		if($ip.StartsWith('fe')) { continue }
		$currentIPcount++
	}
	
	if($currentIPcount -gt $maxIPcount) {
		$maxIPcount = $currentIPcount
	}
}

write-host $maxIPcount

write-host "Processing IP information..."
$vmlist | foreach-object {
	$ipcount = 0
	$vminfo = New-Object PSObject
	$vminfo | Add-Member -MemberType NoteProperty -Name VMName -Value $_.VMName
	$vminfo | Add-Member -MemberType NoteProperty -Name HostName -Value $_.HostName
	$vminfo | Add-Member -MemberType NoteProperty -Name OS -Value $_.OSFullName
	foreach ( $ip in $_.IPAddress ) {
		if($ip.StartsWith('fe')) { continue }
		$ipcount++
		$propName = "IPAddress" + $ipcount
		$vminfo | Add-Member -MemberType NoteProperty -Name $propName -Value $ip
	}
	
	# is powershell stupid? Do I have to make the same number of IPAddress columns...?
	while ($ipcount -lt $maxIPcount) {
		$ipcount++
		$propName = "IPAddress" + $ipcount
		$vminfo | Add-Member -MemberType NoteProperty -Name $propName -Value $null		
	}
	
	# append to results
	$results += $vminfo
}

write-host "Writing output to CSV..."
# output to CSV
$csvFileName = [environment]::getfolderpath("mydocuments") + "\" + ([System.Uri]$global:defaultviserver.ServiceUri.AbsoluteUri).Host + "_" + (Get-Date -UFormat %Y%m%d) + ".csv"
$results | Export-CSV -NoTypeInfo $csvFileName

write-host "Results were written to CSV: "
write-host $csvFileName