Windows 0.2.1 adds a selectable installation folder to the animated Setup. Edit the full path or click Change… to choose a parent folder. The default remains the current user’s LocalAppData/Programs/HingeGlass. The destination must be writable without elevation. Installation, launch and uninstall use the selected path.

Windows 0.2.1 experimental preview adds live desktop effects and a compatibility monitor.

- Select a display, lower Manual angle below Start angle, and enable live desktop. Follow lid angle is available when valid sensor readings arrive.
- The desktop is continuously captured in memory using a bounded GDI capture path (maximum 1600px wide, at most 30 captures/s). WPF applies perspective, uniform blur and dimming. This is not the Mac GPU capture pipeline and performance varies.
- Settings and the overlay request Windows capture exclusion. The settings remain clear and independently interactive. Desktop clicks pass through at original coordinates; perspective does not remap input.
- Ctrl+Alt+Esc restores globally. Pause and restore, expansion, sleep, session lock, display changes and capture failure remove the overlay. Expansion keeps live mode armed; other interruptions require enabling again.
- Compatibility monitor shows angle history, event rate, longest gap, large steps and render callback rate. Event-driven sensors may stop sending while stationary. Readings do not constitute certified hardware support.
- Copy diagnostics includes software/OS and measurements, not serial numbers, screen frames or files.

ZIP and animated Setup are both supplied. Windows 10 2004+ / Windows 11 x64. Unsigned, experimental. No Windows physical laptop sensor or multi-monitor/DPI hardware acceptance test has been completed. Protected content may not capture. No audio capture, screen recording files or uploads. Mac release is unchanged.
