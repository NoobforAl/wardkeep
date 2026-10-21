<#
Tries the installer: installs it silently into a folder of your choice, checks the files and the registry
entries, uninstalls it silently and checks that everything is gone again. Everything is per-user (no
administrator rights); the registry entries are the ones listed in wardkeep.iss.

  powershell -File installer\test-installer.ps1 -Setup dist\wardkeep-0.1.0-windows-x64-setup.exe -Dir C:\scratch\wardkeep

The links Wardkeep claims (vless://, ...) are claimed for real while it is installed, so the script refuses
to run if one of them is already registered for you or a Run entry named Wardkeep exists (it would
overwrite it), unless -AllowExisting. The servers-and-settings folder is only touched with
-DeleteDataCheck, which also needs the CI environment variable: it would delete the real data of
whoever runs it.
#>
param(
  [Parameter(Mandatory)] [string] $Setup,
  [Parameter(Mandatory)] [string] $Dir,
  [switch] $AllowExisting,
  [switch] $DeleteDataCheck
)
$ErrorActionPreference = 'Stop'

$appId = '8F3A5C2E-6B1D-4E7A-9C40-2D5B7E9A1F36'
$schemes = 'vless', 'vmess', 'trojan', 'ss', 'hysteria2', 'hy2', 'hysteria', 'tuic', 'wireguard', 'awg', 'anytls', 'sstp', 'ikev2', 'nordvpn', 'naive+https', 'wardkeep'
$extensions = '.ovpn', '.conf', '.json', '.yaml', '.yml', '.txt'
$classes = 'HKCU:\Software\Classes'
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{$appId}_is1"
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Wardkeep.lnk'
$roaming = $env:APPDATA

$failures = @()
function Check([bool] $ok, [string] $what) {
  if ($ok) { Write-Host "  ok    $what" } else { Write-Host "  FAIL  $what"; $script:failures += $what }
}

if ($DeleteDataCheck -and -not $env:CI) { throw '-DeleteDataCheck deletes the data folders of the current user: only with the CI environment variable set.' }
$Setup = (Resolve-Path $Setup).Path
$Dir = [System.IO.Path]::GetFullPath($Dir)
if (Test-Path $Dir) { throw "$Dir exists already: give an empty or new folder" }

if (-not $AllowExisting) {
  $taken = @($schemes | Where-Object { Test-Path "$classes\$_" }) + @(if (Test-Path "$classes\Wardkeep.Config") { 'Wardkeep.Config' })
  if ($taken) { throw "already registered for this user, not touching them: $($taken -join ', ') (use -AllowExisting to go on)" }
  if ((Get-ItemProperty $run -ErrorAction SilentlyContinue).PSObject.Properties.Name -contains 'Wardkeep') { throw 'a Run entry named Wardkeep exists' }
  if (Test-Path $uninstallKey) { throw 'Wardkeep is already installed (by this installer)' }
}

# what other programs registered for the same file types: it has to be the same after the uninstall
function OpenWith([string] $ext) {
  $k = "$classes\$ext\OpenWithProgids"
  if (Test-Path $k) { (Get-Item $k).GetValueNames() | Where-Object { $_ -ne 'Wardkeep.Config' } | Sort-Object } else { @() }
}
$before = @{}
$keyExisted = @{}
foreach ($e in $extensions) { $before[$e] = @(OpenWith $e) -join '|'; $keyExisted[$e] = Test-Path "$classes\$e" }
$dataBefore = @{}
foreach ($d in "$roaming\dev.omnitun", "$roaming\omnitun") {
  $dataBefore[$d] = if (Test-Path $d) { (Get-ChildItem $d -Recurse -File | ForEach-Object { $_.FullName } | Sort-Object) -join "`n" } else { $null }
}
if ($DeleteDataCheck) {
  New-Item -ItemType Directory -Force "$roaming\dev.omnitun\omnitun" | Out-Null
  Set-Content "$roaming\dev.omnitun\omnitun\omnitun.json" '{}'
}

Write-Host "install into $Dir"
$log = Join-Path ([System.IO.Path]::GetTempPath()) "wardkeep-setup-$PID.log"
$p = Start-Process $Setup -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$Dir`" /TASKS=`"links,startup,desktopicon`" /LOG=`"$log`"" -Wait -PassThru
Check ($p.ExitCode -eq 0) "setup exits with 0 (was $($p.ExitCode))"

foreach ($f in 'omnitun.exe', 'omnitun-svc.exe', 'flutter_windows.dll', 'LICENSE.txt', 'unins000.exe', 'data\app.so', 'data\icudtl.dat', 'data\flutter_assets\assets\tray.ico') {
  if ($f -eq 'data\app.so' -and -not (Test-Path (Join-Path $Dir $f))) { continue } # not in every build mode
  Check (Test-Path (Join-Path $Dir $f)) "installed: $f"
}
Check (Test-Path $startMenu) 'Start menu shortcut'
Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Wardkeep.lnk')) 'desktop shortcut (task)'
$exe = Join-Path $Dir 'omnitun.exe'
foreach ($s in $schemes) {
  $cmd = (Get-ItemProperty "$classes\$s\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
  Check ($cmd -eq "`"$exe`" `"%1`"") "link $s`:// opens $exe"
  Check ($null -ne (Get-ItemProperty "$classes\$s" -ErrorAction SilentlyContinue).'URL Protocol') "link $s`:// is a URL protocol"
}
foreach ($e in $extensions) {
  Check ((Get-Item "$classes\$e\OpenWithProgids" -ErrorAction SilentlyContinue).GetValueNames() -contains 'Wardkeep.Config') "$e offers Wardkeep in Open with"
}
Check ((Get-ItemProperty "$classes\Wardkeep.Config\shell\open\command").'(default)' -eq "`"$exe`" `"%1`"") 'Wardkeep.Config opens files'
Check ((Get-ItemProperty $run -ErrorAction SilentlyContinue).Wardkeep -eq "`"$exe`" --background") 'start with Windows (to the tray)'
$u = Get-ItemProperty $uninstallKey -ErrorAction SilentlyContinue
Check ($null -ne $u) 'listed in Apps (HKCU)'
Check ($u.InstallLocation -like "$Dir*") 'the entry points at the folder'
Check (-not (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{$appId}_is1")) 'nothing in HKLM (no administrator rights used)'
Check (-not (Test-Path "HKLM:\Software\Classes\Wardkeep.Config")) 'no file type in HKLM'

Write-Host 'uninstall'
$p = Start-Process (Join-Path $Dir 'unins000.exe') -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' + $(if ($DeleteDataCheck) { ' /DELETEDATA' } else { '' })) -Wait -PassThru
Check ($p.ExitCode -eq 0) "uninstaller exits with 0 (was $($p.ExitCode))"
# The uninstaller copies itself and ends at once; the copy does the work.
for ($i = 0; $i -lt 120 -and ((Test-Path $Dir) -or (Test-Path $uninstallKey)); $i++) { Start-Sleep -Milliseconds 500 }

Check (-not (Test-Path $Dir)) 'the install folder is gone'
Check (-not (Test-Path $startMenu)) 'Start menu shortcut is gone'
Check (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Wardkeep.lnk'))) 'desktop shortcut is gone'
Check (-not (Test-Path $uninstallKey)) 'no longer listed in Apps'
Check (-not ((Get-ItemProperty $run -ErrorAction SilentlyContinue).PSObject.Properties.Name -contains 'Wardkeep')) 'Run entry is gone'
foreach ($s in $schemes) { Check (-not (Test-Path "$classes\$s")) "link $s`:// is released" }
Check (-not (Test-Path "$classes\Wardkeep.Config")) 'Wardkeep.Config is gone'
foreach ($e in $extensions) { Check ((@(OpenWith $e) -join '|') -eq $before[$e]) "$e keeps what other programs registered" }
if (-not $AllowExisting) {
  foreach ($e in $extensions) {
    if (-not $keyExisted[$e]) { Check (-not (Test-Path "$classes\$e")) "${e}: nothing left of the key" }
  }
}
foreach ($d in $dataBefore.Keys) {
  if ($DeleteDataCheck) {
    Check (-not (Test-Path $d)) "$d deleted (/DELETEDATA)"
  } else {
    $now = if (Test-Path $d) { (Get-ChildItem $d -Recurse -File | ForEach-Object { $_.FullName } | Sort-Object) -join "`n" } else { $null }
    Check ($now -eq $dataBefore[$d]) "$d is untouched (the data is kept)"
  }
}

Remove-Item $log -ErrorAction SilentlyContinue
if ($failures) { Write-Host "`n$($failures.Count) check(s) failed"; exit 1 }
Write-Host "`nall checks passed"
