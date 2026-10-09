. (Join-Path $PSScriptRoot 'Common.ps1')
$settings = Read-Settings
$runtime = Assert-Runtime $settings.runtime
Close-Runtime $runtime
$archive = Join-Path $runtime 'resources/app.asar'
$backup = Join-Path $runtime 'resources/app.original.asar'
$exe = Join-Path $runtime 'ChatGPT.exe'
if (-not (Test-Path -LiteralPath $backup) -or -not (Test-Path -LiteralPath ($exe + '.original'))) { throw 'Original backup pair is missing.' }
Copy-Item -LiteralPath $backup -Destination $archive -Force
Copy-Item -LiteralPath ($exe + '.original') -Destination $exe -Force
$marker = Join-Path $runtime 'codex-pets.json'
if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
Write-Host 'Original renderer restored in the separate copy. The installed Codex and pet source files were not changed.'
