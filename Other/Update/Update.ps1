# -----------------------------------------------------------------------------
# Description: Generic Update Script for PortableApps 
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Globals 
# -----------------------------------------------------------------------------
$Version        = "0.0.6-alpha"
$AppRoot        = "$PSScriptRoot\..\.."
$AppInfoDir     = "$AppRoot\App\AppInfo"
$AppInfoIni     = "$AppInfoDir\appinfo.ini"
$UpdateIni      = "$AppInfoDir\update.ini"
$ExtractPath    = '__Extract__'
$Debug          = $True

# -----------------------------------------------------------------------------
# Classes
# -----------------------------------------------------------------------------
Class IniConfig {
  [string] $File
  [object] $Table
  [bool]   $Verbose = $False
  [bool]   $Parsed  = $False

  IniConfig(
    [string] $f
  ) { 
    $This.File = $f
  }

  [void] Log([string] $Message) {
    If ($This.Verbose) {
      Write-Host "IniConfig: $Message"
    }
  }

  [void] Parse() {
    If ($this.Parsed) { return }
    $Content  = Get-Content $This.File
    $Section  = ''
    $This.Log($Content)
    $This.Table = @()
    Foreach ($Line in $Content) {
      $This.Log("Processing '$Line'")
      If ($Line[0] -eq ";") {
        Debug("Skip comment line")
      }
      ElseIf ($Line[0] -eq "[") {
        $Section = $Line -replace "[\[\]]", ""
        $This.Log("Found new section: '$Section'")
      }
      ElseIf ($Line -like "*=*") {
        $This.Log("Found Keyline")
        $This.Table += @{
          Section  = $Section
          Key      = $Line.split("=")[0].Trim()
          Value    = $Line.split("=")[1].Trim()
        }
      }
    }
    $This.Parsed = $True
  }

  [object] Section([string] $Key) {
    $This.Parse()
    $Section = @{}
    Foreach ($Item in $This.Table) { 
      If ($Item["Section"] -eq $Key) {
        $Section += @{ $Item["Key"] = $Item["Value"] }
      }
    }
    return $Section
  }
}
# -----------------------------------------------------------------------------
Class Download {
  [string] $URL
  [string] $ExtractName
  [string] $TargetName
  [string] $Checksum

  Download(
    [string] $u,
    [string] $en,
    [string] $tn,
    [string] $c
  ){
    $This.URL         = $u
    $This.ExtractName = $en
    $This.TargetName  = $tn
    $This.Checksum    = $c
  }

  [string] Basename() {
    $Elements = $This.URL.split('/')
    $Basename = $Elements[$($Elements.Length-1)]
    return $Basename
  }

  [string] ExtractTo() { 
    # If Extract name is empty the downloaded archive has all files 
    # placed in the root of the archive. In that case we use the
    # TargetName and and attach it to the script location
    If ($This.ExtractName -eq "") {
      return "$PSScriptRoot\$($This.TargetName)" 
    }
    return "$PSScriptRoot"
  }

  [string] MoveFrom() {
    If ($This.ExtractName -eq "") {
      return "$PSScriptRoot\$($This.TargetName)" 
    }
    return "$PSScriptRoot\$($This.ExtractName)"
  }

  [string] MoveTo() {
    return "$PSScriptRoot\..\..\App\$($This.TargetName)"
  }

  [string] OutFile() {
    return "$PSScriptRoot\$($This.Basename())" 
  }
}

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
Function Check-Sum {
  param(
    [object] $Download
  )
  ($Algorithm, $Sum) = $Download.Checksum.Split(':')
  $Result = (Get-FileHash -Path $Download.OutFile() -Algorithm $Algorithm).Hash
  Debug "Checksum of INI ($Sum) and downloaded file ($Result)"
  return ($Sum -eq $Result)
}

# -----------------------------------------------------------------------------
Function Download-File {
  param(
    [object] $Download
  )
  If (!(Test-Path $Download.OutFile())) {
    Debug "Downloading file from '$($Download.URL)"
    Invoke-WebRequest -Uri $Download.URL `
      -OutFile "$($Download.OutFile()).part"
    Move-Item -Path "$($Download.OutFile()).part" `
      -Destination $Download.OutFile() 
  }
  If (!(Check-Sum -Download $Download)) {
    Debug "Checksum of File $DownloadPath does not match with '$Checksum'"
    Exit 1
  }
  Debug "Downloaded file '$($Download.OutFile())'"
}

# -----------------------------------------------------------------------------
Function Expand-Download {
  param(
    [object] $Download
  )
  If (!(Test-Path $Download.ExtractTo())) {
    New-Item -Path $Download.ExtractTo() -Type "directory" 
  }
  Expand-Archive -LiteralPath $Download.OutFile() `
    -DestinationPath $Download.ExtractTo() -Force
}

# -----------------------------------------------------------------------------
Function Update-Release {
  param(
    [object] $Download
  )
  Switch -regex ($Download.Basename()) {
    '\.[Zz][Ii][Pp]$' {
      Expand-Download -Download $Download
      break 
    }
  }
  If (Test-Path $Download.MoveTo()) {
    Debug "Removing $($Download.MoveTo())"
    Remove-Item -Path $Download.MoveTo() `
      -Force `
      -Recurse
  }
  Move-Item -Path $Download.MoveFrom() `
    -Destination $Download.MoveTo() `
    -Force
  #If (Test-Path $Download.OutFile()) {
  #  Debug "Cleanup $($Download.OutFile())"
  #  Remove-Item $Download.OutFile()
  #}
}

# -----------------------------------------------------------------------------
Function Update-Appinfo-Item() {
  param(
    [string] $IniFile,
    [string] $Match,
    [string] $Replace
  )
  If (Test-Path $IniFile) {
    Debug "Updating INI File $IniFile with $Match -> $Replace" 
    $Content = (Get-Content $IniFile)
    $Content -replace $Match, $Replace | Out-File -FilePath $IniFile
  }
}

# -----------------------------------------------------------------------------
Function Update-Appinfo() {
  $Version = $Config.Section("Version")
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
  $Archive = $Config.Section('Archive')
  $Position = 1
  While ($True) {
    If (-Not ($Archive.ContainsKey("URL$Position"))) {
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
$Config = [IniConfig]::new($UpdateIni)
Update-Application
Update-Appinfo
Create-Launcher
Create-Installer
