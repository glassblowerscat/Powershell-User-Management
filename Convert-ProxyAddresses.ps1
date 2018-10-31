<# ---
DEPENDENCIES: User must be able to Powershell-remote into the domains they would like to modify.

Script takes a CSV with columns: fn, ln, and sam. They contain what you'd probably think. Run with command: .\scriptname.ps1 pathtocsv.csv

--- #>

Param(
	[Parameter(Mandatory=$True)][string]$Path
)

If (-Not (Test-Path -Path $Path)) {
	"File '$Path' not found!" | Write-Error
	Exit 1
    }

$users = Import-CSV $Path

Invoke-Command -Session $b -ScriptBlock {
	Foreach ($user in $using:users){
		$u = Get-ADUser $user.sam -Properties proxyaddresses
		Write-Output "Old Addresses"
		$u.proxyAddresses
		For ($i=0;$i -lt $u.proxyaddresses.count;$i++){
			$newProxy = $null
			$newProxy = $u.proxyaddresses[$i].Split("@")[0] + '@crosswindsyouth.org'
			Set-ADUser $u.samAccountName -Add @{ProxyAddresses=$newProxy}
		}
		Write-Output "New Addresses"
		Get-ADUser $user.sam -Properties proxyaddresses | Select -ExpandProperty proxyaddresses
	}
}