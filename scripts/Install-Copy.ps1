param([string]$Pet = 'vpet', [string]$RuntimePath, [string]$ProfilePath, [switch]$Launch, [switch]$ReinstallPlayer, [ValidateSet('canvas','native')][string]$Player='canvas')
. (Join-Path $PSScriptRoot 'Common.ps1')
$node = (Get-Command node -ErrorAction Stop).Source
$nodeVersion = & $node --version
if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch '^v(\d+)\.') { throw 'Unable to read Node.js version.' }
if ([int]$Matches[1] -lt 22) { throw 'Node.js 22 or newer is required.' }
& $node (Join-Path $PSScriptRoot 'validate.cjs') $Pet
if ($LASTEXITCODE -ne 0) { throw 'Pet validation failed.' }
$saved = if (Test-Path -LiteralPath $SettingsFile) { Read-Settings } else { $null }
if (-not $RuntimePath) { $RuntimePath = if ($saved) { $saved.runtime } else { Join-Path $StateRoot 'app' } }
if (-not $ProfilePath) { $ProfilePath = if ($saved) { $saved.profile } else { Join-Path $StateRoot 'profile' } }
$runtime = [IO.Path]::GetFullPath($RuntimePath)
$profile = [IO.Path]::GetFullPath($ProfilePath)
if ($runtime -match '(?i)WindowsApps') { throw 'Do not use the installed Codex directory as destination.' }
if (Test-Path -LiteralPath $runtime) {
    $runtime = Assert-Runtime $runtime
    $marker=Join-Path $runtime 'codex-pets.json'
    if(-not $ReinstallPlayer -and (Test-Path $marker) -and (Get-Content $marker -Raw -Encoding UTF8|ConvertFrom-Json).version -eq 3){
        & $node (Join-Path $PSScriptRoot 'apply-live.cjs') $runtime $Pet $Player
        if($LASTEXITCODE -ne 0){throw 'Live selection failed; previous selection retained.'}
        New-Item -ItemType Directory -Force -Path $StateRoot,$profile | Out-Null
        @{version=1;runtime=$runtime;profile=$profile;pet=$Pet} | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
        if($Launch){ & (Join-Path $PSScriptRoot 'Launch-Copy.ps1') }
        return
    }
    $wasRunning=@(Get-CimInstance Win32_Process | Where-Object ExecutablePath -eq (Join-Path $runtime 'ChatGPT.exe')).Count -gt 0
    Close-Runtime $runtime
} else {
    $package = Get-AppxPackage -Name OpenAI.Codex | Select-Object -First 1
    if (-not $package -or [string]$package.Version -ne '26.1002.7124.0') { throw 'Supported Codex Windows package: 26.1002.7124.0. Other builds require a verified adapter; installation stopped.' }
    $source = Join-Path $package.InstallLocation 'app'
    New-Item -ItemType Directory -Force -Path $runtime | Out-Null
    & robocopy $source $runtime /E /COPY:DAT /DCOPY:DA /R:0 /W:0 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw 'Copy failed. Original Codex was not modified. Choose a new destination after resolving the copy error.' }
    New-Item -ItemType File -Path (Join-Path $runtime '.codex-pets-runtime') | Out-Null
}
& $node (Join-Path $PSScriptRoot 'patch-copy.cjs') $runtime $Pet
if ($LASTEXITCODE -ne 0) { throw 'Patch failed; see diagnostics above.' }
New-Item -ItemType Directory -Force -Path $StateRoot,$profile | Out-Null
@{ version = 1; runtime = $runtime; profile = $profile; pet = $Pet } | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
Write-Host "Installed pet: $Pet"
Write-Host 'Animation attribution and license:'
(Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $RepoRoot "pets/$Pet/pet.json") | ConvertFrom-Json).license | Format-List
& $node (Join-Path $PSScriptRoot 'apply-live.cjs') $runtime $Pet $Player
if($LASTEXITCODE -ne 0){throw 'Live selection failed.'}
if ($Launch -or $wasRunning) { & (Join-Path $PSScriptRoot 'Launch-Copy.ps1') }
