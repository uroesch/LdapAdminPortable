[![Build](https://github.com/uroesch/LdapAdminPortable/workflows/build-package/badge.svg)](https://github.com/uroesch/LdapAdminPortable/actions?query=workflow%3Abuild-package)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/uroesch/LdapAdminPortable?include_prereleases)](https://github.com/uroesch/LdapAdminPortable/releases)
[![Runs on](https://img.shields.io/badge/runs%20on-Win64%20%26%20Win32-blue)](#runtime-dependencies)

# LDAP Admin Portable for PortableApps.com

<!-- img src="App/AppInfo/appicon_128.png" align=left -->

[Ldap Admin](http://www.ldapadmin.org/) is a free Windows LDAP client and 
administration tool for LDAP directory management. This application lets 
you browse, search, modify, create and delete objects on LDAP server. It 
also supports more complex operations such as directory copy and move between 
remote servers and extends the common edit functions to support specific 
object types (such as groups and accounts).

You can use it to manage Posix groups and accounts, Samba accounts and it 
even includes support for Postfix MTA. Ldap Admin is free Open Source 
software distributed under the GNU General Public License. 

## Runtime dependencies
* 32-bit or 64-bit version of Windows.

## Status 
This PortableApp project is in early beta stage. 

## Todo
- [x] Documentation
- [ ] Icons

## Build

### Prerequisites

* [PortableApps.com Launcher](https://portableapps.com/apps/development/portableapps.com_launcher)
* [PortableApps.com Installer](https://portableapps.com/apps/development/portableapps.com_installer)
* [Powershell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7)
* [Wine (Linux / MacOS only)](https://www.winehq.org/)

### Build

To build the installer run the following command in the root of the git repository.

```
powershell Other/Update/Update.ps1
```
