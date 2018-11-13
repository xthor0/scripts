param(
    [Parameter(Mandatory = $true)][String] $datacenter,
    [Parameter(Mandatory = $true)][Int] $hours
)

write-host "Getting clusters in datacenter $($datacenter)..."
$clusters = get-datacenter $datacenter | Get-Cluster

foreach ($cluster in $clusters) {
    write-host "Processing VMhosts in $($cluster)..."
    $vmhosts = Get-Cluster $cluster | Get-VMHost
    
    foreach ($vmHost in $vmhosts) {
        write-host -NoNewline "$($cluster) => $($vmHost) :: "
        $stats = Get-Stat -Entity ($vmHost)-start (get-date).AddHours(-$hours) -Finish (Get-Date)-MaxSamples 10000 -stat cpu.ready.summation 
        if ($stats.count -gt 0) {
          $readyAvg = $stats | Measure-Object -Property Value -Average | select -ExpandProperty Average
          $readyPerc = $readyAvg / ($stats[0].IntervalSecs * 1000)
        
          Write-Output "CPU ready $('{0:p}' -f $readyPerc)"
        } else {
          Write-Output "N/A"
        }
    }
    Write-Output ""
}
