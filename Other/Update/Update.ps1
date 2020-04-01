# -----------------------------------------------------------------------------
# Description: Generic Update Script for PortableApps
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$Version        = "0.0.15-alpha"
$AppRoot        = $(Convert-Path "$PSScriptRoot\..\..")
$AppDir         = "$AppRoot\App"
$AppInfoDir     = "$AppDir\AppInfo"
$AppInfoIni     = "$AppInfoDir\appinfo.ini"
$UpdateIni      = "$AppInfoDir\update.ini"
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
        $This.Log("Skip comment line")
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
  [string] $AppRoot     = $(Convert-Path "$PSScriptRoot\..\..")
  [string] $DownloadDir = $(Fix-Path "$($This.AppRoot)\Download")

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
      return $(Fix-Path "$($This.DownloadDir)\$($This.TargetName)")
    }
    return $This.DownloadDir
  }

  [string] MoveFrom() {
    If ($This.ExtractName -eq "") {
      return $(Fix-Path "$($This.DownloadDir)\$($This.TargetName)")
    }
    return $(Fix-Path "$($This.DownloadDir)\$($This.ExtractName)")
  }

  [string] MoveTo() {
    return $(Fix-Path "$($This.AppRoot)\App\$($This.TargetName)")
  }

  [string] OutFile() {
    return $(Fix-Path "$($This.DownloadDir)\$($This.Basename())")
  }
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Debug() {
  param(
    [string] $Severity,
    [string] $Message
  )
  $Color = 'White'
  $Severity = $Severity.ToUpper()
  Switch ($Severity) {
    'INFO'  { $Color = 'Green';      break }
    'WARN'  { $Color = 'Yellow';     break }
    'ERROR' { $Color = 'DarkYellow'; break }
    'FATAL' { $Color = 'Red';        break }
    default { $Color = 'White';      break }
  }
  If (-Not($Debug)) { return }
  Write-Host "$(Get-Date -Format u) - " -NoNewline
  Write-Host $Severity": " -NoNewline -ForegroundColor $Color
  Write-Host $Message.Replace($(Fix-Path "$AppRoot\"), '')
}

# -----------------------------------------------------------------------------
Function Is-Unix() {
  ($PSScriptRoot)[0] -eq '/'
}

# -----------------------------------------------------------------------------
Function Which-7Zip() {
  $Locations = @(
    "$Env:ProgramFiles\7-Zip",
    "$Env:ProgramFiles(x86)\7-Zip",
    "$AppRoot\..\7-ZipPortable\App\7-Zip"
  )
  Switch (Is-Unix) {
    $True {
      $Prefix = 'wine'
      $Binary = '7z'
      break
    }
    default {
      $Prefix = ''
      $Binary = '7z.exe'
    }
  }
  Try {
    $Path = $(Get-Command $Binary).Source.ToString()
  }
  Catch {
    Foreach ($Location in $Locations) {
      If (Test-Path "$Location\$Binary") {
        $Path = "$Prefix $Location\$Binary"
      }
    }
  }
  Finally {
    If (!($Path)) {
      Debug fatal "Could not locate $Binary"
      Exit 76
    }
  }
  return $Path
}

# -----------------------------------------------------------------------------
Function Check-Sum {
  param(
    [object] $Download
  )
  ($Algorithm, $Sum) = $Download.Checksum.Split(':')
  $Result = (Get-FileHash -Path $Download.OutFile() -Algorithm $Algorithm).Hash
  Debug info "Checksum of INI ($($Sum.ToUpper())) and download ($Result)"
  return ($Sum.ToUpper() -eq $Result)
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
    Debug info "Download URL $($Download.URL) to $($Download.OutFile()).part"
    Invoke-WebRequest -Uri $Download.URL `
      -OutFile "$($Download.OutFile()).part"

    Debug info "Move file $($Download.OutFile).part to $($Download.OutFile())"
    Move-Item -Path "$($Download.OutFile()).part" `
      -Destination $Download.OutFile()
  }
  If (!(Check-Sum -Download $Download)) {
    Debug fatal "Checksum for $($Download.OutFile()) does not match '$Checksum'"
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
    '\.[Zz][Ii][Pp]$' {
      Expand-Download -Download $Download
      break
    }
    '\.7[Zz]\.[Ee][Xx][Ee]$' {
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
  Debug info `
    "Move release from $($Download.MoveFrom()) to $($Download.MoveTo())"
  Move-Item -Path $Download.MoveFrom() `
    -Destination $Download.MoveTo() `
    -Force
}

# -----------------------------------------------------------------------------
Function Update-Appinfo-Item() {
  param(
    [string] $IniFile,
    [string] $Match,
    [string] $Replace
  )
  $IniFile = $(Fix-Path $IniFile)
  If (Test-Path $IniFile) {
    Debug info "Update INI File $IniFile with $Match -> $Replace"
    $Content = (Get-Content $IniFile)
    $Content -replace $Match, $Replace | `
      Out-File -Encoding UTF8 -FilePath $IniFile
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
Function Postinstall() {
  $Postinstall = "$PSScriptRoot\Postinstall.ps1"
  If (Test-Path $Postinstall) {
    . $Postinstall
  }
}

# -----------------------------------------------------------------------------
Function Fix-Path() {
  # Convert Path only Works on Existing Directories :(
  param( [string] $Path )
  Switch (Is-Unix) {
    $True { 
      $From = '\'
      $To   = '/'
      break;
    }
    default {
      $From = '/'
      $To   = '\'
    }
  }
  $Path = $Path.Replace($From, $To)
  return $Path
}

# -----------------------------------------------------------------------------
Function Windows-Path() {
  param( [string] $Path )
  If (!(Is-Unix)) { return $Path }
  $WinPath = $(Invoke-Expression "winepath --windows $Path")
  return $WinPath
}

# -----------------------------------------------------------------------------
Function Create-Launcher() {
  Set-Location $AppRoot
  $AppPath  = (Get-Location)
  Try {
    Invoke-Helper -Command `
      "..\PortableApps.comLauncher\PortableApps.comLauncherGenerator.exe"
  }
  Catch {
    Debug fatal "Unable to create PortableApps Launcher"
    Exit 21
  }
}

# -----------------------------------------------------------------------------
Function Create-Installer() {
  Try {
    Invoke-Helper -Sleep 5 -Timeout 300 -Command `
      "..\PortableApps.comInstaller\PortableApps.comInstaller.exe"
  }
  Catch {
    Debug fatal "Unable to create installer for PortableApps"
    Debug fatal $_
    Exit 42
  }
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

  Switch (Is-Unix) {
    $True   { $Prefix = "timeout $Timeout wine"; break }
    default { $Prefix = '' }
  }

  If ($Sleep) {
    Debug info "Waiting for filsystem cache to catch up"
    Start-Sleep $Sleep
  }

  Debug info "Run PA Command $Prefix $Command $(Windows-Path $AppPath)"
  Invoke-Expression "$Prefix $Command $(Windows-Path $AppPath)"
  If (!(Is-Unix)) { 
    Wait-Process -Name $(Get-Item $Command).Basename -Timeout $Timeout
  }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
$Config = [IniConfig]::new($UpdateIni)
Update-Application
Update-Appinfo
Postinstall
Create-Launcher
Create-Installer
