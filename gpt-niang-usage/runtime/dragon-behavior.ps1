# Local personality and conservative event arbitration. No model calls.
function Initialize-DragonBehavior {
  $script:dragonPreferences=@{ambient=$true;speech=$true;link=$true}
  $script:dragonPreferenceFile=Join-Path $script:dataDir 'dragon-preferences.json'
  try{$saved=Get-Content $script:dragonPreferenceFile -Raw -Encoding UTF8|ConvertFrom-Json;foreach($key in @('ambient','speech','link')){if($saved.$key-is [bool]){$script:dragonPreferences[$key]=$saved.$key}}}catch{}
  $script:dragonPersonality=Get-Content (Join-Path $script:appDir 'assets\dragon-personality.json') -Raw -Encoding UTF8|ConvertFrom-Json
  $script:dragonRandom=[Random]::new();$script:dragonLastQuote='';$script:dragonLastSpeech=0
  $script:dragonSource='manual';$script:dragonManualUntil=0;$script:dragonAmbientUntil=0
  $script:dragonNextAmbient=0;$script:dragonLastBehaviorTick=0;$script:dragonObservedRevision=-1
  $script:dragonLinkStatus='等待新事件';$script:dragonActivityProcess=$null;$script:dragonActivityRetry=0
  $script:dragonAmbientCount=0;$script:dragonLastAppliedRevision=-1
}
function Save-DragonPreferences {Write-WidgetJson $script:dragonPreferenceFile $script:dragonPreferences}
function Set-DragonPreference([string]$Name,[bool]$Value){
  if(!$script:dragonPreferences.ContainsKey($Name)){throw 'Unknown dragon preference'}
  $script:dragonPreferences[$Name]=$Value;Save-DragonPreferences
  if($Name-eq 'link' -and !$Value){Stop-DragonActivityMonitor;$script:dragonLinkStatus='已关闭';if($script:dragonSource-eq 'codex-local-events'){Set-DragonState idle;$script:dragonSource='manual'}}
  $script:dragonNextAmbient=0
}
function Get-DragonQuote([string]$Context='idle') {
  $rows=@($script:dragonPersonality.$Context);if(!$rows.Count){$rows=@($script:dragonPersonality.idle)}
  $choices=@($rows|Where-Object{$_-ne $script:dragonLastQuote});if(!$choices.Count){$choices=$rows}
  $script:dragonLastQuote=[string]$choices[$script:dragonRandom.Next($choices.Count)]
  return $script:dragonLastQuote
}
function Show-DragonSpeech([string]$Context='idle',[switch]$Force){
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if(!$script:window.IsVisible -or $script:dragonHidden){return}
  if((!$script:dragonPreferences.speech -or $script:dragonPaused) -and !$Force){return}
  # Never replace quota, user quotes or completion reminders.
  if(!$script:collapsed -or [bool]$script:drag -or $script:context.IsOpen -or $script:settingsSizePreview){return}
  if(!$Force -and $now-$script:dragonLastSpeech-lt 90000){return}
  $script:dragonNextQuote=Get-DragonQuote $Context
  Show-Quote;$script:dragonLastSpeech=$now
}
function Register-DragonManual {
  $script:dragonSource='manual';$script:dragonManualUntil=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+30000
  $script:dragonAmbientUntil=0;$script:dragonNextAmbient=0
}
function Start-DragonActivityMonitor {
  if(!$script:dragonPreferences.link){return}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if($script:dragonActivityProcess){
    if(!$script:dragonActivityProcess.HasExited){return}
    $script:dragonActivityProcess.Dispose();$script:dragonActivityProcess=$null;$script:dragonActivityRetry=$now+10000
  }
  if($now-lt $script:dragonActivityRetry){return}
  try{
    $script:dragonLastAppliedRevision=-1
    $path=Join-Path $script:dataDir 'dragon-activity.json'
    Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
    $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$script:config.nodePath
    $start.Arguments='"'+(Join-Path $script:appDir 'runtime\dragon-state-monitor.mjs')+'" "'+$path+'"'
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardInput=$true
    if($script:config.codexHome){$start.EnvironmentVariables['CODEX_HOME']=[string]$script:config.codexHome}
    $script:dragonActivityProcess=[Diagnostics.Process]::Start($start)
    $script:dragonLinkStatus='等待新事件'
  }catch{$script:dragonLinkStatus='监听暂不可用';$script:dragonActivityRetry=$now+30000}
}
function Stop-DragonActivityMonitor {
  if(!$script:dragonActivityProcess){return}
  try{if(!$script:dragonActivityProcess.HasExited){$script:dragonActivityProcess.StandardInput.Close();if(!$script:dragonActivityProcess.WaitForExit(1500)){$script:dragonActivityProcess.Kill()}}}catch{}
  $script:dragonActivityProcess.Dispose();$script:dragonActivityProcess=$null
}
function Invoke-DragonBehaviorTick {
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if($now-$script:dragonLastBehaviorTick-lt 1000){return};$script:dragonLastBehaviorTick=$now
  if($script:dragonPendingPreference){$p=$script:dragonPendingPreference;$script:dragonPendingPreference=$null;Set-DragonPreference $p.name $p.value}
  if($script:dragonPendingSpeech){$script:dragonPendingSpeech=$false;Show-DragonSpeech idle -Force}
  Start-DragonActivityMonitor
  if($script:dragonPreferences.link){
    try{
      $event=Get-Content (Join-Path $script:dataDir 'dragon-activity.json') -Raw -Encoding UTF8|ConvertFrom-Json
      $fresh=$event.version-eq 1 -and $event.source-eq 'codex-local-events' -and $now-[long]$event.at-ge 0 -and $now-[long]$event.at-lt 15000
      if(!$fresh){$script:dragonLinkStatus='事件已过期'}
      elseif($event.state-eq 'unknown'){
        $script:dragonLinkStatus='等待新事件'
        if($script:dragonSource-eq 'codex-local-events' -and !$script:dragonPaused -and $now-ge $script:dragonManualUntil){Set-DragonState idle;$script:dragonSource='unknown'}
      }else{
        $script:dragonLinkStatus=if($event.state-eq 'working'){'有会话正在工作'}elseif($event.state-eq 'failure'){'收到明确失败事件'}else{'本轮结束（非任务成功）'}
        if($event.state-in @('working','idle','failure') -and [long]$event.revision-ne $script:dragonLastAppliedRevision -and $now-ge $script:dragonManualUntil -and !$script:dragonPaused -and !$script:context.IsOpen -and ![bool]$script:drag -and $script:characterId-eq 'dragon-v5'){
          Set-DragonState ([string]$event.state);$script:dragonSource='codex-local-events';$script:dragonLastAppliedRevision=[long]$event.revision
          if($event.state-eq 'idle'){Show-DragonSpeech turnEnded}
        }
      }
    }catch{$script:dragonLinkStatus='等待新事件'}
  }
  $eligible=$script:dragonPreferences.ambient -and !$script:dragonPaused -and !$script:dragonHidden -and $script:window.IsVisible -and $script:characterId-eq 'dragon-v5' -and !$script:context.IsOpen -and ![bool]$script:drag -and !$script:settingsSizePreview
  if(!$eligible){$script:dragonNextAmbient=0;return}
  if($script:dragonAmbientUntil-gt 0 -and $now-ge $script:dragonAmbientUntil){
    if($script:dragonSource-eq 'ambient'){Set-DragonState idle;$script:dragonSource='ambient'}
    $script:dragonAmbientUntil=0
  }
  if($script:dragonState-ne 'idle' -or $script:dragonVideoClip-ne 'idle' -or !$script:collapsed -or $now-lt $script:dragonManualUntil){$script:dragonNextAmbient=0;return}
  if(!$script:dragonNextAmbient){$script:dragonNextAmbient=$now+$script:dragonRandom.Next(65000,120001);return}
  if($now-lt $script:dragonNextAmbient){return}
  $name=if($script:dragonRandom.Next(4)-eq 0){'thinking'}else{'click'}
  Set-DragonClip $name;$script:dragonSource='ambient';$script:dragonAmbientCount++
  $duration=if($name-eq 'thinking'){8000}else{[int](1000*$script:dragonVideoPack.clips.$name.count/$script:dragonVideoPack.clips.$name.fps)+500}
  $script:dragonAmbientUntil=$now+$duration;$script:dragonNextAmbient=0
  if($script:dragonRandom.Next(3)-eq 0){Show-DragonSpeech idle}
}
function Update-DragonMenu {
  $labels=@{idle='待机';working='工作';waiting='等待';success='庆祝';failure='失败';review='检查'}
  $clip=if($script:dragonVideoClip){$script:dragonVideoPack.clips.($script:dragonVideoClip).label}else{$labels[$script:dragonState]}
  $script:dragonMenuStatus.Header='当前：'+$clip+$(if($script:dragonPaused){' · 已暂停'}else{' · 播放中'})
  $script:dragonMenuStatus.ToolTip='来源：'+$script:dragonSource+'；'+$script:dragonLinkStatus
  $script:dragonPauseMenu.IsChecked=$script:dragonPaused
  foreach($entry in $script:dragonActionMenuItems.GetEnumerator()){$entry.Value.IsChecked=$entry.Key-eq $script:dragonVideoClip}
  foreach($entry in $script:dragonPreferenceMenus.GetEnumerator()){$entry.Value.IsChecked=$script:dragonPreferences[$entry.Key]}
  $script:dragonLinkMenu.ToolTip=$script:dragonLinkStatus+'；只识别开始、本轮结束和明确失败。等待确认仍用手动入口。'
}
