param(
    [Parameter(Mandatory = $true)][String] $cluster
)

$interval = 5
$stat = 'cpu.ready.summation'
$finish = Get-Date
$start = ($finish).AddHours(- $interval)
$entity = Get-Cluster -Name $cluster | Get-VMHost
$overallstats = Get-Stat -Entity $entity -Stat $stat -Start $start -Finish $finish |
Group-Object -Property {$_.Entity.Name} | %{
    $_.Group | %{
        New-Object PSObject -Property @{
            VMHost = $_.Entity.Name
            Date = $_.Timestamp
            ReadyMs = $_.Value
            ReadyPerc = "{0:P2}" -f ($_.Value/($_.Intervalsecs*1000))
            ReadyNum = ($_.Value/($_.Intervalsecs*1000))
        }
    }
}

$readyAvg = $overallstats | select ReadyNum | Measure-Object -Property ReadyNum -Average
