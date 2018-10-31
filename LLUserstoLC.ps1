Import-Module C:\Users\kimiko\Documents\UserInfoTransforms -ErrorAction Inquire

$users = Import-CSV .\users.csv

Foreach ($user in $users){
	try{
		$importParameters = @{}
		
		$dnsRoot,$emailRoot = Get-Domains
		$name = $user."Display Name"
		$displayName = $user."Display Name"
		$givenName = $user."First Name"
		$surname = $user."Last Name"
		$userPrincipalName,$samAccountName = New-ADUsernames
		$givenName $surname
		$isEmail = CompareEmailAddressToFormat $user."Email Address" $givenName $surname
		If (-not $isEmail){
				$newProxyAddress = Convert-EmailToAlias $user."Email Address"
		}
		$emailAddress = New-EmailAddress $givenName $surname
		$phoneType = Get-PhoneType $user."Office Phone"
		$phoneNumber = $user."Office Phone"
		$company = $user.Department
		$department = $user.Location
		$title = $user.Title
		Switch($user.Location){
			"Admin"{$ou = "Administrative"}
			$null{$ou = "Administrative"}
			"Finance"{$ou = "Finance"}
			"Marketing"{$ou = "Marketing"}
			"IT"{$ou = "IT"}
			"HR"{$ou = "Human Resources"}
			"Executive"{$ou = "Executive"}
			"Development"{$ou = "Development"}
		}
		$path = "ou=$ou,dc=$($dnsroot.Split(".")[0]),dc=$($dnsroot.Split(".")[1])"
		$password = ConvertTo-SecureString -String $user."Password" -AsPlainText -force
		
		#Use variables set above to populate the empty hashtable with values for a New-ADUser command
		$importParameters.Set_Item("samAccountName",$samAccountName)
		$importParameters.Set_Item("Name",$name)
		$importParameters.Set_Item("DisplayName",$displayName)
		$importParameters.Set_Item("givenName",$givenName)
		$importParameters.Set_Item("surname",$surname)
		$importParameters.Set_Item("userPrincipalName",$userPrincipalName)
		$importParameters.Set_Item("emailAddress",$emailAddress)
		$importParameters.Set_Item($phoneType,$phoneNumber)
		$importParameters.Set_Item("company",$user.Department)
		$importParameters.Set_Item("department",$user.Location)
		$importParameters.Set_Item("title",$title)
		$importParameters.Set_Item("Path",$path)
		$importParameters.Set_Item("AccountPassword",$password)
		$importParameters.Set_Item("ChangePasswordAtLogon",$true)
		$importParameters.Set_Item("PasswordNeverExpires",$true)
		$importParameters.Set_Item("Enabled",$true)
		
		#Check to see whether user exists
		$ADUser = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
		
		If ($ADUser){
			Write-Output "$username already exists."
		}
		Else {
			New-ADUser @parameters
			Write-Output "Created new AD user: $($username)"
		}
	}
	catch{
		Write-Output "One or more errors occurred while creating user $username : $_"
	}
}