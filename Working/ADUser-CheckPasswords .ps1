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

    Import-Module ActiveDirectory

    <# Function Test-ADPassword ($username,$password) {
        $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $CSVusername,$CSVpassword

        $credUser = $cred.username
        $credPass = $cred.GetNetworkCredential().password
 
        # Get current domain using logged-on user's credentials
        $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
        $Domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$credUser,$credPass)
        $DomainName = $Domain.name
 
        if ($Domain.name -eq $null) {
            write-host "Authentication failed for $credUser - please verify your username and password." -BackgroundColor Black -ForegroundColor Red
        }
        else
        {
            write-host "The account $credUser successfully authenticated against the domain: $DomainName" -BackgroundColor Black -ForegroundColor Green
        }
    $credPass = $null
    } #>

    Foreach ($user in $using:users) {

        $CSVpassword = (ConvertTo-SecureString $user."Password(s)" -AsPlainText -force)
        $CSVemailAddress = $user.primaryEmail    
		$CSVusername = $CSVemailaddress.Split("@")[0]

        #Test-ADPassword ($CSVusername,$CSVpassword)

        $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $CSVusername,$CSVpassword

        $credUser = $cred.username
        $credPass = $cred.GetNetworkCredential().password
 
        # Get current domain using logged-on user's credentials
        $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
        $Domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$credUser,$credPass)
        $DomainName = $Domain.name
 
        if ($Domain.name -eq $null) {
            write-output "Authentication failed for $credUser - please verify your username and password."
        }
        else
        {
            write-output "The account $credUser successfully authenticated against the domain: $DomainName"
        }
    $credPass = $null
    }
}