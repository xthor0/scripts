param(
    [Parameter(Mandatory = $true)][String] $cluster
)

$allhosts = @()

write-host "Retrieving hosts in cluster $($cluster)..."
$hosts = Get-Cluster $cluster | Get-VMHost | where { $_.State -eq "Connected" }

foreach($vmHost in $hosts) {
    $ramGB = $vmHost.MemoryTotalGB + $ramGB
    $CPUcores = $vmHost.NumCpu + $CPUcores
}
write-host

write-host "Retrieving virtual machines in cluster $($cluster)..."
$vms = Get-Cluster $cluster | Get-VM | where { $_.PowerState -eq "PoweredOn" }

$count = $vms.Length
foreach ($vm in $vms) {
    $allocatedCPU = $vm.NumCpu + $allocatedCPU
    $allocatedRAMGB = $vm.MemoryGB + $allocatedRAMGB
}
write-host

# maths
$cpuratio = $allocatedCPU / $CPUcores
$freeRAMGB = $ramGB - $allocatedRAMGB

# print out results
write-host "Results:"
write-host
write-host "Total pCPUs: $($CPUcores)"
write-host "Total RAM in GB: $($ramGB)"
write-host
write-host "Allocated vCPUs: $($allocatedCPU)"
write-host "Allocated RAM in GB: $($allocatedRAMGB)"
write-host
write-host "pCPU to vCPU Ratio: $($cpuratio):1"
write-host "Free RAM: $($freeRAMGB) GB"