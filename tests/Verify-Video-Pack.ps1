$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$data=Join-Path $env:LOCALAPPDATA 'GPTDragonPet\state'
$checks=New-Object 'System.Collections.Generic.List[string]'
function Assert($ok,$message){if(!$ok){throw "FAIL $message"};$checks.Add($message);Write-Output "PASS $message"}
function Command($action,$value){
  $at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  & (Join-Path $root 'Dragon-Control.ps1') -Action $action -Value $value
  $deadline=[DateTime]::UtcNow.AddSeconds(15)
  do{
    Start-Sleep -Milliseconds 150
    try{$s=Get-Content (Join-Path $data 'dragon-status.json') -Raw|ConvertFrom-Json}catch{$s=@{at=0}}
  }while($s.at-lt $at -and [DateTime]::UtcNow-lt $deadline)
  if($s.at-lt $at){throw 'Command timeout'}
  return $s
}
$null=Command state idle
$a=Command snapshot ''
Assert ($a.clip-eq 'idle') 'Default idle uses new transparent video pack'
$null=Command clip thinking
Start-Sleep -Milliseconds 700
$a=Command snapshot ''
Assert ($a.clip-eq 'thinking' -and $a.frame-gt 0) 'Custom clip advances real frames'
$a=Command clip does-not-exist
Assert ([bool]$a.error -and $a.clip-eq 'thinking') 'Unknown clip rejected without losing current action'
$null=Command clip click
Start-Sleep -Milliseconds 11000
$a=Command snapshot ''
Assert ($a.clip-eq 'idle') 'Click one-shot returns to idle automatically'
$null=Command pause true
$a=Command snapshot ''
$hash=(Get-FileHash (Join-Path $data 'dragon-pet-preview.png')).Hash
Start-Sleep -Milliseconds 400
$null=Command snapshot ''
Assert ((Get-FileHash (Join-Path $data 'dragon-pet-preview.png')).Hash-eq $hash) 'Video pause keeps exact rendered pixels'
$null=Command pause false
$null=Command scale 1.3
$null=Command snapshot ''
Copy-Item (Join-Path $data 'dragon-preview.png') (Join-Path $root 'video-window-preview.png') -Force
$checks|ConvertTo-Json|Set-Content (Join-Path $root 'video-runtime-validation.json') -Encoding UTF8
