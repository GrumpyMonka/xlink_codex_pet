param([Parameter(Mandatory=$true)][string]$Pet)
. (Join-Path $PSScriptRoot 'Common.ps1')
$settings=Read-Settings
$runtime=Assert-Runtime $settings.runtime
& (Join-Path $PSScriptRoot 'Launch-Copy.ps1')
$roots=@(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq (Join-Path $runtime 'ChatGPT.exe') -and $_.CommandLine -notmatch '--type=' })
$debugPort=$null
foreach($entry in $roots){if($entry.CommandLine -match '--remote-debugging-port[= ](\d+)'){$debugPort=[int]$Matches[1];break}}
if($null -eq $debugPort){throw 'Для автоматического выбора один раз закройте дополнительный Codex и откройте его кнопкой менеджера. Старый запуск не имеет канала управления.'}
if($debugPort -eq 0){
    $portFile=Join-Path $settings.profile 'browser/DevToolsActivePort'
    if(-not (Test-Path $portFile)){throw 'Codex ещё не подготовил канал управления. Повторите добавление.'}
    $debugPort=[int](Get-Content -LiteralPath $portFile -TotalCount 1)
}
& node (Join-Path $PSScriptRoot 'activate-native.cjs') $Pet $debugPort
if($LASTEXITCODE -ne 0){throw 'Файлы установлены, но Codex не подтвердил выбор. Подробности в логах.'}
