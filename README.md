# HingeGlass 1.0

A quiet lid effect for your Mac. As you close the display, your live desktop gains perspective, progressive blur and dimming. The English settings panel stays clear and floats above the effect.

## Download

[Download HingeGlass for macOS](https://github.com/jdahd/HingeGlass/releases/latest) · [中文使用说明](使用说明.md)

Choose `HingeGlass-1.0.1-macOS-arm64.zip`, unzip it, and move `HingeGlass.app` to Applications. This release is for Apple silicon MacBooks running macOS 14 or later with a compatible built-in lid-angle sensor. There is no Windows or Intel build.

The app is ad hoc signed and not Apple-notarized. If macOS blocks it, review the warning in System Settings → Privacy & Security and use Open Anyway if available.

## Run

Open `HingeGlass.app`. Requires macOS 14 or later, Apple silicon, and a compatible built-in lid-angle sensor. Allow HingeGlass in System Settings → Privacy & Security → Screen & System Audio Recording for the Desktop scene, then reopen if prompted.

Use **Start angle** and **Maximum blur** to tune the effect. Click **Enable** to follow the physical lid. Your saved settings are preserved. **Restore**, the menu-bar **Pause and Restore** action, or **Control–Option–Command–Escape** restores the desktop. Normal lid-close sleep is preserved.

Screen frames are processed in memory while the effect is active. No audio is captured, and screen footage is neither saved nor uploaded.

## Release

1.0 packages the lid effect with an application icon, About panel, bundled credits and documentation. This local build is ad hoc signed and is not Apple notarized. Rebuilding can require refreshing the Screen Recording permission.

## Development

Run `./scripts/make-icon.sh`, `./build.sh`, then `./scripts/package.sh`. The release ZIP is written to `releases/`. Local build output and development records are excluded from this repository.

The effect implementation adapts Ruixiang Huang’s Macbook_Duo_Effect under the MIT license. Full attribution is included in `Macbook_Duo_Effect.txt` in the release and inside the application Resources. The icon was created with OpenAI image generation.
