param([Parameter(Mandatory=$true)][int]$OwnerId,[switch]$SmokeTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class XLinkTrayNative {
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr icon);
}
'@
$owner=Get-Process -Id $OwnerId -ErrorAction SilentlyContinue
if(-not $owner){return}
$ownerStarted=$owner.StartTime
$repo=Split-Path $PSScriptRoot -Parent
$gate=New-Object Threading.Mutex($false,'Local\XLinkCodexPetsTray')
$locked=$false
$tray=$null;$timer=$null;$icon=$null;$menu=$null
try{
    try{$locked=$gate.WaitOne(0)}catch [Threading.AbandonedMutexException]{$locked=$true}
    if(-not $locked){return}
    $bitmap=New-Object Drawing.Bitmap((Join-Path $repo 'player/assets/xlink.png'))
    try{
        $handle=$bitmap.GetHicon()
        try{$icon=[Drawing.Icon]::FromHandle($handle).Clone()}finally{[void][XLinkTrayNative]::DestroyIcon($handle)}
    }finally{$bitmap.Dispose()}
    $context=New-Object Windows.Forms.ApplicationContext
    $tray=New-Object Windows.Forms.NotifyIcon
    $tray.Icon=$icon;$tray.Text='XLink Codex Pets'
    $menu=New-Object Windows.Forms.ContextMenuStrip
    $open=$menu.Items.Add('Открыть XLink Codex Pets')
    [void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
    $quit=$menu.Items.Add('Exit')
    $openManager={
        Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'Manager.ps1')+'"')) -WindowStyle Hidden
    }
    $open.Add_Click($openManager)
    $tray.Add_DoubleClick($openManager)
    $script:exitWorker=$null
    $quit.Add_Click({
        if($script:exitWorker){return}
        $quit.Enabled=$false;$open.Enabled=$false;$tray.Text='XLink Codex Pets — отключение'
        $script:exitWorker=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'Restore.ps1')+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $repo '.runtime/tray-stop.log') -RedirectStandardError (Join-Path $repo '.runtime/tray-stop-error.log')
    })
    $tray.ContextMenuStrip=$menu;$tray.Visible=$true
    $timer=New-Object Windows.Forms.Timer
    $timer.Interval=500
    $timer.Add_Tick({
        if($script:exitWorker -and $script:exitWorker.HasExited){
            if($script:exitWorker.ExitCode -ne 0){
                $tray.ShowBalloonTip(5000,'Не удалось отключить питомца','Повторите Exit. Подробности: .runtime/tray-stop-error.log',[Windows.Forms.ToolTipIcon]::Error)
                $quit.Enabled=$true;$open.Enabled=$true;$tray.Text='XLink Codex Pets'
            }
            $script:exitWorker.Dispose();$script:exitWorker=$null
        }
        $current=Get-Process -Id $OwnerId -ErrorAction SilentlyContinue
        if(-not $current -or $current.StartTime -ne $ownerStarted){$tray.Visible=$false;$context.ExitThread()}
    })
    $timer.Start()
    if($SmokeTest){
        if($menu.Items.Count -ne 3 -or -not $tray.Icon -or -not $tray.Visible){throw 'Tray smoke test failed.'}
        Write-Output 'Tray icon and menu passed.'
    }else{[Windows.Forms.Application]::Run($context)}
}finally{
    if($timer){$timer.Stop();$timer.Dispose()}
    if($tray){$tray.Visible=$false;$tray.Dispose()}
    if($menu){$menu.Dispose()};if($icon){$icon.Dispose()}
    if($locked){$gate.ReleaseMutex()};$gate.Dispose()
}
