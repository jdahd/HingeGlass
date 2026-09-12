using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Media.Media3D;
namespace HingeGlass.Windows;
// Bounded CPU capture fallback; one frame in flight, maximum 1600 pixels wide / 30 Hz.
internal sealed class DesktopEffect : System.Windows.Forms.Form
{
    readonly ImageBrush image=new(){Stretch=Stretch.Fill};
    readonly MeshGeometry3D mesh=new();
    readonly BlurEffect blur=new(){RenderingBias=RenderingBias.Performance};
    readonly System.Windows.Shapes.Rectangle dim=new(){Fill=Brushes.Black};
    readonly CancellationTokenSource cancellation=new();
    readonly System.Drawing.Rectangle bounds;
    public long Frames {get;private set;}
    public double LastFrame {get;private set;}
    public event Action<string>? Failed;
    readonly Stopwatch clock=Stopwatch.StartNew();
    public double CaptureRate=>Frames/Math.Max(.001,clock.Elapsed.TotalSeconds);
    public double Age=>clock.Elapsed.TotalSeconds-LastFrame;
    public DesktopEffect(System.Windows.Forms.Screen screen)
    {
        bounds=screen.Bounds;FormBorderStyle=System.Windows.Forms.FormBorderStyle.None;
        StartPosition=System.Windows.Forms.FormStartPosition.Manual;Bounds=bounds;
        ShowInTaskbar=false;TopMost=true;BackColor=System.Drawing.Color.Black;
        // Constant-alpha native host supports capture exclusion and cross-process click-through.
        Opacity=254.0/255.0;
        var viewport=new Viewport3D{Camera=new OrthographicCamera(new Point3D(0,0,4),new Vector3D(0,0,-1),new Vector3D(0,1,0),2),Effect=blur};
        viewport.Children.Add(new ModelVisual3D{Content=new GeometryModel3D{Geometry=mesh,Material=new EmissiveMaterial(image)}});
        var grid=new Grid();grid.Children.Add(viewport);grid.Children.Add(dim);
        var host=new System.Windows.Forms.Integration.ElementHost{Dock=System.Windows.Forms.DockStyle.Fill,Child=grid};Controls.Add(host);
        Disposed+=(_,_)=>cancellation.Cancel();
    }
    protected override bool ShowWithoutActivation=>true;
    protected override System.Windows.Forms.CreateParams CreateParams
    {
        get {var p=base.CreateParams;p.ExStyle|=0x20|0x08000000|0x80;return p;}
    }
    public void SetEffect(EffectState s)
    {
        double h=bounds.Height/(double)bounds.Width;
        var p=new Point3DCollection();var uv=new PointCollection();var indices=new Int32Collection();
        for(int i=0;i<=32;i++){double t=i/32.0,w=s.Width+(1-s.Width)*t;p.Add(new(-w,h*(1-2*t),0));p.Add(new(w,h*(1-2*t),0));double v=t/w;uv.Add(new(0,v));uv.Add(new(1,v));if(i<32){int n=i*2;foreach(int j in new[]{n,n+2,n+1,n+1,n+2,n+3})indices.Add(j);}}
        mesh.Positions=p;mesh.TextureCoordinates=uv;mesh.TriangleIndices=indices;blur.Radius=s.Blur;dim.Opacity=s.Darkness;
    }
    public async Task Start()
    {
        image.ImageSource=await Task.Run(()=>Capture(bounds));
        if(cancellation.IsCancellationRequested)return;
        if(!SetWindowDisplayAffinity(Handle,0x11))throw new InvalidOperationException($"Capture exclusion unavailable (0x{Marshal.GetLastWin32Error():X})");
        Show();Bounds=bounds;
        _=Loop();
    }
    async Task Loop()
    {
        try{while(!cancellation.IsCancellationRequested){
            var frame=await Task.Run(()=>Capture(bounds),cancellation.Token);
            if(cancellation.IsCancellationRequested)return;
            image.ImageSource=frame;Frames++;LastFrame=clock.Elapsed.TotalSeconds;
            await Task.Delay(33,cancellation.Token);
        }}catch(OperationCanceledException){}catch(Exception ex){if(cancellation.IsCancellationRequested)return;Failed?.Invoke($"Capture stopped (0x{ex.HResult:X8})");Close();}
    }
    internal static BitmapSource Capture(System.Drawing.Rectangle b)
    {
        using var full=new System.Drawing.Bitmap(b.Width,b.Height,System.Drawing.Imaging.PixelFormat.Format32bppRgb);
        using(var g=System.Drawing.Graphics.FromImage(full))g.CopyFromScreen(b.X,b.Y,0,0,b.Size,System.Drawing.CopyPixelOperation.SourceCopy);
        int w=Math.Min(1600,b.Width),h=Math.Max(1,(int)(b.Height*(double)w/b.Width));
        using var small=new System.Drawing.Bitmap(full,w,h);
        var handle=small.GetHbitmap();try{var frame=Imaging.CreateBitmapSourceFromHBitmap(handle,IntPtr.Zero,Int32Rect.Empty,BitmapSizeOptions.FromEmptyOptions());frame.Freeze();return frame;}finally{DeleteObject(handle);}
    }
    [DllImport("gdi32.dll")]static extern bool DeleteObject(IntPtr h);
    [DllImport("user32.dll",SetLastError=true)]internal static extern bool SetWindowDisplayAffinity(IntPtr h,uint value);
}
