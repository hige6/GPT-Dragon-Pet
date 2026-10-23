// Current-user companion launcher. No network, credentials, task contents or window titles.
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows.Forms;

internal static class DragonCodexWatcher {
  static readonly string Root = AppDomain.CurrentDomain.BaseDirectory;
  static readonly string Pet = Path.Combine(Root, "GPTDragonPet.exe");
  static readonly int Session = Process.GetCurrentProcess().SessionId;
  static readonly string Name = "Local\\GPTDragonPet.CodexWatcher." + Session;

  internal static bool IsDesktop(string name, string file) {
    if (String.IsNullOrEmpty(file)) return false;
    if (!name.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase) && !name.Equals("Codex", StringComparison.OrdinalIgnoreCase)) return false;
    // Exclude Codex CLI workers. Store desktop paths are version-independent.
    return file.IndexOf("\\WindowsApps\\OpenAI.Codex_", StringComparison.OrdinalIgnoreCase) >= 0
      || file.IndexOf("\\OpenAI\\Codex\\app\\", StringComparison.OrdinalIgnoreCase) >= 0;
  }
  static bool CodexRunning() {
    foreach (string name in new[] { "ChatGPT", "Codex" })
      foreach (Process p in Process.GetProcessesByName(name)) using (p) {
        try { if (p.SessionId == Session && IsDesktop(p.ProcessName, p.MainModule.FileName)) return true; } catch { }
      }
    return false;
  }
  static bool PetRunning() {
    foreach (Process p in Process.GetProcessesByName("GPTDragonPet")) using (p) {
      try { if (p.SessionId == Session && String.Equals(p.MainModule.FileName, Pet, StringComparison.OrdinalIgnoreCase)) return true; } catch { }
    }
    return false;
  }
  [STAThread] static int Main(string[] args) {
    using (var stop = new EventWaitHandle(false, EventResetMode.AutoReset, Name + ".Stop")) {
      if (Array.IndexOf(args, "--stop") >= 0) { stop.Set(); return 0; }
      if (Array.IndexOf(args, "--probe") >= 0) {
        var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GPTDragonPet", "state");
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, "codex-autostart-probe.json"), "{\"codexRunning\":" + CodexRunning().ToString().ToLowerInvariant() + ",\"petRunning\":" + PetRunning().ToString().ToLowerInvariant() + "}");
        return 0;
      }
      bool owns;
      using (var mutex = new Mutex(true, Name, out owns)) {
        if (!owns) return 0;
        // A manual pet exit is respected until Codex has fully closed and reopened.
        bool seen = false;
        Action tick = () => {
          if (stop.WaitOne(0)) { Application.ExitThread(); return; }
          bool running = CodexRunning();
          if (running && !seen && !PetRunning() && File.Exists(Pet)) {
            try { Process.Start(new ProcessStartInfo(Pet) { WorkingDirectory = Root, UseShellExecute = false, CreateNoWindow = true }); } catch { }
          }
          seen = running;
        };
        using (var timer = new System.Windows.Forms.Timer()) {
          timer.Interval = 3000; timer.Tick += (s, e) => tick();
          tick(); timer.Start(); Application.Run();
        }
        mutex.ReleaseMutex();
      }
    }
    return 0;
  }
}
