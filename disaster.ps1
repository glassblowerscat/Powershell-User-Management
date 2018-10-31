Import-Module .\UserInfoTransforms.psm1

$users = Import-CSV .\disasterusers.csv

Foreach ($user in $users) { 
	$givenName = $null
	$surname = $null
	$userPrincipalName = $null
	$samAccountName = $null
	$cred = $null
	$displayName = $null
	
	$givenName = $user.FirstName
	$surname = $user.LastName
	$userPrincipalName = $user.Username
	$samAccountName = $user.Username
	$displayName = $user.FirstName + " " + $user.LastName
	$cred = ConvertTo-SecureString -String $user.Password -AsPlainText -force
	$path = "ou=Disaster Recovery,ou=Inhumans,dc=lastingchangeinc,dc=local"
	
	Invoke-Command -Session $j -ScriptBlock {
		Get-ADUser $using:samAccountName | Set-ADAccountPassword -NewPassword $using:cred 
		Set-ADUser $using:samAccountName -Enabled $true -ChangePassWordAtLogon $false -PasswordNeverExpires $true
	}
}