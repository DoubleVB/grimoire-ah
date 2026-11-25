# Profitmancer price updater for WoW Forever: one-line install.
# Paste in PowerShell:   irm https://doublevb.github.io/grimoire-ah/install.ps1 | iex
# It downloads the Profitmancer package from GitHub, then runs its installer: it finds WoW Forever, asks for your
# auction house and schedules a hidden price update every 15 minutes. Nothing is sent anywhere.
& {
  # add TLS 1.2 to what Windows PowerShell 5.1 allows (without removing TLS 1.3 where it exists)
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  # the progress bar makes Invoke-WebRequest many times slower in Windows PowerShell 5.1
  $ProgressPreference = "SilentlyContinue"
  $zipUrl = "https://raw.githubusercontent.com/DoubleVB/grimoire-ah/main/releases/github/Profitmancer-WoW-Forever.zip"
  $tmp = Join-Path $env:TEMP ("Profitmancer-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
  try {
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Write-Host ""
    Write-Host "  Profitmancer: downloading the price updater..." -ForegroundColor Magenta
    $zip = Join-Path $tmp "Profitmancer.zip"
    Invoke-WebRequest -UseBasicParsing $zipUrl -OutFile $zip -TimeoutSec 120 -ErrorAction Stop
    Write-Host ("  SHA256 " + (Get-FileHash $zip -Algorithm SHA256).Hash) -ForegroundColor DarkGray
    Expand-Archive -Path $zip -DestinationPath $tmp -Force -ErrorAction Stop
    $inst = Get-ChildItem $tmp -Recurse -Filter "Install-Profitmancer.ps1" | Select-Object -First 1
    if (-not $inst) { throw "Install-Profitmancer.ps1 not found in the download." }
    $p = Start-Process powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$($inst.FullName)`"") -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Host "  Profitmancer: the installer stopped (code $($p.ExitCode))." -ForegroundColor Yellow }
  } catch {
    Write-Host ("  Profitmancer: " + $_.Exception.Message) -ForegroundColor Red
  } finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}
