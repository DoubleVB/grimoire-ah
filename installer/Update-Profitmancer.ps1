# Profitmancer updater: downloads the latest price file of your auction house into the WoW Forever addon (Profitmancer).
# Run every 15 minutes by the "Profitmancer - WoW Forever prices" scheduled task. Log: %LOCALAPPDATA%\Profitmancer\update.log
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Home2 = Join-Path $env:LOCALAPPDATA "Profitmancer"
$Log = Join-Path $Home2 "update.log"
function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Add-Content -Encoding UTF8 $Log; Write-Host $m }
try {
  $cfg = Get-Content (Join-Path $Home2 "config.json") -Raw | ConvertFrom-Json
  if (-not (Test-Path (Join-Path $cfg.wow "Interface\AddOns\Profitmancer"))) { throw "Profitmancer addon missing in $($cfg.wow)\Interface\AddOns" }
  # The prices live in their own small addon (ProfitmancerData), so an addon update (CurseForge app...) never wipes them
  $dir = Join-Path $cfg.wow "Interface\AddOns\ProfitmancerData"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $toc = Join-Path $dir "ProfitmancerData.toc"
  if (-not (Test-Path $toc)) {
    @("## Interface: 16001", "## Title: |cffb48cffProfitmancer|r Data", "## Notes: Auction house prices for Profitmancer, refreshed by the Profitmancer updater.", "## Author: Workby", "## Dependencies: Profitmancer", "", "ProfitmancerData.lua") | Set-Content -Encoding ASCII $toc
  }
  $url = "https://raw.githubusercontent.com/DoubleVB/grimoire-ah/data/ah/$($cfg.key)/ProfitmancerData.lua?t=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
  $tmp = Join-Path $Home2 "ProfitmancerData.tmp"
  # Right after Windows starts or wakes up, the network can take a minute or two: retry instead of giving up until the next run
  for ($try = 1; ; $try++) {
    try { Invoke-WebRequest -UseBasicParsing $url -OutFile $tmp -TimeoutSec 30; break }
    catch { if ($try -ge 6) { throw }; Start-Sleep -Seconds 20 }
  }
  $head = Get-Content $tmp -TotalCount 3 -Encoding UTF8
  if (-not ($head -join "`n").Contains("ProfitmancerData={")) { throw "Unexpected file content" }
  Move-Item $tmp (Join-Path $dir "ProfitmancerData.lua") -Force
  Log "OK  $($cfg.label)  $($head[0])"
  # keep the log short
  $lines = Get-Content $Log -Encoding UTF8; if ($lines.Count -gt 300) { $lines[-200..-1] | Set-Content -Encoding UTF8 $Log }
} catch { Log "ERROR  $($_.Exception.Message)"; exit 1 }
