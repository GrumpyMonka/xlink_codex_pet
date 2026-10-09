$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$StateRoot = Join-Path $RepoRoot '.runtime'
$SettingsFile = Join-Path $StateRoot 'settings.json'
function Assert-Runtime([string]$Runtime) {
    $full = [IO.Path]::GetFullPath($Runtime)
    if ($full -match '(?i)WindowsApps' -or -not ((Test-Path -LiteralPath (Join-Path $full '.codex-pets-runtime')) -or (Test-Path -LiteralPath (Join-Path $full '.yuki-player-lab')))) { throw 'Expected a marked separate Codex runtime.' }
    return $full
}
function Read-Settings {
    if (-not (Test-Path -LiteralPath $SettingsFile)) { throw 'Managed runtime settings are missing.' }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $SettingsFile | ConvertFrom-Json
}
function Close-Runtime([string]$Runtime) {
    $Runtime = Assert-Runtime $Runtime
    $exe = Join-Path $Runtime 'ChatGPT.exe'
    $roots = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $exe -and $_.CommandLine -notmatch '--type=' }
    foreach ($entry in $roots) {
        $process = Get-Process -Id $entry.ProcessId -ErrorAction SilentlyContinue
        if ($process) { $null = $process.CloseMainWindow(); $null = $process.WaitForExit(2000) }
    }
    $remaining = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $exe }
    # Electron may hide in the tray. Stop only executables in the marked managed copy.
    foreach ($entry in $remaining) {
        Stop-Process -Id $entry.ProcessId -Force -ErrorAction SilentlyContinue
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $remaining = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $exe })
        if (-not $remaining.Count) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Could not stop the managed Codex copy. No patch has been applied.'
}
