<#
Builds the per-user installer (wardkeep.iss) with Inno Setup.

  powershell -File installer\build-installer.ps1 -Version 0.1.0 -SourceDir dist\app -OutputDir dist
  powershell -File installer\build-installer.ps1 -Version 0.1.0 -SourceDir dist\app -OutputDir dist -Pfx cert.pfx

Writes <OutputDir>\wardkeep-<Version>-windows-x64-setup.exe. -Version is the name used in the file name
(0.1.0, 0.2.0-rc1, dev-abc1234); the numbers for Windows are taken from it (x.y.z, else 0.0.0).
-SourceDir is the Flutter release folder with omnitun-svc.exe next to omnitun.exe.

With -Pfx (and WINDOWS_CERT_PASSWORD in the environment) the setup file and its uninstaller are signed by
sign.ps1. Inno Setup 6 is taken from the usual places (the GitHub runners have it); if it is not there it is
installed with Chocolatey, which needs administrator rights, so do that by hand on your own PC.
#>
param(
  [Parameter(Mandatory)] [string] $Version,
  [Parameter(Mandatory)] [string] $SourceDir,
  [Parameter(Mandatory)] [string] $OutputDir,
  [string] $Pfx,
  [string] $MutexName
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-Iscc {
  @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
}
$iscc = Find-Iscc
if (-not $iscc -and (Get-Command choco -ErrorAction SilentlyContinue)) {
  choco install innosetup --version 6.7.1 --no-progress -y | Out-Host
  $iscc = Find-Iscc
}
if (-not $iscc) { throw 'Inno Setup 6 (ISCC.exe) not found: https://jrsoftware.org/isdl.php (the per-user install is enough)' }

$numbers = ($Version -split '-')[0]
if ($numbers -notmatch '^\d+\.\d+\.\d+$') { $numbers = '0.0.0' }

New-Item -ItemType Directory -Force $OutputDir | Out-Null
$iscArgs = @(
  (Join-Path $here 'wardkeep.iss'),
  "/DAppVersion=$numbers",
  "/DAppVersionName=$Version",
  "/DSourceDir=$((Resolve-Path $SourceDir).Path)",
  "/DOutputDir=$((Resolve-Path $OutputDir).Path)"
)
if ($MutexName) { $iscArgs += "/DMutexName=$MutexName" }
if ($Pfx) {
  $pfxPath = (Resolve-Path $Pfx).Path
  $sign = Join-Path $here 'sign.ps1'
  # Inno Setup puts the quoted file to sign where $f is and a double quote where $q is (quotes typed here
  # would reach it with backslashes in front of them from PowerShell 7).
  $iscArgs += '/DSigned'
  $iscArgs += '/Ssign=powershell.exe -NoProfile -ExecutionPolicy Bypass -File $q' + $sign + '$q -Pfx $q' + $pfxPath + '$q -Files $f'
}
& $iscc @iscArgs
if ($LASTEXITCODE -ne 0) { throw "ISCC failed (exit code $LASTEXITCODE)" }
$setup = Join-Path (Resolve-Path $OutputDir).Path "wardkeep-$Version-windows-x64-setup.exe"
if (-not (Test-Path $setup)) { throw "$setup was not written" }
Write-Host "built $setup"
