<# ---

This script imports Active Directory users from a CSV input.
The CSV must be in the default format as downloaded from Google Apps Manager, but
with the addition of a "Password(s)" column for the password.
Passwords in the "Password(s)" column must be either a valid AD password or null.

Must be run when on the domain, by a user with requisite credentials on the DC. 

--- #>

Param(
	[Parameter(Mandatory=$True)]
	[string]$Path
)
If (-Not (Test-Path -Path $Path)) {
	"File '$Path' not found!" | Write-Error
	Exit 1
    }

    
# Import the file with the users. Based on the Param passed in the opening lines.
$users = Import-Csv -Path $Path

$s = New-PSSession -ComputerName fozzie

Invoke-Command -Session $s -Scriptblock {


# Add the Active Directory bits and not complain if they're already there
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Get domain DNS suffix
$dnsroot = '@' + (Get-ADDomain).dnsroot

foreach ($user in $using:users) {
    If ($user.orgUnitPath -like  "/Inhumans*"){
        Write-Output "$($user.primaryEmail) is not a human"
        }

    Else{

                try {
				    
					#Checks CSV for existing password. Sets password for user if CSV has it; if not, sets to Lifeline Default
assword(s){
					    $defPassword = (ConvertTo-SecureString $user."Password(s)" -AsPlainText -force)
                        $changePassword = $false
                        $passwordNeverExpires = $true
                        }
                    Else {
                        $defPassword = (ConvertTo-SecureString "Crosswinds2012" -AsPlainText -force)
                        $changePassword = $true
                        $passwordNeverExpires = $false
                        }
                    
                    #Sets some variables to $null for safety when looping
                    $userPrincipalName = $null
                    $samAccountName = $null

                    #Re-sets all variables based on CSV headers from Google Apps
					$emailAddress = $user.primaryEmail                    
					$username = $emailaddress.Split("@")[0]
					$givenName = $user."name.givenName"
					$surname = $user."name.familyName"
                    $displayName = ($givenName + " " + $surname)
                    $userPrincipalName = ($username + $dnsroot)
					$proxyAddresses = @()
					[System.Collections.ArrayList]$ArrayList = $proxyAddresses
					$title = $user."organizations.0.title"
					$department = $user."organizations.0.department"
					$costcenter = $user."organizations.0.costCenter"
                    If ([string]::IsNullOrEmpty($costcenter)){
                        $costcenter = $null
                        }


                    #Sets the value that will be passed as the samAccountName, which must be <= 20 characters.
                    #If greater than 20, cuts off at the hyphen, because almost certainly all usernames greater than 20 characters are hyphenated names.
                    If ($emailAddress.Length -gt 38) {
                        $samAccountName = ($givenName.Substring(0,1) + $surname)
                        }
                    Else {
                        $samAccountName = $username
                    }


                    #Sets type and value for the phone number based on whether the user has "mobile" or "work" as the type of phone in Google Apps.
                    #If no phone number is in Google Apps, the user's phone number is set to the main office line.
                    If ($user."phones.0.type" -ne ""){
                        switch($user."phones.0.type"){
                        "mobile"{$phoneType="MobilePhone"}
                        "work"{$phoneType="OfficePhone"}
                        ""{$phoneType=""}
                        }
                        $phoneNumber = $user."phones.0.value"
                    }
                    Else {
                        $phoneType = "OfficePhone"
                        $phoneNumber = "(260) 745-3322"
                        }

                    #Parse orgUnitPath into array and use values to create user's path.
                    #Different orgUnitPath lengths each have their own statement in the switch
                    $pathArray = $user.orgUnitPath -split '/'
                    switch($pathArray.length){
                       5{$path = "ou=$($pathArray[4]),ou=$($pathArray[3]),ou=$($pathArray[2]),ou=$($pathArray[1]),dc=crosswindsyouth,dc=local"
                            }
                       4{$path = "ou=$($pathArray[3]),ou=$($pathArray[2]),ou=$($pathArray[1]),dc=crosswindsyouth,dc=local"
                            }
                       3{$path = "ou=$($pathArray[2]),ou=$($pathArray[1]),dc=crosswindsyouth,dc=local"
                            }
                       2{$path = "ou=$($pathArray[1]),dc=crosswindsyouth,dc=local"
                            }
                        }

					
					#create array of proxy addresses from CSV if cells are not empty
					For ($i=0; $i -le 29; $i++) {
						If ($user."aliases.$i" -ne "") {
							$ArrayList.Add($user."aliases.$i")|Out-Null
						}
						
					}

					#Set the parameters for New-ADUser using a hastable
                    $newParameters = @{'SamAccountName'=$samAccountName;
                                        'Name'=$displayName;
                                        'DisplayName'=$displayName;
                                        'GivenName'=$givenName;
                                        'Surname'=$surname;
                                        'EmailAddress'=$emailAddress
                                        'UserPrincipalName'=$userPrincipalName;
                                        'Company'=$department;
                                        'Department'=$costcenter;
                                        'Title'=$title;
                                        'Path'=$path;
                                        $phoneType=$phoneNumber;
                                        'Enabled'=$true;
                                        'ChangePasswordAtLogon'=$changePassword;
                                        'PasswordNeverExpires'=$passwordNeverExpires;
                                        'AccountPassword'=$defPassword
                                        }

                    $modifyParameters = @{'Identity'=$samAccountName;
                                        'Company'=$department;
                                        'Department'=$costcenter;
                                        'Title'=$title;
                                        'EmailAddress'=$emailAddress;
                                        $phoneType=$phoneNumber;
                                        }

                    <# Searches for user in Active Directory and stores the result in a variable for testing against.
                    If user exists, user will be modified. If not, user will be created.
                    Parameters set above will be used to modify/create the user. #>

                    $ADUser = Get-ADUser -Filter {SamAccountName -eq $samAccountName}

                    If ($ADUser){
                        Set-ADUser @modifyParameters
                        Write-Output "Modified $($username)"
                        }
                    Else {
                        New-ADUser @newParameters
                        Write-Output "Created new user: $($username)"
                        }

					
					#Writes proxyaddress array into string, then modifies the user to add the addresses.
					$proxyAddressesList = $ArrayList -split';'
					Set-ADUser -Identity $samAccountName -Add @{ProxyAddresses=$proxyAddressesList}
                    Write-Output "ProxyAddresses updated for $($username)."

                    
				}
                    
                catch [System.Object]
                    {
                        Write-Output "Could not create or modify user $($username), $_"
                    }
        }
    }
}

Remove-PSSession $s