# HingeGlass 1.0

A quiet lid effect for your Mac. As you close the display, your live desktop gains perspective, progressive blur and dimming. The English settings panel stays clear and floats above the effect.

## Run

Open `HingeGlass.app`. Requires macOS 14 or later, Apple silicon, and a compatible built-in lid-angle sensor. Allow HingeGlass in System Settings → Privacy & Security → Screen & System Audio Recording for the Desktop scene, then reopen if prompted.

Use **Start angle** and **Maximum blur** to tune the effect. Click **Enable** to follow the physical lid. Your saved settings are preserved. **Restore**, the menu-bar **Pause and Restore** action, or **Control–Option–Command–Escape** restores the desktop. Normal lid-close sleep is preserved.

Screen frames are processed in memory while the effect is active. No audio is captured, and screen footage is neither saved nor uploaded.

## Release

1.0 formalizes the user-accepted 0.11 effect with an application icon, About panel, bundled credits and documentation. This local build is ad hoc signed and is not Apple notarized. Rebuilding can require refreshing the Screen Recording permission.

## Development

Run `./scripts/make-icon.sh`, `./build.sh`, then `./scripts/package.sh`. The release ZIP is written to `releases/`. Prior development builds and QA evidence are retained in `archive/`; the accepted 0.11 rollback is archived separately. Historical notes are in `docs/development-history.md` and `memories/`.

The effect implementation adapts Ruixiang Huang’s Macbook_Duo_Effect under the MIT license. Full attribution is included in `Macbook_Duo_Effect.txt` in the release and inside the application Resources. The icon was created with OpenAI image generation.
