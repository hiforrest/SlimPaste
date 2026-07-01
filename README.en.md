<p align="right">
  <a href="README.md">中文</a>
</p>

# SlimPaste

**Auto-compress images while pasting**

![Slim Robot](README.assets/ani.avif)

Images on your clipboard are usually stored temporarily as uncompressed bitmap data. Whether you take a screenshot or copy an image, once you paste it into WeChat or a document, the app re-encodes or saves it in its own way, often turning it into a file several megabytes in size. That is how your chats and documents quietly get more and more bloated.

Press Ctrl+Shift+V to paste, and SlimPaste will compress the image in the background with no visible loss in quality, then paste it for you. An image that was several MB can shrink to just a few hundred, or even a few dozen, KB.

Keep every paste light, fast, and tidy.

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
- Config file alongside `SlimPaste.exe` as `.\config.ini`
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

1. Download `SlimPaste-v0.4.0.zip` from [Releases](https://github.com/hiforrest/SlimPaste/releases).
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
TempDirectory=.\temp
ImageFallback=0
CleanupDays=7
ShowNotification=1
StartupWithWindows=0
```

Runtime config is stored alongside `SlimPaste.exe`:

```text
.\config.ini
```

## PowerShell worker command shape

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File worker\clipboard-jpeg-worker.ps1 `
  -Quality 80 `
  -Dpi 96 `
  -OutputDirectory ".\temp" `
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

## FAQ

### How do I install and use it?

SlimPaste is portable software, so there's no installation needed. Just download it, unzip the archive, and run `SlimPaste.exe`.

To use it, first take a screenshot or copy an image. Then press `Ctrl` + `Shift` + `V` where you want to paste it, and SlimPaste will automatically compress the image in your clipboard and paste it for you.

### Is SlimPaste safe?

SlimPaste runs entirely locally. It only processes clipboard images when you press the hotkey. It **does not upload data** or actively read other content. The source code is open for review. AHK/PowerShell executables may trigger false positives from antivirus software. If you downloaded from a trusted source, you can safely add it to your antivirus whitelist, or review and compile the source yourself.

### Is the compression algorithm reliable?

Yes. SlimPaste uses **jpegli** for JPG encoding. jpegli is a high-quality JPEG encoder built on technology from the JPEG XL project. It stays compatible with the standard JPG format while delivering better compression efficiency and visual quality.

By default, SlimPaste compresses images to a visually lossless level, so when viewed at their original size, the difference is almost impossible to notice. If you want smaller file sizes or prefer to preserve even higher image quality, you can also adjust the quality settings yourself.

### Can I customize the hotkey?

Yes, you can change the hotkey in the settings.

### Will SlimPaste modify my original images?

No. SlimPaste only processes the temporary image data on your clipboard. It **does not modify any original image files** on your computer. Think of it this way: before pasting, SlimPaste temporarily creates a lighter version of the image, then pastes that instead.

### Which apps are supported?

SlimPaste works with common applications that support image pasting, such as WeChat, QQ, document editors, note-taking apps, browser input fields, and more.

### Why doesn't an image get compressed when I copy it from a folder?

SlimPaste works on image data in the clipboard, not the image file itself.

If you right-click an image in an image viewer, browser, or chat app and choose "Copy" or "Copy Image," the image is usually copied to the clipboard as pasteable image data, so SlimPaste can compress it.

But if you select an image file (the icon) in a folder and press `Ctrl + C`, what gets copied is usually a reference to the file, not the actual pixel data. It hasn't been converted into a bitmap, so its size hasn't suddenly blown up and it may not need compression. That's why SlimPaste doesn't process it.

To paste a compressed version, open the image first and choose "Copy Image," or simply take a screenshot and press `Ctrl + Shift + V`.
