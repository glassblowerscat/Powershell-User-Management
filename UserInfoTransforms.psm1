Import-Module ActiveDirectory -ErrorAction SilentlyContinue

#Function for extracting the domain suffix and email suffix from the dnsroot of the domain. Returns two values. Call with something like $dnsRoot,$emailDomain = Get-Domains
function Get-Domains {
	$dnsRootSuffix = (Get-ADDomain).dnsroot
	$emailDomainSuffix = '@'+$dnsRootSuffix.Split(".")[0]+'.org'
	return $dnsRootSuffix,$emailDomainSuffix
}

#Function to check whether user's existing email address matches the format of firstname.lastname@domain.com. If it does, returns $true. If not, returns $false
function Compare-EmailAddressToFormat ([string]$currentEmail,[string]$firstName,[string]$lastName) {
	If ($currentEmail.Split(".").length -eq 3){
		If($currentEmail.Split(".")[0] -eq $firstName -or $currentEmail.Split(".")[0] -eq $firstName.ToLower()){
			If($($currentEmail.Split(".")[1]).Split("@")[0] -eq $lastName -or $currentEmail.Split(".")[1] -eq $lastName.ToLower()){
				$emailValid = $true
			}
			Else{$emailValid = $false}
		}
		Else{$emailValid = $false}
	}
	Else {$emailValid = $false}
	return $emailValid
}

#Function to convert an existing email address in a wrong format (e.g., flastname@domain.com) to an alias for the correct domain.
function Convert-EmailToAlias ([string]$currentEmail){
	$dnsRootSuffix = (Get-ADDomain).dnsroot
	$newAlias = $currentEmail.Split("@")[0] + '@' + $dnsRootSuffix.Split(".")[0]+'.org'
	return $newAlias
}

#Function for creating the user's correct email address after the formula firstname.lastname@domain.org. Returns the full email address.
function New-EmailAddress ([string]$firstName, [string]$lastName){
	$rootSuffix,$domainSuffix = Get-Domains
	$newEmail = $firstName.ToLower() + "." + $lastName.ToLower() + $domainSuffix
	return $newEmail
}

#Function for determining whether the user's listed phone number is a mobile or office phone. Checks to see whether it begins with "(260) 702" or "(574) 400", and if so, returns it as an office phone. If not, returns as a mobile phone.
function Get-PhoneType ([string]$phoneNumber){
	$phonePrefix = $phoneNumber.Substring(0,9)
	Switch -wildcard ($phonePrefix){
		"(260) 702"{$phoneType = "officePhone"}
		"260-702*"{$phoneType = "officePhone"}
		"(574) 400"{$phoneType = "officePhone"}
		"574-400*"{$phoneType = "officePhone"}
		default {$phoneType = "mobilePhone"}
	}
	Return $phoneType
}

#Function for transforming the user's firstname and lastname into their UPN and SAM. Checks for total length of more than 19 (room for period); if username exceeds 19, SAM will be firstinitial/lastname format. UPN will be firstname.lastname@domain.local
function New-ADUsernames ([string]$firstName, [string]$lastName){
	$UPNSuffix = (Get-ADDomain).dnsroot
	$UPN = $firstName.ToLower() + "." + $lastName.ToLower() + "@" + $UPNSuffix
	If (($firstName + "." + $lastName).length -gt 20){
		$SAM = $firstName.Substring(0,1).ToLower() + $lastName.ToLower()
	}
	Else {
		$SAM = $firstName.ToLower() + "." + $lastName.ToLower()
	}
	return $UPN,$SAM
}

#Function for examining the user's G Suite path to construct their AD OU path.
function New-ADPathFromGooglePath ([string]$userGooglePath){
	$ADPathList = Get-ADOrganizationalUnit -Filter * -Properties CanonicalName | Select-Object CanonicalName
	#(Canonical Name reads like "lifelineyouth.local/FamilyServices/HBS/Region06")
	$ADPathPrefix = (Get-ADDomain).dnsroot
	#(.dnsroot reads like "lifelineyouth.local")
	Foreach ($path in $ADPathList){
		$inputPath = $path.CanonicalName.Substring($ADPathPrefix.length)
		#(This cuts off the .dnsroot from the beginning of the CanonicalName)
		If($userGooglePath -eq $inputPath){
			switch($pathToParse.length){
				5{$userADPath = "ou=$($pathToParse[4]),ou=$($pathToParse[3]),ou=$($pathToParse[2]),ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
				}
				4{$userADPath = "ou=$($pathToParse[3]),ou=$($pathToParse[2]),ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
				}
				3{$userADPath = "ou=$($pathToParse[2]),ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
				}
				2{$userADPath = "ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
				}
				1{$userADPath = "cn=Users,dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
				}
			}
		}
		Else{
			$userADPath = $null
		}
	}
	return $userADPath
}

#Function for accepting an input OU in the format "/OU/OU/OU" and writing it out as the new AD OU path.
function New-ADPath ([string]$inputPath){
	$ADPathPrefix = (Get-ADDomain).dnsroot
	$pathToParse = $inputPath.Split("/")
	switch($pathToParse.length){
		5{$userADPath = "ou=$($pathToParse[4]),ou=$($pathToParse[3]),ou=$($pathToParse[2]),ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
		}
		4{$userADPath = "ou=$($pathToParse[3]),ou=$($pathToParse[2]),ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
		}
		3{$userADPath = "ou=$($pathToParse[2]),ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
		}
		2{$userADPath = "ou=$($pathToParse[1]),dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
		}
		1{$userADPath = "cn=Users,dc=$($ADPathPrefix.Split(".")[0]),dc=$($ADPathPrefix.Split(".")[1])"
		}
	}
	return $userADPath
}


#Function for reading a GAM-output CSV row, finding the Aliases that aren't blank, and writing them into an array
function Set-ProxyAddressesFromGAM ($userData){
	$proxyAddresses = ""
	For ($i=0; $i -le 29; $i++) {
		If ($userData."aliases.$i" -ne "") {
			$proxyAddresses += $userData."aliases.$i" + ";"
			}
	}
	return $proxyAddresses
}

#Function for writing all relevant variables to $null.
function Reset-HashToNull ([hashtable]$values){
	Foreach($key in $($values.keys)){
		$values[$key] = $null
		}
	return $values
}