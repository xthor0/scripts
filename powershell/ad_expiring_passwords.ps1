## user-modifiable variables
$daysbeforeexpirytonotify = 7
$ous = 'OU=SLC Users,DC=american-ins,DC=com','OU=LV Users,DC=american-ins,DC=com'
$from = "noreply@american-ins.com"
$to = "xthor@xthorsworld.com","xthor0@gmail.com","xthor@msn.com"
$todaysdate = Get-Date -UFormat "%A, %B %d, %Y"
$subject = "Expiring Passwords :: $($todaysdate)"
$smtpserver = "americanins-com02b.mail.protection.outlook.com"


## don't modify this stuff
$now = (get-date).ToUniversalTime().ToFileTime()  
$threshold = (get-date).ToUniversalTime().adddays($daysbeforeexpirytonotify).ToFileTime()  

$users = $ous | ForEach-Object {
    Get-ADUser -searchbase $PSItem -Filter { Enabled -eq $True -and PasswordNeverExpires -eq $False } `
    –Properties "msDS-UserPasswordExpiryTimeComputed",mail |   
Where-Object { $_."msDS-UserPasswordExpiryTimeComputed" -lt $threshold -and `
$_."msDS-UserPasswordExpiryTimeComputed" -gt $now } |   
Select-Object "Name",
 @{Name="Expiration";Expression={  
       [datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")  
       }  
 } | sort-object name  
} 
  
# $users 

$body = "<p><b>Expiring Passwords for the week of $($todaysdate)</b></p><br>The following users have passwords expiring the next $($daysbeforeexpirytonotify) days:<br><br>" | Out-String
$body += $users | ConvertTo-Html | Out-String

Send-MailMessage -from $from -to $to -SmtpServer $smtpserver -subject $subject -body $body -BodyAsHtml
