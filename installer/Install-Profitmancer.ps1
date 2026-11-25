# Profitmancer: installs the WoW Forever addon and keeps its prices up to date (every 15 minutes + at logon).
# Nothing is sent anywhere: the script only downloads the public price files of the Profitmancer scan on GitHub.
param([switch]$Uninstall)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$FR = (Get-Culture).TwoLetterISOLanguageName -eq "fr"
function T($fr, $en) { if ($FR) { $fr } else { $en } }

$Base    = "https://raw.githubusercontent.com/DoubleVB/grimoire-ah/data/"
$Home2   = Join-Path $env:LOCALAPPDATA "Profitmancer"
$Config  = Join-Path $Home2 "config.json"
$Here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Task    = "Profitmancer - WoW Forever prices"

Write-Host ""
Write-Host "  Profitmancer · WoW Forever" -ForegroundColor Magenta
Write-Host ""

if ($Uninstall) {
  Unregister-ScheduledTask -TaskName $Task -Confirm:$false -ErrorAction SilentlyContinue
  Remove-Item $Home2 -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host (T "Mise à jour automatique supprimée. Pour enlever l'addon, supprime les dossiers Interface\AddOns\Profitmancer et ProfitmancerData." "Automatic updates removed. To remove the addon, delete the Interface\AddOns\Profitmancer and ProfitmancerData folders.") -ForegroundColor Green
  return
}

# ——— 1. Find WoW Forever ———
function Test-Forever($p) { $p -and (Test-Path (Join-Path $p "Interface\AddOns")) }
$oldCfg = Join-Path $env:LOCALAPPDATA "Grimoire\config.json"
$old = if (Test-Path $Config) { Get-Content $Config -Raw | ConvertFrom-Json } elseif (Test-Path $oldCfg) { Get-Content $oldCfg -Raw | ConvertFrom-Json } else { $null }
$wow = if ($old -and (Test-Forever $old.wow)) { $old.wow } else { $null }
if (-not $wow) {
  $cands = @()
  foreach ($k in "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft", "HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft") {
    try { $ip = (Get-ItemProperty $k -ErrorAction Stop).InstallPath; if ($ip) { $cands += (Join-Path (Split-Path (Split-Path $ip.TrimEnd('\'))) "_forever_"), (Join-Path $ip "_forever_"), (Join-Path (Split-Path $ip.TrimEnd('\')) "_forever_") } } catch {}
  }
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }).Root) {
    foreach ($sub in "World of Warcraft", "Games\World of Warcraft", "GAMES\World of Warcraft", "Program Files (x86)\World of Warcraft", "Program Files\World of Warcraft", "Blizzard\World of Warcraft", "Jeux\World of Warcraft") {
      $cands += Join-Path $d "$sub\_forever_"
    }
  }
  $wow = $cands | Where-Object { Test-Forever $_ } | Select-Object -First 1
}
if (-not $wow) {
  Write-Host (T "Je n'ai pas trouvé WoW Forever. Choisis le dossier _forever_ (celui qui contient Interface)." "WoW Forever not found. Pick the _forever_ folder (the one that contains Interface).") -ForegroundColor Yellow
  Add-Type -AssemblyName System.Windows.Forms
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "World of Warcraft\_forever_"
  if ($dlg.ShowDialog() -ne "OK" -or -not (Test-Forever $dlg.SelectedPath)) { throw (T "Dossier invalide : il doit contenir Interface\AddOns." "Invalid folder: it must contain Interface\AddOns.") }
  $wow = $dlg.SelectedPath
}
Write-Host ((T "WoW Forever : " "WoW Forever: ") + $wow) -ForegroundColor Green

# ——— Former name (Grimoire): remove its scheduled task, settings and addon folder ———
Unregister-ScheduledTask -TaskName "Grimoire - WoW Forever prices" -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:LOCALAPPDATA "Grimoire") -Recurse -Force -ErrorAction SilentlyContinue
$oldAddon = Join-Path $wow "Interface\AddOns\Grimoire"
if ((Test-Path $oldAddon) -and (Test-Path (Join-Path $oldAddon "Grimoire.toc"))) { Remove-Item $oldAddon -Recurse -Force; Write-Host (T "Ancienne version (Grimoire) supprimée." "Former version (Grimoire) removed.") -ForegroundColor Green }

# ——— 2. Copy the addon ———
$src = Join-Path $Here "Profitmancer"
$dst = Join-Path $wow "Interface\AddOns\Profitmancer"
function Get-TocVersion($dir) {
  $toc = Join-Path $dir "Profitmancer.toc"
  if (-not (Test-Path $toc)) { return $null }
  $m = Select-String -Path $toc -Pattern '^## Version:\s*([\d.]+)' | Select-Object -First 1
  if ($m) { try { return [version]$m.Matches[0].Groups[1].Value } catch { } }
  return [version]"0.0"
}
if (Test-Path $src) {
  $have = Get-TocVersion $dst; $mine = Get-TocVersion $src
  if ($have -and $mine -and $have -ge $mine) {
    # Already installed (CurseForge app or an earlier install) and up to date: keep it, CurseForge keeps updating it
    Write-Host ((T "Addon déjà installé (version " "Addon already installed (version ") + $have + (T ") : conservé." "): kept.")) -ForegroundColor Green
  } else {
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Get-ChildItem $src -File | Where-Object { $_.Name -ne "ProfitmancerData.lua" -or -not (Test-Path (Join-Path $dst "ProfitmancerData.lua")) } | Copy-Item -Destination $dst -Force
    Write-Host (T "Addon installé dans Interface\AddOns\Profitmancer." "Addon installed in Interface\AddOns\Profitmancer.") -ForegroundColor Green
  }
}

# ——— 3. Pick the faction ———
# Each faction has 4 markets (PvP, Normal, RP, RP-PvP): the price file holds all of them and the addon uses the one
# of the server type you play on, so only the faction is asked.
$index = (Invoke-WebRequest -UseBasicParsing ($Base + "index.json?t=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())).Content | ConvertFrom-Json
$houses = @($index.factions | Where-Object { $_ })
if (-not $houses.Count) { $houses = @($index.houses | Sort-Object ruleset, name) }
foreach ($h in $houses) { if ($FR -and $h.labelFr) { $h.label = $h.labelFr } }
# Default: the previous choice, else the faction most of your characters play (read from the addon's saved data)
$def = 0
if ($old) {
  $def = [array]::IndexOf(@($houses.key), $old.key) + 1
  if ($def -le 0) { $f = ($old.key -split "-")[-1]; $def = [array]::IndexOf(@($houses.faction), $f) + 1 }
}
if ($def -le 0) {
  $sv = Get-ChildItem (Join-Path $wow "WTF\Account") -Recurse -Filter "Profitmancer.lua" -ErrorAction SilentlyContinue | Where-Object { $_.DirectoryName -like "*SavedVariables" } | Select-Object -First 1
  if ($sv) {
    $txt = Get-Content $sv.FullName -Raw -ErrorAction SilentlyContinue
    $nh = ([regex]::Matches($txt, '\["f"\] = "H"')).Count; $na = ([regex]::Matches($txt, '\["f"\] = "A"')).Count
    $f = if ($nh -gt $na) { "horde" } elseif ($na -gt 0) { "alliance" } else { "" }
    if ($f) { $def = [array]::IndexOf(@($houses.faction), $f) + 1 }
  }
}
Write-Host ""
Write-Host (T "Ta faction (les prix de ton type de serveur, JcJ, Normal, RP ou RP-JcJ, sont choisis automatiquement en jeu) :" "Your faction (the prices of your server type, PvP, Normal, RP or RP-PvP, are picked automatically in game):")
for ($i = 0; $i -lt $houses.Count; $i++) {
  $mark = if ($def -eq $i + 1) { "  <" } else { "" }
  Write-Host ("  {0,2}. {1}{2}" -f ($i + 1), $houses[$i].label, $mark)
}
do {
  $prompt = if ($def -gt 0) { T "Numéro (Entrée = $def)" "Number (Enter = $def)" } else { T "Numéro" "Number" }
  $a = Read-Host $prompt
  if (-not $a -and $def -gt 0) { $a = "$def" }
  $n = 0; [void][int]::TryParse($a, [ref]$n)
} until ($n -ge 1 -and $n -le $houses.Count)
$house = $houses[$n - 1]

# ——— 4. Save, install the updater, schedule it ———
New-Item -ItemType Directory -Force -Path $Home2 | Out-Null
@{ wow = $wow; key = $house.key; label = $house.label } | ConvertTo-Json | Set-Content -Encoding UTF8 $Config
Copy-Item (Join-Path $Here "Update-Profitmancer.ps1") $Home2 -Force
$vbs = Join-Path $Home2 "Update-Profitmancer.vbs"
@"
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$Home2\Update-Profitmancer.ps1""", 0, False
"@ | Set-Content -Encoding ASCII $vbs

$action  = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbs`""
$hourly  = New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(10)) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
$logon   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName $Task -Action $action -Trigger $hourly, $logon -Settings $set -Description "Downloads the Profitmancer auction house prices for the WoW Forever addon." -Force | Out-Null

& (Join-Path $Home2 "Update-Profitmancer.ps1")
Write-Host ""
Write-Host ((T "Terminé ! Prix de " "Done! Prices for ") + $house.label + (T " récupérés automatiquement : Blizzard les publie une fois par heure, le programme vérifie toutes les 15 minutes (et à l'ouverture de session)." " picked up automatically: Blizzard publishes them once an hour, the updater checks every 15 minutes (and at logon).")) -ForegroundColor Green
Write-Host (T "En jeu : /reload pour charger les derniers prix, /pfm pour l'état. Maintiens Maj sur un objet pour le détail." "In game: /reload to load the latest prices, /pfm for the status. Hold Shift on an item for details.")
