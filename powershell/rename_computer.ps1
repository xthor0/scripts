# most of this was cribbed directly from https://raw.githubusercontent.com/TheJumpCloud/support/master/scripts/windows/InstallWindowsAgent.ps1

# Gotta have your JumpCloud Connect Key. Don't fucking hard-code it in this script, you idiot.

Param (
    [Parameter (Mandatory = $true)]
    [string] $JumpCloudConnectKey
    [Parameter (Mandatory = $true)]
    [string] $ComputerName
)

#--- JumpCloud Stuff ------------------------------

# JumpCloud Agent Installation Variables
$TempPath = 'C:\Windows\Temp\'
$AGENT_PATH = Join-Path ${env:ProgramFiles} "JumpCloud"
$AGENT_BINARY_NAME = "jumpcloud-agent.exe"
$AGENT_INSTALLER_URL = "https://cdn02.jumpcloud.com/production/jcagent-msi-signed.msi"
$AGENT_INSTALLER_PATH = "C:\windows\Temp\jcagent-msi-signed.msi"
# JumpCloud Agent Installation Functions
Function InstallAgent() {
    msiexec /i $AGENT_INSTALLER_PATH /quiet JCINSTALLERARGUMENTS=`"-k $JumpCloudConnectKey /VERYSILENT /NORESTART /NOCLOSEAPPLICATIONS /L*V "C:\Windows\Temp\jcUpdate.log"`"
}
Function DownloadAgentInstaller() {
    (New-Object System.Net.WebClient).DownloadFile("${AGENT_INSTALLER_URL}", "${AGENT_INSTALLER_PATH}")
}
Function DownloadAndInstallAgent() {
    If (Test-Path -Path "$($AGENT_PATH)\$($AGENT_BINARY_NAME)") {
        Write-Output 'JumpCloud Agent Already Installed'
    } else {
        Write-Output 'Downloading JCAgent Installer'
        # Download Installer
        DownloadAgentInstaller
        Write-Output 'JumpCloud Agent Download Complete'
        Write-Output 'Running JCAgent Installer'
        # Run Installer
        InstallAgent

        # Check if agent is running as a service
        # Do a loop for 5 minutes to check if the agent is running as a service
        # The agent pulls cef files during install which may take longer then previously.
        for ($i = 0; $i -lt 300; $i++) {
            Start-Sleep -Seconds 1
            #Output the errors encountered
            $AgentService = Get-Service -Name "jumpcloud-agent" -ErrorAction SilentlyContinue
            if ($AgentService.Status -eq 'Running') {
                Write-Output 'JumpCloud Agent Succesfully Installed'
                exit
            }
        }
        Write-Output 'JumpCloud Agent Failed to Install'
    }
}

Function RenameComputer() {
  Write-Host -ForeGroundColor green '*|*|*|*|*|*|*|*|*|*|*|*|*|*|*'
  $computername = Read-Host -Prompt 'Enter computer name'
  Rename-Computer -NewName $computername -Force -ErrorAction SilentlyContinue
  Write-Host -ForeGroundColor green '*|*|*|*|*|*|*|*|*|*|*|*|*|*|*'
  Write-Host -NoNewLine 'PLEASE NOTE: '
  Write-Host -ForeGroundColor red 'This computer will REBOOT immediately!'
  Write-Host -ForeGroundColor green '*|*|*|*|*|*|*|*|*|*|*|*|*|*|*'
  Write-Host -NoNewLine 'Press any key to reboot...'
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

  shutdown /r /t 00
}

Function CheckComputerName() {
  $env:COMPUTERNAME.StartsWith('DESKTOP-') {
    RenameComputer
  } else {
    Write-Host -NoNewLine 'PLEASE NOTE: This computer is named '
    Write-Host -ForeGroundColor red $env.COMPUTERNAME
    Write-Host -ForeGroundColor green '*|*|*|*|*|*|*|*|*|*|*|*|*|*|*'
    Read-Host -Prompt 'Press press ENTER to proceed with installation - otherwise press CTRL-C and rename this computer.'
  }
}

# Flush DNS Cache Before Install - why? I dunno, ask JumpCloud, but I'm leaving it
ipconfig /FlushDNS

# make sure the damn computer
CheckComputerName

# Deploy JumpCloud Now
DownloadAndInstallAgent

# this is the end