<# ---
DEPENDENCIES: User must be able to Powershell-remote into the domains they would like to modify. User must have the GAM utility installed into the ~\ folder on the server and authenticated.

This script imports Active Directory users from multiple CSV inputs.
One CSV must be in the default format as downloaded from our
Gam Bulk Operations Google Sheet. The second must be a list of users to be imported, with at least a "First Name" column and a a "Last Name" column. The third *can optionally* be a list of users with a first name column and last name column or a full name column, and a column containing the user's password.

It will work for either Lasting Change, Crosswinds, and Lifeline, and therefore requires the input of a domain as a parameter.

Run in the following format: .\scriptname.ps1 pathto1GoogleExport.csv pathtoFirstNameLastName.csv pathtoPasswords.csv domain

Acceptable input for the domain is "lastingchange", "lifeline", or "crosswinds"

--- #>

Param(
	[Parameter(Mandatory=$True)][string]$pathToNames,
	[Parameter(Mandatory=$True)][string]$pathToGoogle,
	[Parameter(Mandatory=$True)][string]$pathToPasswords,
	[Parameter(Mandatory=$True)][string]$domain
)

<#	
If (-Not (Test-Path -Path $pathToNames)) {
	"File '$pathToNames' not found!" | Write-Error
	Exit 1
	Start-Sleep -s 2
    }
	Else {
		"List of Names file found." | Write-Output
		Start-Sleep -s 2
	}
	
If (-Not (Test-Path -Path $pathToGoogle)) {
	"File '$pathToGoogle' not found!" | Write-Error
	Start-Sleep -s 2
	Exit 1
    }
	Else {
		"Google Export file found." | Write-Output
		Start-Sleep -s 2
	}
	
If (-Not (Test-Path -Path $pathToPasswords)) {
	"File '$pathToPasswords' not found; passwords will not be created." | Write-Error
	Start-Sleep -s 2
    }
	Else {
		"Passwords file found." | Write-Output
		Start-Sleep -s 2
	}
	
#>

#Sets the destination -ComputerName based on the domain parameter entered by the user.
If ($domain -eq "lifeline"){
	$computerName = "rowlf.lifelineyouth.local"
	$domainPrefix = "lifelinelocal"
	}
ElseIf ($domain -eq "crosswinds"){
	$computerName = "bobo.crosswindsyouth.local"
	$domainPrefix = "crosswinds"
	}
ElseIf ($domain -eq "lastingchange"){
	$computerName = "janice.lastingchangeinc.local"
	$domainPrefix = "lastingchangeinc"
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
    
# Import the three parameter files.
$namesOfUsers = Import-CSV -Path $pathToNames
$googleUsers = Import-Csv -Path $pathToGoogle
If ($pathToPasswords -ne $null){
	$passwordsOfUsers = Import-CSV -Path $pathToPasswords
}

#Request Domain Admin credentials for the DC
#$cred = Get-Credential -Message "Enter Credentials for $domain ('$domainPrefix\' is  required)."

#$s = New-PSSession -ComputerName $computerName -Credential $cred

#Invoke-Command -Session $s -Scriptblock {

    # Add the Active Directory module and not complain if it's already there.
    #Import-Module ActiveDirectory -ErrorAction SilentlyContinue
	
	#Add the GAM folder to the environment path for this session only
	#$env:Path = $env:Path+";$env:UserProfile\gam";

    # Get domain DNS suffix, then set email address ending based on it
    $dnsroot = "lastingchangeinc.local"
	$emailDomain = '@'+$dnsroot.Split(".")[0]+'.org'
	
	#Write our parameters to variables local to the remote session
	$usersNames = $namesOfUsers
	$usersGoogle = $googleUsers
	$usersPasswords = $passwordsOfUsers
	
	#Compare Name List to Google Export and, upon match of first/last names, merge relevant values into a single array, instantiated immediately below. If there is a match in the passwords csv, add the user's password to the attributes.
	
	$usersToImport = @()
	
	foreach ($name in $usersNames){
		foreach ($id in $usersGoogle){
		If ($id."name.givenName" -eq $name."First Name" -and $id."name.familyName" -eq $name."Last Name"){
		Write-Output "$($id."name.givenName") $($id."name.familyName") found"
			$user = @{}
			$user.Add("givenName",$id."name.givenName")
			$user.Add("surname",$id."name.familyName");
			$user.Add("displayName",($givenName + " " + $surname))
			$user.Add("emailAddress",($id.primaryEmail.Split("@")[0].ToLower() + $emailDomain))
			$user.Add("username",$id.primaryEmail.Split("@")[0])
			$user.Add("title",$id."organizations.0.title")
			$user.Add("department",$id."organizations.0.department")
			$user.Add("officePhone",$id."phones.0.value")
			
			#Set user's location, if it exists in Google Apps.
			$user.location = $id."organizations.0.location"
			
			#create array of proxy addresses from CSV if cells are not empty
			$blankArray = @()
			[System.Collections.ArrayList]$proxyAddressesList = $blankArray
			For ($i=0; $i -le 29; $i++) {
				If ($id."aliases.$i" -ne "") {
					$proxyAddressesList.Add($id."aliases.$i")|Out-Null
				}
			}
			
			#Set user's proxyAddresses attribute to resulting list
			$user.Add("proxyAddresses",($proxyAddressesList.Split(';')))
			
			$user.proxyAddresses
			
			#Compare to CSV with passwords to see if password is on record for user; if so, convert to secure string and add to the user attributes
			If ($usersPassword -ne $null){ 
				foreach ($password in $usersPasswords){
				If ($password."First Name" -eq $name."First Name" -and $password."Last Name" -eq $name."Last Name"){
					$user.password = (ConvertTo-SecureString -String $password."Password(s)" -AsPlainText -force)
					$user.tempPassword = false
				}
				Else {
					"User $user.displayName has no password on file; creating temporary password" | Write-Output
					$user.password = (ConvertTo-SecureString -String "Lifeline.1968" -AsPlainText -force)
					$user.tempPassword = $true
				}
			}
			}
			
			$user.givenName
			$user.surname
			$user.username
			$user.title
			
			$usersToImport += $user
			
			}
		<#Else {
			$displayName = $name."First Name" + " " + $name."Last Name"
			"User $displayName not found in Google Export" | Write-Output
			}#>
		}
		}
		
	#}

#Remove-PSSession $s

#Set console prompting back to user's original setting if it has been changed.
If ($consolePrompting -eq $false){
	Set-ItemProperty -Path $key -Name ConsolePrompting -Value $false
	}