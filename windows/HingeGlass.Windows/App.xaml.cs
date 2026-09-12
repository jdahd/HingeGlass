using System;
using System.IO;
using System.Windows;
namespace HingeGlass.Windows;
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if (Array.IndexOf(e.Args, "--self-test") >= 0)
        {
            try { EffectState.Check(); CompatibilityMonitor.Check(); Shutdown(0); }
            catch { Shutdown(1); }
            return;
        }
        var window = new MainWindow();
        MainWindow = window;
        window.Show();
        if (Array.IndexOf(e.Args, "--desktop-smoke") >= 0)
        {
            window.ContentRendered += async (_, _) => { try { await window.DesktopSmoke(); Shutdown(0); } catch(Exception ex) { File.WriteAllText("desktop-test-error.txt",ex.ToString()); Shutdown(1); } };
        }
        if (Array.IndexOf(e.Args, "--ui-smoke") >= 0)
        {
            window.ContentRendered += async (_, _) => {
                await System.Threading.Tasks.Task.Delay(500);
                try {
                    window.SavePreview("windows-preview.png");
                    Shutdown(0);
                } catch { Shutdown(1); }
            };
        }
    }
}
