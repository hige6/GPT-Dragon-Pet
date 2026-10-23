$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $root ('.test-state\runner-'+[Guid]::NewGuid().ToString('N'))
$scriptPath=Join-Path $fixture 'tests\Run-Upstream-Checks.ps1'
$dummyTests=Join-Path $fixture 'gpt-niang-usage\tests'
$null=New-Item -ItemType Directory -Force -Path (Split-Path $scriptPath -Parent),$dummyTests
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Run-Upstream-Checks.ps1') -Destination $scriptPath
$names=@('quota-selection','widget','characters','character-startup','character-rendering','desktop-mode','drag-sizing','drag-facing','drag-horizontal','drag-vertical','size','settings-menu','host-ready','lifecycle')
foreach($name in $names){[IO.File]::WriteAllText((Join-Path $dummyTests ($name+'.test.ps1')),'exit 0')}
[IO.File]::WriteAllText((Join-Path $dummyTests 'widget.test.ps1'),'exit 7')
$shell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$start=New-Object Diagnostics.ProcessStartInfo
$start.FileName=$shell
$start.Arguments='-NoProfile -STA -ExecutionPolicy Bypass -File "'+$scriptPath+'"'
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.RedirectStandardOutput=$true
$start.RedirectStandardError=$true
$process=[Diagnostics.Process]::Start($start)
$stdout=$process.StandardOutput.ReadToEndAsync()
$stderr=$process.StandardError.ReadToEndAsync()
$process.WaitForExit()
$output=$stdout.Result+$stderr.Result
try{
  if($process.ExitCode-eq 0){throw 'Runner silently accepted a failing child test'}
  if($output-notmatch 'widget'){throw 'Runner did not identify the failing check'}
}finally{$process.Dispose()}
Write-Output 'PASS: Child failures propagate to the Windows test runner exit code'
