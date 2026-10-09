param([Parameter(Mandatory=$true)][int]$OwnerId)
$ErrorActionPreference='Stop'
$owner=Get-Process -Id $OwnerId -ErrorAction SilentlyContinue
if(-not $owner){exit}
$started=$owner.StartTime
$state=Join-Path (Split-Path $PSScriptRoot -Parent) '.runtime'
New-Item -ItemType Directory -Force -Path $state | Out-Null
$lastMessage=''
while($true){
    $owner=Get-Process -Id $OwnerId -ErrorAction SilentlyContinue
    if(-not $owner -or $owner.StartTime -ne $started){break}
    # Bootstrap only; the persistent bridge owns recovery while this window is closed.
    $bridge=$null
    $pidFile=Join-Path $state 'toolbar.pid'
    if(Test-Path $pidFile){$bridgeId=0;if([int]::TryParse((Get-Content $pidFile -Raw).Trim(),[ref]$bridgeId)){$bridge=Get-CimInstance Win32_Process -Filter "ProcessId=$bridgeId" -ErrorAction SilentlyContinue}}
    if(-not $bridge -or $bridge.Name -ne 'node.exe' -or -not $bridge.CommandLine.Contains((Join-Path $PSScriptRoot 'toolbar-bridge.cjs'))){
        try{& (Join-Path $PSScriptRoot 'Main.ps1') -Action watch | Out-Null;$message='Connected or waiting for Codex.'}catch{$message=$_.Exception.Message}
    }else{$message='Background bridge is monitoring Codex.'}
    if($message -ne $lastMessage){Add-Content -LiteralPath (Join-Path $state 'main-watch.log') -Value ((Get-Date -Format s)+' '+$message) -Encoding UTF8;$lastMessage=$message}
    try{& (Join-Path $PSScriptRoot 'Connection-State.ps1')}catch{}
    Start-Sleep -Seconds 2
}
