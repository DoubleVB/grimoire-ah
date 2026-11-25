# Builds both release packages from the sources:
#   releases/curseforge/Profitmancer-<ver>-curseforge.zip   (addon only, upload on CurseForge)
#   releases/github/Profitmancer-WoW-Forever.zip            (addon + installer/, served by install.ps1)
# The version comes from addon/Profitmancer/Profitmancer.toc. Run:  powershell -File scripts/build-release.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "addon\Profitmancer"
$ver = (Select-String (Join-Path $src "Profitmancer.toc") -Pattern '^## Version:\s*([\d.]+)').Matches[0].Groups[1].Value
function Add-Entry($zip, $path, $entry) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $path, $entry, [IO.Compression.CompressionLevel]::Optimal) }
function New-Zip($out, $parts) {
  if (Test-Path $out) { Remove-Item $out }
  New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
  $z = [IO.Compression.ZipFile]::Open($out, "Create")
  foreach ($p in $parts) { foreach ($f in Get-ChildItem $p.dir -File | Sort-Object Name) { Add-Entry $z $f.FullName ($p.prefix + "/" + $f.Name) } }
  $z.Dispose()
  Write-Host "$out"
}
$cf = Join-Path $root "releases\curseforge"
Get-ChildItem $cf -Filter "Profitmancer-*-curseforge.zip" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "Profitmancer-$ver-curseforge.zip" } | Move-Item -Destination (Join-Path $root "releases\archive") -Force
New-Zip (Join-Path $cf "Profitmancer-$ver-curseforge.zip") @(@{ dir = $src; prefix = "Profitmancer" })
New-Zip (Join-Path $root "releases\github\Profitmancer-WoW-Forever.zip") @(
  @{ dir = (Join-Path $root "installer"); prefix = "Profitmancer-WoW-Forever" },
  @{ dir = $src; prefix = "Profitmancer-WoW-Forever/Profitmancer" })
Write-Host "Version $ver built."

