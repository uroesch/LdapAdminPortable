# -----------------------------------------------------------------------------
# Description: Module to read INI files
# Author: Urs Roesch <github@bun.ch>
# Version: 0.3.0
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
    Return $This.Struct[$Key]
  }

  [Void] Dump() {
    Write-Host $This.FormatIni(4)
  }

  [Void] InsertSection([String] $Section) {
    $This.InsertSection($Section, [Ordered]@{})
  }

  [Void] InsertSection([String] $Section, [Object] $Config) {
    $This.Struct.Insert(0, $Section.Trim(), $Config)
  }

  [Void] AddSection([String] $Section) {
    $This.AddSection($Section.Trim(), [Ordered]@{})
  }

  [Void] AddSection([String] $Section, [Object] $Config) {
    $This.Struct.Add($Section.Trim(), $Config)
  }

  [Void] RemoveSection([String] $Section) {
    $This.Struct.Remove($Section.Trim())
  }
}

Class WriteIniConfig : IniConfig {
  WriteIniConfig([String] $f) {
    $This.Init($f, [Ordered]@{})
  }

  WriteIniConfig([String] $f, [Object] $s) {
    $This.Init($f, $s)
  }

  [Void] Init([String] $File, [Object] $Struct) {
    $This.File   = $File
    $This.Struct = $Struct
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
    $This.Struct = [Ordered]@{}
    Foreach ($Line in $Content) {
      Switch -regex ($Line) {
        "^\s*;" {
          Continue
        }
        "^\s*\[" {
          $Section = $Line -replace "[\[\]]", ""
          $This.AddSection($Section)
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
    [Parameter(Mandatory)]
    [String] $IniFile
  )
  Return [ReadIniConfig]::new($IniFile)
}

Function Write-IniFile {
  param(
    [Parameter(Mandatory)]
    [String] $IniFile,
    [Object] $Struct = [Ordered]@{}
  )
  Return [WriteIniConfig]::new($IniFile, $Struct)
}

# -----------------------------------------------------------------------------
# Export
# -----------------------------------------------------------------------------
Export-ModuleMember -Function Read-IniFile
Export-ModuleMember -Function Write-IniFile
