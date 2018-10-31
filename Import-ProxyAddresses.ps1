<# ---
DEPENDENCIES: User must be able to Powershell-remote into the domains they would like to modify. User must have the GAM utility installed into the ~\ folder on the server and authenticated.

This script imports Active Directory ProxyAddresses from a CSV input.
The CSV must have two columns, one named "User" and one named "Address".
The "User" column should contain usernames without an "@" suffix.
The "Address" column should contain Proxy Addresses/Aliases without an "@" suffix.

It will work for either Lifeline or Crosswinds, and therefore requires the input of a domain as a parameter.

Run in the following format: .\scriptname.ps1 pathto.csv domain

Acceptable input for the domain is either "lifeline" or "crosswinds"

--- #>

Param(
	[Parameter(Mandatory=$True)][string]$Path,
	[Parameter(Mandatory=$True)][string]$domain
)
If (-Not (Test-Path -Path $Path)) {
	"File '$Path' not found!" | Write-Error
	Exit 1
    }

#Sets the destination -ComputerName based on the domain parameter entered by the user.
If ($domain -eq "lifeline"){
	$computerName = "rowlf.lifelineyouth.local"
	$domainPrefix = "lifelinelocal"
	}
ElseIf ($domain -eq "crosswinds"){
	$computerName = "fozzie.crosswindsyouth.local"
	$domainPrefix = "crosswinds"
	}
Else {
	"Domain input not valid" | Write-Error
	Exit 1
	}
	
#Set console prompting to on if not already on. This ensures that even if using an alternate console that doesn't properly produce a GUI prompt for credentials the user can still enter their credentials.
$key = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds"
$consolePrompting = Get-ItemProperty $key
If ($consolePrompting.ConsolePrompting -eq $false){
	Set-ItemProperty -Path $key -Name ConsolePrompting -Value $true
	}
    
# Import the file with the users. Based on the Param passed in the opening lines.
$aliases = Import-Csv -Path $Path

#Request Domain Admin credentials for the DC
$cred = Get-Credential -Message "Enter Credentials for $domain ('$domainPrefix\' is  required)."

$s = New-PSSession -ComputerName $computerName -Credential $cred

Invoke-Command -Session $s -Scriptblock {

    # Add the Active Directory bits and not complain if they're already there
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
	
	#Add the GAM folder to the environment path for this session only
	$env:Path = $env:Path+";$env:UserProfile\gam";

    # Get domain DNS suffix, then set email address ending based on it
    $dnsroot = "@"+(Get-ADDomain).dnsroot
	$emailDomain = $dnsroot.Split(".")[0]+'.org'

    foreach ($alias in $using:aliases) {
		#Zero out our two fields so there's not looping issues if one instance of the loop fails.
		$identity = $null
		$proxyAddress = $null
		
		#Now set the values based on the CSV.
		$identity = $alias.User + $dnsroot
		$proxyAddress = $alias.Address + $emailDomain
		Get-ADUser -Filter {UserPrincipalName -eq $identity} | Set-ADUser -Add @{ProxyAddresses=$proxyAddress}
		gam create alias $alias.Address user $alias.User
	}
}

Remove-PSSession $s

#Set console prompting back to user's original setting if it has been changed.
If ($consolePrompting -eq $false){
	Set-ItemProperty -Path $key -Name ConsolePrompting -Value $false
	}