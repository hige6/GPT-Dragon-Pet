$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$automation=[Management.Automation.PSObject].Assembly.Location
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /out:"$PSScriptRoot\GPTDragonPet.exe" /reference:"$automation" /reference:System.Windows.Forms.dll "$PSScriptRoot\DragonHost.cs"
if($LASTEXITCODE-ne 0){throw 'C# GUI launcher build failed.'}
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /out:"$PSScriptRoot\GPTDragonCodexWatcher.exe" /reference:System.Windows.Forms.dll "$PSScriptRoot\DragonCodexWatcher.cs"
if($LASTEXITCODE-ne 0){throw 'Codex companion watcher build failed.'}
