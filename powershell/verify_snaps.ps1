$servers = @("PFDAPME","PFQA1APME1","SLC1-QA1-PORTAL","SLC1-RC1-PORTAL","PFQA1RAD01","PFDMOAPME01","PFDMOAPME02","POC-DMO-APME-01","SLC-DMO-APME01","SLC-DMO-APME02")

foreach ($server in $servers) {
	#New-Snapshot -VM $($server) -Quiesce -Name "Linux Patching 20171109"
	write-host "Checking:: $($server)"
	Get-Snapshot $($server) | select Name
}
