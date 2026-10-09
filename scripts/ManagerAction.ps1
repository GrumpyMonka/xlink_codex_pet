param([Parameter(Mandatory=$true)][string]$RequestFile)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$global:LASTEXITCODE=0
$request=Get-Content -LiteralPath $RequestFile -Raw -Encoding UTF8 | ConvertFrom-Json
$resultFile=$RequestFile+'.result.json'
try {
    switch ($request.operation) {
        'install-native' { & (Join-Path $PSScriptRoot 'Main.ps1') -Action apply -Pet $request.pet -Player native }
        'install' { & (Join-Path $PSScriptRoot 'Main.ps1') -Action apply -Pet $request.pet -Player $request.player }
        'launch' { & (Join-Path $PSScriptRoot 'Main.ps1') -Action apply -Pet $request.pet -Player $request.player }
        'connect' { & (Join-Path $PSScriptRoot 'Main.ps1') -Action apply -Pet $request.pet -Player $request.player }
        'restore' { & (Join-Path $PSScriptRoot 'Main.ps1') -Action stop }
        'validate' { & node (Join-Path $PSScriptRoot 'validate.cjs') $request.pet }
        'import' { & node (Join-Path $PSScriptRoot 'import-pet.cjs') $request.source }
        default { throw 'Unknown manager operation.' }
    }
    if($LASTEXITCODE -ne 0){ throw "Operation failed (exit code $LASTEXITCODE). See the log for details." }
    @{success=$true;operation=$request.operation} | ConvertTo-Json | Set-Content -LiteralPath $resultFile -Encoding UTF8
} catch {
    Write-Output $_.Exception.Message
    @{success=$false;operation=$request.operation;message=$_.Exception.Message} | ConvertTo-Json | Set-Content -LiteralPath $resultFile -Encoding UTF8
    exit 1
}
