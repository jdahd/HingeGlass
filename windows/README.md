# HingeGlass · Windows Preview 0.1.4

[Download Windows Preview](https://github.com/jdahd/HingeGlass/releases/tag/windows-v0.1.4-preview)

Experimental Windows x64 preview. This is a separate early Windows implementation, not feature parity with the Mac release. Windows 10 version 2004 or later / Windows 11. Windows-on-ARM and HarmonyOS are not validated targets.

## Install (recommended)

Download `HingeGlass-0.1.4-Windows-x64-Setup.exe` from the release page and double-click it. Click Install HingeGlass in the animated English installer, then Open HingeGlass when it finishes. The installer respects Windows client-area animation settings. It installs for the current user, creates a Start menu entry, without a desktop shortcut. Administrator access is not required. Uninstall via Windows Settings → Apps. The installer uses the HingeGlass icon and brand name; it is unsigned, so Windows may display a reputation warning.

The ZIP remains available for portable use.

## Try it

Extract the entire ZIP to a folder and open `HingeGlass.exe`. Keep the accompanying files together. The package includes the .NET runtime; a separate .NET install is not required. This preview is unsigned and may trigger Windows reputation warnings.

- Move **Manual angle** to preview perspective, blur and dimming in the application window.
- Change **Start angle** and **Maximum blur** to tune the response.
- **Open image…** loads a local image.
- **Take desktop snapshot** briefly hides the app and captures the primary display once. It stays in memory; this is not live desktop capture.
- **Detect angle sensor** probes Windows' `HingeAngleSensor`. If available, move the lid slowly and inspect the angle/readings count. Do not fully close the lid during testing.
- **Follow sensor in preview** is enabled after a valid reading. Angle conventions may differ; verify before using. It affects only the preview. The last angle is held between sensor events; a stationary lid may not emit new readings. Use Esc to stop following.
- **Restore preview** or **Esc** stops following and opens the preview angle.

No account, network calls, audio capture, background service or automatic desktop overlay. No screen image is saved during normal use. Closing the window quits the app. This preview does not change lid-close sleep settings and does not persist preferences.

## Known limits

No live desktop capture or full-screen effect overlay yet. WPF uses a subdivided trapezoid and uniform blur; the Mac version's gradient blur is not reproduced exactly. Hardware rendering availability and performance depend on the machine. A successful build does not validate a laptop sensor. No Windows laptop model has been physically validated for this preview.

If sensor detection returns no compatible sensor, manual mode remains usable. That result does not prove the hardware lacks any sensor; its driver may not expose the standard Windows API.

## Feedback

Include computer model, Windows version, whether the app opens, sensor status, whether the angle changes, and whether manual preview is smooth. Do not include a desktop screenshot containing personal information. File feedback at https://github.com/jdahd/HingeGlass/issues.

## Development

`dotnet publish HingeGlass.Windows/HingeGlass.Windows.csproj -c Release -r win-x64 --self-contained true`

GitHub Actions builds on Windows, runs effect boundary checks and a UI startup/render smoke check, then uploads a portable ZIP and a generated sample-scene screenshot. `--self-test` exits with a test result; `--ui-smoke` explicitly writes `windows-preview.png` using the generated landscape only. Real hardware sensor and desktop capture testing are still needed.

Effect formulas are adapted from the Mac renderer, derived from Ruixiang Huang's Macbook_Duo_Effect (MIT). See bundled ThirdPartyNotices.txt. The existing HingeGlass icon is reused.
