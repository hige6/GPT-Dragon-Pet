# Local RGBA video frame packs. Extend pack.json; never infer Codex task outcomes.
function Initialize-DragonVideoPack {
  $script:dragonVideoRoot=Join-Path $script:appDir 'assets\dragon-video'
  $manifest=Join-Path $script:dragonVideoRoot 'pack.json'
  $script:dragonVideoPack=$null;$script:dragonVideoClip=$null
  $script:dragonVideoCache=@{}
  $script:dragonVideoQueue=New-Object 'System.Collections.Generic.Queue[string]'
  if(!(Test-Path -LiteralPath $manifest)){return}
  $p=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8|ConvertFrom-Json
  if($p.version-ne 1 -or $p.width-lt 64 -or $p.width-gt 1024 -or $p.height-lt 64 -or $p.height-gt 1024){throw 'Invalid dragon video pack dimensions/version.'}
  foreach($entry in $p.clips.PSObject.Properties){
    $c=$entry.Value
    if($entry.Name-notmatch '^[a-z][a-z0-9-]{0,40}$' -or $c.directory-notmatch '^[a-z][a-z0-9-]{0,40}$' -or $c.count-lt 1 -or $c.count-gt 720 -or $c.fps-lt 1 -or $c.fps-gt 30 -or $c.playback-notin @('once','pingpong','loop')){throw 'Invalid dragon video clip definition.'}
    for($i=0;$i-lt $c.count;$i++){
      if(!(Test-Path -LiteralPath (Join-Path $script:dragonVideoRoot ($c.directory+('\{0:D4}.png'-f $i))))){throw "Dragon video frame missing: $($entry.Name)/$i"}
    }
  }
  if(!$p.clips.idle){throw 'Dragon video pack requires idle.'}
  $script:dragonVideoPack=$p
  if(!('DragonFrameCache'-as [type])){Add-Type -Path (Join-Path $script:appDir 'runtime\dragon-frame-cache.cs') -ReferencedAssemblies @('PresentationCore','WindowsBase','System.Xaml')}
  $script:dragonFrameCache=[DragonFrameCache]::new()
}
function Set-DragonClip([string]$Name) {
  if(!$script:dragonVideoPack -or $Name-notmatch '^[a-z][a-z0-9-]{0,40}$'){throw 'Video pack or clip unavailable.'}
  $clip=$script:dragonVideoPack.clips.$Name
  if(!$clip){throw "Unknown dragon clip: $Name"}
  $old=$script:ui.Girl.Source
  $script:dragonVideoClip=$Name;$script:dragonVideoDirection=1
  $script:dragonFrame=0;$script:dragonElapsed=0;$script:dragonClock.Restart()
  Set-WidgetIndependentLayout
  Request-DragonFrames -Reset
  Show-DragonFrame
  Start-DragonTransition $old
}
function Request-DragonFrames([switch]$Reset){
  if(!$script:dragonFrameCache -or !$script:dragonVideoClip){return}
  $clip=$script:dragonVideoPack.clips.($script:dragonVideoClip);$paths=@()
  for($i=0;$i-lt 14;$i++){
    $index=$script:dragonFrame+$i
    if($index-ge $clip.count){
      if($clip.playback-eq 'loop'){$start=[int]$clip.loopStart;$index=$start+(($index-$clip.count)%($clip.count-$start))}
      elseif($clip.playback-eq 'pingpong'){$index=[Math]::Max(0,2*$clip.count-2-$index)}else{break}
    }
    $paths+=Join-Path $script:dragonVideoRoot ($clip.directory+('\{0:D4}.png'-f $index))
  }
  $script:dragonFrameCache.Prefetch([string[]]$paths,[bool]$Reset)
}
function Start-DragonTransition($Old){
  if(!$Old -or $Old.PixelWidth-ne $script:dragonVideoPack.width -or !$script:ui.Girl.Parent){return}
  if(!$script:dragonTransitionImage){
    $script:dragonTransitionImage=[Windows.Controls.Image]::new();$script:dragonTransitionImage.IsHitTestVisible=$false
    [Windows.Controls.Panel]::SetZIndex($script:dragonTransitionImage,1)
    $script:ui.Girl.Parent.Children.Add($script:dragonTransitionImage)|Out-Null
  }
  $overlay=$script:dragonTransitionImage;$overlay.Source=$Old;$overlay.Width=$script:ui.Girl.Width;$overlay.Height=$script:ui.Girl.Height
  [Windows.Controls.Canvas]::SetLeft($overlay,[Windows.Controls.Canvas]::GetLeft($script:ui.Girl))
  [Windows.Controls.Canvas]::SetTop($overlay,[Windows.Controls.Canvas]::GetTop($script:ui.Girl))
  $fade=[Windows.Media.Animation.DoubleAnimation]::new(1,0,[TimeSpan]::FromMilliseconds(140))
  $overlay.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
}
function Get-DragonVideoFrame {
  $clip=$script:dragonVideoPack.clips.($script:dragonVideoClip)
  $im=$script:dragonFrameCache.Get((Join-Path $script:dragonVideoRoot ($clip.directory+('\{0:D4}.png'-f $script:dragonFrame))))
  if($im.PixelWidth-ne $script:dragonVideoPack.width -or $im.PixelHeight-ne $script:dragonVideoPack.height){throw 'Video frame size mismatch.'}
  Request-DragonFrames
  return $im
}
function Step-DragonVideo {
  $clip=$script:dragonVideoPack.clips.($script:dragonVideoClip)
  $script:dragonFrame+=$script:dragonVideoDirection
  if($script:dragonFrame-ge $clip.count){
    switch($clip.playback){
      'pingpong' {$script:dragonVideoDirection=-1;$script:dragonFrame=[Math]::Max(0,$clip.count-2)}
      'loop' {$script:dragonFrame=[int]$clip.loopStart}
      'once' {
        $next=[string]$clip.returnTo
        if($next -and $next-ne 'idle'){Set-DragonClip $next}else{Set-DragonState idle}
      }
    }
  }elseif($script:dragonFrame-lt 0){$script:dragonVideoDirection=1;$script:dragonFrame=[Math]::Min(1,$clip.count-1)}
}
function Invoke-DragonAction([string]$Name) {
  [IO.File]::WriteAllText((Join-Path $script:dataDir 'dragon-last-action.json'),(@{action=$Name;at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  if(!$script:dragonVideoPack.clips.$Name){throw 'Unknown dragon action.'}
  if($script:characterId-ne 'dragon-v5'){$null=Set-WidgetCharacter 'dragon-v5'}
  $script:dragonHidden=$false;$script:dragonPaused=$false
  Register-DragonManual
  Set-DragonClip $Name
  Show-DragonSpeech $Name
  $script:dragonTimer.Start()
}
