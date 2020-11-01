# -----------------------------------------------------------------------------
# Description: Generic Update Script for PortableApps
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Modules
# -----------------------------------------------------------------------------
Using module ".\PortableAppsCommon.psm1"

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$Version    = "0.0.4-alpha"
$Debug      = $True
$RestUrl    = "https://api.github.com/repos/uroesch/{0}/releases" -f $AppName

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Fetch-InstalledVersion() {
  Try {
    $Line    = (Get-Content -Path $AppInfoIni | Select-String 'DisplayVersion')
    $Version = ($Line -split "=")[1]
    If ($Version.Length -eq 0 ) { Throw }
    Return $Version
  }
  Catch {
    Debug error "Failed to parse version $AppInfoIni file"
    exit 120
  }
}

# -----------------------------------------------------------------------------
Function Fetch-LatestVersion() {
  Try {
    $Version = (Fetch-LatestRelease).name -replace "^v", ""
    If ($Version.Length -eq 0 ) { Throw }
    Return $Version
  }
  Catch {
    Debug error "Failed to parse github release version"
    exit 121
  }
}

# -----------------------------------------------------------------------------
Function Fetch-LatestRelease() {
  Try {
    (Invoke-RestMethod -Uri $RestUrl)[0]
  }
  Catch {
    Debug error "Failed to fetch latest release of $AppName"
    exit 122
  }
}

# -----------------------------------------------------------------------------
Function Fetch-InstallerLink() {
  Debug info "Fetching installer download URL '$RestUrl'"
  Try {
    (Fetch-LatestRelease).assets | ForEach-Object {
      If ($_.name -Match "$AppName.*.paf.exe") {
        Debug info "Download link is $($_.browser_download_url)"
        Return $_.browser_download_url
      }
    }
  }
  Catch {
    Debug error "Failed to download and parse release information for $AppName"
    Exit 123
  }
}

# -----------------------------------------------------------------------------
Function Download-Release {
  $DownloadDir   = "$AppRoot\Download"
  $InstallerLink = Fetch-InstallerLink
  $InstallerFile = "$DownloadDir\" + ($InstallerLink.split("/"))[-1]

  If (!(Test-Path $DownloadDir)) {
    New-Item -Path $DownloadDir -ItemType directory
  }

  If (Test-Path $InstallerFile) {
    Debug info "File '$InstallerFile' is already present; Skip download"
    Return $InstallerFile
  }

  Debug info "Downloading Installer from '$InstallerLink'"
  Try {
    Invoke-WebRequest `
      -Uri $InstallerLink `
      -OutFile $InstallerFile | Out-Null
  }
  Catch {
    Debug error "Failed to download '$InstallerLink'"
    Exit 125
  }

  Return $InstallerFile
}

# -----------------------------------------------------------------------------
Function Invoke-Installer() {
  param(
    [string] $Command
  )
  Set-Location "$AppRoot\.."
  $PARoot    = (Get-Location)
  $Arguments = "/AUTOCLOSE=true " +
               "/DESTINATION=""$(ConvertTo-WindowsPath $PARoot)\\"""
  #  Addtional Switches for paf.exe
  #  /HIDEINSTALLER=true
  #  /SILENT=true

  Switch (Test-Unix) {
    $True   {
      $Arguments = "$Command $Arguments"
      $Command   = "wine"
      break
    }
    default { }
  }

  Debug info "Run PA $Command $Arguments"
  Start-Process $Command -ArgumentList $Arguments -NoNewWindow -Wait
}

# -----------------------------------------------------------------------------
Function Check-Version {
  $CurrentVersion = Fetch-InstalledVersion
  $LatestVersion  = Fetch-LatestVersion

  If ($CurrentVersion -eq $LatestVersion) {
    Debug info "Current version and latest release one are the same."
    Exit 124
  }
}

# -----------------------------------------------------------------------------
Function Install-Release() {
  $Installer = Download-Release
  Invoke-Installer -Command $Installer
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
Check-Version
Install-Release
