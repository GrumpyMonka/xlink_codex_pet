. (Join-Path $PSScriptRoot 'Common.ps1')
$settings = Read-Settings
$runtime = Assert-Runtime $settings.runtime
$env:CODEX_ELECTRON_USER_DATA_PATH = Join-Path $settings.profile 'electron'
$env:CODEX_HOME = Join-Path $settings.profile 'codex-home'
$env:CODEX_SPARKLE_ENABLED = 'false'
New-Item -ItemType Directory -Force -Path $env:CODEX_ELECTRON_USER_DATA_PATH,$env:CODEX_HOME | Out-Null
$arguments = @(('--user-data-dir="' + (Join-Path $settings.profile 'browser') + '"'),'--remote-debugging-address=127.0.0.1','--remote-debugging-port=0')
# This launcher deliberately opens the user-requested interactive application.
$exe = Join-Path $runtime 'ChatGPT.exe'
$process = Start-Process -FilePath $exe -WorkingDirectory $runtime -ArgumentList $arguments -PassThru -ErrorAction Stop
Start-Sleep -Seconds 4
$running = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $exe -and $_.CommandLine -notmatch '--type=' })
if (-not $running.Count) { throw 'Codex exited during startup. Reinstall the selected player and try again.' }
Write-Output ('Codex is running. PID: ' + ($running.ProcessId -join ', '))
$process.Dispose()
