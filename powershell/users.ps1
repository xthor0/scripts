$users = @("Mark Hardaway","Jenny Adams","Martin Isaksen","Alex Amat","Bryan Swainston","Eric Eberly","Hoang Coa","Jenessa Fenochietti","Jesse Grant","Jon Castellanos","Jordan Young","Mason Edgel","Spencer Edgel","Nash Thomson","Rich Reeves","Vijyant Saini","Dan Hakes","Lee Wiltbank","Anthony Manuell","Doug Hansen")

foreach ($user in $users) {

echo "Looking up $($user) in AD:"
$id = get-aduser -Filter 'Name -eq $user' -properties samaccountname
$id.samaccountname
write-host

}