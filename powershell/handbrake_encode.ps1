. pushover_msg.ps1

[Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath
$preset = "High Profile"
$files = get-childitem -Recurse -Include "*.mkv"
foreach ($file in $files) {
 $subpath = $file.DirectoryName.Replace([Environment]::CurrentDirectory , "")
 $destname = "C:\Video" + "\" + $file.BaseName + ".m4v"
 if ((test-path $destname)) {
	echo "Destination filename already exists: $($destname)"
 } else {
	write-host "Source file: $($file)"
	write-host "Destination file: $($destname)"
	& "C:\Program Files\Handbrake\HandBrakeCLI.exe" -e vce_h264 -Z 'HQ 1080p30 Surround' -m -i $file -o $destname 2> EncodeLog.txt
 }
}

# send a pushover notification...
Send-PushOver -APIToken 'a74zm3s7dc577532z2qet8fpkwuy6f' -User 'uiLUuynXsvF7UCQATr3j6j7pG7dGoh' -Message "Encoding with Handbrake Completed"