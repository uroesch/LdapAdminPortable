# -----------------------------------------------------------------------------
# Description: Module to read INI files
# Author: Urs Roesch <github@bun.ch>
# Version: 0.1.0
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Classes
# -----------------------------------------------------------------------------
Class IniConfig {
  [String] $File
  [Object] $Struct
  [Bool]   $Verbose    = $False

  [String] FormatIni([Int] $Indent = 0) {
    $Config = @()
    ForEach ($Section in $This.Sections()) {
      If ($Config.Length -gt 0) { $Config += "" }
      $Config += "[$Section]"
      $Items  = $This.Section($Section)
      $Length = $This.LongestItem($Items.Keys)
      ForEach ($Item in $Items.Keys) {
        $Config += "{0,$Indent}{1,-$Length} = {2}" -f "", $Item, $Items[$Item]
      }
    }
    Return $Config -Join "`n"
  }

  [Object] Sections() {
    Return $This.Struct.Keys
  }

  [Int] LongestItem([Array] $Items) {
    $Length = 0
    $Items | ForEach-Object {
      If ($_.Length -gt $Length) {
        $Length = $_.Length
      }
    }
    Return $Length
  }

  [Object] Section([String] $Key) {
    $Section = @{}
    Return $This.Struct[$Key]
  }

  [Void] Dump() {
    Write-Host $This.FormatIni(4)
  }
}

Class WriteIniConfig : IniConfig {
  WriteIniConfig(
    [String] $f,
    [Object] $c
  ) {
    $This.File   = $f
    $This.Struct = $c
  }

  [Void] Commit() {
    $Content = $This.FormatIni(0)
    try {
      Set-Content -Path $This.File -Value $Content
    }
    catch {
      Write-Host $_
    }
  }
}

Class ReadIniConfig : IniConfig {
  [Bool] $Parsed = $False

  ReadIniConfig(
    [String] $f
  ) {
    $This.File = $f
    $This.Parse()
  }

  [Void] Parse() {
    If ($This.Parsed) { return }
    $Content = Get-Content $This.File
    $Section = ''
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
}
# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Read-IniFile {
  param(
    [String] $IniFile
  )
  Return [ReadIniConfig]::new($IniFile)
}

Function Write-IniFile {
  param(
    [String] $IniFile,
    [Object] $Struct
  )
  Return [WriteIniConfig]::new($IniFile, $Struct)
}

# -----------------------------------------------------------------------------
# Export
# -----------------------------------------------------------------------------
Export-ModuleMember -Function Read-IniFile
Export-ModuleMember -Function Write-IniFile
