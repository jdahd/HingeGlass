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
    bool loadingPreferences, desktopSuspended, sessionLocked, sleeping, remoteDisconnected;
    bool pendingFollow;
    bool testMode=Environment.GetCommandLineArgs().Any(a=>a.EndsWith("-smoke")||a=="--self-test");
    void SaveDesktopPreferences() {
        if(loadingPreferences||testMode)return;
        try { DesktopPreferences.Save(DesktopPreferences.PathName,new DesktopPreferences {
            Live=live.IsChecked==true, Follow=follow.IsChecked==true||pendingFollow,
            Angle=angle.Value,Start=start.Value,Blur=blur.Value,
            Display=(displays.SelectedItem as System.Windows.Forms.Screen)?.DeviceName
        }); } catch { status.Text="Settings could not be saved. Check your user folder permissions."; }
    }
    async void LoadDesktopPreferences() {
        if(testMode)return;
        var p=DesktopPreferences.Load(DesktopPreferences.PathName);
        loadingPreferences=true;
        start.Value=double.IsFinite(p.Start)?Math.Clamp(p.Start,45,150):114;
        blur.Value=double.IsFinite(p.Blur)?Math.Clamp(p.Blur,0,80):68;
        angle.Value=double.IsFinite(p.Angle)?Math.Clamp(p.Angle,0,180):124;
        foreach(var item in displays.Items)if(item is System.Windows.Forms.Screen screen && screen.DeviceName==p.Display)displays.SelectedItem=item;
        pendingFollow=p.Live&&p.Follow;
        live.IsChecked=p.Live&&hotkey;
        // Do not apply a stale manual angle while waiting for a sensor.
        loadingPreferences=false;
        if(pendingFollow) {
            await Detect();
            if(closed)return;
            if(pendingFollow && live.IsChecked==true && follow.IsEnabled)follow.IsChecked=true;
            else if(pendingFollow) { live.IsChecked=false; status.Text="Saved sensor follow could not resume. Detect a compatible sensor or use manual mode."; }
            pendingFollow=false;
        }
        if(p.Live&&!hotkey)status.Text="Saved desktop effect paused: restore shortcut unavailable.";
    }
    void PauseDesktop(string reason) { desktopSuspended=true; StopDesktop(); status.Text=reason+"; will resume when available."; }
    async void ResumeDesktop() {
        if(closed||sessionLocked||sleeping||remoteDisconnected)return;
        if(follow.IsChecked==true && sensor!=null) {
            int ticket= generation;
            try {
                var reading=await sensor.GetCurrentReadingAsync().AsTask().WaitAsync(TimeSpan.FromSeconds(10));
                if(closed||ticket!=generation||sessionLocked||sleeping||remoteDisconnected)return;
                if(reading==null)throw new InvalidOperationException("No fresh angle reading");
                UpdateReading(reading.AngleInDegrees);
            } catch { if(!closed)status.Text="Resume paused: fresh sensor reading unavailable. Detect the sensor again."; return; }
        }
        desktopSuspended=false;
        if(live.IsChecked==true) { shown=follow.IsChecked==true?lastAngle:angle.Value; status.Text="Desktop effect re-enabled; waiting for an angle below the start angle."; }
    }
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
        live.Checked+=(_,_)=>{SaveDesktopPreferences();if(live.IsChecked==true&&!loadingPreferences)ResumeDesktop();};
        live.Unchecked+=(_,_)=>{pendingFollow=false;StopDesktop();SaveDesktopPreferences();};
        displays.SelectionChanged+=(_,_)=>{StopDesktop();SaveDesktopPreferences();};
        foreach(var slider in new[]{angle,start,blur})slider.ValueChanged+=(_,_)=>SaveDesktopPreferences();
        follow.Checked+=(_,_)=>SaveDesktopPreferences();follow.Unchecked+=(_,_)=>SaveDesktopPreferences();
        var panel=new StackPanel();panel.Children.Add(new Border{Height=80,Background=new SolidColorBrush(Color.FromRgb(10,17,26)),Child=graph,Margin=new Thickness(0,8,0,8)});panel.Children.Add(diagnostics);
        AddButton(panel,"Copy diagnostics",()=>{try{Clipboard.SetText(monitor.Report(clock.Elapsed.TotalSeconds,renderFps,captureStatus));}catch{status.Text="Clipboard busy. Try again.";}});
        controls.Children.Add(new Expander{Header="Compatibility monitor",Foreground=Brushes.White,Content=panel,IsExpanded=false,Margin=new Thickness(0,12,0,0)});
    }
    void InitializeDesktopEvents()
    {
        SourceInitialized+=(_,_)=>{handle=new WindowInteropHelper(this).Handle;hotkey=RegisterHotKey(handle,741,0x4003,0x1B);HwndSource.FromHwnd(handle)?.AddHook(Messages);LoadDesktopPreferences();};
        SystemEvents.PowerModeChanged+=PowerChanged;SystemEvents.DisplaySettingsChanged+=DisplayChanged;SystemEvents.SessionSwitch+=SessionChanged;
    }
    void UnregisterDesktopEvents(){if(hotkey)UnregisterHotKey(handle,741);SystemEvents.PowerModeChanged-=PowerChanged;SystemEvents.DisplaySettingsChanged-=DisplayChanged;SystemEvents.SessionSwitch-=SessionChanged;}
    void PowerChanged(object? s,PowerModeChangedEventArgs e)=>Dispatcher.BeginInvoke(new Action(()=>{
        if(e.Mode==PowerModes.Suspend){sleeping=true;PauseDesktop("Paused for sleep");}
        else if(e.Mode==PowerModes.Resume){sleeping=false;ResumeDesktop();}
    }));
    void DisplayChanged(object? s,EventArgs e)=>Dispatcher.BeginInvoke(new Action(()=>{
        var selected=(displays.SelectedItem as System.Windows.Forms.Screen)?.DeviceName;
        PauseDesktop("Display configuration changed"); loadingPreferences=true;
        displays.Items.Clear();foreach(var screen in System.Windows.Forms.Screen.AllScreens)displays.Items.Add(screen);
        displays.SelectedIndex=0;
        foreach(var item in displays.Items)if(item is System.Windows.Forms.Screen screen && screen.DeviceName==selected)displays.SelectedItem=item;
        loadingPreferences=false;ResumeDesktop();
    }));
    void SessionChanged(object? s,SessionSwitchEventArgs e)=>Dispatcher.BeginInvoke(new Action(()=>{
        if(e.Reason==SessionSwitchReason.SessionLock){sessionLocked=true;PauseDesktop("Paused while locked");}
        else if(e.Reason==SessionSwitchReason.RemoteDisconnect){remoteDisconnected=true;PauseDesktop("Remote session disconnected");}
        else if(e.Reason==SessionSwitchReason.SessionUnlock){sessionLocked=false;ResumeDesktop();}
        else if(e.Reason==SessionSwitchReason.RemoteConnect||e.Reason==SessionSwitchReason.ConsoleConnect){remoteDisconnected=false;ResumeDesktop();}
    }));
    IntPtr Messages(IntPtr h,int message,IntPtr w,IntPtr l,ref bool handled){if(message==0x312&&w.ToInt32()==741){RestoreDesktop("Restored by shortcut");handled=true;}return IntPtr.Zero;}
    void RestoreDesktop(string reason){pendingFollow=false;live.IsChecked=false;follow.IsChecked=false;angle.Value=Math.Max(124,start.Value);StopDesktop();SaveDesktopPreferences();status.Text=reason;}
    void StopDesktop(){generation++;desktop?.Close();desktop=null;Topmost=false;if(handle!=IntPtr.Zero)DesktopEffect.SetWindowDisplayAffinity(handle,0);captureStatus="Off";}
    async void UpdateDesktop(double now)
    {
        if(now-statsTime>=.5){renderFps=renderCount/(now-statsTime);renderCount=0;statsTime=now;diagnostics.Text=monitor.Report(now,renderFps,captureStatus);var history=monitor.History;graph.Points=new PointCollection(history.Select((r,i)=>new Point(i*250.0/Math.Max(1,history.Length-1),78-Math.Clamp(r.Angle,0,180)/180*76)));}
        if(live.IsChecked!=true||desktopSuspended||pendingFollow||loadingPreferences)return;
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
            pending.Failed+=reason=>{if(token==generation)RestoreDesktop(reason);};
            await pending.Start();
            if(token!=generation||closed){pending.Close();return;}
            Topmost=true;Activate();captureStatus="Live";
        }catch(Exception ex){pending?.Close();if(token==generation)RestoreDesktop($"Desktop unavailable: {ex.Message}");}finally{starting=false;}
    }
    internal async Task DesktopSmoke()
    {
        // Exercise real desktop capture, exclusion, threshold restoration and cleanup on Windows.
        if(!hotkey)throw new Exception("Hotkey registration failed");
        var screen=System.Windows.Forms.Screen.PrimaryScreen!;
        var fixture=await DesktopTestFixture.Create();
        Width=MinWidth;Height=MinHeight;Left=screen.Bounds.Left;Top=screen.Bounds.Top;
        Activate();
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
        if(fixture.Clicks!=1)throw new Exception($"Desktop mouse input blocked; clicks={fixture.Clicks}; screen={screen.Bounds}; controls={Left},{Top},{ActualWidth},{ActualHeight}");
        fixture.Red();
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
        WindowState=WindowState.Minimized;angle.Value=75;
        for(int i=0;i<50 && desktop==null;i++)await Task.Delay(100);
        if(desktop==null)throw new Exception("Minimized follow loop stopped");
        PauseDesktop("Test sleep");
        if(live.IsChecked!=true||desktop!=null)throw new Exception("Suspend lost user intent or retained capture");
        sessionLocked=true;ResumeDesktop();
        if(!desktopSuspended)throw new Exception("Resumed while still locked");
        sessionLocked=false;ResumeDesktop();
        for(int i=0;i<50 && (desktop==null||desktop.Frames<2);i++)await Task.Delay(100);
        if(desktop==null||desktop.Frames<2)throw new Exception("Resume did not restart live capture");
        RestoreDesktop("Smoke complete");ResumeDesktop();
        if(live.IsChecked==true||desktop!=null)throw new Exception("Manual restore re-enabled itself");
        var prefPath=System.IO.Path.Combine(System.IO.Path.GetTempPath(),Guid.NewGuid()+"-hingeglass.json");
        try {
            DesktopPreferences.Save(prefPath,new DesktopPreferences{Live=true,Follow=true,Angle=88,Start=110,Blur=55});
            var pref=DesktopPreferences.Load(prefPath);
            if(!pref.Live||!pref.Follow||pref.Angle!=88||pref.Start!=110||pref.Blur!=55)throw new Exception("Settings roundtrip failed");
            DesktopPreferences.Save(prefPath,new DesktopPreferences{Live=false});
            if(DesktopPreferences.Load(prefPath).Live)throw new Exception("Manual disable not persisted");
        } finally { System.IO.File.Delete(prefPath); }
        WindowState=WindowState.Normal;
        System.IO.File.WriteAllText("desktop-test.txt","Live frames, mouse pass-through, global shortcut input, shortcut restoration, expansion restoration and minimized activation passed. Live underlying color change and overlay exclusion passed on hosted runner. Physical sensor and device performance need QA.");
        } finally {RestoreDesktop("Test cleanup");await fixture.Close();}
    }
    [DllImport("user32.dll")]static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")]static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
    [DllImport("user32.dll")]static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
    [DllImport("user32.dll",SetLastError=true)]static extern bool RegisterHotKey(IntPtr h,int id,uint modifiers,uint key);
    [DllImport("user32.dll")]static extern bool UnregisterHotKey(IntPtr h,int id);
}
