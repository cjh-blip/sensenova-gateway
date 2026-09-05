# sensenova-gateway launcher - background hidden start
# keys self-heal from User registry env, then spawn litellm (hidden)
# used by: manual double-click, Scheduled Task keep-alive (every 5 min)
# idempotent: if litellm is alive AND port 4000 is listening, do nothing.
# half-dead (process alive but port dead): kill and restart.
$ErrorActionPreference = "Stop"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir "gateway.log"
$err = Join-Path $dir "gateway.err.log"
$exe = Join-Path $dir ".venv\Scripts\litellm.exe"
$cfg = Join-Path $dir "config.yaml"

$env:SENSENOVA_KEY1 = [Environment]::GetEnvironmentVariable("SENSENOVA_KEY1", "User")
$env:SENSENOVA_KEY2 = [Environment]::GetEnvironmentVariable("SENSENOVA_KEY2", "User")
$env:SENSENOVA_KEY3 = [Environment]::GetEnvironmentVariable("SENSENOVA_KEY3", "User")

$proc = Get-Process litellm -ErrorAction SilentlyContinue
$listening = Get-NetTCPConnection -LocalPort 4000 -State Listen -ErrorAction SilentlyContinue

if ($proc -and $listening) {
  Write-Host "gateway already running (PID $($proc.Id))"
  exit 0
}

if ($proc) {
  Write-Host "gateway half-dead (process up, port not listening) - restarting"
  $proc | Stop-Process -Force
  Start-Sleep -Seconds 2
}

Start-Process -FilePath $exe -ArgumentList "--config", $cfg, "--port", "4000" -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
Write-Host "gateway started"
