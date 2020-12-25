[![Build](https://github.com/uroesch/LdapAdminPortable/workflows/build-package/badge.svg)](https://github.com/uroesch/LdapAdminPortable/actions?query=workflow%3Abuild-package)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/uroesch/LdapAdminPortable?include_prereleases)](https://github.com/uroesch/LdapAdminPortable/releases)
[![Runs on](https://img.shields.io/badge/runs%20on-Win64%20%26%20Win32-blue)](#runtime-dependencies)
![GitHub All Releases](https://img.shields.io/github/downloads/uroesch/LdapAdminPortable/total?style=flat)

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

## Support matrix

| OS              | 32-bit             | 64-bit              | 
|-----------------|:------------------:|:-------------------:|
| Windows XP      | ![fs][fs]          | ![nd][nd]           | 
| Windows Vista   | ![fs][fs]          | ![fs][fs]           | 
| Windows 7       | ![fs][fs]          | ![fs][fs]           |  
| Windows 8       | ![fs][fs]          | ![fs][fs]           |  
| Windows 10      | ![fs][fs]          | ![fs][fs]           |

Legend: ![ns][ns] not supported;  ![nd][nd] no data; ![ps][ps] supported but not verified; ![fs][fs] verified;`

## Status 
This PortableApp project is in early beta stage. 

## Todo
- [x] Documentation
- [ ] Icons


<!-- Start include INSTALL.md -->
## Installation

The Packages found under the release page are not digitally signed so there the installation
is a bit involved.

After download the `.paf.exe` installer trying to install may result in a windows defender
warning.

<img src="Other/Images/info_defender-protected.png" width="260">

To unblock the installer and install the application follow the annotated screenshot below.

<img src="Other/Images/howto_unblock-file.png" width="600">

1. Right click on the executable file.
2. Choose `Properties` at the bottom of the menu.
3. Check the unblock box.
<!-- End include INSTALL.md -->

<!-- Start include BUILD.md -->
### Build

#### Windows 10

To build the installer run the following command in the root of the git
repository.

```
powershell -ExecutionPolicy ByPass -File Other/Update/Update.ps1
```

#### Linux (Docker)

Note: This is currently the preferred way of building.

For a Docker build run the following command.

```
curl -sJL https://raw.githubusercontent.com/uroesch/PortableApps/master/scripts/docker-build.sh | bash
```

#### Linux (Wine)

To build the installer under Linux with Wine and PowerShell installed run the
command below.

```
pwsh Other/Update/Update.ps1
```
<!-- End include BUILD.md -->

[nd]: Other/Icons/no_data.svg
[ns]: Other/Icons/no_support.svg
[ps]: Other/Icons/probably_supported.svg
[fs]: Other/Icons/full_support.svg
