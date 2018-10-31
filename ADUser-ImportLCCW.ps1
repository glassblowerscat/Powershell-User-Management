<# ---
DEPENDENCIES: User must be able to Powershell-remote into the domains they would like to modify. User must have the GAM utility installed into the ~\ folder on the server and authenticated.

This script imports Active Directory users from a CSV input.
The CSV must be in the default format as downloaded from our
Gam Bulk Operations Google Sheet.

It will work for either Lifeline or Crosswinds, and therefore requires the input of a domain as a parameter.

Run in the following format: .\scriptname.ps1 pathto.csv domain

Acceptable input for the domain is either "lifeline","crosswinds", or "lastingchange"

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
	$computerName = "floyd.internal.crosswinds.org"
	$domainPrefix = "crosswinds"
	}
ElseIf ($domain -eq "lastingchange"){
	$computerName = "janice.lastingchangeinc.local"
	$domainPrefix = "lastingchange"
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
$cred = Get-Credential -Message "Enter Credentials for $domain ('$domainPrefix\' is  required)."

$s = New-PSSession -ComputerName $computerName -Credential $cred

Invoke-Command -Session $s -Scriptblock {

    # Add the Active Directory bits and not complain if they're already there
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
	
	#Add the GAM folder to the environment path for this session only
	$env:Path = $env:Path+";$env:UserProfile\gam";

    # Get domain DNS suffix, then set email address ending based on it
    $dnsroot = 'crosswinds.org'
	$emailDomain = 'crosswinds.org'
	If ($emailDomain -eq "crosswindsyouth.org"){
		$emailDomain = "crosswinds.org"
	}

    foreach ($user in $using:users) {
        If ($user.LastName -ne "#VALUE!"){

                try {                   
                    #Sets some variables to $null for safety when looping
                    $emailAddress = $null
                    $username = $null
                    $givenName = $null
                    $displayName = $null
                    $surname = $null
                    $userPrincipalName = $null
                    $title = $null
                    $department = $null
                    $costCenter = $null
                    $samAccountName = $null
                    $mobilePhone = $null
					$officePhone = $null
                    $path = $null

                    #The following several blocks re-set all variables based on CSV headers
					
					$emailAddress = $user.EmailAddress + $emailDomain
					$username = $user.EmailAddress
					$givenName = $user.FirstName
					$surname = $user.LastName
                    $displayName = ($givenName + " " + $surname)
                    $userPrincipalName = $emailAddress
					$proxyAddresses = @{proxyAddresses = ($givenName.Substring(0,1)+$surname+$emailDomain),`
						($givenName+$surname+$emailDomain)}
					$title = $user.EmployeeTitle
					$department = $user.Department
                    If ([string]::IsNullOrEmpty($user.CostCenter)){
                        $costCenter = $null
                        }
					Else {
						$costCenter = $user.CostCenter
						}
				    $defPassword = (ConvertTo-SecureString $user.Password -AsPlainText -force)
                    $changePassword = $false
                    $passwordNeverExpires = $true

                    <#Sets the value that will be passed as the samAccountName, which must be <= 20 characters.
                    If greater than 20, uses first initial + full last name (our old schema).
					If less than or equal to 20, uses firstname.lastname. #>
                    If ($username.Length -gt 20) {
                        $samAccountName = ($givenName.Substring(0,1) + $surname)
                        }
                    Else {
                        $samAccountName = $username
                    }

                    <#Sets type and value for the phone number based on whether the user has "mobile" or "work" as the type of phone in Google Apps.
                    If no phone number is in Google Apps, the user's phone number is set to the main office line.#>
                    If (-Not [string]::IsNullOrEmpty($user.MobilePhone)){
                        $mobilePhone = $user.MobilePhone
                        }
					Else{$mobilePhone = $null}
                    If (-Not [string]::IsNullOrEmpty($user.OfficePhone)){
                        $officePhone = $user.OfficePhone
                        }
					Else{$officePhone = $null}

                    <#Parse orgUnitPath into array and use values to create user's path.
                    Different orgUnitPath lengths each have their own statement in the switch#>
                    $pathArray = $user.Organization -split '/'
                    switch($pathArray.length){
                       4{$path = "ou=$($pathArray[3]),ou=$($pathArray[2]),ou=$($pathArray[1]),ou=$($pathArray[0]),dc=$($dnsroot.Split(".")[0]),dc=$($dnsroot.Split(".")[1])"
                            }
                       3{$path = "ou=$($pathArray[2]),ou=$($pathArray[1]),ou=$($pathArray[0]),dc=$($dnsroot.Split(".")[0]),dc=$($dnsroot.Split(".")[1])"
                            }
                       2{$path = "ou=$($pathArray[1]),ou=$($pathArray[0]),dc=$($dnsroot.Split(".")[0]),dc=$($dnsroot.Split(".")[1])"
                            }
                       1{$path = "ou=$($pathArray[0]),dc=$($dnsroot.Split(".")[0]),dc=$($dnsroot.Split(".")[1])"
                            }
                        }


					#Set the parameters for New-ADUser using a hastable
                    $parameters = @{'SamAccountName'=$samAccountName;
                                        'Name'=$displayName;
                                        'DisplayName'=$displayName;
                                        'GivenName'=$givenName;
                                        'Surname'=$surname;
                                        'EmailAddress'=$emailAddress;
                                        'UserPrincipalName'=$userPrincipalName;
                                        'Company'=$department;
                                        'Department'=$costCenter;
                                        'Title'=$title;
                                        'Path'=$path;
                                        'OfficePhone'=$officePhone;
                                        'MobilePhone'=$mobilePhone;
										'OtherAttributes'=$proxyAddresses;
                                        'AccountPassword'=$defPassword;
                                        'Enabled'=$true;
                                        'ChangePasswordAtLogon'=$changePassword;
                                        'PasswordNeverExpires'=$passwordNeverExpires;
                                        }

                    <# Searches for user in Active Directory and stores the result in a variable for testing against.
                    If user exists, a message to that effect will be displayed. If not, user will be created. #>

                    $ADUser = Get-ADUser -Filter {SamAccountName -eq $samAccountName}

                    If ($ADUser){
                        Write-Output "$username already exists."
                        }
                    Else {
                        New-ADUser @parameters
                        Write-Output "Created new AD user: $($username)"
                        }
						
					<# PLACEHOLDER: below this we'll eventually put a codeblock that runs a GADS sync operation to immediately put the new users in Google Apps. For now, we'll do this directly using GAM.#>
					
					<#Here is where we used to do that thing mentioned above. Commented out now instead of deleted, for safety.
					
					try {
						#Now we'll use GAM to add what we need in Google Apps
						#Create the user
						gam create user $user.EmailAddress firstname $user.FirstName lastname $user.LastName password $user.Password changepassword off phone type mobile value $user.MobilePhone primary organization title $user.EmployeeTitle department $user.Department location $user.CostCenter type work customType work primary
						
                        Write-Output "Created new Google Apps user: $($username)"
						}
					catch [System.Object] {
						Write-Output "One or more errors occurred: $_"
						}
					
					try {
						#Add to correct group
						gam update group $user.Group add member $user.EmailAddress 2>&1 | %{ "$_" }
						
                        Write-Output "Updated group for: $($username)"
						}
					catch [System.Object] {
						Write-Output "One or more errors occurred: $_"
						}
					
					try {					
						#Place in correct organization
						gam update org $user.Organization add user $user.EmailAddress 2>&1 | %{ "$_" }
						
                        Write-Output "Updated org for: $($username)"
						}
					catch [System.Object] {
						Write-Output "One or more errors occurred: $_"
						}
					
					try {					
						#Create signature for user
						gam user $user.EmailAddress signature $user.signature 2>&1 | %{ "$_" }
						
                        Write-Output "Set email signature for: $($username)"
						}
					catch [System.Object] {
						Write-Output "One or more errors occurred: $_"
						}
						
					#>
				          
            }
                    
            catch [System.Object] {
                    Write-Output "One or more errors occurred while creating user $username : $_"
                }
        }
    }
}


#Now we'll get the "services" account credentials so we can run a GADS sync operation

$scred = Get-Credential -Username $domainPrefix\services -Message "Enter password for the $domain 'services' account."

$ss = New-PSSession -ComputerName $computerName -Credential $scred

Invoke-Command -Session $ss -Scriptblock {
	.\gcdsync.bat
	}
	
Invoke-Command -Session $s -Scriptblock {
	foreach ($user in $using:users) {
        If ($user.LastName -ne "#VALUE!"){
			If ($using:domain -ne "crosswinds"){
				try {					
					#Create signature for user
					gam user $user.EmailAddress signature $user.signature 2>&1 | %{ "$_" }
					}
				catch [System.Object] {
					Write-Output "One or more errors occurred: $_"
					}
			}
			try {
				gam update group $user.Group add member $user.EmailAddress 2>&1 | %{ "$_" }
				}
			catch [System.Object] {
				Write-Output "One or more errors occurred: $_"
				}
			try {					
				#Update user's gam password
				gam update user $user.EmailAddress password $user.Password changepassword off 2>&1 | %{ "$_" }
				}
			catch [System.Object] {
				Write-Output "One or more errors occurred: $_"
				}
			}
		}
	}

Remove-PSSession $ss

Remove-PSSession $s

#Set console prompting back to user's original setting if it has been changed.
If ($consolePrompting -eq $false){
	Set-ItemProperty -Path $key -Name ConsolePrompting -Value $false
	}