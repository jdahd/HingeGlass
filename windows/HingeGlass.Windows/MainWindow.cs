using System;
using System.IO;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Media.Media3D;
using Windows.Devices.Sensors;
using Microsoft.Win32;
namespace HingeGlass.Windows;
public sealed class MainWindow : Window
{
    readonly Slider angle=new(){Minimum=0,Maximum=180,Value=124};
    readonly Slider start=new(){Minimum=45,Maximum=150,Value=114};
    readonly Slider blur=new(){Minimum=0,Maximum=80,Value=68};
    readonly TextBlock value=new(){FontSize=48,Margin=new Thickness(0,4,0,12)};
    readonly TextBlock status=new(){Text="Detect the sensor to check this computer.",TextWrapping=TextWrapping.Wrap};
    readonly CheckBox follow=new(){Content="Follow sensor in preview",Foreground=Brushes.LightGray,IsEnabled=false,Margin=new Thickness(0,12,0,12)};
    readonly MeshGeometry3D mesh=new();
    readonly Viewport3D viewport=new();
    readonly BlurEffect blurEffect=new(){RenderingBias=RenderingBias.Performance};
    readonly Border preview=new(){Background=Brushes.Black,ClipToBounds=true,MinHeight=220};
    readonly ImageBrush imageBrush=new(){Stretch=Stretch.Fill};
    readonly System.Windows.Shapes.Rectangle dim=new(){Fill=Brushes.Black,IsHitTestVisible=false};
    HingeAngleSensor? sensor;
    bool closed, detecting;
    double lastAngle=124, shown=124;
    long samples;
    readonly Stopwatch clock=Stopwatch.StartNew();
    double previous;
    EffectState? lastDrawn;
    double lastAspect;
    public MainWindow()
    {
        Title="HingeGlass · Windows Preview 0.1.1";
        Width=1020;Height=760;MinWidth=720;MinHeight=580;
        Background=new SolidColorBrush(Color.FromRgb(19,25,35));Foreground=Brushes.White;
        FontFamily=new FontFamily("Segoe UI");FontSize=14;
        var root=new Grid{Margin=new Thickness(24)};
        root.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(290)});
        root.ColumnDefinitions.Add(new ColumnDefinition());
        Content=root;
        var controls=new StackPanel{Margin=new Thickness(0,0,24,0)};
        var scroll=new ScrollViewer{Content=controls,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};root.Children.Add(scroll);
        controls.Children.Add(new TextBlock{Text="HingeGlass",FontSize=30,FontWeight=FontWeights.SemiBold});
        controls.Children.Add(new TextBlock{Text="Windows · experimental preview",Foreground=Brushes.LightSkyBlue,Margin=new Thickness(0,4,0,16)});
        controls.Children.Add(value);
        AddSlider(controls,"Manual angle",angle);
        AddSlider(controls,"Start angle",start);
        AddSlider(controls,"Maximum blur",blur);
        AddButton(controls,"Detect angle sensor",async()=>await Detect());
        controls.Children.Add(follow);controls.Children.Add(status);
        AddButton(controls,"Open image…",OpenImage);
        AddButton(controls,"Take desktop snapshot",async()=>await Snapshot());
        AddButton(controls,"Restore preview",()=>{follow.IsChecked=false;angle.Value=124;});
        controls.Children.Add(new TextBlock{Text="Preview only. The desktop snapshot is a still image, not a live feed. Esc stops following the sensor.",TextWrapping=TextWrapping.Wrap,Foreground=Brushes.LightGray,Margin=new Thickness(0,18,0,0)});
        var right=new Grid();Grid.SetColumn(right,1);root.Children.Add(right);
        right.RowDefinitions.Add(new RowDefinition());right.RowDefinitions.Add(new RowDefinition{Height=GridLength.Auto});
        var layers=new Grid();layers.Children.Add(viewport);layers.Children.Add(dim);preview.Child=layers;right.Children.Add(preview);
        var note=new TextBlock{Text="Angle-driven perspective · blur · dimming\nNo recording, uploads, or automatic desktop overlay.",TextWrapping=TextWrapping.Wrap,Foreground=Brushes.LightGray,Margin=new Thickness(0,12,0,0)};Grid.SetRow(note,1);right.Children.Add(note);
        viewport.Camera=new OrthographicCamera(new Point3D(0,0,4),new Vector3D(0,0,-1),new Vector3D(0,1,0),2);
        viewport.Effect=blurEffect;
        var model=new GeometryModel3D{Geometry=mesh,Material=new EmissiveMaterial(imageBrush)};
        viewport.Children.Add(new ModelVisual3D{Content=model});
        imageBrush.ImageSource=MakeScene();
        follow.Checked+=(_,_)=>angle.IsEnabled=false;follow.Unchecked+=(_,_)=>angle.IsEnabled=true;
        SizeChanged+=(_,_)=>Draw();
        System.Windows.Media.CompositionTarget.Rendering+=Frame;
        Closed+=(_,_)=>{closed=true;System.Windows.Media.CompositionTarget.Rendering-=Frame;if(sensor!=null)sensor.ReadingChanged-=Reading;};
        KeyDown+=(_,e)=>{if(e.Key==System.Windows.Input.Key.Escape){follow.IsChecked=false;angle.Value=124;}};
        Draw();
    }
    static void AddButton(Panel p,string name,Action action){var b=new Button{Content=name,Padding=new Thickness(10,7,10,7),Margin=new Thickness(0,12,0,0)};b.Click+=(_,_)=>action();p.Children.Add(b);}
    static void AddSlider(Panel p,string name,Slider s){var label=new TextBlock{Margin=new Thickness(0,10,0,5)};void Update()=>label.Text=$"{name}   {s.Value:0}";s.ValueChanged+=(_,_)=>Update();Update();p.Children.Add(label);p.Children.Add(s);}
    void Frame(object? sender,EventArgs e)
    {
        double now=clock.Elapsed.TotalSeconds,dt=Math.Clamp(now-previous,0,.1);previous=now;
        double target=follow.IsChecked==true?lastAngle:angle.Value;
        shown+=(target-shown)*(1-Math.Exp(-dt/.045));
        Draw();
    }
    void Draw()
    {
        var s=EffectState.At(shown,start.Value,blur.Value);
        value.Text=$"{shown:0}°";
        double h=viewport.ActualWidth>0?viewport.ActualHeight/viewport.ActualWidth:1;
        if(lastDrawn is EffectState old && Math.Abs(old.Width-s.Width)<.00001 && Math.Abs(old.Blur-s.Blur)<.001 && Math.Abs(old.Darkness-s.Darkness)<.00001 && h==lastAspect)return;
        lastDrawn=s;lastAspect=h;
        // Subdivided trapezoid reduces the diagonal interpolation seam of a single quad.
        var points=new Point3DCollection();var uv=new PointCollection();var indices=new Int32Collection();
        const int rows=32;
        for(int i=0;i<=rows;i++){
            double t=i/(double)rows,w=s.Width+(1-s.Width)*t;
            points.Add(new Point3D(-w,h*(1-2*t),0));points.Add(new Point3D(w,h*(1-2*t),0));
            double v=t/(s.Width+(1-s.Width)*t);
            uv.Add(new Point(0,v));uv.Add(new Point(1,v));
            if(i<rows){int n=i*2;foreach(int j in new[]{n,n+2,n+1,n+1,n+2,n+3})indices.Add(j);}
        }
        mesh.Positions=points;mesh.TextureCoordinates=uv;mesh.TriangleIndices=indices;
        blurEffect.Radius=s.Blur;dim.Opacity=s.Darkness;
    }
    async Task Detect()
    {
        if(detecting)return;detecting=true;follow.IsChecked=false;follow.IsEnabled=false;
        if(sensor!=null){sensor.ReadingChanged-=Reading;sensor=null;}
        status.Text="Checking angle sensor…";
        try {
            var detected=await HingeAngleSensor.GetDefaultAsync();
            if(closed)return;
            sensor=detected;
            if(sensor==null){status.Text="No compatible angle sensor found. Manual preview is available.";return;}
            samples=0;sensor.ReadingChanged+=Reading;
            var reading=await sensor.GetCurrentReadingAsync();
            if(closed)return;
            if(reading!=null)UpdateReading(reading.AngleInDegrees);
            status.Text="Sensor found. Slowly move the lid to check readings. Do not fully close it.";
        }catch(Exception ex){status.Text=$"Sensor unavailable (0x{ex.HResult:X8}). Manual preview is available.";}
        finally{detecting=false;}
    }
    void Reading(HingeAngleSensor sender,HingeAngleSensorReadingChangedEventArgs args)
    {
        double a=args.Reading.AngleInDegrees;
        if(!closed)Dispatcher.BeginInvoke(new Action(()=>{if(!closed && ReferenceEquals(sensor,sender))UpdateReading(a);}));
    }
    void UpdateReading(double a)
    {
        if(!double.IsFinite(a)||a<0||a>360)return;
        lastAngle=a;samples++;follow.IsEnabled=true;
        status.Text=$"Sensor: {a:0.0}° · {samples} readings\nAngle convention depends on your device. Verify before enabling follow.";
    }
    void OpenImage()
    {
        var picker=new OpenFileDialog{Filter="Images|*.png;*.jpg;*.jpeg;*.bmp"};
        if(picker.ShowDialog(this)!=true)return;
        try{var img=new BitmapImage();img.BeginInit();img.CacheOption=BitmapCacheOption.OnLoad;img.DecodePixelWidth=1600;img.UriSource=new Uri(picker.FileName);img.EndInit();img.Freeze();imageBrush.ImageSource=img;}
        catch{status.Text="This image could not be opened.";}
    }
    [DllImport("gdi32.dll")]static extern bool DeleteObject(IntPtr value);
    async Task Snapshot()
    {
        try{
            Hide();await Task.Delay(250);if(closed)return;
            var bounds=System.Windows.Forms.Screen.PrimaryScreen!.Bounds;
            using var bitmap=new System.Drawing.Bitmap(bounds.Width,bounds.Height);
            using(var graphics=System.Drawing.Graphics.FromImage(bitmap))graphics.CopyFromScreen(bounds.Location,System.Drawing.Point.Empty,bounds.Size);
            IntPtr handle=bitmap.GetHbitmap();
            try{var img=System.Windows.Interop.Imaging.CreateBitmapSourceFromHBitmap(handle,IntPtr.Zero,Int32Rect.Empty,BitmapSizeOptions.FromEmptyOptions());img.Freeze();imageBrush.ImageSource=img;}
            finally{DeleteObject(handle);}
            status.Text="Primary desktop snapshot loaded in memory. Click again to refresh.";
        }catch{status.Text="Desktop snapshot unavailable. Open an image instead.";}
        finally{if(!closed){Show();Activate();}}
    }
    static ImageSource MakeScene()
    {
        var drawing=new DrawingVisual();using(var d=drawing.RenderOpen()){
            d.DrawRectangle(new LinearGradientBrush(Color.FromRgb(39,88,142),Color.FromRgb(172,206,214),90),null,new Rect(0,0,1200,800));
            d.DrawEllipse(Brushes.LightGoldenrodYellow,null,new Point(890,200),55,55);
            for(int i=0;i<4;i++)d.DrawEllipse(new SolidColorBrush(Color.FromRgb((byte)(30-i*4),(byte)(80-i*10),(byte)(97-i*11))),null,new Point(200+i*280,850+i*35),750,420-i*20);
        }
        var image=new RenderTargetBitmap(1200,800,96,96,PixelFormats.Pbgra32);image.Render(drawing);image.Freeze();return image;
    }
    internal void SavePreview(string path)
    {
        follow.IsChecked=false;angle.Value=75;shown=75;Draw();UpdateLayout();
        var bitmap=new RenderTargetBitmap((int)ActualWidth,(int)ActualHeight,96,96,PixelFormats.Pbgra32);bitmap.Render(this);
        var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));using var file=File.Create(path);encoder.Save(file);
    }
}
