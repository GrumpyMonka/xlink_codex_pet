# Decode only the requested preview frame. No extracted PNGs or full-animation bitmap cache.
$script:webpSources=@{}
$script:webpFrames=@{}
$script:webpOrder=New-Object 'System.Collections.Generic.Queue[string]'
function Clear-WebPPreview {
    $script:webpFrames.Clear();$script:webpOrder.Clear()
    foreach($entry in $script:webpSources.Values){$entry.stream.Dispose()}
    $script:webpSources.Clear()
}
function Get-WebPPreviewFrame([string]$Root,$Frame) {
    $name=[string]$Frame.file
    if($name -notmatch '^[a-zA-Z0-9_./-]+\.webp$' -or $name.StartsWith('/') -or ($name -split '/') -contains '..'){throw 'Invalid WebP preview path'}
    $asset=[IO.Path]::GetFullPath((Join-Path $Root $name))
    if(-not $asset.StartsWith([IO.Path]::GetFullPath($Root)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'WebP outside pet directory'}
    $index=[int]$Frame.imageFrame;$key=$asset+':'+$index
    if($script:webpFrames.ContainsKey($key)){return $script:webpFrames[$key]}
    if(-not $script:webpSources.ContainsKey($asset)){
        $stream=[IO.File]::Open($asset,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try{
            $decoder=[Windows.Media.Imaging.BitmapDecoder]::Create($stream,[Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[Windows.Media.Imaging.BitmapCacheOption]::None)
            $script:webpSources[$asset]=@{stream=$stream;decoder=$decoder}
        }catch{$stream.Dispose();throw 'WebP preview requires the Windows WebP image codec.'}
    }
    $decoder=$script:webpSources[$asset].decoder
    if($index -lt 0 -or $index -ge $decoder.Frames.Count){throw 'Invalid WebP preview frame'}
    $source=$decoder.Frames[$index]
    if($Frame.rect){$r=$Frame.rect;$source=[Windows.Media.Imaging.CroppedBitmap]::new($source,[Windows.Int32Rect]::new($r[0],$r[1],$r[2],$r[3]))}
    $scale=[Math]::Min(1.0,480.0/[Math]::Max($source.PixelWidth,$source.PixelHeight))
    if($scale -lt 1){$source=[Windows.Media.Imaging.TransformedBitmap]::new($source,[Windows.Media.ScaleTransform]::new($scale,$scale))}
    $source=[Windows.Media.Imaging.FormatConvertedBitmap]::new($source,[Windows.Media.PixelFormats]::Pbgra32,$null,0)
    $stride=$source.PixelWidth*4;$pixels=New-Object byte[] ($stride*$source.PixelHeight)
    $source.CopyPixels($pixels,$stride,0)
    $bitmap=[Windows.Media.Imaging.BitmapSource]::Create($source.PixelWidth,$source.PixelHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32,$null,$pixels,$stride)
    $bitmap.Freeze()
    while($script:webpOrder.Count -ge 8){$script:webpFrames.Remove($script:webpOrder.Dequeue())}
    $script:webpFrames[$key]=$bitmap;$script:webpOrder.Enqueue($key)
    return $bitmap
}
