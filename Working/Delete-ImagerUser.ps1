$computer = $env:computername
$Users = Get-WMIObject Win32_UserAccount -Filter "LocalAccount=True" -ComputerName $computer
Foreach ($user in $Users){
	if ($Users.Name -eq 'Imager') {
			$ADSI = [ADSI]"WinNT://$computer"
			$ADSI.Delete('User','Imager') 
		}
}