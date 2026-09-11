# HingeGlass 1.0.0

First packaged release of HingeGlass for Apple silicon MacBooks.

HingeGlass maps the built-in lid-angle sensor to a live desktop effect with fixed-bottom perspective, progressive blur and dimming. The English control panel stays clear above the transformed desktop.

## Requirements

- Apple silicon MacBook
- macOS 14 or later
- Screen & System Audio Recording permission for the live Desktop scene

## Install

1. Download and unzip `HingeGlass-1.0.0-macOS-arm64.zip`.
2. Move `HingeGlass.app` to Applications.
3. Because this local build is not Apple-notarized, Control-click the app and choose **Open** if macOS cannot verify the developer.
4. Allow HingeGlass in **System Settings → Privacy & Security → Screen & System Audio Recording**, then reopen it when prompted.
5. Select **Desktop**, click **Enable**, open the lid past the configured start angle, and close it slowly.

Use **Restore**, the menu-bar **Pause and Restore** command, or **Control–Option–Command–Escape** to remove the effect immediately.

Screen frames stay in memory. HingeGlass does not capture audio, save screen footage, or upload screen content.

The effect implementation adapts Ruixiang Huang's Macbook_Duo_Effect under the MIT license. Attribution and the full license are bundled with the application and release archive.
