# HingeGlass Windows 0.2.2 Preview

- Remember live desktop, sensor-follow preference, angle controls and selected display across application restarts.
- Pause desktop capture while locked or asleep, retaining the enabled setting. Resume after unlock/wake when the desktop and restore shortcut are available; sensor mode requests a fresh reading first.
- Manual disable, Pause and restore, Escape and Ctrl+Alt+Escape keep the effect off.
- Ignore stale capture failures from a previous paused session.
- Lock-screen effects are not supported. No new angle sensor support is added.

Includes the portable x64 ZIP and branded Setup with selectable installation folder. Windows 10 version 2004+ / Windows 11 x64. This remains an experimental preview.

Validation: Windows CI builds both packages and exercises live capture, pause/resume state transitions, settings persistence, manual restoration, installation and uninstallation. Physical laptop sleep/lock and sensor behavior still require device testing.
