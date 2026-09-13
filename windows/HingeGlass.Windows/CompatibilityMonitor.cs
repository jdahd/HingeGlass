using System;
using System.Collections.Generic;
using System.Linq;
namespace HingeGlass.Windows;
internal sealed class CompatibilityMonitor
{
    readonly Queue<(double Time,double Angle)> readings=new();
    public string SensorStatus="Not checked";
    public long Count {get;private set;}
    public void Reset(){readings.Clear();Count=0;SensorStatus="Checking";}
    public void Add(double time,double angle){if(!double.IsFinite(angle)||angle<0||angle>360)return;readings.Enqueue((time,angle));Count++;while(readings.Count>300)readings.Dequeue();SensorStatus="Receiving";}
    public (double Time,double Angle)[] History=>readings.ToArray();
    public string Report(double now,double renderFps,string capture)
    {
        var a=History; double span=a.Length>1?a[^1].Time-a[0].Time:0;
        double range=a.Length>0?a.Max(x=>x.Angle)-a.Min(x=>x.Angle):0;
        double gap=0;int jumps=0;
        for(int i=1;i<a.Length;i++){gap=Math.Max(gap,a[i].Time-a[i-1].Time);if(Math.Abs(a[i].Angle-a[i-1].Angle)>20)jumps++;}
        string result=a.Length==0?"Not verified":range<5?"Move the lid to verify motion":jumps>0?"Large steps detected — inspect the graph":"Motion received — verify direction on this device";
        return $"HingeGlass Windows 0.2.2\nOS: {Environment.OSVersion.Version}\n64-bit: {Environment.Is64BitProcess}\nWPF render tier: {System.Windows.Media.RenderCapability.Tier>>16}\nSensor: {SensorStatus}\nSamples: {Count} · angle: {(a.Length>0?a[^1].Angle.ToString("0.0"):"—")}°\nObserved range: {range:0.0}° · event rate: {(span>0?(a.Length-1)/span:0):0.0}/s\nLongest interval: {gap:0.00}s · steps >20°: {jumps}\nLast reading age: {(a.Length>0?(now-a[^1].Time).ToString("0.0"):"—")}s\nRender callbacks: {renderFps:0.0}/s (not GPU presentation FPS)\nDesktop: {capture}\nResult: {result}\nEvent intervals include stationary time; they alone do not prove lag.\nNo manufacturer interface was probed. No hardware serials or screen images included.";
    }
    public static void Check(){var m=new CompatibilityMonitor();m.Add(0,double.NaN);if(m.Count!=0)throw new Exception("Invalid reading accepted");for(int i=0;i<400;i++)m.Add(i*.1,90+i%10);if(m.Count!=400||m.History.Length!=300)throw new Exception("History bounds");}
}
