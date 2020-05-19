<#

GPO Settings

First, copy a file:

Computer Configuration -> Preferences -> Windows Settings -> Files
New File
Action: Replace
Source: \\labdc02\share\admscripts\install_laps.ps1
Destination: c:\admscripts\install_laps.ps1

Next, a scheduled task:

Computer Configuration -> Preferences -> Control Panel Settings -> Scheduled Tasks
New -> Immediate Task (At least Windows 7)
Name: Install LAPS
use the following user account: NT AUTHORITY\SYSTEM
Run only when user is logged on
Run with highests privileges (checked box)
Configure for: Windows 7, Windows Server 2008R2
Actions tab, new
Start a program
Script: C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe
Arguments: -ExecutionPolicy Bypass -command "& C:\admscripts\install_laps.ps1"

Sources:

https://4sysops.com/archives/run-powershell-scripts-as-immediate-scheduled-tasks-with-group-policy/

https://powershellexplained.com/2016-10-21-powershell-installing-msi-files/

https://stackoverflow.com/questions/7834656/create-log-file-in-powershell

#>

$msi_64 = "LAPS.x64.msi"
$msi_32 = "LAPS.x86.msi"
$smbserver = "aiifs01"
$share = "\\{0}\laps" -f $smbserver
$logFile = "{0}\{1}" -f $PSScriptRoot,$env:COMPUTERNAME
$remoteLogFile = '{0}\logs\{1}.log' -f $share,$env:COMPUTERNAME

# set this to 1 to disable all local accounts *OTHER* than Administrator
$disableLocalAccounts = 0

Function LogWrite
{
   Param ([string]$logstring)
   $DateStamp = get-date
   $LogPrefix = "$($DateStamp) :: "
   Add-content $Logfile -nonewline -value $LogPrefix
   Add-content $Logfile -value $logstring
}

# make some logging noise
LogWrite "Begin"

# Are we running on a 32-bit or 64-bit machine?
$arch = (gwmi win32_operatingsystem | select osarchitecture).osarchitecture
LogWrite "Running on arch $($arch)"
if($arch -eq "64-bit") {
	$file = "{0}\{1}" -f $share,$msi_64
} else {
	$file = "{0}\{1}" -f $share,$msi_32
}

LogWrite "We'll be installing MSI $($file)"

$MSIArguments = @(
    "/i"
    ($file)
    "/quiet"
    "/norestart"
)

# check for connectivity
# this makes nearly a 2 hour wait
# honestly - I'm not even sure this is necessary! I don't think the script executes until the computer attaches to the domain...
$max_loops = 20
$loops = 0
while (-Not($network_up)) {
	$loop++
	$ping = Test-NetConnection -ComputerName $smbserver
	if ($ping.PingSucceeded) {
		LogWrite "Ping test to $($smbserver) successful."
		$network_up = 1
	} else {
		# check the loop counter
		if ($loops -ge $max_loops) {
			LogWrite "Sorry, no network connection to $($smbserver) in $($max_loops) attempts - exiting!"
			exit
		} else {
			# the user has to connect to VPN eventually, you'd hope...
			LogWrite "ping test to $($smbserver) unsuccessful - sleeping 5 minutes, trying again."
			sleep 300
		}
	}
}

# make sure the local Administrator account is enabled!
$localAdmin = Get-LocalUser -Name Administrator
if ($localAdmin.Enabled) {
	LogWrite "Local Administrator account on $($env:COMPUTERNAME) is already enabled!"
} else {
	LogWrite "Enabling local Administrator account on $($env:COMPUTERNAME)..."
	Enable-LocalUser -Name Administrator | Add-Content $logFile
	LogWrite "Done!"
}

# I'd like to know what other accounts are enabled on this machine...
$localAccounts = Get-LocalUser | where {$_.Enabled} | where {$_.Name -ne "Administrator"} 
if ($localAccounts.Count -eq 0) {
	LogWrite "No local accounts are enabled on $($env:COMPUTERNAME)."
} else {
	LogWrite "Here's a list of local accounts that are enabled on $($env:COMPUTERNAME):"
	$localAccounts | Add-Content $logFile
	write-host "`n"
}

if (($disableLocalAccounts -eq 1) -and ($localAccounts.Count -ne 0)) {
	# ...before I disable them
	LogWrite "Disabling the following local accounts:"
	$localAccounts | Add-Content $logFile
	$localAccounts | Disable-LocalUser
	LogWrite "Done!"
}

$fileToCheck = "c:\Program Files\LAPS\CSE\AdmPwd.dll"
if (Test-Path $fileToCheck -PathType leaf)
{
    LogWrite "LAPS is already installed on $($env:COMPUTERNAME)"
} else {
	LogWrite "Installing LAPS on $($env:COMPUTERNAME)"
	Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow 
	LogWrite "LAPS has been installed."
}

# more logging noise
LogWrite "End of script!"

# what the hell, copy the log to the SMB server
copy $logFile $remoteLogFile