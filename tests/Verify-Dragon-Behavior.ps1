$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$temp=Join-Path ([IO.Path]::GetTempPath()) ('dragon-behavior-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
$script:dataDir=$temp;$script:appDir=Join-Path $root 'gpt-niang-usage'
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime\dragon-behavior.ps1'),[Text.Encoding]::UTF8)))
function Write-WidgetJson($Path,$Value){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))}
function Set-DragonState($Value){$script:dragonState=$Value;$script:dragonVideoClip=if($Value-eq 'working'){'thinking'}else{'idle'}}
function Set-DragonClip($Value){$script:dragonVideoClip=$Value}
function Start-DragonActivityMonitor {}
function Stop-DragonActivityMonitor {}
function Show-Quote {$script:collapsed=$false;$script:shownQuote=$script:dragonNextQuote}
function Assert($Condition,$Message){if(!$Condition){throw $Message};'PASS: '+$Message}
function Tick {$script:dragonLastBehaviorTick=0;Invoke-DragonBehaviorTick}
function Event($State,$Revision){Write-WidgetJson (Join-Path $temp 'dragon-activity.json') @{version=1;source='codex-local-events';state=$State;revision=$Revision;at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}}
try{
  Initialize-DragonBehavior
  $script:window=[pscustomobject]@{IsVisible=$true};$script:context=[pscustomobject]@{IsOpen=$false}
  $script:characterId='dragon-v5';$script:dragonPaused=$false;$script:dragonHidden=$false;$script:collapsed=$true
  $script:dragonState='idle';$script:dragonVideoClip='idle'
  $script:dragonVideoPack=[pscustomobject]@{clips=[pscustomobject]@{click=[pscustomobject]@{count=121;fps=12}}}
  Tick;$delay=$script:dragonNextAmbient-[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  Assert ($delay-ge 64000 -and $delay-le 120000) 'Autonomous delay stays between 65 and 120 seconds'
  $script:dragonNextAmbient=1;$script:dragonPaused=$true;Tick
  Assert ($script:dragonAmbientCount-eq 0 -and $script:dragonNextAmbient-eq 0) 'Pause suppresses autonomous actions'
  $script:dragonPaused=$false;$script:context.IsOpen=$true;$script:dragonNextAmbient=1;Tick
  Assert ($script:dragonAmbientCount-eq 0) 'Open menu suppresses autonomous actions'
  $script:context.IsOpen=$false;$script:dragonNextAmbient=1;Tick
  Assert ($script:dragonAmbientCount-eq 1 -and $script:dragonSource-eq 'ambient') 'Due autonomous action plays with ambient source'
  $script:dragonAmbientUntil=1;$script:collapsed=$true;Tick
  Assert ($script:dragonVideoClip-eq 'idle') 'Autonomous thinking returns to idle'
  Register-DragonManual;Event working 1;Tick
  Assert ($script:dragonState-eq 'idle') 'Manual playback takes priority over incoming Codex events'
  $script:dragonManualUntil=0;Tick
  Assert ($script:dragonState-eq 'working' -and $script:dragonSource-eq 'codex-local-events') 'Fresh start event maps to working'
  Event idle 2;Tick
  Assert ($script:dragonState-eq 'idle') 'End event returns idle without celebration'
  Event failure 3;$script:dragonPaused=$true;Tick
  Assert ($script:dragonState-eq 'idle') 'Codex event never resumes paused animation'
  $script:dragonPaused=$false;Tick
  Assert ($script:dragonState-eq 'failure') 'Explicit failure accepted after resume'
  Set-DragonPreference ambient $false;Set-DragonPreference speech $false
  Initialize-DragonBehavior
  Assert (!$script:dragonPreferences.ambient -and !$script:dragonPreferences.speech) 'Preferences survive reload'
  $script:collapsed=$false;$script:shownQuote=$null
  Show-DragonSpeech idle -Force
  Assert (!$script:shownQuote) 'Personality speech does not replace an open quota bubble'
  $script:collapsed=$true;Show-DragonSpeech idle -Force
  Assert ($script:shownQuote.Length-gt 0) 'Local personality bubble has text without a provider'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force}
