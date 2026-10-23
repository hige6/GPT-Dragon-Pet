param([switch]$Disable)
$ErrorActionPreference='Stop'
$watcher=Join-Path $PSScriptRoot 'GPTDragonCodexWatcher.exe'
$startup=[Environment]::GetFolderPath('Startup')
$link=Join-Path $startup 'GPT Dragon Pet with Codex.lnk'
if($Disable){
  if(Test-Path -LiteralPath $link){Remove-Item -LiteralPath $link}
  if(Test-Path -LiteralPath $watcher){$p=Start-Process -FilePath $watcher -ArgumentList '--stop' -WindowStyle Hidden -PassThru;$null=$p.WaitForExit(5000)}
  Write-Output 'Codex companion autostart disabled. The current pet is left running.'
  return
}
if(!(Test-Path -LiteralPath $watcher)){throw 'Companion watcher is missing.'}
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut($link)
$shortcut.TargetPath=$watcher;$shortcut.WorkingDirectory=$PSScriptRoot
$shortcut.WindowStyle=7;$shortcut.Description='Start GPT Dragon Pet when the Codex desktop app is running.'
$shortcut.Save()
$null=Start-Process -FilePath $watcher -WindowStyle Hidden -PassThru
Write-Output 'Codex companion autostart enabled for the current Windows user.'
