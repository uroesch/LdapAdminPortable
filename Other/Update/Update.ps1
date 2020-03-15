# -----------------------------------------------------------------------------
# Description: Generic Update Script for PortableApps 
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Globals 
# -----------------------------------------------------------------------------
$Version    = "0.0.3-alpha"
$AppRoot    = "$PSScriptRoot\..\.."
$AppInfoDir = "$AppRoot\App\AppInfo"
$AppInfoIni = "$AppInfoDir\appinfo.ini"
$UpdateIni  = "$AppInfoDir\update.ini"
$Debug      = $True

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Debug() { 
  param( [string] $Message )
  If (-Not($Debug)) { return }
  Write-Host $Message
}

# -----------------------------------------------------------------------------
Function Is-Unix() {
  ($PSScriptRoot)[0] -eq '/'
}

# -----------------------------------------------------------------------------
Function Parse-Ini {
  param (
     $IniFile
  )

  $IniContent  = Get-Content $IniFile
  $ResultTable = @()
  foreach ($Line in $IniContent) {
     Debug "Processing '$Line'"
     If ($Line[0] -eq ";") {
       Debug "Skip comment line"
     }
     ElseIf ($Line[0] -eq "[") {
       $Section = $Line -replace "[\[\]]", ""
       Debug "Found new section: '$Section'"
     }
     ElseIf ($Line -like "*=*") {
       Debug "Found Keyline"
         $ResultTable += @{
           Section  = $Section
           Key      = $Line.split("=")[0].Trim()
           Value    = $Line.split("=")[1].Trim()
         }
       }
     Else {
       Debug "Skip line"
     }
  }
  return $ResultTable
}

# -----------------------------------------------------------------------------
Function Fetch-Section() {
  param( [string] $Key )
  $Section = @{}
  Foreach ($Item in $Config) { 
    If ($Item["Section"] -eq $Key) {
      $Section += @{ $Item["Key"] = $Item["Value"] }
    }
  }
  return $Section
} 

# -----------------------------------------------------------------------------
Function Url-Basename {
  param(
    [string] $URL
  )
  $Elements = $URL.split('/')
  $Basename = $Elements[$($Elements.Length-1)]
  return $Basename
}

# -----------------------------------------------------------------------------
Function Check-Sum {
  param(
    [string] $Checksum,
    [string] $File
  )
  ($Algorithm, $Sum) = $Checksum.Split(':')
  $Result = (Get-FileHash -Path $File -Algorithm $Algorithm).Hash
  Debug "Checksum of INI ($Sum) and downloaded file ($Result)"
  return ($Sum -eq $Result)
}

# -----------------------------------------------------------------------------
Function Download-Release { 
  param(
    [string] $URL,
    [string] $Checksum
  )
  $DownloadPath = "$PSScriptRoot\$(Url-Basename -URL $URL)"
  If (!(Test-Path $DownloadPath)) {
    Debug "Downloading file from '$URL'"
    Invoke-WebRequest -Uri $URL -OutFile $DownloadPath
  }
  If (!(Check-Sum -Checksum $Checksum -File $DownloadPath)) {
    Debug "Checksum of File $DownloadPath does not match with '$Checksum'"
    Exit 1
  }
  Debug "Downloaded file '$DownloadPath'"
  return $DownloadPath
}

# -----------------------------------------------------------------------------
Function Expand-Download {
  param(
    [string] $ArchiveFile
  )
  Expand-Archive -LiteralPath $ArchiveFile `
    -DestinationPath $PSScriptRoot -Force
}

# -----------------------------------------------------------------------------
Function Update-Release {
  param(
    [string] $URL,
    [string] $TargetName,
    [string] $ExtractName,
    [string] $Checksum
  )
  $ReleaseFile = $(Download-Release -URL $URL -Checksum $Checksum)
  $TargetPath = "$AppRoot\App\$TargetName"
  Switch -regex ($ReleaseFile) {
    '\.[Zz][Ii][Pp]$' { Expand-Download -ArchiveFile $ReleaseFile; break }
  }
  If (Test-Path $TargetPath) {
    Debug "Removing $TargetPath"
    Remove-Item -Path $TargetPath -Force -Recurse
  }
  Move-Item -Path $PSScriptRoot\$ExtractName -Destination $TargetPath -Force
  If (Test-Path $ReleaseFile) { 
    Debug "Cleanup $ReleaseFile"
    Remove-Item $ReleaseFile 
  }
}

# -----------------------------------------------------------------------------
Function Update-Appinfo-Item() {
  param(
    [string] $IniFile,
    [string] $Match,
    [string] $Replace
  )
  If (Test-Path $IniFile) {
    $Content = (Get-Content $IniFile)
    $Content -replace $Match, $Replace | Out-File -FilePath $IniFile
  }
}

# -----------------------------------------------------------------------------
Function Update-Appinfo() {
  $Version = (Fetch-Section "Version")
  Update-Appinfo-Item `
    -IniFile $AppInfoIni `
    -Match '^PackageVersion\s*=.*' `
    -Replace "PackageVersion=$($Version['Package'])"
  Update-Appinfo-Item `
    -IniFile $AppInfoIni `
    -Match '^DisplayVersion\s*=.*' `
    -Replace "DisplayVersion=$($Version['Display'])"
}

# -----------------------------------------------------------------------------
Function Update-Application() {
  $Archive = (Fetch-Section 'Archive')
  $Position = 1
  While ($True) {
    If (-Not ($Archive.ContainsKey("URL$Position"))) {
      Break
    } 
    Update-Release `
      -URL $Archive["URL$Position"] `
      -TargetName $Archive["TargetName$Position"] `
      -ExtractName $Archive["ExtractName$Position"] `
      -Checksum $Archive["Checksum$Position"]
    $Position += 1
  }
}

# -----------------------------------------------------------------------------
Function Windows-Path() {
  param( [string] $Path )
  $Path = $Path -replace ".*drive_(.)", '$1:'  
  $Path = $Path.Replace("/", "\") 
  return $Path
}

# -----------------------------------------------------------------------------
Function Create-Launcher() { 
  Set-Location $AppRoot
  $AppPath  = (Get-Location)
  $Launcher = "..\PortableApps.comLauncher\PortableApps.comLauncherGenerator.exe"
  If (Is-Unix) {
    Debug "Running Launcher: wine $Launcher $(Windows-Path $AppPath)"
    Invoke-Expression "wine $Launcher $(Windows-Path $AppPath)"
  }
  Else {
    Debug "Running Launcher: $Launcher AppPath"
    Invoke-Expression "$Launcher $AppPath"
    Write-FileSystemCache $AppPath.Drive.Name
  }
}

# -----------------------------------------------------------------------------
Function Create-Installer() { 
  Set-Location $AppRoot
  $AppPath   = (Get-Location)
  $Installer = "..\PortableApps.comInstaller\PortableApps.comInstaller.exe"
  If (Is-Unix) {
    Debug "Running Installer: wine $Installer $(Windows-Path $AppPath)"
    Invoke-Expression "wine $Installer $(Windows-Path $AppPath)"
  }
  Else {
    # Windows seems to need a bit of break before
    # writing the file completely to disk
    Debug "Sleeping ..."
    Sleep 5
    Debug "Running Installer: $Installer $AppPath"
    Invoke-Expression "$Installer $AppPath"
  }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
$Config = (Parse-Ini $UpdateIni)
Update-Application
Update-Appinfo
Create-Launcher
Create-Installer
