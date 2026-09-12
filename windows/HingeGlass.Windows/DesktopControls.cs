using System;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using Microsoft.Win32;
namespace HingeGlass.Windows;
public sealed partial class MainWindow
{
    readonly CompatibilityMonitor monitor=new();
    readonly TextBlock diagnostics=new(){TextWrapping=TextWrapping.Wrap,FontSize=13,Foreground=Brushes.LightGray};
    readonly System.Windows.Shapes.Polyline graph=new(){Stroke=Brushes.LightSkyBlue,StrokeThickness=2};
    readonly ComboBox displays=new(){Margin=new Thickness(0,10,0,0)};
    readonly CheckBox live=new(){Content="Enable live desktop",Foreground=Brushes.White,Margin=new Thickness(0,14,0,8)};
    DesktopEffect? desktop;
    bool starting,hotkey;
    int generation,renderCount;
    double statsTime,renderFps;
    string captureStatus="Off";
    IntPtr handle;
    void AddDesktopControls(Panel controls)
    {
        foreach(var screen in System.Windows.Forms.Screen.AllScreens)displays.Items.Add(screen);
        displays.DisplayMemberPath="DeviceName";displays.SelectedIndex=0;
        controls.Children.Add(displays);controls.Children.Add(live);
        live.Checked+=(_,_)=>{if(!hotkey){live.IsChecked=false;status.Text="Global restore shortcut unavailable. Close conflicting apps and reopen HingeGlass.";}};
        live.Unchecked+=(_,_)=>StopDesktop();displays.SelectionChanged+=(_,_)=>RestoreDesktop("Display changed; enable again");
        var panel=new StackPanel();panel.Children.Add(new Border{Height=80,Background=new SolidColorBrush(Color.FromRgb(10,17,26)),Child=graph,Margin=new Thickness(0,8,0,8)});panel.Children.Add(diagnostics);
        AddButton(panel,"Copy diagnostics",()=>{try{Clipboard.SetText(monitor.Report(clock.Elapsed.TotalSeconds,renderFps,captureStatus));}catch{status.Text="Clipboard busy. Try again.";}});
        controls.Children.Add(new Expander{Header="Compatibility monitor",Foreground=Brushes.White,Content=panel,IsExpanded=false,Margin=new Thickness(0,12,0,0)});
    }
    void InitializeDesktopEvents()
    {
        SourceInitialized+=(_,_)=>{handle=new WindowInteropHelper(this).Handle;hotkey=RegisterHotKey(handle,741,0x4003,0x1B);HwndSource.FromHwnd(handle)?.AddHook(Messages);};
        SystemEvents.PowerModeChanged+=PowerChanged;SystemEvents.DisplaySettingsChanged+=DisplayChanged;SystemEvents.SessionSwitch+=SessionChanged;
    }
    void UnregisterDesktopEvents(){if(hotkey)UnregisterHotKey(handle,741);SystemEvents.PowerModeChanged-=PowerChanged;SystemEvents.DisplaySettingsChanged-=DisplayChanged;SystemEvents.SessionSwitch-=SessionChanged;}
    void PowerChanged(object? s,PowerModeChangedEventArgs e){if(e.Mode==PowerModes.Suspend)Dispatcher.Invoke(()=>RestoreDesktop("Paused for sleep"));}
    void DisplayChanged(object? s,EventArgs e)=>Dispatcher.BeginInvoke(new Action(()=>{RestoreDesktop("Display configuration changed");displays.Items.Clear();foreach(var screen in System.Windows.Forms.Screen.AllScreens)displays.Items.Add(screen);displays.SelectedIndex=0;}));
    void SessionChanged(object? s,SessionSwitchEventArgs e){if(e.Reason==SessionSwitchReason.SessionLock||e.Reason==SessionSwitchReason.RemoteDisconnect)Dispatcher.BeginInvoke(new Action(()=>RestoreDesktop("Session paused")));}
    IntPtr Messages(IntPtr h,int message,IntPtr w,IntPtr l,ref bool handled){if(message==0x312&&w.ToInt32()==741){RestoreDesktop("Restored by shortcut");handled=true;}return IntPtr.Zero;}
    void RestoreDesktop(string reason){live.IsChecked=false;follow.IsChecked=false;angle.Value=Math.Max(124,start.Value);StopDesktop();status.Text=reason;}
    void StopDesktop(){generation++;desktop?.Close();desktop=null;Topmost=false;if(handle!=IntPtr.Zero)DesktopEffect.SetWindowDisplayAffinity(handle,0);captureStatus="Off";}
    async void UpdateDesktop(double now)
    {
        renderCount++;
        if(now-statsTime>=.5){renderFps=renderCount/(now-statsTime);renderCount=0;statsTime=now;diagnostics.Text=monitor.Report(now,renderFps,captureStatus);var history=monitor.History;graph.Points=new PointCollection(history.Select((r,i)=>new Point(i*250.0/Math.Max(1,history.Length-1),78-Math.Clamp(r.Angle,0,180)/180*76)));}
        if(live.IsChecked!=true)return;
        // Expansion removes the overlay and stops capture, while keeping follow armed.
        if(shown>=start.Value-.15){if(desktop!=null)StopDesktop();return;}
        if(desktop!=null){desktop.SetEffect(EffectState.At(shown,start.Value,blur.Value));captureStatus=$"Live · {desktop.CaptureRate:0.0} captures/s · {desktop.Frames} frames · frame age {desktop.Age:0.00}s · max 1600px / 30 Hz";if(desktop.Age>3)RestoreDesktop("Capture stalled; desktop restored");return;}
        if(starting)return;
        starting=true;int token=++generation;
        DesktopEffect? pending=null;
        try{
            if(!hotkey)throw new InvalidOperationException("Restore shortcut unavailable");
            if(!DesktopEffect.SetWindowDisplayAffinity(handle,0x11))throw new InvalidOperationException("Settings capture exclusion unavailable");
            var screen=displays.SelectedItem as System.Windows.Forms.Screen??throw new InvalidOperationException("Select a display");
            pending=new DesktopEffect(screen);desktop=pending;pending.SetEffect(EffectState.At(shown,start.Value,blur.Value));
            pending.Failed+=reason=>RestoreDesktop(reason);
            await pending.Start();
            if(token!=generation||closed){pending.Close();return;}
            Topmost=true;Activate();captureStatus="Live";
        }catch(Exception ex){pending?.Close();RestoreDesktop($"Desktop unavailable: {ex.Message}");}finally{starting=false;}
    }
    internal async Task DesktopSmoke()
    {
        // Exercise real desktop capture, exclusion, threshold restoration and cleanup on Windows.
        if(!hotkey)throw new Exception("Hotkey registration failed");
        var screen=System.Windows.Forms.Screen.PrimaryScreen!;
        var fixture=new Window{WindowStyle=WindowStyle.None,WindowState=WindowState.Maximized,Background=Brushes.Lime,ShowInTaskbar=false};
        Width=MinWidth;Height=MinHeight;Left=screen.Bounds.Left;Top=screen.Bounds.Top;
        int clicks=0;fixture.MouseDown+=(_,_)=>clicks++;
        fixture.Show();Activate();
        try {
        angle.Value=75;live.IsChecked=true;
        for(int i=0;i<60 && (desktop==null||desktop.Frames<3);i++)await Task.Delay(100);
        if(desktop==null||desktop.Frames<3)throw new Exception($"No live frames: {status.Text}; {captureStatus}; starting={starting}; shown={shown}; live={live.IsChecked}");
        if(!DesktopEffect.SetWindowDisplayAffinity(handle,0x11))throw new Exception("No exclusion");
        var first=DesktopEffect.Capture(screen.Bounds);
        byte[] pixel=new byte[4];
        first.CopyPixels(new Int32Rect(first.PixelWidth-30,first.PixelHeight/2,1,1),pixel,4,0);
        if(pixel[1]<200||pixel[0]>50||pixel[2]>50)throw new Exception($"Overlay exclusion failed: {pixel[0]},{pixel[1]},{pixel[2]}");
        SetCursorPos(screen.Bounds.Right-50,screen.Bounds.Top+screen.Bounds.Height/2);
        mouse_event(2,0,0,0,UIntPtr.Zero);mouse_event(4,0,0,0,UIntPtr.Zero);await Task.Delay(200);
        if(clicks!=1)throw new Exception($"Desktop mouse input blocked; clicks={clicks}; screen={screen.Bounds}; controls={Left},{Top},{ActualWidth},{ActualHeight}");
        fixture.Background=Brushes.Red;
        for(int i=0;i<30;i++){
            await Task.Delay(100);
            var second=DesktopEffect.Capture(screen.Bounds);
            second.CopyPixels(new Int32Rect(second.PixelWidth-30,second.PixelHeight/2,1,1),pixel,4,0);
            if(pixel[2]>200&&pixel[0]<50&&pixel[1]<50)break;
        }
        if(pixel[2]<200||pixel[0]>50||pixel[1]>50)throw new Exception($"Live source did not change: {pixel[0]},{pixel[1]},{pixel[2]}");
        // Deliver the registered shortcut through Windows keyboard input, not a direct restore call.
        keybd_event(0x11,0,0,UIntPtr.Zero);keybd_event(0x12,0,0,UIntPtr.Zero);keybd_event(0x1B,0,0,UIntPtr.Zero);
        keybd_event(0x1B,0,2,UIntPtr.Zero);keybd_event(0x12,0,2,UIntPtr.Zero);keybd_event(0x11,0,2,UIntPtr.Zero);
        await Task.Delay(300);
        if(desktop!=null||live.IsChecked==true||Topmost)throw new Exception("Restore failed");
        angle.Value=75;live.IsChecked=true;await Task.Delay(1500);angle.Value=150;await Task.Delay(600);
        if(desktop!=null)throw new Exception("Expansion failed");
        RestoreDesktop("Smoke complete");
        System.IO.File.WriteAllText("desktop-test.txt","Live frames, mouse pass-through, global shortcut input, shortcut restoration, expansion restoration passed. Live underlying color change and overlay exclusion passed on hosted runner. Physical sensor and device performance need QA.");
        } finally {RestoreDesktop("Test cleanup");fixture.Close();}
    }
    [DllImport("user32.dll")]static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")]static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
    [DllImport("user32.dll")]static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
    [DllImport("user32.dll",SetLastError=true)]static extern bool RegisterHotKey(IntPtr h,int id,uint modifiers,uint key);
    [DllImport("user32.dll")]static extern bool UnregisterHotKey(IntPtr h,int id);
}
