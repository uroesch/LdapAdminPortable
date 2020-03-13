# -----------------------------------------------------------------------------
# Description: Generic Update Script for PortableApps 
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Globals 
# -----------------------------------------------------------------------------
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

  $IniContent = Get-Content $IniFile

  $resulttable=@()
  foreach ($line in $IniContent) {
     Debug "Processing $line"
     if ($line[0] -eq ";") {
       Debug "Skip comment line"
     }

     elseif ($line[0] -eq "[") {
       $Section = $line.replace("[","").replace("]","")
       Debug "Found new section: $Section"
     }
     elseif ($line -like "*=*") {
       Debug "Found Keyline"
         $resulttable += @{
           Section  = $Section
           Key      = $line.split("=")[0].Trim()
           Value    = $line.split("=")[1].Trim()
         }
        }
        else {
          Debug "Skip line"
        }
  }
  return $resulttable
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
Function Download-ZIP { 
  param(
    [string] $URL,
    [string] $Checksum
  )
  $PathZip = "$PSScriptRoot\$(Url-Basename -URL $URL)"
  If (!(Test-Path $PathZip)) {
    Debug "Downloading file from '$URL'"
    Invoke-WebRequest -Uri $URL -OutFile $PathZip
  }
  If (!(Check-Sum -Checksum $Checksum -File $PathZip)) {
    Debug "Checksum of File $PathZip does not match with '$Checksum'"
    Exit 1
  }
  Debug "Downloaded ZIP file '$PathZip'"
  return $PathZip
}

# -----------------------------------------------------------------------------
Function Update-Zip {
  param(
    [string] $URL,
    [string] $TargetDir,
    [string] $ExtractDir,
    [string] $Checksum
  )
  $ZipFile    = $(Download-ZIP -URL $URL -Checksum $Checksum)
  $TargetPath = "$AppRoot\App\$TargetDir"
  Expand-Archive -LiteralPath $ZipFile -DestinationPath $PSScriptRoot -Force
  If (Test-Path $TargetPath) {
    Write-Output "Removing $TargetPath"
    Remove-Item -Path $TargetPath -Force -Recurse
  }
  Debug "Move $ExtractDir to $TargetPath"
  Move-Item -Path $PSScriptRoot\$ExtractDir -Destination $TargetPath -Force
  Debug "Cleanup $ZipFile"
  Remove-Item $ZipFile
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
    Update-ZIP `
      -URL $Archive["URL$Position"] `
      -TargetDir $Archive["TargetDir$Position"] `
      -ExtractDir $Archive["ExtractDir$Position"] `
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
