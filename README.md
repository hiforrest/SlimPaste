# SlimPaste / 剪贴板图片瘦身粘贴

A small Windows tray utility based on AutoHotkey v2 and PowerShell.

Copy a screenshot or image, press `Ctrl + Alt + V`, and the tool compresses the clipboard image to a JPG file, places that JPG as a `FileDropList` / file object back onto the clipboard, then sends `Ctrl + V` to the current window.

普通 `Ctrl + V` 不会被拦截。

## First version status

Implemented:

- Dedicated configurable global hotkey, default `^!v`
- Tray menu
  - Compress and Paste
  - Setup
  - Open Temp Folder
  - Pause Hotkey
  - Reload
  - Exit
- Config file at `%APPDATA%\SlimPaste\config.ini`
- Startup cleanup for old temp files
- PowerShell STA worker
- Clipboard image detection
- Clipboard image-file detection
- White-background bitmap flattening
- Temporary PNG source creation
- JPEGli first, system JPEG fallback
- Bundled `cjpegli.exe` at `bin\jpegli\cjpegli.exe`
- JPG file object written back to clipboard using FileDropList
- Optional compatibility image fallback
- JSON worker output
- Modern dark WPF setup window using `setup/setup.axml`

Not implemented in v1:

- PNG lossless mode
- Ctrl+V interception
- App whitelist
- Full vendored ahko `ahk-xaml` engine

## Requirements

- Windows
- AutoHotkey v2
- Windows PowerShell

The app bundles JPEGli at `bin\jpegli\cjpegli.exe`. It falls back to the Windows system JPEG encoder if JPEGli is unavailable.

## Run

1. Install AutoHotkey v2.
2. Run `SlimPaste.ahk`.
3. Copy a screenshot or image.
4. Press `Ctrl + Alt + V`.
5. Paste target receives a compressed JPG file object.

## Configuration

Default config:

```ini
[General]
Hotkey=^!v
UseJpegli=1
OutputMode=jpg_quality
Quality=80
TempDirectory=%TEMP%\SlimPaste
ImageFallback=0
CleanupDays=7
ShowNotification=1
StartupWithWindows=0
```

Runtime config is stored in:

```text
%APPDATA%\SlimPaste\config.ini
```

## PowerShell worker command shape

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File worker\clipboard-jpeg-worker.ps1 `
  -Quality 80 `
  -Dpi 96 `
  -OutputDirectory "%TEMP%\SlimPaste" `
  -JsonOutput
```

The worker auto-detects the bundled JPEGli at `bin\jpegli\cjpegli.exe`.

Disable JPEGli:

```powershell
-DisableJpegli
```

Compatibility fallback:

```powershell
-ImageFallback
```

## Worker JSON output

Image success:

```json
{
  "ok": true,
  "hadImage": true,
  "encoder": "jpegli",
  "source": "clipboard image data",
  "jpgPath": "C:\\Users\\xxx\\AppData\\Local\\Temp\\SlimPaste\\clipboard_20260625_123456_000.jpg",
  "sourceBytes": 1250000,
  "outputBytes": 182000,
  "width": 1920,
  "height": 1080,
  "quality": 80,
  "message": "OK"
}
```

Not an image:

```json
{
  "ok": true,
  "hadImage": false,
  "message": "Clipboard does not contain an image."
}
```

## File object behavior

The worker uses Windows Forms `DataObject.SetFileDropList(...)`, then calls `Clipboard.SetDataObject(...)`.

This means the clipboard receives a JPG file object, not a text path.

## Notes on JPG wording

This project should not describe PNG-to-JPG conversion as "lossless JPG compression".

JPEGli outputs normal JPG files. The product value is better visual quality per byte compared with traditional JPEG encoders. If a future "lossless mode" is added, it should keep PNG format and perform PNG lossless optimization instead of converting to JPG.

## UI architecture

The repository mirrors the ahko setup organization:

```text
lib/ahk-xaml/
setup/setup.axml
setup/settings_gui.ahk
themes.ini
```

For this first version, `settings_gui.ahk` launches a WPF/XAML settings window hosted by PowerShell. This avoids AutoHotkey native GUI controls and keeps the UI layout separated from logic.

If you later vendor ahko's ahk-xaml engine under `lib/ahk-xaml/`, keep its MIT license notice.

## Suggested release packaging

For a shareable version:

1. Use Ahk2Exe to compile `SlimPaste.ahk`.
2. Keep these folders beside the exe:
   - `worker`
   - `setup`
   - `config`
   - `assets`
   - `bin`
3. Include `LICENSE` and `THIRD_PARTY_NOTICES.md`.
