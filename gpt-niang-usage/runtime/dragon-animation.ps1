# GPT Dragon Pet extension. Original GPT-Niang window/quota code remains in widget.ps1.
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime\dragon-video.ps1'),[Text.Encoding]::UTF8)))
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime\dragon-behavior.ps1'),[Text.Encoding]::UTF8)))
function Initialize-DragonAnimation {
  $pack=Join-Path $script:appDir 'assets\dragon-v5'
  $pet=Get-Content (Join-Path $pack 'pet.json') -Raw -Encoding UTF8|ConvertFrom-Json
  $script:dragonLayout=Get-Content (Join-Path $pack 'atlas-layout.json') -Raw -Encoding UTF8|ConvertFrom-Json
  $layout=$script:dragonLayout
  if($pet.spriteVersionNumber-ne 2 -or $pet.spritesheetPath-ne 'spritesheet.webp' -or $layout.columns-ne 8 -or $layout.rows-ne 11 -or $layout.cellWidth-ne 192 -or $layout.cellHeight-ne 208){throw 'Dragon atlas format mismatch; rebuild with tools/prepare-atlas.py.'}
  foreach($pair in @(@('spritesheet.webp',$layout.sourceSha256),@('spritesheet.png',$layout.pngSha256))){
    $hasher=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead((Join-Path $pack $pair[0]))
    try{$hash=([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','')}finally{$stream.Dispose();$hasher.Dispose()}
    if($hash-ne $pair[1]){throw 'Dragon atlas checksum mismatch; rebuild with tools/prepare-atlas.py.'}
  }
  $sheet=Read-WidgetCharacterImage (Join-Path $pack 'spritesheet.png')
  if($sheet.PixelWidth-ne 1536 -or $sheet.PixelHeight-ne 2288){throw 'Dragon atlas must be 1536 x 2288.'}
  $script:dragonFrames=@{}
  foreach($animation in $layout.animations.PSObject.Properties){
    $row=[int]$animation.Value.row;$durations=@($animation.Value.durations)
    if($row-lt 0 -or $row-gt 8 -or $durations.Count-lt 1 -or $durations.Count-gt 8){throw 'Invalid dragon animation layout.'}
    $frames=@()
    for($i=0;$i-lt $durations.Count;$i++){
      if([int]$durations[$i]-lt 20 -or [int]$durations[$i]-gt 5000){throw 'Invalid dragon frame duration.'}
      $crop=[Windows.Media.Imaging.CroppedBitmap]::new($sheet,[Windows.Int32Rect]::new($i*192,$row*208,192,208));$crop.Freeze()
      $pixels=New-Object byte[] (192*208*4);$crop.CopyPixels($pixels,192*4,0)
      $frames+=,@{image=$crop;pixels=$pixels;duration=[int]$durations[$i]}
    }
    $script:dragonFrames[$animation.Name]=$frames
  }
  $script:dragonState='idle';$script:dragonPaused=$false;$script:dragonHidden=$false;$script:dragonFrame=0
  $script:dragonClock=[Diagnostics.Stopwatch]::StartNew();$script:dragonElapsed=0
  $script:dragonTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background)
  $script:dragonTimer.Interval=[TimeSpan]::FromMilliseconds(20)
  $script:dragonTimer.Add_Tick({
    if($script:dragonPendingState){
      $state=$script:dragonPendingState;$script:dragonPendingState=$null
      try{if($script:characterId-ne 'dragon-v5'){$null=Set-WidgetCharacter 'dragon-v5'};$script:dragonPaused=$false;Register-DragonManual;Set-DragonState $state}catch{$script:dragonCommandError='State playback failed'}
    }
    if($script:dragonPendingAction){
      $action=$script:dragonPendingAction;$script:dragonPendingAction=$null
      try{Invoke-DragonAction $action}catch{$script:dragonCommandError='Action playback failed'}
    }
    try{Invoke-DragonBehaviorTick}catch{$script:dragonCommandError='Behavior update failed';[IO.File]::WriteAllText((Join-Path $script:dataDir 'dragon-behavior-error.txt'),($_.Exception.Message+"`n"+$_.ScriptStackTrace),[Text.UTF8Encoding]::new($false))}
    if($script:dragonPaused -or !$script:window.IsVisible -or $script:characterId-ne 'dragon-v5'){$script:dragonClock.Restart();return}
    $script:dragonElapsed+=$script:dragonClock.Elapsed.TotalMilliseconds;$script:dragonClock.Restart()
    if($script:dragonVideoClip){
      $duration=1000.0/[double]$script:dragonVideoPack.clips.($script:dragonVideoClip).fps
      $changed=$false;$steps=0
      while($script:dragonElapsed-ge $duration -and $steps-lt 40){
        $script:dragonElapsed-=$duration;Step-DragonVideo;$changed=$true;$steps++
      }
      if($changed){Show-DragonFrame};return
    }
    $frames=$script:dragonFrames[$script:dragonAnimation]
    $steps=0
    while($script:dragonElapsed-ge $frames[$script:dragonFrame].duration -and $steps-lt 80){
      $script:dragonElapsed-=$frames[$script:dragonFrame].duration
      $script:dragonFrame=($script:dragonFrame+1)%$frames.Count;$steps++
    }
    if($steps-gt 0){Show-DragonFrame}
  })
  Initialize-DragonVideoPack
  Initialize-DragonBehavior
  Set-DragonState 'idle'
  $script:dragonTimer.Start()
}
function Show-DragonFrame {
  if($script:characterId-ne 'dragon-v5'){return}
  if($script:dragonVideoClip){
    $im=Get-DragonVideoFrame
    $stride=$im.PixelWidth*4
    if(!$script:dragonVideoPixels -or $script:dragonVideoPixels.Length-ne ($stride*$im.PixelHeight)){$script:dragonVideoPixels=New-Object byte[] ($stride*$im.PixelHeight)}
    $im.CopyPixels($script:dragonVideoPixels,$stride,0)
    $script:bitmap=$im;$script:alphaBitmap=$im;$script:alphaStride=$stride;$script:alphaPixels=$script:dragonVideoPixels
    $script:ui.Girl.Source=$im
    if($script:widgetColors){foreach($overlay in @($script:widgetColors.halo,$script:widgetColors.tint)){if($overlay -and $overlay.OpacityMask){$overlay.OpacityMask.ImageSource=$im}}}
    return
  }
  $frame=$script:dragonFrames[$script:dragonAnimation][$script:dragonFrame]
  # One fixed cell and unchanged Canvas geometry anchor all states. Hit testing uses current alpha.
  $script:bitmap=$frame.image;$script:alphaBitmap=$frame.image;$script:alphaStride=192*4;$script:alphaPixels=$frame.pixels
  $script:ui.Girl.Source=$frame.image
  if($script:widgetColors){foreach($overlay in @($script:widgetColors.halo,$script:widgetColors.tint)){if($overlay -and $overlay.OpacityMask){$overlay.OpacityMask.ImageSource=$frame.image}}}
}
function Set-DragonState([ValidateSet('idle','working','waiting','success','failure','review')][string]$State) {
  $script:dragonVideoClip=$null
  $script:dragonState=$State;$script:dragonAnimation=[string]$script:dragonLayout.states.$State
  if($script:dragonVideoPack){
    $clip=[string]$script:dragonVideoPack.states.$State
    if($clip -and $clip-ne 'atlas'){Set-DragonClip $clip;return}
  }
  Set-WidgetIndependentLayout
  if($script:dragonTransitionImage){$script:dragonTransitionImage.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$script:dragonTransitionImage.Opacity=0}
  $script:dragonFrame=0;$script:dragonElapsed=0;$script:dragonClock.Restart();Show-DragonFrame
}
function Initialize-DragonMenu {
  # Manual state means exactly that. Reply-end notifications are never converted into task success.
  $submenu=[Windows.Controls.MenuItem]::new();$submenu.Header='龙娘动画（手动状态）'
  foreach($pair in @(@('idle','空闲'),@('working','工作'),@('waiting','等待确认'),@('success','任务成功'),@('failure','任务失败'),@('review','检查'))){
    $item=[Windows.Controls.MenuItem]::new();$item.Header=$pair[1];$item.CommandParameter=$pair[0]
    if($script:dragonVideoPack -and $script:dragonVideoPack.notes.($pair[0])){$item.Header+=' · '+[string]$script:dragonVideoPack.notes.($pair[0])}
    $item.Add_Click({param($sender,$event)$script:dragonPendingState=[string]$sender.CommandParameter;$script:dragonTimer.Start();$event.Handled=$true})
    $submenu.Items.Add($item)|Out-Null
  }
  $pause=[Windows.Controls.MenuItem]::new();$pause.Header='暂停动画（再次点击恢复）';$pause.IsCheckable=$true;$pause.Add_Click({$script:dragonPaused=!$script:dragonPaused;$script:dragonClock.Restart()})
  $script:dragonPauseMenu=$pause
  $script:dragonMenuStatus=[Windows.Controls.MenuItem]::new();$script:dragonMenuStatus.IsEnabled=$false
  $actions=[Windows.Controls.MenuItem]::new();$actions.Header='动作'
  $outfits=[Windows.Controls.MenuItem]::new();$outfits.Header='装扮'
  $script:context.Items.Insert(0,$script:dragonMenuStatus);$script:context.Items.Insert(1,$actions);$script:context.Items.Insert(2,$outfits)
  $script:context.Items.Insert(3,$submenu);$script:context.Items.Insert(4,$pause)
  if($script:dragonVideoPack){
    $script:dragonActionMenuItems=@{}
    $actionIndex=0
    foreach($entry in $script:dragonVideoPack.clips.PSObject.Properties){
      $item=[Windows.Controls.MenuItem]::new();$item.Header='播放：'+[string]$entry.Value.label;$item.CommandParameter=$entry.Name
      # Native menu input only queues work. Rendering runs on the normal animation tick.
      $item.Add_Click({param($sender,$event)$script:dragonPendingAction=[string]$sender.CommandParameter;$script:dragonTimer.Start();$event.Handled=$true})
      $script:dragonActionMenuItems[$entry.Name]=$item
      $item.IsCheckable=$true
      if($entry.Name-in @('rabbit-ears','scarf')){$outfits.Items.Add($item)|Out-Null}else{$actions.Items.Add($item)|Out-Null}
    }
  }
  $personality=[Windows.Controls.MenuItem]::new();$personality.Header='性格与联动'
  $script:dragonPreferenceMenus=@{}
  foreach($pair in @(@('ambient','自主小动作（65–120 秒）'),@('speech','傲娇气泡（不覆盖额度）'),@('link','Codex 有限状态联动'))){
    $item=[Windows.Controls.MenuItem]::new();$item.Header=$pair[1];$item.CommandParameter=$pair[0];$item.IsCheckable=$true
    $item.Add_Click({param($sender,$event)$script:dragonPendingPreference=@{name=[string]$sender.CommandParameter;value=[bool]$sender.IsChecked};$event.Handled=$true})
    $script:dragonPreferenceMenus[$pair[0]]=$item;$personality.Items.Add($item)|Out-Null
  }
  $script:dragonLinkMenu=$script:dragonPreferenceMenus.link
  $speak=[Windows.Controls.MenuItem]::new();$speak.Header='说一句';$speak.Add_Click({$script:dragonPendingSpeech=$true});$personality.Items.Add($speak)|Out-Null
  $script:context.Items.Insert(5,$personality)
  $quick=[Windows.Controls.MenuItem]::new();$quick.Header='傲娇一下';$quick.Add_Click({$script:dragonPendingAction='click';$script:dragonTimer.Start()})
  $script:context.Items.Insert(1,$quick)
  # Match the upstream rounded menu and let its screen-aware placement handle groups.
  foreach($group in @($actions,$outfits,$submenu,$personality)){
    $group.Style=$script:settingsMenuResources['SettingsItem'];$group.Tag=[Windows.Controls.Primitives.PlacementMode]::Right
    $script:settingsSubmenus+=,$group
    foreach($child in $group.Items){$child.Style=$script:settingsMenuResources['SettingsItem']}
  }
  foreach($item in @($script:dragonMenuStatus,$quick,$pause)){$item.Style=$script:settingsMenuResources['SettingsItem']}
  $script:context.Add_Opened({Update-DragonMenu})
  $actions.Add_SubmenuOpened({Update-DragonMenu});$outfits.Add_SubmenuOpened({Update-DragonMenu});$personality.Add_SubmenuOpened({Update-DragonMenu})
  $hide=[Windows.Controls.MenuItem]::new();$hide.Header='隐藏桌宠（从托盘恢复）';$hide.Add_Click({$script:dragonHidden=$true;Tick-Widget})
  $script:context.Items.Add($hide)|Out-Null
  # Disable upstream replacement of this fork, including the manual update entry.
  if($script:settingsMenuUi.Updates){$script:settingsMenuUi.Updates.IsEnabled=$false;$script:settingsMenuUi.Updates.Header='原型版本（上游更新已禁用）'}
  $script:dragonTray=[Windows.Forms.NotifyIcon]::new();$script:dragonTray.Icon=[Drawing.SystemIcons]::Information
  $script:dragonTray.Text='GPT Dragon Pet';$script:dragonTray.Visible=$true
  $menu=[Windows.Forms.ContextMenuStrip]::new()
  $show=$menu.Items.Add('显示 / 隐藏桌宠');$show.Add_Click({$script:dragonHidden=!$script:dragonHidden;Tick-Widget})
  $quota=$menu.Items.Add('显示额度');$quota.Add_Click({$script:dragonHidden=$false;Tick-Widget;Show-Quota})
  $refresh=$menu.Items.Add('刷新额度');$refresh.Add_Click({Request-Refresh})
  $exit=$menu.Items.Add('退出');$exit.Add_Click({$script:window.Close()})
  $script:dragonTray.ContextMenuStrip=$menu
  $script:dragonTray.Add_DoubleClick({$script:dragonHidden=$false;Tick-Widget})
}
function Read-DragonCommand {
  $file=Join-Path $script:dataDir 'dragon-command.json'
  if(![IO.File]::Exists($file)){return}
  try{
    if((Get-Item $file).Length-gt 4096){throw 'Command too large'}
    $command=Get-Content $file -Raw -Encoding UTF8|ConvertFrom-Json
    Remove-Item -LiteralPath $file
    $script:dragonCommandError=$null
    switch($command.action){
      'state' {Register-DragonManual;Set-DragonState ([string]$command.value)}
      'clip' {Register-DragonManual;Set-DragonClip ([string]$command.value)}
      'ambient' {Set-DragonPreference ambient ([bool]$command.value)}
      'speech' {Set-DragonPreference speech ([bool]$command.value)}
      'link' {Set-DragonPreference link ([bool]$command.value)}
      'speak' {Show-DragonSpeech idle -Force}
      'preview' {
        if($command.value-ne 'close'){
          $name=if($command.value){[string]$command.value}else{'idle'}
          $item=$script:dragonActionMenuItems[$name]
          if(!$item){throw 'Unknown menu action'}
          $item.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
        }
      }
      'pause' {$script:dragonPaused=[bool]$command.value;$script:dragonClock.Restart()}
      'hide' {$script:dragonHidden=[bool]$command.value}
      'mode' {if($command.value-notin @('desktop','follow')){throw 'Invalid mode'};Set-WidgetFollowHost ($command.value-eq 'follow')}
      'scale' {$value=[double]$command.value;if([double]::IsNaN($value) -or $value-lt 0.6 -or $value-gt 2.5){throw 'Invalid scale'};$script:scale=$value;Set-Appearance;Save-Settings}
      'quota' {Show-Quota}
      'refresh' {Request-Refresh}
      'snapshot' {
        $root=$script:window.FindName('AnimationStage');$root.UpdateLayout()
        $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(378,378,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($root)
        $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
        $stream=[IO.File]::Create((Join-Path $script:dataDir 'dragon-preview.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
        # Capture the bound character frame separately from live quota/bubble transitions.
        $petEncoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$petEncoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($script:bitmap))
        $stream=[IO.File]::Create((Join-Path $script:dataDir 'dragon-pet-preview.png'));try{$petEncoder.Save($stream)}finally{$stream.Dispose()}
      }
      'quit' {$script:window.Close()}
      default {throw 'Unknown action'}
    }
  }catch{$script:dragonCommandError='Command rejected';[IO.File]::WriteAllText((Join-Path $script:dataDir 'dragon-command-error.txt'),($_.Exception.Message+"`n"+$_.ScriptStackTrace),[Text.UTF8Encoding]::new($false))}
  # Diagnostics contain only prototype state; no account fields, window titles or response content.
  Write-WidgetJson (Join-Path $script:dataDir 'dragon-status.json') @{state=$script:dragonState;clip=$script:dragonVideoClip;frame=$script:dragonFrame;paused=$script:dragonPaused;previewOpen=$false;hidden=$script:dragonHidden;visible=$script:window.IsVisible;follow=$script:followHost;scale=$script:scale;source=$script:dragonSource;preferences=$script:dragonPreferences;linkStatus=$script:dragonLinkStatus;ambientCount=$script:dragonAmbientCount;nextAmbient=$script:dragonNextAmbient;eligibility=@{menuOpen=$script:context.IsOpen;dragging=[bool]$script:drag;bubbleOpen=!$script:collapsed;sizePreview=[bool]$script:settingsSizePreview;manualUntil=$script:dragonManualUntil};cache=@{count=$script:dragonFrameCache.Count;hits=$script:dragonFrameCache.Hits;misses=$script:dragonFrameCache.Misses;failures=$script:dragonFrameCache.Failures};error=$script:dragonCommandError;at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
}
function Stop-DragonAnimation {
  if($script:dragonTimer){$script:dragonTimer.Stop()}
  Stop-DragonActivityMonitor
  if($script:dragonFrameCache){$script:dragonFrameCache.Dispose()}
  if($script:dragonTray){$script:dragonTray.Visible=$false;$script:dragonTray.Dispose()}
  # Let Node run its exit handlers, including terminating an in-flight app-server child.
  if($script:worker){
    try{
      if(!$script:worker.HasExited){
        $stopFile=Join-Path $script:dataDir 'stop.flag';$stopToken='dragon-exit:'+([Guid]::NewGuid().ToString('N'))
        [IO.File]::WriteAllText($stopFile,$stopToken)
        if(!$script:worker.WaitForExit(2500)){
          $killer=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\taskkill.exe') -ArgumentList @('/PID',[string]$script:worker.Id,'/T','/F') -WindowStyle Hidden -PassThru
          try{$null=$killer.WaitForExit(2500)}finally{$killer.Dispose()}
        }
        if([IO.File]::Exists($stopFile) -and [IO.File]::ReadAllText($stopFile)-eq $stopToken){[IO.File]::Delete($stopFile)}
      }
    }catch{}
  }
}
