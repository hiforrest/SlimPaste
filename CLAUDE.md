# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SlimPaste** — Windows tray utility that compresses clipboard images to JPG and pastes as a file object. Built with AutoHotkey v2 + PowerShell worker + JPEGli.

## Architecture

```
SlimPaste.ahk          # Main entry — tray app, hotkey, config, calls worker
worker/
  clipboard-jpeg-worker.ps1   # PowerShell STA worker: reads clipboard image,
                              #   compresses via JPEGli or system JPEG,
                              #   writes JPG file object back to clipboard
setup/
  settings_gui.ahk     # AHK launcher that starts the WPF setup window
  settings-wpf.ps1     # PowerShell WPF host: loads XAML, handles events, saves config
  setup.axml           # XAML layout for the dark-themed settings window
config/
  default-config.ini   # Shipped default config (copied alongside exe on first run)
bin/jpegli/
  cjpegli.exe          # Bundled JPEGli encoder
lib/ahk-xaml/          # Placeholder for future ahk-xaml engine vendoring
```

## Data Flow

1. User copies image → press Ctrl+Shift+V
2. `SlimPaste.ahk` → `RunWorker()` → launches `clipboard-jpeg-worker.ps1` via cmd.exe
3. Worker reads clipboard via `[System.Windows.Forms.Clipboard]`, compresses to JPG, writes JPG file object back to clipboard
4. AHK sends `^V` to paste

## Key Technical Details

- **PowerShell STA mode required** for clipboard access. Always pass `-STA` flag
- **cmd.exe /C quoting**: Use AHK `""` (double-doublequote) pairs for the command argument, NOT `\"`. `QuoteArg`'s `\"` escaping does not work with cmd.exe's `/C` parser. Example: `cmd := A_ComSpec ' /D /C ""' PS_EXE '" ' args ' > "' outFile '" 2> "' errFile '""'`
- **INI encoding**: Write config as UTF-8 without BOM (`[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`). `Set-Content -Encoding UTF8` in Windows PowerShell writes with BOM which can cause AHK `IniRead` issues
- **JPEGli bundled** at `bin\jpegli\cjpegli.exe`. The worker auto-detects it via `$PSScriptRoot\..\bin\jpegli\cjpegli.exe`
- **WPF XAML**: Loaded via PowerShell `XamlReader.Load()`. Avoid `{x:Static}` references to types that resolve outside the default WPF namespace — they fail in PowerShell's XAML parser. Set colors via `{StaticResource}` or handle in PowerShell code-behind
- **ComboBox styling in XAML**: The default WPF template's VisualState overrides `Background`. To force dark backgrounds, set via PowerShell in the `Loaded` event on `ToggleButton` template parts

## Config File Location

`config.ini` 与 `SlimPaste.exe` 同目录（绿色软件零写盘）。

| Key                | Type        | Default                | Description                                    |
| ------------------ | ----------- | ---------------------- | ---------------------------------------------- |
| Hotkey             | string      | `^+v`                  | AHK hotkey, `^`=Ctrl `!`=Alt `+`=Shift `#`=Win |
| UseJpegli          | bool        | 1                      | Use bundled JPEGli encoder                     |
| OutputMode         | string      | `jpg_quality`          | Compression mode                               |
| Quality            | int (1-100) | 80                     | JPG quality                                    |
| TempDirectory      | string      | `.\temp`（exe 同目录） | Temporary output dir                           |
| ImageFallback      | bool        | 0                      | Also put image data on clipboard               |
| CleanupDays        | int         | 7                      | Auto-delete temp files older than N days       |
| ShowNotification   | bool        | 1                      | Tray notification after paste                  |
| StartupWithWindows | bool        | 0                      | Auto-start with Windows                        |

## How to Run

```powershell
# Start the app
# Double-click SlimPaste.ahk (requires AHK v2 installed)
# Or from command line:
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" SlimPaste.ahk

# Open setup window
# Right-click tray icon → Setup

# Manually test the worker (with clipboard containing an image):
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File worker\clipboard-jpeg-worker.ps1 -Quality 80 -Dpi 96 -JsonOutput

# Test setup XAML parsing:
powershell -NoProfile -STA -Command "Add-Type -AssemblyName PresentationFramework; [xml]$x = Get-Content setup\setup.axml -Raw; [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))"
```

## Compile to EXE

在 **Git Bash** 中编译时必须加 `MSYS2_ARG_CONV_EXCL='*'` 前缀，否则 Git Bash 会把 `/in`、`/out`、`/base` 参数误转成 Unix 路径导致编译失败：

```bash
# 编译主程序
MSYS2_ARG_CONV_EXCL='*' "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" \
  /in "SlimPaste.ahk" \
  /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" \
  /out "SlimPaste.exe" \
  /icon "assets\icon.ico"

# 编译设置窗口
MSYS2_ARG_CONV_EXCL='*' "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" \
  /in "setup\settings_gui.ahk" \
  /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" \
  /out "setup\Settings.exe" \
  /icon "assets\icon.ico"
```

PowerShell / cmd 中不需要 `MSYS2_ARG_CONV_EXCL`，直接调用即可。

### 图标编译注意事项

- **不要**在源码中用 `;@Ahk2Exe-SetIcon` 指令——新版 Ahk2Exe 处理该指令时会弹出错误弹窗并阻塞编译（即使图标文件路径正确）。改用命令行 `/icon` 参数可避免此问题。
- 编译后被旧版 Ahk2Exe 编译的 exe 图标可能是 AHK 默认图标，而非 SlimPaste 图标。确保使用正确的 Ahk2Exe 版本（v2 兼容版）并传入 `/icon` 参数即可获得正确图标。

## Commit Convention

`<type>(<scope>): <描述>`

Type: feat, fix, refactor, docs
Scope: script/component name (optional for cross-cutting changes)

Example messages in existing history:

- `feat: 项目更名为 SlimPaste`
- `fix: 关闭按钮不可见 + ComboBox 下拉高亮/边框问题`
- `fix(ClipboardJpgPaste): 修复 cmd.exe /C 参数引用导致 PowerShell worker 无输出的问题`
