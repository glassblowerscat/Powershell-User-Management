<#
    Uses the GAM tool to download CSVs of users by title or OU.
    Imports the CSVs to be read, then uses GAM to update the groups
    according to the information in the CSVs.

    Dependency: GAM installed with admin credentials on the machine
    running the script
    Will be run as a scheduled task.
#>

 
#Adds the Google Apps Manager (GAM) directory as a path.
#This enables running commands against the Google API using GAM.
$env:Path += ";C:\gam"


<# This next section is for syncing Organizational Unit memmbership
to the appropriate groups.
Here's what we will do. We will create two arrays, orgGroups and orgOrgs.
orgGroups is a list of groups that will be synced to an OU.
orgOrgs is a list of the OUs to which they will be synced.
First, we'll instantiate the arrays empty. Then we will add to them in pairs.
Each pair of lines should be a group and an OU that go together.
They can be in any order, as long as they are paired the way they need to sync.
This way, we can add a pair in the middle if the organizational structure changes.

Then, at the end of this list, we will use a for loop to run a GAM command
that iterates through each array and syncs orgGroups[$i] with orgOrgs[$i].
#>


$orgGroups = @()
$orgOrgs = @()

$orgGroups += "administrative"
$orgOrgs += "/Admin"

$orgGroups += "development"
$orgOrgs += "/Admin/Development"

$orgGroups += "executive"
$orgOrgs += "/Admin/Executive"

$orgGroups += "crt"
$orgOrgs += "/Admin/FamilyServices/CRT"

$orgGroups += "ihfcadmin"
$orgOrgs += "/Admin/FamilyServices/IHFC"

$orgGroups += "humanresources"
$orgOrgs += "/Admin/HR"

$orgGroups += "itdept"
$orgOrgs += "/Admin/IT"

#Fix Marketing so that users are in either the CW or LL group, not both
#Then create a master group (like "lcmarketing") so they can conveniently email everyone
#$orgGroups += "marketing"
#$orgOrgs += "/Admin/Marketing"

$orgGroups += "homebuilders02"
$orgOrgs += "/FamilyServices/HBS/Homebuilders/Region02"

$orgGroups += "homebuilders03"
$orgOrgs += "/FamilyServices/HBS/Homebuilders/Region03"

$orgGroups += "homebuilders06"
$orgOrgs += "/FamilyServices/HBS/Homebuilders/Region06"

$orgGroups += "region03a"
$orgOrgs += "/FamilyServices/HBS/Region03a"

$orgGroups += "region03b"
$orgOrgs += "/FamilyServices/HBS/Region03b"

$orgGroups += "region04"
$orgOrgs += "/FamilyServices/HBS/Region04"

$orgGroups += "region05"
$orgOrgs += "/FamilyServices/HBS/Region05"

$orgGroups += "region06"
$orgOrgs += "/FamilyServices/HBS/Region06"

$orgGroups += "region07"
$orgOrgs += "/FamilyServices/HBS/Region07"

$orgGroups += "region08"
$orgOrgs += "/FamilyServices/HBS/Region08"

$orgGroups += "region09"
$orgOrgs += "/FamilyServices/HBS/Region09"

$orgGroups += "region10"
$orgOrgs += "/FamilyServices/HBS/Region10"

$orgGroups += "region11"
$orgOrgs += "/FamilyServices/HBS/Region11"

$orgGroups += "region12"
$orgOrgs += "/FamilyServices/HBS/Region12"

$orgGroups += "region13"
$orgOrgs += "/FamilyServices/HBS/Region13"

$orgGroups += "region14"
$orgOrgs += "/FamilyServices/HBS/Region14"

$orgGroups += "region15"
$orgOrgs += "/FamilyServices/HBS/Region15"

$orgGroups += "region16"
$orgOrgs += "/FamilyServices/HBS/Region16"

$orgGroups += "region16"
$orgOrgs += "/FamilyServices/HBS/Region16"

$orgGroups += "rescm"
$orgOrgs += "/Residential/CaseManagement"

$orgGroups += "eande"
$orgOrgs += "/Residential/Endurance-Endeavor"

$orgGroups += "pwakitchen"
$orgOrgs += "/Residential/FoodService"

$orgGroups += "pwaschool"
$orgOrgs += "/Residential/PWASchool"

$orgGroups += "spencer"
$orgOrgs += "/Residential/Spencer"

$orgGroups += "resth"
$orgOrgs += "/Residential/Therapy"

$orgGroups += "vandc"
$orgOrgs += "/Residential/Voyager-Challenger"

#Now we sync up the groups and the orgs.
For ($i=0;$i -lt $orgGroups.Length;$i++){
    gam update group $orgGroups[$i] sync member org $orgOrgs[$i]
}


$orgParentGroups = @()
$orgParentOrgs = @()

$orgParentGroups += "familyservices"
$orgParentOrgs += "/Admin/FamilyServices"

$orgParentGroups += "Residential"
$orgParentOrgs += "/Residential"

For ($i=0;$i -lt $orgParentGroups.Length;$i++){
    gam update group $orgParentGroups[$i] sync member ou_and_children $orgParentOrgs[$i]
}


<# This is what I was going to do. Delete this later

Function UpdateGroup-ByOrg ($group,$org) {
    gam update group $group sync member org $org
}

UpdateGroup-ByOrg administrative "/Admin"
UpdateGroup-ByOrg development "/Admin/Development"
UpdateGroup-ByOrg executive "/Admin/Executive"
UpdateGroup-ByOrg familyservices "/Admin/FamilyServices"
UpdateGroup-ByOrg crt "/Admin/FamilyServices/CRT"
UpdateGroup-ByOrg ihfcadmin "/Admin/FamilyServices/IHFC"
UpdateGroup-ByOrg humanresources "/Admin/HR"
UpdateGroup-ByOrg itdept "/Admin/IT"
#UpdateGroup-ByOrg marketing "/Admin/Marketing"

#>