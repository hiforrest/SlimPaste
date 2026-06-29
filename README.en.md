<p align="right">
  <a href="README.md">中文</a>
</p>

# SlimPaste

**Auto-compress images while pasting**

![Slim Robot](README.en.assets/ani.avif)

Whenever you paste a screenshot or copied image into WeChat or a document, the system often inserts a newly generated image. That file can be larger than the original, slowly bloating your chats and office files.

SlimPaste is built to solve this. Press Ctrl+Shift+V and your image is compressed automatically during paste, keeping it visually lossless while greatly reducing file size.

Use SlimPaste to make every paste light, clean, and efficient.

---

Copy a screenshot or image, press `Ctrl + Shift + V`, and the tool compresses the clipboard image to a JPG file, places that JPG as a `FileDropList` / file object back onto the clipboard, then sends `Ctrl + V` to the current window.

Normal `Ctrl + V` is never intercepted.

## Features

- Dedicated configurable global hotkey, default `^+v`
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

## Requirements

- Windows (64-bit)
- Windows PowerShell

The app bundles JPEGli at `bin\jpegli\cjpegli.exe`. It falls back to the Windows system JPEG encoder if JPEGli is unavailable.

## Run

1. Download `SlimPaste-v0.2.0.zip` from [Releases](https://github.com/hiforrest/SlimPaste/releases).
2. Unzip and run `SlimPaste.exe`.
3. Copy a screenshot or image.
4. Press `Ctrl + Shift + V`.
5. Paste target receives a compressed JPG file object.

> No AutoHotkey installation required.

## Configuration

Open **Setup** from the tray icon.

Default config:

```ini
[General]
Hotkey=^+v
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

## UI architecture

```text
lib/ahk-xaml/
setup/setup.axml
setup/settings_gui.ahk
themes.ini
```

For this first version, `settings_gui.ahk` launches a WPF/XAML settings window hosted by PowerShell. This avoids AutoHotkey native GUI controls and keeps the UI layout separated from logic.

## Building from source

Requires AutoHotkey v2. Compile with Ahk2Exe:

- `SlimPaste.ahk` → `SlimPaste.exe`
- `setup\settings_gui.ahk` → `setup\Settings.exe`

Keep `worker`, `setup`, `config`, `assets`, `bin` beside the exe.
