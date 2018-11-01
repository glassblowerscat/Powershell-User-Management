# Powershell and G Suite/GAM Administration Scripts
 
**Modules, functions, scripts, and working files for managing users with Active Directory and GAM for G Suite.** 

**DO NOT USE IN YOUR OWN ENVIRONMENT WITHOUT SERIOUS MODIFICATION. Heavily oriented around my own AD and G Suite Domains and stored here only for version control, not for public consumption.**

## Dependencies

  - Active Directory admin credentials for PowerShell remoting
  - PowerShell remoting to the DC configured on client machine
  - Google Apps Manager (GAM) installation with user/groups admin credential for your G Suite (Google Apps for Work) domain. GAM must be installed and authenticated on the DC, under the same account used for administering Active Directory.
  - Some features require a working installation of Google Cloud Directory Sync (GCDS), which synchronizes Active Directory information to G Suite. It is assumed that GCDS will be configured to run under a service account so that sync operations can be scheduled without depending on a specific user's account being enabled.
