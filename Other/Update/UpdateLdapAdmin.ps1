$AppRoot        = "$PSScriptRoot\..\.."
$AppInfoIni     = "$AppRoot\App\AppInfo\appinfo.ini"
$PackageVersion = '1.8.3.0'
$DisplayVersion = '1.8.3-beta0-uroesch'
$ZipVersion     = '1.8.3'
$Archive64URL   = "https://netcologne.dl.sourceforge.net/project/ldapadmin/ldapadmin/$ZipVersion/LdapAdminExe-w32-$ZipVersion.zip"
$TargetDir64    = 'LdapAdmin64.exe'
$ExtractDir64   = 'LdapAdmin.exe'
$Archive32URL   = "https://netcologne.dl.sourceforge.net/project/ldapadmin/ldapadmin/$ZipVersion/LdapAdminExe-w32-$ZipVersion.zip"
$TargetDir32    = 'LdapAdmin32.exe'
$ExtractDir32   = 'LdapAdmin.exe'

Function Url-Basename {
  param(
    [string] $URL
  )
  $Elements = $URL.split('/')
  $Basename = $Elements[$($Elements.Length-1)]
  return $Basename
}

Function Download-ZIP { 
  param(
    [string] $URL
  )
  $PathZip = "$PSScriptRoot\$(Url-Basename -URL $URL)"
  If (!(Test-Path $PathZip)) {
    Invoke-WebRequest -Uri $URL -OutFile $PathZip
  }
  return $PathZip
}

Function Update-Zip {
  param(
    [string] $URL,
    [string] $TargetDir,
    [string] $ExtractDir
  )
  $ZipFile    = $(Download-ZIP -URL $URL)
  $TargetPath = "$AppRoot\App\$TargetDir"
  Expand-Archive -LiteralPath $ZipFile -DestinationPath $PSScriptRoot -Force
  If (Test-Path $TargetPath) {
    Write-Output "Removing $TargetPath"
    Remove-Item -Path $TargetPath -Force -Recurse
  }
  Move-Item -Path $PSScriptRoot\$ExtractDir -Destination $TargetPath -Force
  Remove-Item $ZipFile
}

Function Update-Appinfo() {
  param(
    [string] $IniFile,
	[string] $Match,
	[string] $Replace
  )
  If (Test-Path $IniFile) {
    $Content = (Get-Content $IniFile)
	$Content -replace $Match,$Replace | Out-File -FilePath $IniFile
  }
}

Update-ZIP -URL $Archive64URL -TargetDir $TargetDir64 -ExtractDir $ExtractDir64
Update-ZIP -URL $Archive32URL -TargetDir $TargetDir32 -ExtractDir $ExtractDir32
Update-Appinfo -IniFile $AppInfoIni -Match '^PackageVersion\s*=.*' -Replace "PackageVersion=$PackageVersion"
Update-Appinfo -IniFile $AppInfoIni -Match '^DisplayVersion\s*=.*' -Replace "DisplayVersion=$DisplayVersion"