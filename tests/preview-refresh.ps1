param([string]$ManagerPath=(Join-Path $PSScriptRoot '../scripts/Manager.ps1'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationCore
$tokens=$null;$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($ManagerPath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$fn=$ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-FrameBitmap'},$true)
Invoke-Expression $fn.Extent.Text
$RepoRoot=Join-Path ([IO.Path]::GetTempPath()) ('xlink-preview-test-'+[Guid]::NewGuid())
$assetDir=Join-Path $RepoRoot 'pets/test/assets'
New-Item -ItemType Directory -Path $assetDir -Force | Out-Null
$script:pet=[pscustomobject]@{id='test'};$script:cache=@{}
$frame=[pscustomobject]@{file='assets/frame.png'};$file=Join-Path $assetDir 'frame.png'
function Write-Pixel([byte[]]$pixel){
    $image=[Windows.Media.Imaging.BitmapSource]::Create(1,1,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixel,4)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($image))
    $output=[IO.File]::Create($file);try{$encoder.Save($output)}finally{$output.Dispose()}
}
function First-Pixel($image){$bytes=New-Object byte[] ($image.PixelWidth*$image.PixelHeight*4);$image.CopyPixels($bytes,$image.PixelWidth*4,0);return ($bytes[0..3] -join ',')}
try{
    Write-Pixel ([byte[]]@(0,0,255,255));$before=Get-FrameBitmap $frame
    if((First-Pixel $before) -ne '0,0,255,255'){throw 'Red fixture failed'}
    Write-Pixel ([byte[]]@(255,0,0,255))
    if(-not [object]::ReferenceEquals($before,(Get-FrameBitmap $frame))){throw 'Playback cache was not reused'}
    $script:cache=@{} # The same reset performed by Select-Pet during Refresh-Pets.
    $after=Get-FrameBitmap $frame
    if((First-Pixel $after) -ne '255,0,0,255'){throw 'Refresh reused stale WPF image bytes'}
    if((First-Pixel $before) -ne '0,0,255,255'){throw 'Previous immutable image was modified'}
    Write-Output 'PASS: same-path PNG replacement appears after refresh; normal playback remains cached.'
}finally{
    $resolved=[IO.Path]::GetFullPath($RepoRoot)
    $allowed=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if($resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'xlink-preview-test-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
