Windows Preview 0.1.3 refines the Setup experience with an ice-blue palette, larger Segoe UI typography, a branded welcome, clear step labels and a redesigned completion page.

**Recommended:** download `HingeGlass-0.1.3-Windows-x64-Setup.exe`, double-click, and follow the wizard. Installs for your Windows user account without administrator access. Start menu shortcut included; desktop shortcut optional. Uninstall in Settings → Apps.

安装方法：下载 Setup.exe 并双击，跟随安装向导即可。安装后从开始菜单打开 HingeGlass。仍然是 Windows x64 测试版，不是鸿蒙版，也不是完整的实时桌面覆盖效果。安装包尚未签名，Windows 可能显示安全提示。

Download `HingeGlass-0.1.3-Windows-x64-preview.zip`, extract the **entire folder**, then open `HingeGlass.exe`. Windows 10 version 2004+ / Windows 11 x64; the .NET runtime is included.

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
