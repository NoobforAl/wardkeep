<#
.SYNOPSIS
  Tries the Windows service of the core (omnitun-svc) from install to uninstall.

.DESCRIPTION
  Run it from an ELEVATED PowerShell (Run as administrator). It has NOT been run by
  the person who wrote it (no administrator rights were available there), so read
  it first and expect to fix small things.

  What it does, in order. Every step prints what it is about to do and whether it passed:
    1. installs the service (copies omnitun-svc.exe to Program Files, registers it)
    2. starts it and checks the folder that holds the control file (token) is closed to other users
    3. asks the service as a NORMAL (unelevated) process whether it can use it
    4. VPN-mode test: starts a TUN with a profile that goes nowhere, but routes only the
       documentation range 192.0.2.0/24 into the tunnel, so the rest of the machine's traffic
       is not touched. Checks that the "Wardkeep" network adapter appears and is gone after stop.
    5. (-CrashTest) kills the service while the adapter is up and checks that the next start
       cleans the leftover adapter up
    6. (-KillSwitchTest) raises a kill switch for a few seconds: the whole machine, your own
       VPN included, loses its network for about a second
    7. stops and uninstalls the service (also when a step failed), unless -KeepInstalled

  It never touches the system proxy, other adapters or other firewall rules. If you run your
  own VPN, step 4 still works (its traffic is not routed into the test tunnel) but step 6 will
  interrupt it briefly. The adapter checks only look at the adapter named "Wardkeep".

.PARAMETER Exe
  The omnitun-svc.exe to install. Default: ..\bin\omnitun-svc.exe next to this script's folder.
  Build it first:  go build -tags "with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_acme,badlinkname,tfogo_checklinkname0" -ldflags=-checklinkname=0 -o bin\omnitun-svc.exe .\cmd\omnitun-svc

.PARAMETER User
  Account allowed to use the service (default: the account running this script).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\windows-service-test.ps1
  powershell -ExecutionPolicy Bypass -File scripts\windows-service-test.ps1 -CrashTest -KillSwitchTest
#>
[CmdletBinding()]
param(
  [string]$Exe,
  [string]$User,
  [switch]$SkipTun,
  [switch]$CrashTest,
  [switch]$KillSwitchTest,
  [switch]$KeepInstalled
)

$ErrorActionPreference = 'Stop'
$script:failures = 0
$AdapterName = 'Wardkeep'
$ServiceName = 'OmnitunSvc'
$ProgramData = if ($env:ProgramData) { $env:ProgramData } else { 'C:\ProgramData' }
$CommonDir = Join-Path $ProgramData 'omnitun'
$ControlDir = Join-Path $CommonDir 'control'
$ControlFile = Join-Path $ControlDir 'control.json'

function Step($text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }
function Info($text) { Write-Host "   $text" }
function Pass($text) { Write-Host "   PASS: $text" -ForegroundColor Green }
function Fail($text) { Write-Host "   FAIL: $text" -ForegroundColor Red; $script:failures++ }
function Check($ok, $text) { if ($ok) { Pass $text } else { Fail $text } }

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Svc {
  # Runs the installed or source program with arguments and returns its exit code; output is shown.
  param([string[]]$Arguments)
  Info ("omnitun-svc " + ($Arguments -join ' '))
  # Windows PowerShell 5.1 turns a native program's stderr into errors; here it is just output.
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $script:ExePath @Arguments 2>&1 | ForEach-Object { Info "  | $_" } } finally { $ErrorActionPreference = $old }
  return $LASTEXITCODE
}

function Get-Adapter { Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue }

# Talks to the service the way the app does: newline-delimited JSON on the loopback port.
function Invoke-Control {
  param([string]$Method, $Params = $null, [int]$Id = 1)
  $cf = Get-Content -Raw $ControlFile | ConvertFrom-Json
  $hostPart, $portPart = $cf.addr -split ':(?=[^:]+$)'
  $client = New-Object Net.Sockets.TcpClient
  $client.Connect($hostPart, [int]$portPart)
  $client.ReceiveTimeout = 30000
  $stream = $client.GetStream()
  $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8)
  $writer = New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($false)))
  $writer.NewLine = "`n"
  $writer.AutoFlush = $true
  try {
    $writer.WriteLine((@{ id = 1; method = 'hello'; params = @{ token = $cf.token } } | ConvertTo-Json -Compress -Depth 8))
    $hello = $reader.ReadLine() | ConvertFrom-Json
    if ($hello.error) { throw "hello: $($hello.error.message)" }
    $req = @{ id = 2; method = $Method }
    if ($null -ne $Params) { $req.params = $Params }
    $writer.WriteLine(($req | ConvertTo-Json -Compress -Depth 12))
    while ($true) {
      $line = $reader.ReadLine()
      if ($null -eq $line) { throw "connection closed" }
      $msg = $line | ConvertFrom-Json
      if ($msg.id -eq 2) { return $msg }
    }
  } finally { $client.Close() }
}

function Wait-State {
  param([scriptblock]$Done, [int]$Seconds = 30)
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    $st = (Invoke-Control 'state').result
    if (& $Done $st) { return $st }
    Start-Sleep -Milliseconds 500
  }
  return $null
}

if (-not (Test-Admin)) { Write-Host "Run this from an elevated PowerShell (Run as administrator)." -ForegroundColor Red; exit 2 }
if (-not $Exe) { $Exe = Join-Path $PSScriptRoot '..\bin\omnitun-svc.exe' }
if (-not (Test-Path $Exe)) { Write-Host "Cannot find $Exe . Build it first (see Get-Help)." -ForegroundColor Red; exit 2 }
$script:ExePath = (Resolve-Path $Exe).Path
$installed = $false

try {
  Step "0. Before: is the service already there?"
  $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Host "The service $ServiceName already exists ($($existing.Status)). Remove it first with: omnitun-svc uninstall" -ForegroundColor Red
    exit 2
  }
  if (Get-Adapter) {
    Write-Host "A network adapter named '$AdapterName' already exists (a leftover?). Run: omnitun-svc cleanup" -ForegroundColor Red
    exit 2
  }
  Pass "no service, no '$AdapterName' adapter"

  Step "1. Install"
  $args1 = @('install')
  if ($User) { $args1 += @('--user', $User) }
  $rc = Svc $args1
  Check ($rc -eq 0) "install exited with $rc"
  $installed = $true
  $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
  Check ($null -ne $svc) "the service is registered"
  Check (Test-Path (Join-Path $env:ProgramFiles 'Omnitun\omnitun-svc.exe')) "the program was copied to Program Files (only administrators can write there)"
  $rc = Svc @('status')
  Check ($rc -eq 3) "status says installed but not running (exit $rc, expected 3)"

  Step "2. Start, and check who can read the token"
  $rc = Svc @('start')
  Check ($rc -eq 0) "start exited with $rc"
  Check ((Get-Service $ServiceName).Status -eq 'Running') "the service is running"
  Check (Test-Path $ControlFile) "the control file exists: $ControlFile"
  Info "Access list of the control folder:"
  $acl = (& icacls $ControlDir) | Out-String
  $acl -split "`r?`n" | Where-Object { $_.Trim() } | ForEach-Object { Info "  | $_" }
  $open = [regex]::IsMatch($acl, 'Everyone|BUILTIN\\Users|Authenticated Users|\(I\)')
  Check (-not $open) "no Everyone / Users / Authenticated Users entry and nothing inherited"
  Check ($acl -match 'NT AUTHORITY\\SYSTEM') "SYSTEM has access"
  $rootAcl = (& icacls $CommonDir) | Out-String
  Check (-not [regex]::IsMatch($rootAcl, 'Everyone|BUILTIN\\Users|Authenticated Users')) "the parent folder $CommonDir is closed to normal users too"

  Step "3. A normal (unelevated) process asks the service"
  $tmp = Join-Path $env:TEMP ("omnitun-status-" + [guid]::NewGuid().ToString('N') + '.txt')
  # runas /trustlevel:0x20000 starts the program with the limited ("basic user") token: what the app has.
  & runas /trustlevel:0x20000 "cmd.exe /c `"`"$script:ExePath`" status > `"$tmp`" 2>&1`"" | Out-Null
  for ($i = 0; $i -lt 40 -and -not (Test-Path $tmp); $i++) { Start-Sleep -Milliseconds 250 }
  Start-Sleep -Milliseconds 500
  if (Test-Path $tmp) {
    $out = Get-Content $tmp -Raw
    $out -split "`r?`n" | Where-Object { $_.Trim() } | ForEach-Object { Info "  | $_" }
    Check ($out -match 'this user can use the service') "the unelevated process can use the service"
    Remove-Item $tmp -ErrorAction SilentlyContinue
  } else {
    Fail "the unelevated test process produced no output (runas /trustlevel may be blocked on this machine); run '$script:ExePath status' in a normal terminal and look for 'this user can use the service'"
  }

  if (-not $SkipTun) {
    Step "4. VPN (TUN) mode through the service"
    Info "The profile points at 127.0.0.1:9 where nothing listens, and only 192.0.2.0/24 (documentation range) is routed into the tunnel."
    Info "The connection will not succeed; what is tested is that SYSTEM can create the adapter and that stop removes it."
    $profile = @{ id = 'svc-test'; name = 'svc-test'; protocol = 'shadowsocks'; server = '127.0.0.1'; port = 9; method = 'aes-128-gcm'; password = 'x' }
    $params = @{ profiles = @($profile); mode = 'tun'; selected = 'svc-test'; bypass = '192.0.2.0/24'; bypass_only = $true; failover = $false }
    $r = Invoke-Control 'start' $params
    if ($r.error) { Fail "start was refused: $($r.error.code) $($r.error.message)" } else { Pass "start accepted" }
    $seen = $false
    $null = Wait-State -Seconds 25 -Done {
      param($st)
      if (Get-Adapter) { $script:seen = $true }
      $st.status -ne 'connecting'
    }
    if (-not $seen) { $seen = [bool](Get-Adapter) }
    Check $seen "the '$AdapterName' adapter appeared while the tunnel was starting or failing"
    $st = (Invoke-Control 'state').result
    Info "state: $($st.status) $($st.error)"
    if ($CrashTest) {
      Step "5. Crash cleanup"
      if (-not (Get-Adapter)) { Info "the adapter is already gone (the tunnel failed and closed it); the crash test needs it up, skipping" }
      else {
        $cf = Get-Content -Raw $ControlFile | ConvertFrom-Json
        Info "killing the service process $($cf.pid) while the adapter exists"
        Stop-Process -Id $cf.pid -Force
        Start-Sleep -Seconds 2
        Info "adapter after the crash: $(if (Get-Adapter) { 'still there (a leftover)' } else { 'gone' })"
        Info "waiting for the service manager to restart the service (recovery action, about 5 s) or starting it"
        for ($i = 0; $i -lt 30 -and (Get-Service $ServiceName).Status -ne 'Running'; $i++) { Start-Sleep -Seconds 1 }
        if ((Get-Service $ServiceName).Status -ne 'Running') { $null = Svc @('start') }
        Start-Sleep -Seconds 2
        Check (-not (Get-Adapter)) "after the restart the leftover adapter is gone"
      }
    }
    $null = Invoke-Control 'stop'
    Start-Sleep -Seconds 1
    Check (-not (Get-Adapter)) "after stop the '$AdapterName' adapter is gone"
  }

  if ($KillSwitchTest) {
    Step "6. Kill switch self-test (the machine loses its network for about a second)"
    $rc = Svc @('killswitch-selftest', '--yes')
    Check ($rc -eq 0) "killswitch-selftest exited with $rc (0 = passed)"
  }

  Step "7. Stop"
  $rc = Svc @('stop')
  Check ($rc -eq 0) "stop exited with $rc"
  Check (-not (Test-Path $ControlFile)) "the control file was removed on stop"
  Check (-not (Get-Adapter)) "no '$AdapterName' adapter left"
  $rc = Svc @('cleanup')
  Check ($rc -eq 0) "cleanup on a clean machine exits 0 (it is safe to run twice)"
}
catch {
  Fail "the script stopped on an error: $($_.Exception.Message)"
  Write-Host $_.ScriptStackTrace
}
finally {
  if ($installed -and -not $KeepInstalled) {
    Step "8. Uninstall"
    try {
      $rc = Svc @('uninstall', '--purge')
      Check ($rc -eq 0) "uninstall exited with $rc"
      Check ($null -eq (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) "the service is gone"
      Check (-not (Test-Path $CommonDir)) "$CommonDir was removed"
    } catch { Fail "uninstall: $($_.Exception.Message)" }
  }
  Write-Host ""
  if ($script:failures -eq 0) { Write-Host "ALL CHECKS PASSED" -ForegroundColor Green; exit 0 }
  Write-Host "$($script:failures) CHECK(S) FAILED" -ForegroundColor Red
  exit 1
}
