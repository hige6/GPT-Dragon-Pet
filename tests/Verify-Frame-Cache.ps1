$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName PresentationCore,WindowsBase
Add-Type -Path (Join-Path $root 'gpt-niang-usage\runtime\dragon-frame-cache.cs') -ReferencedAssemblies @('PresentationCore','WindowsBase','System.Xaml')
$cache=[DragonFrameCache]::new()
$frameRoot=Join-Path $root 'gpt-niang-usage\assets\dragon-video\idle'
$checks=0
function Assert($Condition,$Message){if(!$Condition){throw $Message};$script:checks++;Write-Output ('PASS: '+$Message)}
try{
  $frame=Join-Path $frameRoot '0000.png'
  $first=$cache.Get($frame)
  Assert ($first.IsFrozen -and $first.PixelWidth-eq 512) 'Decoded frames are frozen WPF bitmaps'
  $second=$cache.Get($frame)
  Assert ([object]::ReferenceEquals($first,$second) -and $cache.Hits-eq 1) 'Repeated frame uses cached instance'
  for($i=1;$i-lt 50;$i++){$null=$cache.Get((Join-Path $frameRoot ('{0:D4}.png'-f $i)))}
  Assert ($cache.Count-eq 40) 'Frame cache stays bounded at 40 entries'
  $next=Join-Path $frameRoot '0050.png'
  $background=[DragonFrameCache]::new()
  try{
    $background.Prefetch([string[]]@($next),$true)
    $deadline=[DateTime]::UtcNow.AddSeconds(3)
    while($background.Count-lt 1 -and [DateTime]::UtcNow-lt $deadline){Start-Sleep -Milliseconds 25}
    Assert ($background.Count-eq 1) 'Background prefetch decodes without foreground requests'
    $null=$background.Get($next)
    Assert ($background.Hits-eq 1 -and $background.Misses-eq 0) 'Prefetched frame needs no foreground decode'
  }finally{$background.Dispose()}
  $wake=$cache.GetType().GetField('wake',[Reflection.BindingFlags]'NonPublic,Instance').GetValue($cache)
  $worker=$cache.GetType().GetField('worker',[Reflection.BindingFlags]'NonPublic,Instance').GetValue($cache)
  $cache.Dispose();$cache.Dispose()
  Assert (!$worker.IsAlive) 'Dispose stops the decoder thread and is idempotent'
  Assert ($wake.SafeWaitHandle.IsClosed) 'Decoder wait handle is released'
  Assert ($cache.Count-eq 0) 'Dispose releases cached bitmaps'
  $thrown=$false;try{$null=$cache.Get($frame)}catch{$thrown=$true}
  Assert $thrown 'Disposed cache refuses further decoding'
  $cache.Prefetch([string[]]@($next),$false)
  Assert $true 'Late prefetch after disposal is harmless'
  Write-Output ('Frame cache checks passed: '+$checks)
}finally{$cache.Dispose()}
