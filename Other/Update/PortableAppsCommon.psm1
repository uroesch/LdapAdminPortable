# -----------------------------------------------------------------------------
# Description: Common classes and functions for portable apps powershell
#   scripts
# Author: Urs Roesch <github@bun.ch>
# Version: 0.7.2
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$AppRoot         = $(Convert-Path "$PSScriptRoot\..\..")
$AppName         = (Get-Item $AppRoot).Basename
$AppDir          = Join-Path $AppRoot App
$DownloadDir     = Join-Path $AppRoot Download
$AppInfoDir      = Join-Path $AppDir AppInfo
$LauncherDir     = Join-Path $AppInfoDir Launcher
$AppInfoIni      = Join-Path $AppInfoDir appinfo.ini
$UpdateIni       = Join-Path $AppInfoDir update.ini
$LauncherIni     = Join-Path $LauncherDir "$AppName.ini"
$InfraDirDefault = $(Convert-Path "$AppRoot\..")

# -----------------------------------------------------------------------------
# Classes
# -----------------------------------------------------------------------------
Class ReadIniConfig {
  [string] $File
  [object] $Struct
  [bool]   $Verbose = $False
  [bool]   $Parsed  = $False

  ReadIniConfig(
    [string] $f
  ) {
    $This.File = $f
  }

  [void] Parse() {
    If ($this.Parsed) { return }
    $Content  = Get-Content $This.File
    $Section  = ''
    $This.Struct = @{}
    Foreach ($Line in $Content) {
      Switch -regex ($Line) {
        "^\s*;" {
          Continue
        }
        "^\s*\[" {
          $Section = $Line -replace "[\[\]]", ""
          $This.Struct.Add($Section.Trim(), @{})
        }
        ".*=.*" {
          ($Name, $Value) = $Line.split("=")
          $This.Struct[$Section] += @{ $Name.Trim() = $Value.Trim() }
        }
      }
    }
    $This.Parsed = $True
  }

  [object] Section([string] $Key) {
    $This.Parse()
    $Section = @{}
    Return $This.Struct[$Key]
  }
}

# -----------------------------------------------------------------------------
Class Download {
  [string] $URL
  [string] $ExtractName
  [string] $TargetName
  [string] $Checksum
  [string] $AppRoot     = $(Convert-Path "$PSScriptRoot\..\..")
  [string] $DownloadDir = $(Switch-Path "$($This.AppRoot)\Download")

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
    $Elements = ($This.URL.split('?'))[0].split('/')
    $Basename = $Elements[$($Elements.Length-1)]
    return $Basename
  }

  [string] ExtractTo() {
    # If Extract name is empty the downloaded archive has all files
    # placed in the root of the archive. In that case we use the
    # TargetName and and attach it to the script location
    If ($This.ExtractName -eq "") {
      return $(Switch-Path "$($This.DownloadDir)\$($This.TargetName)")
    }
    return $This.DownloadDir
  }

  [string] MoveFrom() {
    If ($This.ExtractName -eq "") {
      return $(Switch-Path "$($This.DownloadDir)\$($This.TargetName)")
    }
    return $(Switch-Path "$($This.DownloadDir)\$($This.ExtractName)")
  }

  [string] MoveTo() {
    return $(Switch-Path "$($This.AppRoot)\App\$($This.TargetName)")
  }

  [string] OutFile() {
    return $(Switch-Path "$($This.DownloadDir)\$($This.Basename())")
  }
}

# -----------------------------------------------------------------------------
# Function
# -----------------------------------------------------------------------------
Function Read-IniFile {
  param(
    [string] $IniFile
  )
  Return [ReadIniConfig]::new($IniFile)
}


# -----------------------------------------------------------------------------
Function Test-Unix() {
  ($PSScriptRoot)[0] -eq '/'
}

# -----------------------------------------------------------------------------
Function ConvertTo-WindowsPath() {
  param( [string] $Path )
  If (!(Test-Unix)) { return $Path }
  $WinPath = & winepath --windows $Path 2>/dev/null
  Return $WinPath
}

# -----------------------------------------------------------------------------
Function Switch-Path() {
  # Convert Path only Works on Existing Directories :(
  Param( [string] $Path )
  Switch (Test-Unix) {
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
  Return $Path
}

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
  Write-Host $Message.Replace($(Switch-Path "$AppRoot\"), '')
}

# -----------------------------------------------------------------------------
Function Download-Checksum() {
  Param(
    [String] $Uri
  )
  Try {
    $Sum = (Invoke-WebRequest -Uri $Uri -OutFile $OutFile).Content
    $Sum = $Sum.Trim() -replace "([A-Fa-f0-9]{32,}).*", "`$1"
    Debug debug "Downloaded checksum: $Sum"
    Return $Sum
  }
  Catch {
    Debug error "Unable to download checksum from URL '$Uri'"
    Exit 124
  }
}

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
Function Compare-Checksum {
  param(
    [string] $Path,
    [string] $Checksum
  )

  Debug debug "Compare-Checksum -> -Path $Path -Checksum $Checksum"
  # The somewhat involved split is here to make it compatible with win10
  ($Algorithm, $Sum) = ($Checksum -replace '::', "`n").Split("`n")
  If ($Sum -like 'http*') {
    $Sum = Download-Checksum -Uri $Sum
    $Checksum = $Algorithm + "::" + $Sum
    Debug debug "Checksum from download: $Checksum"
  }
  Debug debug "Get-Checksum -Path $Path -Algorithm $Algorithm"
  $Result = Get-Checksum -Path $Path -Algorithm $Algorithm
  Debug info "Checksum of INI ($($Checksum.ToUpper())) and download ($Result)"
  Return ($Checksum.ToUpper() -eq $Result)
}

# -----------------------------------------------------------------------------
Function Get-Checksum {
  Param(
    [string] $Path,
    [string] $Algorithm
  )
  Debug debug "Get-FileHash -Path $Path -Algorithm $Algorithm"
  $Hash = (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash
  Return ($Algorithm + "::" + $Hash).ToUpper()
}

# -----------------------------------------------------------------------------
Function Update-Checksum {
  Param(
    [string] $Path,
    [string] $Checksum
  )
  Debug debug "Update-Checksum -> -Path $Path -Checksum $Checksum"
  ($Algorithm, $Sum) = ($Checksum -replace '::', "`n").Split("`n")
  If ($Sum -like 'http*') { Return $Checksum }
  Debug debug "Get-Checksum -Path $Path -Algorithm $Algorithm"
  $NewChecksum = Get-Checksum -Path $Path -Algorithm $Algorithm
  Get-Content -Path $UpdateIni | `
    Foreach-Object { $_ -Replace $Checksum, $NewChecksum } | `
    Set-Content -Path $UpdateIni
  Return $NewChecksum
}

# -----------------------------------------------------------------------------
# Export
# -----------------------------------------------------------------------------
Export-ModuleMember -Function Read-IniFile
Export-ModuleMember -Function Test-Unix
Export-ModuleMember -Function ConvertTo-WindowsPath
Export-ModuleMember -Function Switch-Path
Export-ModuleMember -Function Compare-Checksum
Export-ModuleMember -Function Get-Checksum
Export-ModuleMember -Function Update-Checksum
Export-ModuleMember -Function Debug
Export-ModuleMember -Variable AppRoot
Export-ModuleMember -Variable AppName
Export-ModuleMember -Variable AppDir
Export-ModuleMember -Variable DownloadDir
Export-ModuleMember -Variable AppInfoDir
Export-ModuleMember -Variable LauncherDir
Export-ModuleMember -Variable AppInfoIni
Export-ModuleMember -Variable UpdateIni
Export-ModuleMember -Variable LauncherIni
Export-ModuleMember -Variable InfraDirDefault
