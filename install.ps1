# Profitmancer price updater for WoW Forever: one-line install.
# Paste in PowerShell:   irm https://doublevb.github.io/grimoire-ah/install.ps1 | iex
# It downloads the Profitmancer package from GitHub, then runs its installer: it finds WoW Forever, asks for your
# auction house and schedules a hidden price update every 15 minutes. Nothing is sent anywhere.
& {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $zipUrl = "https://raw.githubusercontent.com/DoubleVB/grimoire-ah/main/Profitmancer-WoW-Forever.zip"
  $tmp = Join-Path $env:TEMP ("Profitmancer-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
  try {
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Write-Host ""
    Write-Host "  Profitmancer: downloading the price updater..." -ForegroundColor Magenta
    $zip = Join-Path $tmp "Profitmancer.zip"
    Invoke-WebRequest -UseBasicParsing $zipUrl -OutFile $zip -ErrorAction Stop
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
