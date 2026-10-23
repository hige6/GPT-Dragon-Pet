param([ValidateSet('state','clip','preview','pause','hide','mode','scale','quota','refresh','snapshot','quit','ambient','speech','link','speak')][string]$Action='quota',[string]$Value)
$ErrorActionPreference='Stop'
$data=Join-Path $env:LOCALAPPDATA 'GPTDragonPet\state'
if(!(Test-Path $data)){throw 'Start Dragon first.'}
$parsed=$Value
if($Action-in @('pause','hide','ambient','speech','link')){$parsed=[bool]::Parse($Value)}
if($Action-eq 'scale'){$parsed=[double]::Parse($Value,[Globalization.CultureInfo]::InvariantCulture)}
$temp=Join-Path $data ('dragon-command.'+[Guid]::NewGuid().ToString('N')+'.tmp')
[IO.File]::WriteAllText($temp,(@{action=$Action;value=$parsed}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$target=Join-Path $data 'dragon-command.json'
if([IO.File]::Exists($target)){
  $previous=$target+'.previous'
  try{[IO.File]::Replace($temp,$target,$previous)}finally{if([IO.File]::Exists($previous)){[IO.File]::Delete($previous)}}
}else{[IO.File]::Move($temp,$target)}
