Write-Host -ForewgroundColor green '*|*|*|*|*|*|*|*|*|*|*|*|*|*|*';
$computername = Read-Host -Prompt 'Enter computer name';
Rename-Computer -NewName $computername -Force -ErrorAction SilentlyContinue;
Write-Host -ForewgroundColor green '*|*|*|*|*|*|*|*|*|*|*|*|*|*|*';
Write-Host -NoNewLine 'PLEASE NOTE: ';
Write-Host -ForewgroundColor red 'This computer will REBOOT immediately!';
Write-Host -ForewgroundColor green '*|*|*|*|*|*|*|*|*|*|*|*|*|*|*';
Write-Host -NoNewLine 'Press any key to reboot...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

shutdown /r /t 00