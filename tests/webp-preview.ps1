$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationCore
. (Join-Path $PSScriptRoot '../scripts/WebPPreview.ps1')
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../pets/yuki-xlink-pro'))
$hashes=New-Object 'System.Collections.Generic.HashSet[string]'
$times=@();$sha=[Security.Cryptography.SHA256]::Create()
for($i=0;$i -lt 74;$i++){
 $watch=[Diagnostics.Stopwatch]::StartNew()
 $bitmap=Get-WebPPreviewFrame $root ([pscustomobject]@{file='assets/laptop.webp';imageFrame=$i})
 $watch.Stop();$times+=$watch.Elapsed.TotalMilliseconds
 if($bitmap.PixelWidth -gt 480 -or $script:webpFrames.Count -gt 8){throw 'Preview cache limit exceeded'}
 $bytes=New-Object byte[] ($bitmap.PixelWidth*$bitmap.PixelHeight*4);$bitmap.CopyPixels($bytes,$bitmap.PixelWidth*4,0)
 $null=$hashes.Add([Convert]::ToBase64String($sha.ComputeHash($bytes)))
}
if($hashes.Count -lt 60){throw 'Preview is not animated'}
Clear-WebPPreview
if($script:webpFrames.Count -or $script:webpSources.Count){throw 'Cache not cleared'}
$again=Get-WebPPreviewFrame $root ([pscustomobject]@{file='assets/laptop.webp';imageFrame=0})
Clear-WebPPreview
Write-Output ('WebP preview: {0} distinct frames; max cache 8; mean {1:N1}ms, max {2:N1}ms; reload passed' -f $hashes.Count,($times|Measure-Object -Average).Average,($times|Measure-Object -Maximum).Maximum)
