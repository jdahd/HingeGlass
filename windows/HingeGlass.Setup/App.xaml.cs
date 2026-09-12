using System;
using System.Windows;
namespace HingeGlass.Setup;
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var window=new SetupWindow(e.Args);MainWindow=window;window.Show();
    }
}
