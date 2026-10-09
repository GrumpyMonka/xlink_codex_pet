param([string]$Pet='vpet',[ValidateSet('canvas','native')][string]$Player='canvas',[switch]$Launch)
& (Join-Path $PSScriptRoot 'Main.ps1') -Action apply -Pet $Pet -Player $Player
