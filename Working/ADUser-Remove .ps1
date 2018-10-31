<# ---

This script removes Active Directory users based on a CSV input.

Created mostly to be used for testing: input users with a CSV, then
immediately remove based on that same CSV. 

Requires a prompt for each deletion. DO NOT JUST SKATE THROUGH THE PROMPTS;
ACTUALLY READ EACH ONE TO MAKE SURE YOU REALLY WANT TO DELETE.

Must be run when on the domain, by a user with requisite credentials on the DC. 

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
	}
ElseIf ($domain -eq "crosswinds"){
	$computerName = "fozzie.crosswindsyouth.local"
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
$users = Import-Csv -Path $Path

#Request Domain Admin credentials for the DC
$cred = Get-Credential -Message "Enter Credentials for $domain ('$domain\' is  required)."

$s = New-PSSession -ComputerName $computerName -Credential $cred

Invoke-Command -Session $s -Scriptblock {

    # Add the Active Directory bits and not complain if they're already there
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue

    # Get domain DNS suffix
    $dnsroot = '@' + (Get-ADDomain).dnsroot

		foreach ($user in $using:users) {
			If ($user.orgUnitPath -like  "/Inhumans*"){
				Write-Output "Not a human"
				}
			Else {
				If ($user.LastName -ne "#VALUE!"){
					try {				
						#set username based on CSV headers from Google Apps
						$emailaddress = $user.EmailAddress
						If ($emailAddress.Length -gt 38) {
							$username = $emailAddress.Split("-")[0]
							}
						Else {
							$username = $emailaddress.Split("@")[0]
							}
							
						Remove-ADUser $username
						Write-Output "$($username) removed"
						
						gam delete user $emailAddress
							
						}
							
						catch [System.Object]{
							Write-Output "Could not remove user $($username), $_"
							}
					}
			}
		}
}

Remove-PSSession $s
