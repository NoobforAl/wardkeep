<#
Signs files with a code-signing certificate (Authenticode, SHA-256, timestamped).

  $env:WINDOWS_CERT_PASSWORD = '...'
  powershell -File installer\sign.ps1 -Pfx cert.pfx -Files dist\app\omnitun.exe, dist\app\omnitun-svc.exe

The password comes from the environment, never from the command line. Used by .github/workflows/windows.yml
(for the two programs, and by the installer script as its SignTool for the setup file and the uninstaller,
see build-installer.ps1). Exits with an error if a file could not be signed.
#>
param(
  [Parameter(Mandatory)] [string] $Pfx,
  [Parameter(Mandatory)] [string[]] $Files,
  [string] $TimestampUrl = 'http://timestamp.digicert.com'
)
$ErrorActionPreference = 'Stop'

if (-not $env:WINDOWS_CERT_PASSWORD) { throw 'WINDOWS_CERT_PASSWORD is not set' }

# signtool comes with the Windows SDK (it is on the GitHub runners); the newest one wins.
$signtool = Get-Command signtool.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
if (-not $signtool) {
  $roots = @("${env:ProgramFiles(x86)}\Windows Kits\10\bin", "$env:ProgramFiles\Windows Kits\10\bin") | Where-Object { Test-Path $_ }
  $signtool = Get-ChildItem $roots -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\' } | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $signtool) { throw 'signtool.exe not found (install the Windows SDK)' }

# Windows PowerShell 5.1 does not escape a double quote inside an argument for a program; 7.3 and later do.
$password = $env:WINDOWS_CERT_PASSWORD
if ($PSVersionTable.PSVersion -lt [version]'7.3') { $password = $password.Replace('"', '\"') }

foreach ($f in $Files) {
  & $signtool sign /fd SHA256 /f $Pfx /p $password /tr $TimestampUrl /td SHA256 $f
  if ($LASTEXITCODE -ne 0) { throw "signtool failed on $f (exit code $LASTEXITCODE)" }
}
