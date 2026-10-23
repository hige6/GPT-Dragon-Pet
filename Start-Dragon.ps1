param([switch]$CheckOnly,[switch]$Preview,[switch]$QaWindow,[string]$DataDir)
$ErrorActionPreference='Stop'
$app=Join-Path $PSScriptRoot 'gpt-niang-usage'
$data=if($DataDir){[IO.Path]::GetFullPath($DataDir)}else{Join-Path $env:LOCALAPPDATA 'GPTDragonPet\state'}
$null=New-Item -ItemType Directory -Force -Path $data
$node=(Get-Command node.exe -ErrorAction Stop).Source
if([int]((& $node --version)-replace '^v(\d+).*','$1')-lt 20){throw 'Node.js 20+ required.'}
# Executable discovery only. Never open an authentication file.
$cli=Get-ChildItem (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin') -Filter codex.exe -Recurse -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 1
$codexPath=if($cli){$cli.FullName}else{'codex.exe'}
$config=@{dataDir=$data;nodePath=$node;codexPath=$codexPath;appDir=$app;version='1.3.5-dragon.1';portable=$true;qaWindow=[bool]$QaWindow}
[IO.File]::WriteAllText((Join-Path $app 'installation.json'),($config|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
# Portable prototype has no installer, autostart, supervisor, MCP registration or binary self-update.
[IO.File]::WriteAllText((Join-Path $data 'update-preferences.json'),'{"automatic":false}',[Text.UTF8Encoding]::new($false))
& (Join-Path $app 'runtime\start-widget.ps1') -CheckOnly:$CheckOnly -Preview:$Preview
