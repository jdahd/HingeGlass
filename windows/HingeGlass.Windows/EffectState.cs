using System;
namespace HingeGlass.Windows;
// Geometry/strength formula adapted from the Mac renderer, derived from
// Ruixiang Huang's Macbook_Duo_Effect (MIT). See bundled ThirdPartyNotices.txt.
internal readonly record struct EffectState(double Width, double Darkness, double Blur)
{
    public static EffectState At(double angle, double start, double maximum)
    {
        if (!double.IsFinite(angle) || !double.IsFinite(start) || start <= 0) return new(1,0,0);
        angle = Math.Clamp(angle,0,360);
        if (angle >= start) return new(1,0,0);
        double delta = Math.Min(75,start-angle)*Math.PI/180;
        double depth = 1/(Math.Cos(delta)+0.2*Math.Sin(delta));
        double width = Math.Max(.08,1-depth*Math.Sin(delta)/2.5);
        double f = Math.Clamp(1-angle/start,0,1);
        double amount = f*f*(3-2*f);
        return new(width,amount,Math.Clamp(maximum,0,100)*amount);
    }
    public static void Check()
    {
        if (At(114,114,68) != new EffectState(1,0,0)) throw new Exception("Threshold");
        if (At(150,114,68) != new EffectState(1,0,0)) throw new Exception("Open");
        double previous=0;
        for (int a=114;a>=0;a--) {
            var s=At(a,114,68);
            if (s.Width<.08 || s.Width>1 || s.Darkness<previous || !double.IsFinite(s.Blur)) throw new Exception("Bounds");
            previous=s.Darkness;
        }
        if (At(0,114,68).Blur!=68 || At(0,114,0).Blur!=0) throw new Exception("Blur endpoints");
        if (At(double.NaN,114,68)!=new EffectState(1,0,0)) throw new Exception("Invalid sample");
    }
}
