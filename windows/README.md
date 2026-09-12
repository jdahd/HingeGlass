# HingeGlass for Windows

**0.2.1 · Experimental preview** · [Download](https://github.com/jdahd/HingeGlass/releases/tag/windows-v0.2.1-preview) · [Project overview](../README.md)

Live desktop perspective, blur and dimming on Windows 10 version 2004+ / Windows 11 x64. You can use manual desktop effects without an angle sensor. Automatic lid following requires readable angle data; it is not supported on every laptop.

## Install

| Package | How to use it |
| --- | --- |
| **HingeGlass-0.2.1-Windows-x64-Setup.exe** | Run Setup, enter an **Installation folder** or click **Change…**, then click **Install HingeGlass**. Use **Open HingeGlass** when finished. |
| **HingeGlass-0.2.1-Windows-x64-preview.zip** | Extract the entire archive, then open **HingeGlass.exe**. Keep the accompanying files together. |

Setup installs for the current user into a writable folder and creates a Start menu entry. It does not create a desktop shortcut. Uninstall through **Windows Settings → Apps**. The .NET runtime is included. The installer is unsigned, so Windows may display a reputation warning.

## First run: try the desktop effect

1. Select the display you want to use.
2. Check **Enable live desktop**.
3. Lower **Manual angle** below **Start angle**. For example, use a start angle of 114° and a manual angle of 80°.
4. Adjust **Maximum blur** to taste.
5. Press **Ctrl + Alt + Esc** or click **Pause and restore** to restore the desktop.

The settings stay clear above the effect. Mouse clicks reach original desktop coordinates; perspective does not remap input. Opening past the start angle removes the overlay and stops capture, while leaving live mode armed.

**Open image…** and **Take desktop snapshot** supply images for the in-app preview. A snapshot is taken once; **Enable live desktop** is the separate continuous-capture mode.

## Check automatic lid following

Click **Detect angle sensor**, move the lid slowly without fully closing it, and expand **Compatibility monitor**.

| Result | What it means |
| --- | --- |
| **No compatible API sensor** | The current Windows interface found no angle sensor. Use manual mode. This does not prove there is no manufacturer-specific hardware interface. |
| Readings arrive but the angle stays fixed | Movement has not been verified. Slowly move the lid and inspect the history. |
| Angle changes with lid movement | Check that its direction and values match the physical motion before enabling **Follow lid angle**. |
| Large steps or irregular readings | Review the graph and diagnostics. A long interval while the lid is stationary does not by itself indicate a fault. |

The app probes Windows' `HingeAngleSensor` API. It does not probe private manufacturer interfaces. A binary lid-open/lid-closed switch cannot provide continuous angles. No Windows laptop model is certified for automatic following by this project.

**Compatibility monitor** shows recent angle history, reading count, event rate, longest interval, large steps, last-reading age, render callbacks and capture state. Render callbacks are not GPU presentation FPS. **Desktop: Off** means capture was off when the report was copied, for example after restoring or opening above the start angle.

## Recovery and privacy

**Ctrl + Alt + Esc** restores globally; **Esc** restores when the app has keyboard focus. Live mode is blocked if the global shortcut cannot register. Sleep, session lock, display changes and capture errors pause the effect. Closing the app stops capture and quits. Normal lid-close sleep is preserved.

Frames are processed in memory during live mode. Normal use does not capture audio, save screen recordings or upload frames. There is no account, background service or startup task. Preview preferences are not persisted.

## Limits and testing

The Windows implementation uses CPU/GDI capture, limited to 1600 pixels wide and at most 30 capture cycles per second, with WPF perspective, uniform blur and dimming. It differs from the Mac rendering pipeline. Performance, protected content, graphics drivers and mixed-DPI/multi-monitor behavior require real-device testing. Windows ARM and HarmonyOS are not validated targets.

CI checks the effect math, diagnostic history bounds, UI startup, live source changes, capture exclusion, pointer pass-through, keyboard restoration, expansion restoration, minimized activation, and installation/uninstallation into a custom path. Physical laptop angle response and visual smoothness are separate acceptance checks.

## Feedback

Use **Copy diagnostics** and include the computer model in a [GitHub issue](https://github.com/jdahd/HingeGlass/issues). State whether **manual desktop effects** work and whether **automatic lid following** works. The copied report excludes hardware serials and screen images.

## Development

From the repository root:

```powershell
dotnet publish windows/HingeGlass.Windows/HingeGlass.Windows.csproj -c Release -r win-x64 --self-contained true
```

`--self-test` runs logic checks. `--ui-smoke` explicitly writes a generated-scene preview image. `--desktop-smoke` creates test windows, exercises desktop capture and recovery, and writes a test result. These switches are for controlled development environments.

The effect formula derives from Ruixiang Huang's Macbook_Duo_Effect (MIT). See [the third-party notice](../ThirdPartyNotices/Macbook_Duo_Effect.txt). The existing HingeGlass icon is reused.
