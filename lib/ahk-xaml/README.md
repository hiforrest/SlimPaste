# ahk-xaml placeholder

This first-version package does not vendor ahko's `ahk-xaml` engine directly.

The project keeps an ahko-compatible folder layout:

- `lib/ahk-xaml/`
- `setup/setup.axml`
- `setup/settings_gui.ahk`
- `themes.ini`

For a stricter ahko-style implementation, vendor the MIT-licensed ahk-xaml framework here and replace `setup/settings-wpf.ps1` with an AutoHotkey v2 ahk-xaml host. Keep the upstream MIT license and add the original copyright notice to `THIRD_PARTY_NOTICES.md`.

The current first-version settings window is still a modern WPF/XAML window and does not use AutoHotkey native GUI controls.
