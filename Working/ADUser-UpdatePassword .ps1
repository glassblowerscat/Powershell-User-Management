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


# Add the Active Directory bits and not complain if they're already there
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Get domain DNS suffix
$dnsroot = '@' + (Get-ADDomain).dnsroot

foreach ($user in $users) {
    If ($user.orgUnitPath -like  "/Inhumans*"){
        Write-Output "$($user.primaryEmail) is not a human"
        }

    Else{

                try {
				    
					#Checks CSV for existing password. Sets password for user if CSV has it; if not, sets to Lifeline Default
                   $defPassword = (ConvertTo-SecureString $user."Password(s)" -AsPlainText -force)                        
                   
                    #Sets some variables to $null for safety when looping
                    $userPrincipalName = $null
                    $samAccountName = $null
                    
                    #Re-sets all variables based on CSV headers from Google Apps
					$emailAddress = $user.primaryEmail                    
					$username = $emailaddress.Split("@")[0]

                    Set-ADAccountPassword -Identity $username -NewPassword $defPassword
                    Set-ADUser -Identity $username -PasswordNeverExpires $true -ChangePasswordAtLogon $false
                    Write-Output "Password update for $username"
                    }

                catch {

                    Write-Output "Could not update password for user, $_"


                }
					
        }
    }