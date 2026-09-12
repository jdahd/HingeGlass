Windows Preview 0.1.4 introduces a custom animated Setup: floating glass icon, softly moving light, large typography, smooth stage transitions, installation status and a completion screen. The underlying installer/uninstaller remains per-user Inno Setup.

Download Setup.exe and click **Install HingeGlass**, then **Open HingeGlass**. A Start menu shortcut is created; administrator access is not required. ZIP portable download remains available alongside Setup.

Download `HingeGlass-0.1.4-Windows-x64-preview.zip`, extract the **entire folder**, then open `HingeGlass.exe`. Windows 10 version 2004+ / Windows 11 x64; the .NET runtime is included.

### Included
- Manual angle, start angle and blur controls.
- Perspective, uniform blur and dimming inside the preview window.
- Built-in landscape, local images and one-time primary desktop snapshot.
- Windows hinge-angle sensor detection, live reading counter and optional sensor-follow preview.
- Esc / Restore preview; closing the window exits the app.

### Limits
This is **not the full Mac desktop effect**: no live desktop feed or full-screen overlay yet. No physical Windows laptop has been validated. Sensor availability and angle conventions depend on the device. Windows-on-ARM and HarmonyOS are not validated targets. The app is unsigned.

Normal use does not record audio, save screen images or upload data. The desktop snapshot is held in memory. This preview does not change sleep settings.

### 给测试者
解压整个文件夹后打开 HingeGlass.exe，先拖动 Manual angle，看看预览是否流畅。再点 Detect angle sensor，慢慢开合一小段屏幕，检查角度和 readings 数字是否变化；不用完全合上。能读取时，可以勾选 Follow sensor in preview。

请反馈电脑型号、Windows 版本、能否打开程序、能否读取角度、预览是否流畅。这版只在软件窗口内预览，并不是 Mac 版的全桌面自动特效。华为电脑需要运行 Windows；鸿蒙电脑不适用。
