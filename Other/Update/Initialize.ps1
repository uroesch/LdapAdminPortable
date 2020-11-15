#!/usr/bin/env pwsh

# -----------------------------------------------------------------------------
# Modules
# -----------------------------------------------------------------------------
Using module ".\PortableAppsCommon.psm1"


# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
$Version      = "0.0.1-alpha"
$Debug        = $True
$Files        = @(
  (Join-Path $AppRoot help.html)
  (Join-Path $AppRoot README.md)
  $AppInfoIni
  $UpdateIni
)

$Placeholders = @{
  AppName = @{
    Message = 'Application name e.g. "FooPortable"'
    Value   = ''
  }
  AppNameSpaced = @{
    Message = 'Application name with spaces e.g. "Foo Portable"'
    Value   = ''
  }
  UpstreamPublisher = @{
    Message = 'Publishers name e.g. "ACME Ltd."'
    Value   = ''
  }
  UpstreamUrl = @{
    Message = "Upstream project's URL. e.g. `"https://acme.ltd/foo`""
    Value   = ''
  }
  UpstreamName = @{
    Message = 'Upstream name e.g. "Foo"'
    Value   = ''
  }
  UpstreamDescription = @{
    Message = 'App description e.g. "Best app ever..."'
    Value   = ''
  }
  Category = @{
    Message = 'App category e.g. "Utilities"'
    Value   = 'Utilities'
  }
  Language = @{
    Message = 'Installer language e.g. "Multilingual"'
    Value   = 'Multilingual'
  }
  PackageVersion = @{
    Message = 'Package version 4 digits delimited by dot e.g. "1.2.3.0"'
    Value   = ''
  }
  DisplayVersion = @{
    Message = 'Display version e.g. "1.2.3-beta1-uroesch"'
    Value   = ''
  }
  UpstreamVersion = @{
    Message = 'Upstream version e.g. "1.2.3"'
    Value   = ''
  }
  AppProjectUrl = @{
    Message = 'App project URL e.g. "https://github.com/uroesch/FooPortable"'
    Value   = ''
  }
  GitHubUser = @{
    Message = 'GitHubUser e.g. "uroesch"'
    Value   = ''
  }
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Function Assign-Placeholder() {
  Param(
    [String] $Key,
    [String] $Value
  )
  Try {
    $Placeholders[$Key]['Value'] = $Value
    Debug info "Placeholder '$Key' set to '$Value'"
  }
  Catch {
    Debug Error "Failed to assign placeholder '$Key' to '$Value'"
    Error 124
  }
}

Function Replace-Placeholder() {
  Param(
    [String] $Key,
    [String] $Content
  )
  $Pattern = "{{ $Key }}"
  $Value   = $Placeholders[$Key].Value
  If ($Content -match $Pattern) {
    $Content = $Content -replace $Pattern, $Value
    Debug info "Replace '$Pattern' with '$Value'"
  }
  $Content
}

Function Replace-Placeholders() {
  Foreach ($Path in $Files) {
    $Content = Get-Content -Path $Path -Raw
    $Placeholders.Keys | ForEach {
      If ($Placeholders[$_].Value -ne "") {
        $Content = Replace-Placeholder -Key $_ -Content $Content
      }
    }
    Set-Content -Value $Content -Path $Path -Encoding utf-8
  }
}


Function Check-Initial() {
  If ($AppName -notmatch 'Portable$') {
    Debug error "App directory '$AppName' does not end with 'Portable'"
    Exit 123
  }
  $AppNameSpaced = $AppName -replace "Portable$", " Portable"
  $UpstreamName  = $AppName -replace "Portable$", ""
  Assign-Placeholder -Key AppName -Value $AppName
  Assign-Placeholder -Key AppNameSpaced -Value $AppNameSpaced
  Assign-Placeholder -Key UpstreamName -Value $UpstreamName
}

Function Rename-Launcher() {
  $DefaultLauncher = Join-Path $LauncherDir Rename-to-AppName.ini
  If (Test-Path $DefaultLauncher) {
    Debug info "Rename '$DefaultLauncher' to '$LauncherIni'"
    Move-Item -Path $DefaultLauncher -Destination $LauncherIni
  }
}

Function Query-GitOrigin() {
  $Origin = git config --get remote.origin.url
  If ($Origin -match '^http') {
    # extract the project url
    $Origin = $Origin -replace ".git$", ""
    Assign-Placeholder -Key AppProjectUrl -Value $Origin
    # extract github user
    $GitHubUser = $Origin -replace "/$AppName$", "" -replace ".*/", ""
    Assign-Placeholder -Key GitHubUser -Value $GitHubUser
  }
}

Function Ask-Question() {
  Param(
    [String] $Key
  )
  $Value  = $Placeholders[$Key].Value
  $Prompt = "`nPlaceholer {0} {1}`nDefault [{2}]" -f `
    $Key, $Placeholders[$Key].Message, $Value
  $Result = Read-Host -Prompt $Prompt
  $Result = $Result.Trim()
  If ($Result -ne '') {
    Assign-Placeholder -Key $Key -Value $Result
    Return
  }
  ElseIf ($Value -ne '' -and $Result -eq '') {
    Return
  }
  ElseIf ($Value -eq '' -and $Result -eq '') {
    Ask-Question -Key $Key
  }
}

Function Questionaire() {
  $Placeholders.Keys | Sort-Object | %{
     Ask-Question -Key $_
  }
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
Check-Initial
Rename-Launcher
Query-GitOrigin
Questionaire
Replace-Placeholders
