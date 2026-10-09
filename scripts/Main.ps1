param([ValidateSet('launch','apply','stop','watch')][string]$Action='launch',[string]$Pet,[ValidateSet('canvas','native')][string]$Player='canvas')
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$mutex=New-Object Threading.Mutex($false,'Local\XLinkMainCodexPlayer')
$locked=$false
try {
    try{$locked=$mutex.WaitOne(45000)}catch [Threading.AbandonedMutexException]{$locked=$true}
    if(-not $locked){throw 'Another pet operation is still running.'}
    New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null
    $configFile=Join-Path $StateRoot 'main-settings.json'
    $config=if(Test-Path $configFile){Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json}else{[pscustomobject]@{enabled=$false;pet='vpet';player='canvas'}}
    if($Action -eq 'watch' -and -not $config.enabled){return}
    if($Action -eq 'launch'){$config.enabled=$true}
    if($Action -eq 'apply'){
        if(-not $Pet){$Pet=$config.pet}
        & node (Join-Path $PSScriptRoot 'validate.cjs') $Pet
        if($LASTEXITCODE -ne 0){throw 'Invalid pet package.'}
        $config=[pscustomobject]@{enabled=$true;pet=$Pet;player=$Player}
    }
    if($Action -eq 'stop'){$config.enabled=$false}
    $package=Get-AppxPackage -Name OpenAI.Codex | Select-Object -First 1
    if(-not $package -or [string]$package.Version -ne '26.1002.7124.0'){throw 'Unsupported installed Codex version. No changes made.'}
    $exe=Join-Path $package.InstallLocation 'app/ChatGPT.exe'
    $roots=@(Get-CimInstance Win32_Process | Where-Object {$_.ExecutablePath -eq $exe -and $_.CommandLine -notmatch '--type='})
    $port=9340
    $connected=@($roots|Where-Object {$_.CommandLine -match '--remote-debugging-port=9340(?: |$)'})
    if($Action -eq 'watch' -and -not $roots.Count){return}
    $restarted=$false
    if($Action -eq 'stop' -and -not $connected.Count){
        $config|ConvertTo-Json|Set-Content $configFile -Encoding UTF8
        Write-Output 'Automatic attachment disabled.';return
    }
    if(-not $connected.Count){
        if(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue){throw 'Local port 9340 is occupied. No processes stopped.'}
        if($Action -eq 'watch'){
            # One conversion per observed process; never loop on a failed restart.
            $restartFile=Join-Path $StateRoot 'watch-restart.json'
            $identity=(@($roots|ForEach-Object {"$($_.ProcessId):$($_.CreationDate.ToUniversalTime().Ticks)"})|Sort-Object) -join ','
            if(Test-Path $restartFile){
                $last=Get-Content $restartFile -Raw -Encoding UTF8|ConvertFrom-Json
                if($last.identity -eq $identity){throw 'Automatic connection already attempted for this process. Use Connect Codex to retry.'}
                if(([DateTime]::UtcNow-[DateTime]::Parse($last.at).ToUniversalTime()).TotalSeconds -lt 60){throw 'Waiting before another automatic connection attempt.'}
            }
            @{identity=$identity;at=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content $restartFile -Encoding UTF8
        }
        foreach($entry in $roots){
            $process=Get-Process -Id $entry.ProcessId -ErrorAction SilentlyContinue
            if($process){$null=$process.CloseMainWindow();$null=$process.WaitForExit(3000)}
        }
        # A tray process can survive CloseMainWindow. Only this installed app is stopped.
        Get-CimInstance Win32_Process | Where-Object {$_.ExecutablePath -eq $exe} | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        $deadline=[DateTime]::UtcNow.AddSeconds(15)
        while(@(Get-CimInstance Win32_Process|Where-Object {$_.ExecutablePath -eq $exe}).Count){if([DateTime]::UtcNow -gt $deadline){throw 'Codex did not exit.'};Start-Sleep -Milliseconds 300}
        $previous=@{}
        try{
            foreach($key in @('CODEX_HOME','CODEX_ELECTRON_USER_DATA_PATH')){$previous[$key]=[Environment]::GetEnvironmentVariable($key,'Process');[Environment]::SetEnvironmentVariable($key,$null,'Process')}
            # Codex is the user-facing window; only our helpers should start hidden.
            # Activate the registered Store application to preserve its Shell identity.
            & (Join-Path $PSScriptRoot 'Activate-Codex.ps1') -AppUserModelId ($package.PackageFamilyName+'!App') -Arguments '--remote-debugging-address=127.0.0.1 --remote-debugging-port=9340' | Out-Null
            $restarted=$true
        }finally{foreach($key in $previous.Keys){[Environment]::SetEnvironmentVariable($key,$previous[$key],'Process')}}
    }
    function Invoke-Session([string]$Id,[switch]$Ensure){
        $arguments=@((Join-Path $PSScriptRoot 'main-session.cjs'),$Id,'9340');if($Ensure){$arguments+='--ensure'}
        $output=& node @arguments 2>&1
        if($LASTEXITCODE -ne 0){throw ($output -join "`n")}
        Write-Output ($output -join "`n")
    }
    if($Action -eq 'stop'){Invoke-Session '--stop'}
    else{
        # A detected normal launch is converted once, then its pet window is restored.
        if($Action -ne 'watch' -or $restarted){
            $ready=$false
            for($attempt=0;$attempt -lt 12;$attempt++){try{Invoke-Session '--show';$ready=$true;break}catch{Start-Sleep -Milliseconds 500}}
            if(-not $ready){throw 'Codex did not expose its pet window. See logs.'}
        }
        if($config.enabled){
            if($config.player -eq 'native'){
                if($Action -ne 'watch' -or $restarted){
                    & node (Join-Path $PSScriptRoot 'install-native.cjs') $config.pet --main
                    if($LASTEXITCODE -ne 0){throw 'Native installation failed.'}
                    & node (Join-Path $PSScriptRoot 'activate-native.cjs') $config.pet $port --main
                    if($LASTEXITCODE -ne 0){throw 'Native selection failed.'}
                }
                Invoke-Session '--stop'
            }else{
                $applied=$false
                for($attempt=0;$attempt -lt 4;$attempt++){try{Invoke-Session $config.pet -Ensure:($Action -eq 'watch');$applied=$true;break}catch{if($Action -eq 'watch'){throw};Start-Sleep -Milliseconds 500}}
                if(-not $applied){throw 'Pet attachment failed.'}
            }
        }
    }
    if($Action -ne 'watch'){
        $temp=$configFile+'.tmp'
        $config|ConvertTo-Json|Set-Content $temp -Encoding UTF8
        Move-Item -LiteralPath $temp -Destination $configFile -Force
    }
    if($config.enabled){
        $bridgeFile=Join-Path $PSScriptRoot 'toolbar-bridge.cjs'
        $bridgePidFile=Join-Path $StateRoot 'toolbar.pid'
        $bridgeProcess=$null
        if(Test-Path $bridgePidFile){$bridgeId=0;if([int]::TryParse((Get-Content $bridgePidFile -Raw).Trim(),[ref]$bridgeId)){$bridgeProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$bridgeId" -ErrorAction SilentlyContinue}}
        if(-not $bridgeProcess -or $bridgeProcess.Name -ne 'node.exe' -or -not $bridgeProcess.CommandLine.Contains($bridgeFile)){
            $bridge=Start-Process -FilePath (Get-Command node).Source -ArgumentList @(('"'+$bridgeFile+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $StateRoot 'toolbar.out.log') -RedirectStandardError (Join-Path $StateRoot 'toolbar.err.log') -PassThru
            [IO.File]::WriteAllText($bridgePidFile,[string]$bridge.Id)
        }
    }
} finally {if($locked){$mutex.ReleaseMutex()};$mutex.Dispose()}
