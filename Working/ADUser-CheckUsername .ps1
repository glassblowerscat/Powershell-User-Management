<# ---

This script checks every user in the AD Forest for a mismatch between
the user's SamAccountName and UserPrincipalName.

It returns a message if there is a mismatch; no message if the two match.

**THERE WILL ALWAYS BE A FEW MISMATCHES; this is a necessary evil resulting
from the length limit of the SamAccountName. What we do not want is an
obvious case of one user having another user's SAN or UPN.**

Must be run when on the domain, by a user with requisite credentials on the DC. 

--- #>

$s = New-PSSession -ComputerName rowlf

Invoke-Command -Session $s -Scriptblock {

    # Add the Active Directory bits and not complain if they're already there
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue

    # Get domain DNS suffix
    $dnsroot = '@' + (Get-ADDomain).dnsroot

    $users = Get-ADUser -Filter * -Properties EmailAddress

    foreach ($user in $users) {
        $upn = $null
        $sam = $null
        If (-Not [string]::IsNullOrEmpty($user.UserPrincipalName)){
            $upn = $user.UserPrincipalName.Split("@")[0]
            }

        If (-Not [string]::IsNullOrEmpty($user.SamAccountName)){
            $sam = $user.SamAccountName
            }

        If ($sam -ne $upn) {
            Write-Output "$sam does not match $upn"
            }
        }
    }

Remove-PSSession $s