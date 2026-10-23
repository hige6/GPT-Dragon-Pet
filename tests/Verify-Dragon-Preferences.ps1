$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$data=Join-Path $env:LOCALAPPDATA 'GPTDragonPet/state'
function Command($Action,$Value=''){
  $stamp=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  & (Join-Path $root 'Dragon-Control.ps1') -Action $Action -Value $Value
  $until=[DateTime]::UtcNow.AddSeconds(15)
  do{Start-Sleep -Milliseconds 150;try{$s=Get-Content (Join-Path $data 'dragon-status.json') -Raw|ConvertFrom-Json}catch{$s=@{at=0}}}while($s.at-lt $stamp -and [DateTime]::UtcNow-lt $until)
  if($s.at-lt $stamp -or $s.error){throw 'Preference command failed'}
  return $s
}
$initial=(Command snapshot).preferences
try{
  foreach($name in @('ambient','speech','link')){
    $s=Command $name false
    if($s.preferences.$name-ne $false){throw "Cannot disable $name"}
    $saved=Get-Content (Join-Path $data 'dragon-preferences.json') -Raw|ConvertFrom-Json
    if($saved.$name-ne $false){throw "Preference was not saved: $name"}
    $s=Command $name true
    if($s.preferences.$name-ne $true){throw "Cannot enable $name"}
    "PASS: live $name toggle and persistence"
  }
}finally{
  foreach($name in @('ambient','speech','link')){$null=Command $name ([string][bool]$initial.$name)}
}
'PASS: initial preferences restored'
