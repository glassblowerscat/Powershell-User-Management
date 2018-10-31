<#
Works by reading the "c:\Resources\fonts" folder on the targeted user's computer. Any fonts found in this folder will be installed by the script.
#>

$FONTS = 0x14
$FromPath="c:\Resources\fonts"

$objShell = New-Object -ComObject Shell.Application
$objFolder = $objShell.Namespace($FONTS)

$CopyOptions = 4 + 16
$CopyFlag = [String]::Format("{0:x}", $CopyOptions)

foreach($File in $(Ls $Frompath)) {
  If (test-path "c:\windows\fonts\$($file.name)"){
     "$($file.fullname) already installed - not installing" #Useful for testing
	 }
  Else {
      $copyFlag = [String]::Format("{0:x}", $CopyOptions)
      "installing $($file.fullname)"           # Useful for debugging
      $objFolder.CopyHere($File.fullname, $CopyOptions)
     }
}