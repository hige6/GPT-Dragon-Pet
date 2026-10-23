param([switch]$Quit)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$data=Join-Path $env:LOCALAPPDATA 'GPTDragonPet\state'
$results=New-Object 'System.Collections.Generic.List[string]'
function Assert-Dragon($ok,$name){if(!$ok){throw "FAIL: $name"};$results.Add($name);Write-Output "PASS: $name"}
function Command($action,$value){
  $requestedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $file=Join-Path $data 'dragon-command.json'
  $temp=$file+'.tmp'
  [IO.File]::WriteAllText($temp,(@{action=$action;value=$value}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  if([IO.File]::Exists($file)){[IO.File]::Replace($temp,$file,$null)}else{[IO.File]::Move($temp,$file)}
  $deadline=[DateTime]::UtcNow.AddSeconds(15)
  do{
    Start-Sleep -Milliseconds 100
    try{$reply=Get-Content (Join-Path $data 'dragon-status.json') -Raw -Encoding UTF8|ConvertFrom-Json}catch{$reply=@{at=0}}
  }while(((Test-Path $file) -or $reply.at-lt $requestedAt)-and [DateTime]::UtcNow-lt $deadline)
  if(Test-Path $file){throw 'Command timed out'}
  if($reply.at-lt $requestedAt){throw 'Command reply timed out'}
  return $reply
}
function Presence{Get-Content (Join-Path $data 'presence.json') -Raw -Encoding UTF8|ConvertFrom-Json}
function ShotHash{
  $null=Command snapshot $null
  (Get-FileHash (Join-Path $data 'dragon-pet-preview.png') -Algorithm SHA256).Hash
}
$runtime=Get-Content (Join-Path $data 'runtime.json') -Raw|ConvertFrom-Json
$worker=Get-Content (Join-Path $data 'worker-status.json') -Raw|ConvertFrom-Json
Assert-Dragon ([bool](Get-Process -Id $runtime.pid -ErrorAction SilentlyContinue)) 'Native process running'
$null=Command mode desktop
$null=Command hide $false
$null=Command pause $false
Start-Sleep -Milliseconds 1200
Assert-Dragon ((Presence).visible) 'Desktop visible'
$hashes=@{}
foreach($state in @('idle','working','waiting','success','failure','review')){
  $answer=Command state $state
  Assert-Dragon ($answer.state-eq $state -and !$answer.error) ("State accepted: "+$state)
  $hashes[$state]=ShotHash
  Copy-Item (Join-Path $data 'dragon-preview.png') (Join-Path $root ('preview-'+$state+'.png'))
}
Assert-Dragon ($hashes.idle-ne $hashes.working -and $hashes.working-ne $hashes.failure) 'States render different pixels'
$null=Command state working
$null=Command pause $true
$first=ShotHash;$second=ShotHash
Assert-Dragon ($first-eq $second) 'Pause holds exact pixels'
$null=Command pause $false
$samples=@();1..4|ForEach-Object{$samples+=ShotHash}
Assert-Dragon (@($samples|Select-Object -Unique).Count-gt 1) 'Timer advances actual rendered pixels'
$null=Command scale 1.4
Start-Sleep -Milliseconds 1200
Assert-Dragon ((Presence).sizing.character-eq 1.4) 'Scale changes to 140 percent'
$null=Command scale 1.0
$null=Command hide $true
Start-Sleep -Milliseconds 1200
Assert-Dragon (!(Presence).visible) 'Hide removes overlay'
$null=Command hide $false
Start-Sleep -Milliseconds 1200
Assert-Dragon ((Presence).visible) 'Show restores overlay'
$null=Command mode follow
Start-Sleep -Milliseconds 1200
Assert-Dragon ((Presence).followHost) 'Codex follow mode accepted'
$null=Command mode desktop
$old=(Get-Content (Join-Path $data 'status.json') -Raw|ConvertFrom-Json).observedAt
$null=Command refresh $null
$samples=@();1..4|ForEach-Object{$samples+=ShotHash}
Assert-Dragon (@($samples|Select-Object -Unique).Count-gt 1) 'Quota refresh does not stop animation'
$q=Get-Content (Join-Path $data 'status.json') -Raw|ConvertFrom-Json
Assert-Dragon ($q.queryOk -and $q.source-eq 'official' -and $q.observedAt-ge $old) 'Real read-only quota response'
Assert-Dragon (@($q.windows|Where-Object {$_.minutes-eq 300}).Count-eq 1 -and @($q.windows|Where-Object {$_.minutes-eq 10080}).Count-eq 1) 'Real 5 hour and weekly windows present on this account'
$null=Command state idle
$null=Command pause $false
if($Quit){
  $null=Command quit $null
  $deadline=[DateTime]::UtcNow.AddSeconds(8)
  do{Start-Sleep -Milliseconds 200}while(((Get-Process -Id $runtime.pid -ErrorAction SilentlyContinue)-or (Get-Process -Id $worker.pid -ErrorAction SilentlyContinue))-and [DateTime]::UtcNow-lt $deadline)
  Assert-Dragon (!(Get-Process -Id $runtime.pid -ErrorAction SilentlyContinue)) 'Normal exit stops native GUI'
  Assert-Dragon (!(Get-Process -Id $worker.pid -ErrorAction SilentlyContinue)) 'Normal exit stops owned quota worker'
}
[IO.File]::WriteAllText((Join-Path $root 'verification.json'),(@{checks=$results;count=$results.Count;source='real local integration';passed=$true}|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
