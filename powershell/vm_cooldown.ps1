# cooldown a bunch of VMs
$vmlist = @("SLC-DMOMSGRED01","SLC-DMOMSGRED02","SLC-DMOMSGRED03")

foreach ($vm in $vmlist) {
	write-host $vm
	set-vm $vm -name "$($vm) - cooldown on 2017-10-13"
}
