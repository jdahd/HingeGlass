using System;
using System.Threading;
using System.Threading.Tasks;
namespace HingeGlass.Windows;
// A separate UI thread catches false-positive click-through tests on same-thread windows.
internal sealed class DesktopTestFixture
{
    readonly System.Windows.Forms.Form form;
    int clicks;
    public int Clicks=>Volatile.Read(ref clicks);
    readonly TaskCompletionSource<bool> finished=new(TaskCreationOptions.RunContinuationsAsynchronously);
    DesktopTestFixture(System.Windows.Forms.Form f){form=f;form.MouseDown+=(_,_)=>Interlocked.Increment(ref clicks);}
    public static Task<DesktopTestFixture> Create()
    {
        var ready=new TaskCompletionSource<DesktopTestFixture>(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread=new Thread(()=>{
            try{
                using var f=new System.Windows.Forms.Form{FormBorderStyle=System.Windows.Forms.FormBorderStyle.None,WindowState=System.Windows.Forms.FormWindowState.Maximized,BackColor=System.Drawing.Color.Lime,ShowInTaskbar=false};
                var fixture=new DesktopTestFixture(f);f.Shown+=(_,_)=>ready.SetResult(fixture);
                System.Windows.Forms.Application.Run(f);fixture.finished.TrySetResult(true);
            }catch(Exception ex){ready.TrySetException(ex);}
        }){IsBackground=true};thread.SetApartmentState(ApartmentState.STA);thread.Start();return ready.Task.WaitAsync(TimeSpan.FromSeconds(5));
    }
    public void Red()=>form.BeginInvoke(new Action(()=>{form.BackColor=System.Drawing.Color.Red;form.Refresh();}));
    public async Task Close(){form.BeginInvoke(new Action(()=>form.Close()));await finished.Task.WaitAsync(TimeSpan.FromSeconds(3));}
}
