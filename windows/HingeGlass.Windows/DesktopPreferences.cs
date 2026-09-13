using System;
using System.IO;
using System.Text.Json;
namespace HingeGlass.Windows;
public sealed class DesktopPreferences
{
    public bool Live { get; set; }
    public bool Follow { get; set; }
    public double Angle { get; set; }=124;
    public double Start { get; set; }=114;
    public double Blur { get; set; }=68;
    public string? Display { get; set; }
    internal static string PathName => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"HingeGlass","desktop-settings.json");
    internal static DesktopPreferences Load(string path) {
        try { return JsonSerializer.Deserialize<DesktopPreferences>(File.ReadAllText(path)) ?? new(); }
        catch { return new(); }
    }
    internal static void Save(string path,DesktopPreferences value) {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path+".tmp",JsonSerializer.Serialize(value));
        File.Move(path+".tmp",path,true);
    }
}
