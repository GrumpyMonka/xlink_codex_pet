param([switch]$SmokeTest,[switch]$NativeInstallTest,[string]$ScreenshotPath,[ValidateSet("light","dark")][string]$SmokeTheme="light")
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
. (Join-Path $PSScriptRoot 'Common.ps1')
$managerGate=$null
if(-not $SmokeTest){
    New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null
    $managerGate=New-Object Threading.Mutex($false,'Local\XLinkPetsManager')
    $ownsManager=$false
    try{$ownsManager=$managerGate.WaitOne(0)}catch [Threading.AbandonedMutexException]{$ownsManager=$true}
    Add-Content -LiteralPath (Join-Path $StateRoot 'manager-open.log') -Value ((Get-Date -Format s)+" pid=$PID owns=$ownsManager") -Encoding UTF8
    if(-not $ownsManager){[IO.File]::WriteAllText((Join-Path $StateRoot 'open-manager.signal'),[guid]::NewGuid().ToString());$managerGate.Dispose();exit}
}
try {
    [xml]$markup=Get-Content -LiteralPath (Join-Path $RepoRoot 'player/manager.xaml') -Raw -Encoding UTF8
    $window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $markup))
    $ui=@{}
    foreach($name in @('PetList','ImportButton','RefreshButton','PetTitle','PetSummary','PlayerChoice','PetImage','ActionChoice','FrameInfo','BindingInfo','LicenseButton','AuthorInfo','BrandLogo','InstalledInfo','RuntimePath','BrowseButton','InstallButton','LaunchButton','LogsButton','Progress','Status','NativeNotice','LaunchIcon','LaunchLabel','NativePlayerOption','ThemeButton','ThemeIcon','SpeedPanel','SpeedSlider','SpeedLabel')) { $ui[$name]=$window.FindName($name) }
    $themeFile=Join-Path $StateRoot 'ui-settings.json'
    $script:theme='light'
    if(-not $SmokeTest -and (Test-Path $themeFile)){try{$savedTheme=Get-Content $themeFile -Raw -Encoding UTF8|ConvertFrom-Json;if($savedTheme.theme -eq 'dark'){$script:theme='dark'}}catch{}}
    if($SmokeTest){$script:theme=$SmokeTheme}
    $darkPalette=@{'223458'='343C50';'F3F5FA'='151820';'20283C'='E8ECF5';'E8ECF5'='2B3242';'25324B'='E5EAF4';'CCD3E2'='424B60';'DFE6FF'='34466D';'294BB8'='B7CAFF';'F0F3FC'='222938';'DFE7FF'='34466D';'E4E9F5'='2D3649';'63708A'='A4AFC4';'E7EBF3'='202635';'A6ADBB'='939EB2';'4165D5'='4165D5';'FFFFFF'='202530';'D9E0EE'='343C50';'EAF0FE'='343C50';'B5C5F3'='343C50';'6C8ADD'='343C50';'E1E6F0'='343C50';'EDF0F7'='343C50'}
    function Apply-Theme {
        foreach($color in $darkPalette.Keys){$hex=if($script:theme -eq 'dark'){$darkPalette[$color]}else{$color};$window.Resources['Brush'+$color]=[Windows.Media.BrushConverter]::new().ConvertFromString('#'+$hex)}
        $window.Resources['PlayerSelectedBackground']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($script:theme -eq 'dark'){'#4165D5'}else{'#FFFFFF'}))
        $window.Resources['PlayerSelectedForeground']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($script:theme -eq 'dark'){'#FFFFFF'}else{'#294BB8'}))
        $ui.ThemeIcon.Data=$window.Resources[$(if($script:theme -eq 'dark'){'SunIcon'}else{'MoonIcon'})]
        $ui.ThemeButton.ToolTip=if($script:theme -eq 'dark'){'Светлая тема'}else{'Тёмная тема'}
        if($script:codexIcons){$ui.LaunchIcon.Source=$script:codexIcons[$script:theme]}
    }
    $ui.ThemeButton.Add_Click({$script:theme=if($script:theme -eq 'dark'){'light'}else{'dark'};Apply-Theme;if(-not $SmokeTest){@{theme=$script:theme}|ConvertTo-Json|Set-Content -LiteralPath $themeFile -Encoding UTF8}})
    Apply-Theme
    $ui.LicenseInfo=$ui.LicenseButton.ToolTip.Content
    $brandPath=Join-Path $RepoRoot 'player/assets/xlink.png'
    $brandImage=[Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri $brandPath))
    $ui.BrandLogo.Source=$brandImage;$window.Icon=$brandImage
    $ui.LicenseButton.Add_Click({
        $licenseUri=$null
        if([Uri]::TryCreate([string]$script:pet.license.url,[UriKind]::Absolute,[ref]$licenseUri) -and $licenseUri.Scheme -eq 'https'){
            $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$licenseUri.AbsoluteUri;$start.UseShellExecute=$true;$null=[Diagnostics.Process]::Start($start)
        }else{$ui.LicenseButton.ToolTip.IsOpen=$true}
    })
    $package=Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue | Select-Object -First 1
    $script:codexIcons=@{}
    foreach($variant in @('light','dark')){
        $paths=@()
        if($package){$paths+=Join-Path $package.InstallLocation ('app/resources/chatgpt-app-'+$variant+'.ico')}
        $paths+=Join-Path $RepoRoot ('player/assets/chatgpt-app-'+$variant+'.png')
        foreach($icon in $paths){if(Test-Path -LiteralPath $icon){$decoder=[Windows.Media.Imaging.BitmapDecoder]::Create((New-Object Uri $icon),[Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[Windows.Media.Imaging.BitmapCacheOption]::OnLoad);$script:codexIcons[$variant]=$decoder.Frames|Sort-Object PixelWidth -Descending|Select-Object -First 1;break}}
    }
    Apply-Theme
    $script:pet=$null;$script:cache=@{};$script:loading=$false;$script:paused=$false;$script:job=$null;$script:currentFrame=-1
    $script:clock=[Diagnostics.Stopwatch]::StartNew()
    $script:speed=1.0;$script:previewElapsed=0.0;$script:previewLast=0.0;$script:speedPending=$false;$script:speedSaveAt=[DateTime]::MaxValue
    $script:speeds=@{};$playbackFile=Join-Path $StateRoot 'playback-settings.json'
    if(Test-Path $playbackFile){try{$playback=Get-Content $playbackFile -Raw -Encoding UTF8|ConvertFrom-Json;foreach($entry in $playback.speeds.psobject.Properties){$value=[double]$entry.Value;if($value -ge 0.2 -and $value -le 5){$script:speeds[$entry.Name]=$value}}}catch{}}
    function Update-SpeedLabel {$ui.SpeedLabel.Text='×'+$script:speed.ToString('0.##',[Globalization.CultureInfo]::GetCultureInfo('ru-RU'))}
    function Save-Speed {
        if(-not $script:speedPending -or $SmokeTest){return}
        New-Item -ItemType Directory -Force -Path $StateRoot|Out-Null
        $temp=$playbackFile+'.tmp';@{speeds=$script:speeds}|ConvertTo-Json|Set-Content -LiteralPath $temp -Encoding UTF8
        Move-Item -LiteralPath $temp -Destination $playbackFile -Force;$script:speedPending=$false
    }
    $ui.SpeedSlider.Add_ValueChanged({
        if($script:loading -or -not $script:pet){return}
        Draw-Frame
        $script:speed=[Math]::Pow(5,[double]$ui.SpeedSlider.Value);Update-SpeedLabel
        $script:speeds[$script:pet.id]=$script:speed;$script:speedPending=$true;$script:speedSaveAt=[DateTime]::UtcNow.AddMilliseconds(200)
    })
    $ui.SpeedLabel.Add_MouseLeftButtonDown({$ui.SpeedSlider.Value=0})
    $actionNames=@{idle='Ожидание';dance='Танец';walk='Ходьба';think='Размышление';pat='Поглаживание';sad='Грусть';running='Бег';'running-left'='Бег влево';'running-right'='Бег вправо';waving='Приветствие';jumping='Прыжок';review='Проверка';waiting='Ожидание ответа';failed='Ошибка'}
    $script:logWindow=$null;$script:closingMain=$false
    $ui.Log=New-Object Windows.Controls.TextBox
    $ui.Log.IsReadOnly=$true;$ui.Log.AcceptsReturn=$true;$ui.Log.TextWrapping='NoWrap'
    $ui.Log.VerticalScrollBarVisibility='Auto';$ui.Log.HorizontalScrollBarVisibility='Auto'
    $ui.Log.FontFamily='Consolas';$ui.Log.FontSize=14;$ui.Log.Padding='16';$ui.Log.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'BrushFFFFFF');$ui.Log.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'Brush20283C')
    function Open-Logs {
        $watchLog=Join-Path $StateRoot 'main-watch.log'
        if(Test-Path $watchLog){Write-Log (Get-Content $watchLog -Raw -Encoding UTF8)}
        if(-not $script:logWindow){
            $script:logWindow=New-Object Windows.Window
            $script:logWindow.Title='XLink Codex Pets — логи';$script:logWindow.Width=1000;$script:logWindow.Height=720
            $script:logWindow.Icon=$window.Icon;$script:logWindow.MinWidth=640;$script:logWindow.MinHeight=400;$script:logWindow.Owner=$window
            $script:logWindow.WindowStartupLocation='CenterOwner';$script:logWindow.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'BrushF3F5FA')
            $script:logWindow.Resources=$window.Resources
            $panel=New-Object Windows.Controls.DockPanel;$panel.Margin='20'
            $bar=New-Object Windows.Controls.StackPanel;$bar.Orientation='Horizontal';$bar.Margin='0,0,0,12'
            [Windows.Controls.DockPanel]::SetDock($bar,'Top')
            $copy=New-Object Windows.Controls.Button;$copy.Content='Копировать всё';$copy.Margin='0,0,10,0';$copy.Add_Click({[Windows.Clipboard]::SetText($ui.Log.Text)})
            $save=New-Object Windows.Controls.Button;$save.Content='Сохранить в файл…';$save.Add_Click({$dialog=New-Object Microsoft.Win32.SaveFileDialog;$dialog.Filter='Текстовый файл|*.txt';$dialog.FileName='codex-pets-logs.txt';if($dialog.ShowDialog()) {[IO.File]::WriteAllText($dialog.FileName,$ui.Log.Text,(New-Object Text.UTF8Encoding($true)))}})
            $null=$bar.Children.Add($copy);$null=$bar.Children.Add($save);$null=$panel.Children.Add($bar);$null=$panel.Children.Add($ui.Log)
            $script:logWindow.Content=$panel
            $script:logWindow.Add_Closing({param($sender,$event)if(-not $script:closingMain){$event.Cancel=$true;$sender.Hide()}})
        }
        $script:logWindow.Show();$null=$script:logWindow.Activate();$ui.Log.ScrollToEnd()
    }
    function Update-PlayerMode {
        $native=$ui.PlayerChoice.SelectedItem.Tag -eq 'native'
        $supported=$script:pet -and $script:capabilities.($script:pet.id).supported
        $ui.NativePlayerOption.IsEnabled=[bool]$supported
        $ui.NativePlayerOption.ToolTip=if($supported){'Установить в штатный плеер Codex'}else{'Для этого питомца не подготовлен нативный спрайт-лист'}
        if($native -and -not $supported){$ui.PlayerChoice.SelectedIndex=0;$native=$false}
        $ui.InstallButton.Content=if($native){'Добавить в Codex'}else{'Применить питомца'}
        $ui.InstallButton.IsEnabled=(-not $script:job) -and ((-not $native) -or $supported)
        $ui.NativeNotice.Visibility='Collapsed';$ui.PetImage.Visibility='Visible'
        foreach($name in @('ActionChoice','FrameInfo','BindingInfo')){$ui[$name].Visibility='Visible'}
        $ui.SpeedPanel.Visibility=if($native){'Collapsed'}else{'Visible'}
        $ui.PetList.IsEnabled=-not $script:job
    }
    function Write-Log([string]$Message) { $ui.Log.AppendText($Message+[Environment]::NewLine);$ui.Log.ScrollToEnd() }
    function Update-Installed {
        $mainFile=Join-Path $StateRoot 'main-settings.json'
        $ui.InstalledInfo.Text='Основной Codex — питомец ещё не подключён'
        if(Test-Path $mainFile){$main=Get-Content $mainFile -Raw -Encoding UTF8|ConvertFrom-Json;$ui.InstalledInfo.Text=if($main.enabled){'Основной Codex: '+$main.pet+' / '+$(if($main.player -eq 'native'){'Codex'}else{'XLink Player'})}else{'Основной Codex — штатный плеер'}}
        $ui.RuntimePath.Visibility='Collapsed';$ui.BrowseButton.Visibility='Collapsed'

    }
    $script:connectionAction='launch'
    function Update-Connection {
        if($script:job){return}
        $file=Join-Path $StateRoot 'connection.json'
        if(-not (Test-Path $file)){$ui.LaunchLabel.Text='Проверка Codex…';$ui.LaunchButton.IsEnabled=$false;return}
        try{$state=Get-Content $file -Raw -Encoding UTF8|ConvertFrom-Json;if(([DateTime]::UtcNow-[DateTime]::Parse($state.checkedAt).ToUniversalTime()).TotalSeconds -gt 15){$ui.LaunchLabel.Text='Проверка Codex…';$ui.LaunchButton.IsEnabled=$false;return}}catch{return}
        $ui.LaunchButton.IsEnabled=$true
        if($state.connected){$script:connectionAction='restore';$ui.LaunchLabel.Text='Отключиться Codex';$ui.LaunchButton.ToolTip='Отключить XLink Player и вернуть штатное отображение'}
        elseif($state.running){$script:connectionAction='connect';$ui.LaunchLabel.Text='Подключить Codex';$ui.LaunchButton.ToolTip='Подключить питомца. Если канал управления не включён, Codex будет перезапущен.'}
        else{$script:connectionAction='launch';$ui.LaunchLabel.Text='Запустить Codex';$ui.LaunchButton.ToolTip='Запустить Codex и автоматически подключить питомца'}
    }
    function Set-Busy([bool]$Busy) {
        foreach($name in @('PetList','ImportButton','RefreshButton','PlayerChoice','InstallButton','LaunchButton','LogsButton','BrowseButton','RuntimePath')){$ui[$name].IsEnabled=-not $Busy}
        $ui.Progress.IsIndeterminate=$Busy
        if(-not $Busy){Update-Connection;Update-PlayerMode}
    }
    function Get-FrameBitmap($Frame) {
        $key=$Frame.file+':'+($Frame.rect -join ',');if($script:cache.ContainsKey($key)){return $script:cache[$key]}
        $root=[IO.Path]::GetFullPath((Join-Path $RepoRoot ('pets/'+$script:pet.id)))
        if($Frame.file -notmatch '^[a-zA-Z0-9_./-]+\.png$' -or $Frame.file.StartsWith('/') -or ($Frame.file -split '/') -contains '..'){throw 'Invalid preview asset path.'}
        $asset=[IO.Path]::GetFullPath((Join-Path $root $Frame.file));if(-not $asset.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Preview asset is outside package.'}
        $bitmap=New-Object Windows.Media.Imaging.BitmapImage;$bitmap.BeginInit();$bitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$bitmap.UriSource=New-Object Uri $asset
        if(-not $Frame.rect){$bitmap.DecodePixelHeight=600};$bitmap.EndInit();$bitmap.Freeze()
        if($Frame.rect){$r=$Frame.rect;$bitmap=New-Object Windows.Media.Imaging.CroppedBitmap($bitmap,(New-Object Windows.Int32Rect([int]$r[0],[int]$r[1],[int]$r[2],[int]$r[3])));$bitmap.Freeze()}
        $script:cache[$key]=$bitmap;return $bitmap
    }
    function Draw-Frame {
        if(-not $script:pet -or -not $ui.ActionChoice.SelectedItem){return}
        $action=$script:pet.actions.($ui.ActionChoice.SelectedItem.id);$frames=@($action.frames);$duration=($frames.durationMs|Measure-Object -Sum).Sum;if($duration -le 0){return}
        $now=$script:clock.Elapsed.TotalMilliseconds;$script:previewElapsed+=[Math]::Max(0,$now-$script:previewLast)*$script:speed;$script:previewLast=$now
        $time=$script:previewElapsed % $duration;$index=0;while($index -lt $frames.Count-1 -and $time -ge $frames[$index].durationMs){$time-=$frames[$index].durationMs;$index++}
        if($index -ne $script:currentFrame){$ui.PetImage.Source=Get-FrameBitmap $frames[$index];$script:currentFrame=$index}
    }
    function Select-Action {
        if($script:loading -or -not $ui.ActionChoice.SelectedItem){return}
        $id=$ui.ActionChoice.SelectedItem.id;$frames=@($script:pet.actions.$id.frames);$ms=($frames.durationMs|Measure-Object -Sum).Sum
        $culture=[Globalization.CultureInfo]::GetCultureInfo('ru-RU')
        $seconds=($ms/1000).ToString('0.###',$culture)
        $fps=($frames.Count*1000/$ms).ToString('0.##',$culture)
        $sizes=@($frames|ForEach-Object {
            if($_.rect){'{0} × {1}' -f $_.rect[2],$_.rect[3]}
            else{
                $asset=Join-Path $RepoRoot ('pets/'+$script:pet.id+'/'+$_.file)
                $stream=[IO.File]::OpenRead($asset)
                try{$header=New-Object byte[] 24;if($stream.Read($header,0,24) -ne 24){throw 'Incomplete PNG header'}}finally{$stream.Dispose()}
                $width=[uint32]$header[16]*16777216+[uint32]$header[17]*65536+[uint32]$header[18]*256+$header[19]
                $height=[uint32]$header[20]*16777216+[uint32]$header[21]*65536+[uint32]$header[22]*256+$header[23]
                '{0} × {1}' -f $width,$height
            }
        }|Select-Object -Unique)
        $ui.FrameInfo.Text=('{0} кадров' -f $frames.Count)+[Environment]::NewLine+$seconds+' с'+[Environment]::NewLine+'FPS: '+$fps+' (средний)'+[Environment]::NewLine+'Размер: '+($sizes -join ', ')+' px'
        $events=@($script:pet.bindings.psobject.Properties|Where-Object{$_.Value.action -eq $id}|ForEach-Object{$_.Name});if($script:pet.idleSequence -contains $id){$events+= 'цикл idle'}
        $ui.BindingInfo.Text='Событие Codex: '+$(if($events.Count){$events -join ', '}else{'—'});$script:currentFrame=-1;$script:clock.Restart();$script:previewElapsed=0.0;$script:previewLast=0.0;if($script:paused){$script:clock.Stop()};Draw-Frame
    }
    function Select-Pet {
        if($script:loading -or -not $ui.PetList.SelectedItem){return}
        $script:pet=$ui.PetList.SelectedItem;$script:cache=@{};$ui.PetTitle.Text=$script:pet.name;$ui.PetSummary.Text=('{0} действий · {1}' -f @($script:pet.actions.psobject.Properties).Count,$script:pet.id);$ui.LicenseInfo.Text=$script:pet.license.text
        $script:speed=if($script:speeds.ContainsKey($script:pet.id)){[double]$script:speeds[$script:pet.id]}else{1.0}
        $script:loading=$true;$ui.SpeedSlider.Value=[Math]::Log($script:speed,5);$script:loading=$false;Update-SpeedLabel
        if($script:pet.license.url){$ui.LicenseInfo.Text='Открыть лицензию / README'+[Environment]::NewLine+$script:pet.license.url}
        $ui.AuthorInfo.Inlines.Clear()
        $author=$script:pet.author
        if($author -and $author.name){
            $null=$ui.AuthorInfo.Inlines.Add('(')
            $authorUri=$null
            if([Uri]::TryCreate([string]$author.url,[UriKind]::Absolute,[ref]$authorUri) -and $authorUri.Scheme -eq 'https'){
                $link=New-Object Windows.Documents.Hyperlink
                $link.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty,'Brush294BB8')
                $null=$link.Inlines.Add([string]$author.name);$link.NavigateUri=$authorUri
                $link.Add_RequestNavigate({param($sender,$event)$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$event.Uri.AbsoluteUri;$start.UseShellExecute=$true;$null=[Diagnostics.Process]::Start($start);$event.Handled=$true})
                $null=$ui.AuthorInfo.Inlines.Add($link)
            }else{$null=$ui.AuthorInfo.Inlines.Add([string]$author.name)}
            $null=$ui.AuthorInfo.Inlines.Add(')')
        }
        $script:loading=$true;$items=@($script:pet.actions.psobject.Properties|ForEach-Object{$id=$_.Name;$label=if($_.Value.label){[string]$_.Value.label}elseif($actionNames.ContainsKey($id)){$actionNames[$id]}else{$id};[pscustomobject]@{id=$id;label=$label}});$ui.ActionChoice.ItemsSource=$items;$ui.ActionChoice.SelectedIndex=0;$script:loading=$false;Select-Action;Update-PlayerMode
    }
    function Refresh-Pets {
        $json=& node (Join-Path $PSScriptRoot 'install-native.cjs') --capabilities
        if($LASTEXITCODE -ne 0){throw 'Unable to inspect native compatibility'}
        $script:capabilities=$json | ConvertFrom-Json
        $selected=if($script:pet){$script:pet.id}else{''};$pets=@();foreach($directory in Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'pets') -Directory){$file=Join-Path $directory.FullName 'pet.json';if(Test-Path $file){try{$p=Get-Content $file -Raw -Encoding UTF8|ConvertFrom-Json;if($p.id -ne $directory.Name -or $p.id -notmatch '^[a-z0-9][a-z0-9-]{0,63}$' -or $p.formatVersion -ne 1){throw 'Invalid pet metadata'};$pets+=$p}catch{Write-Log "Пропущен пакет $($directory.Name): $($_.Exception.Message)"}}}
        $script:loading=$true;$ui.PetList.ItemsSource=$pets;$ui.PetList.SelectedIndex=0;for($i=0;$i -lt $pets.Count;$i++){if($pets[$i].id -eq $selected){$ui.PetList.SelectedIndex=$i}};$script:loading=$false;Select-Pet;Update-Installed
    }
    function Start-Operation([string]$Operation,[string]$Source='') {
        if($script:job){return};if($Operation -in @('install','validate') -and -not $script:pet){return}
        New-Item -ItemType Directory -Force -Path (Join-Path $StateRoot 'manager')|Out-Null
        $request=Join-Path $StateRoot ('manager/'+[guid]::NewGuid().ToString()+'.json');$data=@{operation=$Operation;pet=$script:pet.id;runtime=$ui.RuntimePath.Text;source=$Source;player=$ui.PlayerChoice.SelectedItem.Tag};$data|ConvertTo-Json|Set-Content -LiteralPath $request -Encoding UTF8
        $worker=Join-Path $PSScriptRoot 'ManagerAction.ps1';$code="& '"+$worker.Replace("'","''")+"' -RequestFile '"+$request.Replace("'","''")+"'";$encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $process=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -WindowStyle Hidden -RedirectStandardOutput ($request+'.out') -RedirectStandardError ($request+'.err') -PassThru
        $script:job=@{process=$process;request=$request;operation=$Operation};Set-Busy $true;$ui.Status.Text='Выполняется операция…';Write-Log "Начато: $Operation"
    }
    function Browse-Folder([string]$Title) {$dialog=New-Object System.Windows.Forms.FolderBrowserDialog;$dialog.Description=$Title;try{if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){return $dialog.SelectedPath}}finally{$dialog.Dispose()};return $null}
    $ui.PetList.Add_SelectionChanged({try{Select-Pet}catch{$ui.Status.Text=$_.Exception.Message;Write-Log $_.Exception.Message}})
    $ui.ActionChoice.Add_SelectionChanged({try{Select-Action}catch{$ui.Status.Text=$_.Exception.Message}})
    $ui.RefreshButton.Add_Click({Refresh-Pets})
    $ui.ImportButton.Add_Click({$source=Browse-Folder 'Выберите папку питомца с файлом pet.json';if($source){Start-Operation 'import' $source}})
    $ui.BrowseButton.Add_Click({$folder=Browse-Folder 'Выберите родительскую папку: копия Codex будет создана в подпапке CodexPets';if($folder){$ui.RuntimePath.Text=Join-Path $folder 'CodexPets'}})
    $ui.InstallButton.Add_Click({if($ui.PlayerChoice.SelectedItem.Tag -eq 'native'){Start-Operation 'install-native'}else{Start-Operation 'install'}})
    $ui.LaunchButton.Add_Click({Update-Connection;if($ui.LaunchButton.IsEnabled){Start-Operation $script:connectionAction}})

    $ui.LogsButton.Add_Click({Open-Logs})

    $ui.PlayerChoice.Add_SelectionChanged({$ui.Status.Text='';Update-PlayerMode;Set-Busy ([bool]$script:job)})
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(33)
    $script:activationPoll=[DateTime]::MinValue
    $timer.Add_Tick({try{
        if($script:speedPending -and [DateTime]::UtcNow -ge $script:speedSaveAt){Save-Speed}
        if([DateTime]::UtcNow -gt $script:activationPoll){
            $script:activationPoll=[DateTime]::UtcNow.AddMilliseconds(400)
            Update-Connection
            $signal=Join-Path $StateRoot 'open-manager.signal'
            if(Test-Path $signal){Remove-Item -LiteralPath $signal -ErrorAction SilentlyContinue;$window.Show();if($window.WindowState -eq 'Minimized'){$window.WindowState='Normal'};$window.Topmost=$true;$null=$window.Activate();$window.Topmost=$false}
        }
        if(-not $script:paused){Draw-Frame}
        if($script:job -and $script:job.process.HasExited){$job=$script:job;$script:job=$null;foreach($suffix in @('.out','.err')){if(Test-Path ($job.request+$suffix)){Write-Log (Get-Content ($job.request+$suffix) -Raw -Encoding UTF8)}};$resultFile=$job.request+'.result.json';if(Test-Path $resultFile){$result=Get-Content $resultFile -Raw -Encoding UTF8|ConvertFrom-Json;if($result.success){$ui.Status.Text=switch($job.operation){'install-native'{'Питомец установлен и выбран в штатном Codex.'}'install'{'Выбор сохранён. Открытый плеер подхватит его автоматически.'}'launch'{'Codex запущен и подключён.'}'connect'{'Codex подключён.'}'restore'{'Отключено. Codex продолжает работать.'}'validate'{'Пакет прошёл проверку.'}'import'{'Питомец добавлен в библиотеку.'}}}else{$ui.Status.Text='Ошибка: '+$result.message}}else{$ui.Status.Text='Операция завершилась без результата. Откройте журнал.'};Refresh-Pets;Set-Busy $false;$job.process.Dispose()}
    }catch{$ui.Status.Text=$_.Exception.Message;Write-Log $_.Exception.Message}})
    $window.Add_Closing({param($sender,$event)if($script:job){$event.Cancel=$true;$ui.Status.Text='Дождитесь завершения операции перед закрытием.'}else{Save-Speed;$script:closingMain=$true;$timer.Stop();if($script:logWindow){$script:logWindow.Close()}}})
    if(-not $SmokeTest){
        $watchCommand="& '"+(Join-Path $PSScriptRoot 'Watch-Main.ps1').Replace("'","''")+"' -OwnerId $PID"
        $watchEncoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($watchCommand))
        $script:watcher=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$watchEncoded) -WindowStyle Hidden -PassThru
    }
    $logDir=Join-Path $StateRoot 'manager'
    if(Test-Path $logDir){foreach($entry in Get-ChildItem -LiteralPath $logDir -Filter '*.result.json' | Sort-Object LastWriteTime){
        $request=$entry.FullName.Substring(0,$entry.FullName.Length-12)
        Write-Log ('── '+$entry.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')+' ──')
        foreach($file in @($request,($request+'.out'),($request+'.err'),$entry.FullName)){if(Test-Path -LiteralPath $file){Write-Log (Get-Content -LiteralPath $file -Raw -Encoding UTF8)}}
    }}
    Refresh-Pets;Set-Busy $false;$timer.Start()
    if($SmokeTest){
        Start-Operation 'validate'
        $waitFrame=New-Object Windows.Threading.DispatcherFrame;$deadline=[DateTime]::UtcNow.AddSeconds(25)
        $waitTimer=New-Object Windows.Threading.DispatcherTimer;$waitTimer.Interval=[TimeSpan]::FromMilliseconds(100)
        $waitTimer.Add_Tick({if(-not $script:job -or [DateTime]::UtcNow -gt $deadline){$waitFrame.Continue=$false}});$waitTimer.Start()
        [Windows.Threading.Dispatcher]::PushFrame($waitFrame);$waitTimer.Stop()
        if($script:job -or $ui.Status.Text -ne 'Пакет прошёл проверку.'){throw ('GUI worker test failed: '+$ui.Status.Text+' '+$ui.Log.Text)}
    }
    if($NativeInstallTest){
        $ui.PetList.SelectedItem=@($ui.PetList.ItemsSource|Where-Object id -eq 'yuki')[0];Select-Pet
        $ui.PlayerChoice.SelectedIndex=1
        $ui.InstallButton.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
        $waitFrame=New-Object Windows.Threading.DispatcherFrame;$deadline=[DateTime]::UtcNow.AddSeconds(30)
        $waitTimer=New-Object Windows.Threading.DispatcherTimer;$waitTimer.Interval=[TimeSpan]::FromMilliseconds(100)
        $waitTimer.Add_Tick({if(-not $script:job -or [DateTime]::UtcNow -gt $deadline){$waitFrame.Continue=$false}});$waitTimer.Start()
        [Windows.Threading.Dispatcher]::PushFrame($waitFrame);$waitTimer.Stop()
        if($script:job -or $ui.Status.Text -notmatch '^Питомец установлен и выбран'){throw ('Native install button failed: '+$ui.Status.Text)}
        Write-Output 'Native install button passed.'
        $ui.PlayerChoice.SelectedIndex=0
    }
    if($SmokeTest){
        $ui.PlayerChoice.SelectedIndex=1
        foreach($p in @($ui.PetList.ItemsSource)){
            $ui.PetList.SelectedItem=$p;Select-Pet;Update-PlayerMode
            if($ui.NativePlayerOption.IsEnabled -ne [bool]$script:capabilities.($p.id).supported){throw 'Native compatibility gating failed'};if(-not $script:capabilities.($p.id).supported -and $ui.PlayerChoice.SelectedItem.Tag -ne 'canvas'){throw 'Automatic player fallback failed'}
            if($script:capabilities.($p.id).supported){$ui.PlayerChoice.SelectedIndex=1;Update-PlayerMode;if($ui.SpeedPanel.Visibility -ne 'Collapsed'){throw 'Native mode must hide animation speed'}}
            $ui.PlayerChoice.SelectedIndex=0;Update-PlayerMode;if($ui.SpeedPanel.Visibility -ne 'Visible'){throw 'XLink mode must show animation speed'}
        }
        foreach($testValue in @(-1,0,1)){$ui.SpeedSlider.Value=$testValue;if([Math]::Abs($script:speed-[Math]::Pow(5,$testValue)) -gt 0.00001){throw 'Speed slider mapping failed'}};$ui.SpeedSlider.Value=0
        $ui.PlayerChoice.SelectedIndex=0
        if(-not $ui.InstallButton.IsEnabled){throw 'Canvas mode failed'}
        $window.Show();Open-Logs
        if(-not $script:logWindow.IsVisible -or $ui.Log.Text.Length -eq 0){throw 'Log window failed'}
        $script:logWindow.Close()
        if($script:logWindow.IsVisible){throw 'Log window must hide'}
        Open-Logs;$script:logWindow.Hide()
        Write-Output 'Player compatibility and separate log window passed.'
        $window.Show();$window.UpdateLayout();$count=0;foreach($p in @($ui.PetList.ItemsSource)){$ui.PetList.SelectedItem=$p;Select-Pet;foreach($a in $p.actions.psobject.Properties){foreach($f in $a.Value.frames){$null=Get-FrameBitmap $f;$count++}}};$ui.PetList.SelectedIndex=0;Select-Pet;$window.UpdateLayout();$window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Render);if($ScreenshotPath){$render=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($window);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render));$stream=[IO.File]::Create($ScreenshotPath);try{$encoder.Save($stream)}finally{$stream.Dispose()}};$timer.Stop();$window.Close();Write-Output "GUI smoke test passed: $count frame references decoded."}
    else{$null=$window.ShowDialog()}
} catch {if($SmokeTest){throw};[System.Windows.MessageBox]::Show($_.Exception.Message,'XLink Codex Pets',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error)|Out-Null;exit 1}

finally {if($managerGate -and $ownsManager){$managerGate.ReleaseMutex();$managerGate.Dispose()}}
