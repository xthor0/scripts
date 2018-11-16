param(
    [Parameter(Mandatory = $true)][String] $cluster,
    [Parameter(Mandatory = $true)][Int] $hours
)

$results = @()

write-host "Processing VMs in $($cluster)..."
$vms = Get-Cluster $cluster | Get-VM | where { $_.PowerState -eq "PoweredOn" }

write-host "Collecting stats for $($vms.Length) VMs..."
foreach ($vm in $vms) {
    # write-host -NoNewline "$($cluster) => $($vm) :: "
    write-host " => $($vm) :: "
    $vmhost = $vm | Get-VMHost
    $stats = Get-Stat -Entity ($vm) -start (get-date).AddHours(-$hours) -Finish (Get-Date)-MaxSamples 10000 -stat cpu.ready.summation 
    if ($stats.count -gt 0) {
        $readyAvg = $stats | Measure-Object -Property Value -Average | select -ExpandProperty Average
        $readyMax = $stats | Measure-Object -Property Value -Maximum | select -ExpandProperty Maximum
        $readyAvgRaw = $readyAvg / ($stats[0].IntervalSecs * 1000)
        $readyMaxRaw = $readyMax / ($stats[0].IntervalSecs * 1000)
        $readyMaxPerc = ('{0:p}' -f $readyMaxRaw)
        $readyAvgPerc = ('{0:p}' -f $readyAvgRaw)
    
        # Write-Output "CPU ready $('{0:p}' -f $readyPerc)"
    } else {
        # Write-Output "N/A"
        $readyMaxPerc = "N/A"
        $readyAvgPerc = "N/A"
    }

    $results += [pscustomobject][ordered]@{
        vm = $vm
        cluster = $cluster
        host = $vmhost
        readyMax = $readyMax
        readyAvg = $readyAvg
        readyAvgPerc = $readyAvgPerc
        readyMaxPerc = $readyMaxPerc
    }
}
$results | Format-Table