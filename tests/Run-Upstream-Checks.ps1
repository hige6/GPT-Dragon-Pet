$ErrorActionPreference='Stop'
$tests=Join-Path (Split-Path $PSScriptRoot -Parent) 'gpt-niang-usage\tests'
$shell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if($args.Count){
  $name=$args[0]
  $file=Join-Path $tests ($name+'.test.ps1')
  $source=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)
  if($source-match '(?s)^param\([^\)]*\$TestRoot'){
    & ([ScriptBlock]::Create($source)) -TestRoot $tests
  }else{
    & $shell -NoProfile -STA -ExecutionPolicy Bypass -File $file
    if($LASTEXITCODE-ne 0){exit $LASTEXITCODE}
  }
  exit
}
$failed=New-Object 'System.Collections.Generic.List[string]'
foreach($name in @('quota-selection','widget','characters','character-startup','character-rendering','desktop-mode','drag-sizing','drag-facing','drag-horizontal','drag-vertical','size','settings-menu','host-ready','lifecycle')){
  & $shell -NoProfile -STA -ExecutionPolicy Bypass -File $PSCommandPath $name
  Write-Output ("RESULT {0}: exit={1}" -f $name,$LASTEXITCODE)
  if($LASTEXITCODE-ne 0){$failed.Add($name)}
}
if($failed.Count-gt 0){throw ('Failed Windows checks: '+($failed -join ', '))}
