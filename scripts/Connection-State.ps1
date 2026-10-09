$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$stateDir=Join-Path (Split-Path $PSScriptRoot -Parent) '.runtime'
$result=@{running=$false;connected=$false;checkedAt=[DateTime]::UtcNow.ToString('o')}
try{
    $package=Get-AppxPackage -Name OpenAI.Codex | Select-Object -First 1
    if($package){
        $exe=Join-Path $package.InstallLocation 'app/ChatGPT.exe'
        $roots=@(Get-CimInstance Win32_Process | Where-Object {$_.ExecutablePath -eq $exe -and $_.CommandLine -notmatch '--type='})
        $result.running=$roots.Count -gt 0
        $settingsFile=Join-Path $stateDir 'main-settings.json'
        $settings=if(Test-Path $settingsFile){Get-Content $settingsFile -Raw -Encoding UTF8|ConvertFrom-Json}else{$null}
        if($result.running -and $settings.enabled -and @($roots|Where-Object {$_.CommandLine -match '--remote-debugging-port=9340(?: |$)'}).Count){
            $output=& node (Join-Path $PSScriptRoot 'main-session.cjs') --status 9340 2>$null
            if($LASTEXITCODE -eq 0){$actual=$output|ConvertFrom-Json;$result.connected=[bool]($actual.bridge -and ($settings.player -eq 'native' -or ($actual.active -and $actual.pet -eq $settings.pet)))}
        }
    }
}catch{$result.error=$_.Exception.Message}
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$target=Join-Path $stateDir 'connection.json'
$result|ConvertTo-Json|Set-Content -LiteralPath ($target+'.tmp') -Encoding UTF8
Move-Item -LiteralPath ($target+'.tmp') -Destination $target -Force
