#!/usr/bin/env powershell
# -----------------------------------------------------------------------------
# Description: Generic Update Script for PortableApps
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

<#
.SYNOPSIS
  Update and build a new release of a PortableApps application installer.

.DESCRIPTION
  A script to automate the tedious process of building the application
  installers for PortableApps.
  The scripts does get the instructions from the custom ini file
  located under <ApplicationRoot>/App/AppInfo/update.ini

.PARAMETER UpdateChecksums
  Updates the ini files Checksums with the one of the newly downloaded
  upstream version.

.PARAMETER InfraDir
  Override the default directory where the build infrastructure resides.
  E.g the Launcher and Installer packages from PortableApps.com.
#>


# -----------------------------------------------------------------------------
# Modules
# -----------------------------------------------------------------------------
Using module ".\PortableAppsCommon.psm1"
Using module ".\IniConfig.psm1"

Param(
  [Switch] $UpdateChecksums,
  [String] $InfraDir = $InfraDirDefault
)
# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$Version = "0.0.35-alpha"
$Debug   = $True

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Which-7Zip() {
  $Locations  = $env:PATH.Split([IO.Path]::PathSeparator)
  $Locations += @(
    "$Env:ProgramFiles\7-Zip",
    "$Env:ProgramFiles(x86)\7-Zip",
    "$AppRoot\..\7-ZipPortable\App\7-Zip",
    "$AppRoot\..\PortableApps.comInstaller\App\7zip"
  )
  Switch (Test-Unix) {
    $True   { $Binary = '7z'; break; }
    default { $Binary = '7z.exe' }
  }
  Foreach ($Location in $Locations) {
    $Fullpath = Join-Path $Location $Binary
    # There is get command but this way it works with relative pathes
    If (Test-Path $Fullpath) {
      Return $Fullpath
    }
  }
  If (!($Path)) {
    Debug fatal "Could not locate $Binary"
    Exit 76
  }
}

# -----------------------------------------------------------------------------
Function Check-Sum {
  param(
    [object] $Download
  )
  If ($UpdateChecksums) {
    $Download.Checksum = Update-Checksum `
      -Path $Download.OutFile() `
      -Checksum $Download.Checksum
  }
  Return Compare-Checksum `
    -Checksum $Download.Checksum `
    -Path $Download.OutFile()
}

# -----------------------------------------------------------------------------
Function Download-File {
  param(
    [object] $Download
  )
  # hide progress bar
  $Global:ProgressPreference = 'silentlyContinue'
  If (!(Test-Path $Download.DownloadDir)) {
    Debug info "Create directory $($Download.DownloadDir)"
    New-Item -Path $Download.DownloadDir -Type directory | Out-Null
  }
  If (!(Test-Path $Download.OutFile())) {
    Try {
      Debug info "Download URL $($Download.URL) to $($Download.OutFile()).part"
      # iwr Does not work for sourceforge.net :( so we use this construct
      $Downloader = New-Object System.Net.WebClient
      $Downloader.DownloadFile($Download.URL, "$($Download.OutFile()).part")

      Debug info "Move file $($Download.OutFile()).part to $($Download.OutFile())"
      Move-Item -Path "$($Download.OutFile()).part" `
        -Destination $Download.OutFile()
    }
    Catch {
      Debug fatal "Failed to download URL $($Download.URL)"
      Exit 1
    }
  }
  If (!(Check-Sum -Download $Download)) {
    Debug fatal "Checksum for $($Download.OutFile()) " `
      "does not match '$($Donwload.Checksum)'"
    Exit 1
  }
  Debug info "Downloaded file '$($Download.OutFile())'"
}

# -----------------------------------------------------------------------------
Function Expand-Download {
  param(
    [object] $Download
  )
  If (!(Test-Path $Download.ExtractTo())) {
    Debug info "Create extract directory $($Download.ExtractTo())"
    New-Item -Path $Download.ExtractTo() -Type "directory" | Out-Null
  }
  Debug info "Extract $($Download.OutFile()) to $($Download.ExtractTo())"
  Expand-Archive -LiteralPath $Download.OutFile() `
    -DestinationPath $Download.ExtractTo() -Force
}

# -----------------------------------------------------------------------------
Function Expand-7Zip {
  param(
    [object] $Download
  )
  $7ZipExe = $(Which-7Zip)
  If (!(Test-Path $Download.ExtractTo())) {
    Debug info "Create extract directory $($Download.ExtractTo())"
    New-Item -Path $Download.ExtractTo() -Type "directory" | Out-Null
  }
  Debug info "Extract $($Download.OutFile()) to $($Download.ExtractTo())"
  $Command = "$7ZipExe x -r -y  " +
    " -o""$($Download.ExtractTo())"" " +
    " ""$($Download.OutFile())"""
  Debug info "Running command '$Command'"
  Invoke-Expression $Command | Out-Null
}

# -----------------------------------------------------------------------------
Function Update-Release {
  param(
    [object] $Download
  )
  Switch -regex ($Download.Basename()) {
    '\.zip$' {
      Expand-Download -Download $Download
      break
    }
    '\.7z.exe$' {
      Expand-7Zip -Download $Download
      break
    }
  }
  If (Test-Path $Download.MoveTo()) {
    Debug info "Cleanup $($Download.MoveTo())"
    Remove-Item -Path $Download.MoveTo() `
      -Force `
      -Recurse
  }
  # Create destination Directory if not exist
  $MoveBaseDir = $Download.MoveTo() | Split-Path
  If (!(Test-Path $MoveBaseDir)) {
  Debug info "Create directory $MoveBaseDir prior to moving items"
    New-Item -Path $MoveBaseDir -Type "directory" | Out-Null
  }
  Debug info `
    "Move release from $($Download.MoveFrom()) to $($Download.MoveTo())"
  Move-Item -Path $Download.MoveFrom() `
    -Destination $Download.MoveTo() `
    -Force
}

# -----------------------------------------------------------------------------
Function Update-Appinfo() {
  $Version = $Config.Section("Version")
  $AppInfo = Read-IniFile -IniFile $AppInfoIni
  $AppInfo.Section("Version")["PackageVersion"] = $Version["Package"]
  $AppInfo.Section("Version")["DisplayVersion"] = $Version["Display"]
  (Write-IniFile -IniFile $AppInfoIni -Struct $AppInfo.Struct).Commit()
}

# -----------------------------------------------------------------------------
Function Update-Application() {
  $Archive = $Config.Section('Archive')
  $Position = 1
  While ($True) {
    If (-Not ($Archive.Contains("URL$Position"))) {
      Break
    }
    $Download  = [Download]::new(
      $Archive["URL$Position"],
      $Archive["ExtractName$Position"],
      $Archive["TargetName$Position"],
      $Archive["Checksum$Position"]
    )
    Download-File -Download $Download
    Update-Release -Download $Download
    $Position += 1
  }
}

# -----------------------------------------------------------------------------
Function Postinstall() {
  $Postinstall = "$PSScriptRoot\Postinstall.ps1"
  If (Test-Path $Postinstall) {
    . $Postinstall
  }
}

# -----------------------------------------------------------------------------
Function Create-AdditionalLaunchers() {
  $Control = (Read-IniFile -IniFile $AppInfoIni).Section("Control")
  $Counter = 2
  $Icons   = $Control.Item("Icons")
  $PALDir  = Join-Path $InfraDir "PortableApps.comLauncher"
  $Nsis    = [System.IO.Path]::Combine($PALDir, 'App', 'NSIS', 'makensis.exe')
  $Script  = "$PALDir\Other\Source\PortableApps.comLauncher.nsi"
  $Options = @(
    "/O""$(ConvertTo-WindowsPath $PALDir)\Data\PortableApps.comLauncherGeneratorLog.txt""",
    "/DPACKAGE=""$(ConvertTo-WindowsPath $AppRoot)""",
    "/DNamePortable=""{0}""",
    "/DAppID=""{1}""",
    "/DIconPath=""$(ConvertTo-WindowsPath $AppInfoDir)\appicon{2}.ico"""
  ) -join " "
  While ($Counter -le $Icons) {
    $Name    = $Control.Item("Name$Counter")
    $AppId   = $Control.Item("Start$Counter").Replace(".exe", "")
    $Args    = $Options -f $Name, $AppId, $Counter

    Switch (Test-Unix) {
      $True   {
        $Arguments = "$Nsis $Args $(ConvertTo-WindowsPath $Script)"
        $Command   = "wine"
        break
      }
      default {
        $Arguments = "$Args $(ConvertTo-WindowsPath $Script)"
        $Command   = $Nsis
      }
    }
    Start-Process $Command -ArgumentList $Arguments -NoNewWindow -Wait
    $Counter++
  }
}

# -----------------------------------------------------------------------------
Function Create-Launcher() {
  Set-Location $AppRoot
  $AppPath  = (Get-Location)
  Create-AdditionalLaunchers
  Try {
    $Command = Assemble-PAExec `
      -Name 'PortableApps.comLauncher' `
      -Suffix 'Generator.exe'
    Invoke-Helper -Command $Command
  }
  Catch {
    Debug fatal "Unable to create PortableApps Launcher - " + $_
    Exit 21
  }
}

# -----------------------------------------------------------------------------
Function Create-Installer() {
  Try {
    $Command = Assemble-PAExec -Name 'PortableApps.comInstaller'
    Invoke-Helper -Sleep 5 -Timeout 300 -Command $Command
  }
  Catch {
    Debug fatal "Unable to create installer for PortableApps - " + $_
    Exit 42
  }
}

# -----------------------------------------------------------------------------
Function Assemble-PAExec() {
  Param(
    [String] $Name,
    [String] $Suffix = '.exe'
  )
  Debug debug "InfraDir is ${InfraDir}"
  [System.IO.Path]::Combine($InfraDir, $Name, "$Name$Suffix")
}

# -----------------------------------------------------------------------------
Function Invoke-Helper() {
  param(
    [string] $Command,
    [int]    $Sleep   = $Null,
    [int]    $Timeout = 30
  )
  Set-Location $AppRoot
  $AppPath = (Get-Location)

  Switch (Test-Unix) {
    $True   {
      $Arguments = "$Command $(ConvertTo-WindowsPath $AppPath)"
      $Command   = "wine"
      break
    }
    default {
      $Arguments = ConvertTo-WindowsPath $AppPath
    }
  }

  Debug info "Run PA $Command $Arguments"
  Start-Process $Command -ArgumentList $Arguments -NoNewWindow -Wait
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
$Config = Read-IniFile -IniFile $UpdateIni
Update-Application
Update-Appinfo
Postinstall
Create-Launcher
Create-Installer
