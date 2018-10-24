param(
    [Parameter(Mandatory = $true)][String] $cluster
)

$allhosts = @()

write-host "Retrieving VM cluster $($cluster)..."
$hosts = Get-Cluster Development | Get-VMHost

foreach($vmHost in $hosts){
  write-host "Processing stats for $($vmHost) - Please Wait..."
  $hoststat = "" | Select HostName, MemMax, MemAvg, MemMin, CPUMax, CPUAvg, CPUMin
  $hoststat.HostName = $vmHost.name
  
  $statcpu = Get-Stat -Entity ($vmHost)-start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 10000 -stat cpu.usage.average
  $statmem = Get-Stat -Entity ($vmHost)-start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 10000 -stat mem.usage.average

  $cpu = $statcpu | Measure-Object -Property value -Average -Maximum -Minimum
  $mem = $statmem | Measure-Object -Property value -Average -Maximum -Minimum
  
  $hoststat.CPUMax = $cpu.Maximum
  $hoststat.CPUAvg = $cpu.Average
  $hoststat.CPUMin = $cpu.Minimum
  $hoststat.MemMax = $mem.Maximum
  $hoststat.MemAvg = $mem.Average
  $hoststat.MemMin = $mem.Minimum
  $allhosts += $hoststat
}
$allhosts | select HostName, MemMax, MemAvg, MemMin, CPUMax, CPUAvg, CPUMin | Export-Csv "/users/bebrown/Desktop/$($cluster).csv" -noTypeInformation
