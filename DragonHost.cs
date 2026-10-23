// Native GUI entry point for Windows PowerShell 5.1 + WPF (no terminal window).
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

internal static class DragonHost {
  [STAThread]
  private static int Main(string[] args) {
    try {
      var modules = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "Modules");
      Environment.SetEnvironmentVariable("PSModulePath", modules + ";" + Environment.GetEnvironmentVariable("PSModulePath"));
      using (var runspace = RunspaceFactory.CreateRunspace()) {
        runspace.ApartmentState = ApartmentState.STA;
        runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
        runspace.Open();
        using (var ps = PowerShell.Create()) {
          ps.Runspace = runspace;
          ps.AddCommand("Set-ExecutionPolicy").AddParameter("Scope", "Process").AddParameter("ExecutionPolicy", "Bypass").AddParameter("Force");
          ps.Invoke(); ps.Commands.Clear(); ps.Streams.Error.Clear();
          ps.AddCommand(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Start-Dragon.ps1"));
          if (Array.IndexOf(args, "--qa-window") >= 0) ps.AddParameter("QaWindow");
          if (Array.IndexOf(args, "--check-only") >= 0) ps.AddParameter("CheckOnly");
          int dataDirIndex = Array.IndexOf(args, "--data-dir");
          if (dataDirIndex >= 0) {
            if (dataDirIndex + 1 >= args.Length || args[dataDirIndex + 1].StartsWith("--"))
              throw new ArgumentException("--data-dir requires a directory path.");
            ps.AddParameter("DataDir", args[dataDirIndex + 1]);
          }
          ps.Invoke();
          if (ps.HadErrors) {
            var log = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GPTDragonPet", "state", "host-error.txt");
            Directory.CreateDirectory(Path.GetDirectoryName(log));
            using (var writer = new StreamWriter(log, false)) foreach (var error in ps.Streams.Error) writer.WriteLine(error.ToString());
            throw new InvalidOperationException("Dragon failed to start.");
          }
        }
      }
      return 0;
    } catch (Exception exception) {
      var log = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GPTDragonPet", "state", "host-error.txt");
      Directory.CreateDirectory(Path.GetDirectoryName(log));
      File.AppendAllText(log, exception.GetType().Name + ": " + exception.Message + Environment.NewLine);
      MessageBox.Show("GPT Dragon Pet could not start. Run Start-Dragon.ps1 in PowerShell for diagnostics.", "GPT Dragon Pet", MessageBoxButtons.OK, MessageBoxIcon.Error);
      return 1;
    }
  }
}
