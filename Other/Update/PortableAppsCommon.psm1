# -----------------------------------------------------------------------------
# Description: Common classes and functions for portable apps powershell
#   scripts
# Author: Urs Roesch <github@bun.ch>
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$AppRoot        = $(Convert-Path "$PSScriptRoot\..\..")
$AppName        = (Get-Item $AppRoot).Basename
$AppDir         = "$AppRoot\App"
$DownloadDir    = "$AppRoot\Download"
$AppInfoDir     = "$AppDir\AppInfo"
$AppInfoIni     = "$AppInfoDir\appinfo.ini"
$UpdateIni      = "$AppInfoDir\update.ini"

# -----------------------------------------------------------------------------
# Classes
# -----------------------------------------------------------------------------
Class ReadIniConfig {
  [string] $File
  [object] $Table
  [bool]   $Verbose = $False
  [bool]   $Parsed  = $False

  ReadIniConfig(
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
    $Elements = $This.URL.split('/')
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
  $WinPath = $(Invoke-Expression "winepath --windows $Path")
  Return $WinPath
}

# -----------------------------------------------------------------------------
Function Switch-Path() {
  # Convert Path only Works on Existing Directories :(
  param( [string] $Path )
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
    $OutFile = $DownloadDir + "\" + ($Uri.split('/'))[-1]
    Invoke-WebRequest `
      -Uri $Uri `
      -OutFile $OutFile
   $Sum = (Get-Content -Path $OutFile)
   Return $Sum
  }
  Catch {
    Debug error "Unable to download checksum from URL '$Uri'"
    Exit 124
  }
}

# -----------------------------------------------------------------------------
Function Compare-Checksum {
  param(
    [string] $Path,
    [string] $Checksum
  )

  ($Algorithm, $Sum) = $Checksum.Split('::')
  If ($Sum -like 'http*') {
    $Sum = Download-Checksum -Uri $Sum
    $Checksum = $Algorithm + "::" + $Sum
  }
  $Result = Get-Checksum -Path $Path -Algorithm $Algorithm
  Debug info "Checksum of INI ($($Checksum.ToUpper())) and download ($Result)"
  return ($Checksum.ToUpper() -eq $Result)
}

# -----------------------------------------------------------------------------
Function Get-Checksum {
  Param(
    [string] $Path,
    [string] $Algorithm
  )
  $Hash = (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash
  Return ($Algorithm + "::" + $Hash).ToUpper()
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
Export-ModuleMember -Function Debug
Export-ModuleMember -Variable AppRoot
Export-ModuleMember -Variable AppName
Export-ModuleMember -Variable AppDir
Export-ModuleMember -Variable AppInfoDir
Export-ModuleMember -Variable AppInfoIni
Export-ModuleMember -Variable UpdateIni
