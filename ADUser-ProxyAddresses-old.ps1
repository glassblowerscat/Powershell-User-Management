<# ---
DEPENDENCIES: User must be able to Powershell-remote into the domains they would like to modify. User must have the GAM utility installed into the ~\ folder on the server and authenticated.

This script imports Active Directory users from a CSV input.
The CSV must be in the default format as downloaded from our
Gam Bulk Operations Google Sheet.

It will work for either Lifeline or Crosswinds, and therefore requires the input of a domain as a parameter.

Run in the following format: .\scriptname.ps1 domain

Acceptable input for the domain is either "lifeline","crosswinds", or "lastingchange"

--- #>

Param(
	[Parameter(Mandatory=$True)][string]$domain
)

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

#Request Domain Admin credentials for the DC
$cred = Get-Credential -Message "Enter Credentials for $domain ('$domainPrefix\' is  required)."

$s = New-PSSession -ComputerName $computerName -Credential $cred

Invoke-Command -Session $s -Scriptblock {

    # Add the Active Directory bits and not complain if they're already there
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
	
	#Add the GAM folder to the environment path for this session only
	$env:Path = $env:Path+";C:\gam";

    # Get domain DNS suffix, then set email address ending based on it
    $dnsroot = (Get-ADDomain).dnsroot
	$emailDomain = '@'+$dnsroot.Split(".")[0]+'.org'
	
	function Main-Menu {
		Do {
			$exit = $false
			$caption = "Choose Your Next Move"
			$message = "Would you like to add aliases, remove aliases, or quit?"
			$addAlias = New-Object System.Management.Automation.Host.ChoiceDescription "&Add Aliases", "Add Aliases"
			$removeAlias = New-Object System.Management.Automation.Host.ChoiceDescription "&Remove Aliases", "Remove Aliases"
			$quit = New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit"
			$choices = [System.Management.Automation.Host.ChoiceDescription[]]($addAlias,$removeAlias,$quit)
			$response = $host.ui.PromptForChoice($caption,$message,$choices,0)
			
			switch ($response) {
				0 {Select-User add}
				1 {Select-User remove}
				2 {$exit = $true}
				}
			}#End of Do
		Until ($exit -eq $true)
		Return
		}
		
	function Select-User ([string]$func) {
		Do {
			switch ($func){
				add {$operation = "ADDING"}
				remove {$operation = "REMOVING"}
				}
			$usernameResponse = Read-Host "$operation ALIASES: Enter the user's SamAccountName (email address minus domain), or enter 'm' to return to the Main Menu."
			If ($usernameResponse -ne "m"){
				Try {
				$userExists = Get-ADUser -Identity $usernameResponse
					}
				Catch {
					Write-Warning "User not found"
					}
				If ($userExists){
					switch ($func){
						add {Input-Alias $usernameResponse}
						remove {Remove-Alias $usernameResponse}
						}
					}
				}
			}#End of Do
		Until($usernameResponse -eq "m")
		Return
		}
		
	function Input-Alias ([string]$sam){
		Do {
			Get-ADUser -Identity $sam -Properties Name,proxyaddresses | Select Name,@{n='ProxyAddresses';e={$_.ProxyAddresses -join "`r`n"}} | ft -Wrap
			$aliasResponse = Read-Host "Enter the alias to add for user $sam (omit domain name), or enter 'd' for Done."
			If ($aliasResponse -ne "d"){
				If ($aliasResponse.Split("@")[1]){
					Write-Warning "Please re-enter the alias without the domain name."
					}
				Else {
					$proxyAddress = $aliasResponse + $emailDomain
					Set-ADUser -Identity $sam -Add @{ProxyAddresses=$proxyAddress}
					}
				}
			}#End of Do
		Until ($aliasResponse -eq "d")
		Return
		}
		
	function Remove-Alias ([string]$sam){
		Do {
			Get-ADUser -Identity $sam -Properties Name,proxyaddresses | Select Name,@{n='ProxyAddresses';e={$_.ProxyAddresses -join "`r`n"}} | ft -Wrap
			$aliasResponse = Read-Host "Enter the alias to remove from user $sam (omit domain name), or enter 'd' for Done."
			If ($aliasResponse -ne "d"){
				If ($aliasResponse.Split("@")[1]){
					Write-Warning "Please re-enter the alias without the domain name."
					}
				Else {
					$proxyAddress = $aliasResponse + $emailDomain
					Set-ADUser -Identity $sam -Remove @{ProxyAddresses=$proxyAddress}
					}
				}
			}#End of Do
		Until ($aliasResponse -eq "d")
		Return
		}
	
	Main-Menu
	
    }
	

Remove-PSSession $s

#Set console prompting back to user's original setting if it has been changed.
If ($consolePrompting -eq $false){
	Set-ItemProperty -Path $key -Name ConsolePrompting -Value $false
	}