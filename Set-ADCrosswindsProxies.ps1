<# ---
DEPENDENCIES: User must be able to Powershell-remote into the domains they would like to modify. User must have the GAM utility installed into the ~\ folder on the server and authenticated.
--- #>

Invoke-Command -Session $b -Scriptblock {
	$users = Get-ADUser -Filter * -Properties EmailAddress,Proxyaddresses | Select samAccountName,emailAddress,ProxyAddresses
	Foreach ($user in $users){
		If ($user.emailAddress -ne $null){
			$proxyCount = $null
			$email = $null
			$proxyCount = $user.ProxyAddresses.count
			$email = $user.emailAddress
			For ($i=0;$i -lt $proxyCount;$i++){
				$proxyPrefix = $null
				$cyProxy = $null
				$cProxy = $null
				$proxyPrefix = $user.ProxyAddresses[$i].Split("@")[0]
				$cyProxy = $proxyPrefix + "@crosswindsyouth.org"
				$cProxy = $proxyPrefix + "@crosswinds.org"
				Set-ADUser $user.samAccountName -Add @{ProxyAddresses="$cyProxy"}
				Set-ADUser $user.samAccountName -Add @{ProxyAddresses="$cProxy"}
				Set-ADUser $user.samAccountName -Remove @{ProxyAddresses="$email"}
				
			}
		}
	}
}