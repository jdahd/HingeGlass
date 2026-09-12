using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
namespace HingeGlass.Setup;
public partial class SetupWindow : Window
{
    readonly string[] args;
    readonly string installDir;
    bool busy;
    readonly bool motion=SystemParameters.ClientAreaAnimation;
    public SetupWindow(string[] arguments)
    {
        InitializeComponent();args=arguments;
        installDir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","HingeGlass");
        int index=Array.IndexOf(args,"--test-dir");
        if(index>=0 && index+1<args.Length && Array.IndexOf(args,"--installer-smoke")>=0) installDir=Path.GetFullPath(args[index+1]);
        Loaded+=async(_,_)=>{
            AnimateEntrance();
            if(Array.IndexOf(args,"--installer-smoke")>=0){
                await Task.Delay(900);Capture("installer-preview.png");
                bool ok=await Install();
                await Task.Delay(700);Capture(ok?"installer-finished.png":"installer-error.png");
                Application.Current.Shutdown(ok?0:1);
            }
        };
        Closing+=(_,e)=>{if(busy){e.Cancel=true;System.Windows.MessageBox.Show(this,"Please wait for installation to finish.","Installing HingeGlass",MessageBoxButton.OK,MessageBoxImage.Information);}};
    }
    void AnimateEntrance()
    {
        if(!motion)return;
        var stage=(TransformGroup)IconStage.RenderTransform;
        var scale=(ScaleTransform)stage.Children[0];
        scale.BeginAnimation(ScaleTransform.ScaleXProperty,Tween(.9,1,.85));scale.BeginAnimation(ScaleTransform.ScaleYProperty,Tween(.9,1,.85));
        var floatTransform=(TranslateTransform)stage.Children[1];
        floatTransform.BeginAnimation(TranslateTransform.YProperty,new DoubleAnimation(-5,5,TimeSpan.FromSeconds(3.6)){AutoReverse=true,RepeatBehavior=RepeatBehavior.Forever,EasingFunction=new SineEase{EasingMode=EasingMode.EaseInOut}});
        foreach(var orb in new[]{Halo,HaloTwo}){
            var t=(TranslateTransform)orb.RenderTransform;
            t.BeginAnimation(TranslateTransform.XProperty,new DoubleAnimation(-15,22,TimeSpan.FromSeconds(orb==Halo?6:8)){AutoReverse=true,RepeatBehavior=RepeatBehavior.Forever,EasingFunction=new SineEase{EasingMode=EasingMode.EaseInOut}});
        }
        ContentStage.BeginAnimation(OpacityProperty,Tween(0,1,.75));
        ((TranslateTransform)ContentStage.RenderTransform).BeginAnimation(TranslateTransform.YProperty,Tween(15,0,.75));
    }
    static DoubleAnimation Tween(double from,double to,double seconds)=>new(from,to,TimeSpan.FromSeconds(seconds)){EasingFunction=new CubicEase{EasingMode=EasingMode.EaseOut}};
    async Task Stage(UIElement next)
    {
        if(motion){ContentStage.BeginAnimation(OpacityProperty,Tween(1,0,.16));await Task.Delay(170);}
        foreach(var panel in new UIElement[]{Welcome,Installing,Complete,Failure})panel.Visibility=panel==next?Visibility.Visible:Visibility.Collapsed;
        ContentStage.BeginAnimation(OpacityProperty,null);ContentStage.Opacity=1;
        if(motion){ContentStage.BeginAnimation(OpacityProperty,Tween(0,1,.35));((TranslateTransform)ContentStage.RenderTransform).BeginAnimation(TranslateTransform.YProperty,Tween(10,0,.35));}
    }
    async Task<bool> Install()
    {
        if(busy)return false;busy=true;
        string temp=Path.Combine(Path.GetTempPath(),"HingeGlass-Setup-"+Guid.NewGuid().ToString("N"));
        try{
            await Stage(Installing);
            Directory.CreateDirectory(temp);
            string payload=Path.Combine(temp,"Install.exe");
            using(var resource=Assembly.GetExecutingAssembly().GetManifestResourceStream("HingeGlass.Payload.exe") ?? throw new IOException("Installer payload missing"))
            using(var file=new FileStream(payload,FileMode.CreateNew,FileAccess.Write,FileShare.None,81920,true))await resource.CopyToAsync(file);
            InstallStatus.Text="Installing the app and its shortcuts…";
            if(Array.IndexOf(args,"--installer-smoke")>=0){await Task.Delay(500);Capture("installer-progress.png");}
            var info=new ProcessStartInfo(payload){UseShellExecute=false};
            foreach(var argument in new[]{"/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART","/CURRENTUSER","/DIR="+installDir})info.ArgumentList.Add(argument);
            using(var process=Process.Start(info) ?? throw new IOException("Unable to start installation")){
                using var deadline=new CancellationTokenSource(TimeSpan.FromMinutes(3));
                try{await process.WaitForExitAsync(deadline.Token);}catch(OperationCanceledException){process.Kill(true);await process.WaitForExitAsync();throw new IOException("Installation timed out");}
                if(process.ExitCode!=0 && process.ExitCode!=3010)throw new IOException("Installer exited with code "+process.ExitCode);
            }
            if(!File.Exists(Path.Combine(installDir,"HingeGlass.exe")))throw new IOException("Installed app was not found");
            busy=false;await Stage(Complete);return true;
        }catch(Exception ex){
            busy=false;ErrorText.Text="Installation could not finish. Close any running HingeGlass window and try again.\n\n"+ex.Message;
            await Stage(Failure);return false;
        }finally{try{if(Directory.Exists(temp))Directory.Delete(temp,true);}catch(IOException){}catch(UnauthorizedAccessException){}}
    }
    async void InstallClick(object sender,RoutedEventArgs e)=>await Install();
    void OpenClick(object sender,RoutedEventArgs e)
    {
        try{Process.Start(new ProcessStartInfo(Path.Combine(installDir,"HingeGlass.exe")){UseShellExecute=true});Close();}
        catch{ErrorText.Text="The app could not be opened. You can try it from the Start menu.";Complete.Visibility=Visibility.Collapsed;Failure.Visibility=Visibility.Visible;}
    }
    void CloseClick(object sender,RoutedEventArgs e)=>Close();
    void DragBar(object sender,MouseButtonEventArgs e){if(e.ChangedButton==MouseButton.Left)DragMove();}
    void Capture(string name)
    {
        UpdateLayout();var image=new RenderTargetBitmap((int)ActualWidth,(int)ActualHeight,96,96,PixelFormats.Pbgra32);image.Render(this);
        var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(image));using var file=File.Create(name);encoder.Save(file);
    }
}
