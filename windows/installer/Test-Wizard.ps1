param([Parameter(Mandatory=$true)][string]$Setup)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
$directory = Join-Path $env:RUNNER_TEMP 'HingeGlass-Wizard-Test'
$process = Start-Process $Setup -ArgumentList @('/NORESTART',"/DIR=$directory") -PassThru
function Get-Wizard {
  $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'HingeGlass')
  return [System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children,$condition)
}
function Save-Wizard($window, $name) {
  $r = $window.Current.BoundingRectangle
  $bitmap = New-Object System.Drawing.Bitmap([int]$r.Width,[int]$r.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen([int]$r.X,[int]$r.Y,0,0,$bitmap.Size)
    $bitmap.Save((Join-Path $pwd $name),[System.Drawing.Imaging.ImageFormat]::Png)
  } finally { $graphics.Dispose();$bitmap.Dispose() }
}
try {
  $window=$null
  for($i=0;$i -lt 30 -and !$window;$i++){Start-Sleep -Milliseconds 500;$window=Get-Wizard}
  if(!$window){throw 'Welcome wizard not found'}
  Start-Sleep -Seconds 1
  Save-Wizard $window 'installer-preview.png'
  $finished=$false
  for($step=0;$step -lt 10;$step++) {
    $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Button)
    $buttons = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
    $next=$null
    foreach($button in $buttons){
      $name=$button.Current.Name.Replace('&','').Trim()
      if($name -eq 'Finish' -and $button.Current.IsEnabled){$finished=$true;break}
      if($name -match '^(Continue|Next\s*>?|Install)$' -and $button.Current.IsEnabled){$next=$button}
    }
    if($finished){Save-Wizard $window 'installer-finished.png';break}
    if(!$next){throw 'Expected enabled next/install button'}
    if($next.Current.Name.Replace('&','').Trim() -eq 'Install'){Save-Wizard $window 'installer-ready.png'}
    $invoke = $next.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $invoke.Invoke()
    Start-Sleep -Seconds 2
    # Installation may take longer than a normal page transition.
    for($wait=0;$wait -lt 60;$wait++){
      $window=Get-Wizard
      if(!$window){throw 'Wizard closed unexpectedly'}
      $all=$window.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
      $ready=$false
      foreach($b in $all){if($b.Current.IsEnabled -and $b.Current.Name.Replace('&','').Trim() -match '^(Continue|Next\s*>?|Install|Finish)$'){$ready=$true}}
      if($ready){break}
      Start-Sleep -Seconds 1
    }
  }
  if(!$finished){throw 'Completion page not reached'}
} finally {
  if(!$process.HasExited){taskkill /PID $process.Id /T /F | Out-Null}
  $uninstaller=Join-Path $directory 'unins000.exe'
  if(Test-Path $uninstaller){$u=Start-Process $uninstaller -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru;if(!$u.WaitForExit(60000)){$u.Kill();throw 'Wizard test cleanup timed out'}}
}
