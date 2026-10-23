' Launch the Store desktop application and the local pet from one desktop shortcut.
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
shell.Run "explorer.exe ""shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App""", 1, False
pet = fso.BuildPath(root, "GPTDragonPet.exe")
If fso.FileExists(pet) Then
  running = False
  On Error Resume Next
  Set service = GetObject("winmgmts:\\.\root\cimv2")
  Set processes = service.ExecQuery("SELECT ExecutablePath FROM Win32_Process WHERE Name='GPTDragonPet.exe'")
  For Each process In processes
    If LCase(process.ExecutablePath) = LCase(pet) Then running = True
  Next
  On Error GoTo 0
  If Not running Then shell.Run """" & pet & """", 1, False
End If
