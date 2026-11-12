# pmcu standard installer — Windows 10 (PowerShell 5.1+). No toolchain needed.
# Usage: irm https://raw.githubusercontent.com/tayaee/poor-mans-computer-use/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'
$Repo = 'tayaee/poor-mans-computer-use'
$Base = "https://github.com/$Repo/releases/latest/download"
$BinDir = Join-Path $HOME 'bin'
$Pmcu = Join-Path $BinDir 'pmcu.exe'
$SkillDir = Join-Path $HOME '.claude\skills\pmcu'
New-Item -ItemType Directory -Force -Path $BinDir, $SkillDir | Out-Null
Write-Host '[pmcu] downloading binary...'
Invoke-WebRequest "${Base}/pmcu-windows.exe" -OutFile $Pmcu
Write-Host '[pmcu] downloading skill...'
$Zip = Join-Path $env:TEMP 'pmcu-skill.zip'
Invoke-WebRequest "${Base}/pmcu-skill.zip" -OutFile $Zip
Expand-Archive $Zip -DestinationPath $SkillDir -Force
Remove-Item $Zip -Force
Write-Host "[pmcu] installed: $Pmcu + $SkillDir"
Write-Host '[pmcu] ensure $HOME\bin is on PATH, then run: pmcu status'
& $Pmcu status
