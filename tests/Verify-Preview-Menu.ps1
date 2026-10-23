$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$data=Join-Path $env:LOCALAPPDATA 'GPTDragonPet/state'
function Command($Action,$Value=''){
  $stamp=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  & (Join-Path $root 'Dragon-Control.ps1') -Action $Action -Value $Value
  $deadline=[DateTime]::UtcNow.AddSeconds(20)
  do{Start-Sleep -Milliseconds 150;try{$s=Get-Content (Join-Path $data 'dragon-status.json') -Raw|ConvertFrom-Json}catch{$s=@{at=0}}}while($s.at-lt $stamp -and [DateTime]::UtcNow-lt $deadline)
  if($s.at-lt $stamp -or $s.error){throw 'Preview command failed'}
  return $s
}
$null=Command pause true
# The command raises the real WPF MenuItem.Click event, exercising its binding.
$pack=Get-Content (Join-Path $root 'gpt-niang-usage/assets/dragon-video/pack.json') -Raw -Encoding UTF8|ConvertFrom-Json
foreach($clip in @($pack.clips.PSObject.Properties.Name)){
  $null=Command preview $clip
  Start-Sleep -Milliseconds 150
  $s=Command snapshot
  if($s.previewOpen -or $s.paused -or $s.clip-ne $clip){throw "Menu did not play on pet: $clip"}
  "PASS: actual $clip menu Click plays on desktop pet, with no extra window"
}
$null=Command preview thinking
Start-Sleep -Milliseconds 700
$a=Command snapshot
$h=(Get-FileHash (Join-Path $data 'dragon-pet-preview.png')).Hash
Start-Sleep -Milliseconds 900
$b=Command snapshot
if($a.frame-eq $b.frame -or $h-eq (Get-FileHash (Join-Path $data 'dragon-pet-preview.png')).Hash){throw 'Preview is static'}
'PASS: menu-selected desktop character frames and pixels advance'
$null=Command pause false
$null=Command state idle
'PASS: normal desktop playback left running'
