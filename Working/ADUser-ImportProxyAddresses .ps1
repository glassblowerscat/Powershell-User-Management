<# ---

This script adds Active Directory proxyaddresses to existing users.
It takes a CSV in the following format:

Username,Aliases
test.employee,testemployee;temployee;t.employee;test.employe

In other words, each row contains one username and one or more email addresses aliases (sans domain).

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

$s = New-PSSession -ComputerName rowlf

Invoke-Command -Session $s -Scriptblock {

    # Add the Active Directory bits and not complain if they're already there
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue

    # Get domain DNS suffix
    $dnsroot = '@' + (Get-ADDomain).dnsroot
    $emailDomain = $dnsroot.Split(".")[0]+".org"

    foreach ($user in $using:users) {

        try {
            #Sets all variables to $null in case of loop errors
            $samAccountName = $null
            $proxyAddresses = $null
            $aliasList = @()

            #Sets new values based on CSV imported above
            $samAccountName = $user.Username
            $aliasList = $user.Aliases.Split(";")

            #Creates new proxyaddress list from modified array
            $proxyAddressList = [system.String]::Join("$emailDomain;", $aliasList)
            $proxyAddressList = $proxyAddressList+$emailDomain

            #Adds Proxy Addresses 
            Set-ADUser -Identity $samAccountName -Add @{proxyAddresses = ($proxyAddressList -split ";")}
            }

        catch [System.Object] {
            Write-Output "Update failed for $samAccountName. Error: ** $_ **"
            }

        }
}

Remove-PSSession $s