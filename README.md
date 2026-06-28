<p align="right">
  <a href="README.en.md">English</a>
</p>

# SlimPaste / 剪贴板图片瘦身粘贴

**粘贴时自动压缩图片**

你每次将截屏或复制的图片粘贴到微信、文档中时，系统实际贴入的是一张重新生成的图片。它的体积往往比原图大很多，有时一张截屏可达数 MB，你的微信和文档文件就是这样被一点点撑大的。

SlimPaste 专门用来解决这个问题。只需按下 Ctrl+Shift+V，图片在粘贴时会自动压缩，在保证肉眼无损的同时，大幅减小图片体积。

使用 SlimPaste，让每次粘贴都轻盈利落。

---

截图或复制图片后，按下 `Ctrl + Shift + V`，工具会自动将剪贴板中的图片压缩为 JPG 文件，然后将该 JPG 以**文件对象**的形式放回剪贴板，最后模拟粘贴操作。

普通 `Ctrl + V` 不会被拦截，日常使用不受影响。

## 功能

- 自定义全局快捷键（默认 `Ctrl + Shift + V`）
- 截图/图片自动压缩为 JPG，质量可调
- 以文件对象形式粘贴，可直接插入文档、聊天窗口等
- 优先使用内置 JPEGli 编码器（更小体积、更好画质），失败时自动回退系统编码器
- 托盘菜单：执行粘贴 / 设置 / 打开临时目录 / 暂停热键
- 自动清理过期临时文件
- 深色风格设置窗口

## 使用方式

1. 下载 [Releases](https://github.com/hiforrest/SlimPaste/releases) 中的 `SlimPaste-v0.2.0.zip`
2. 解压，运行 `SlimPaste.exe`
3. 截图或复制一张图片
4. 按 `Ctrl + Shift + V`
5. 在目标窗口（聊天、文档、笔记等）中即粘贴为压缩后的 JPG 文件

> 无需安装 AutoHotkey。

## 配置

右键托盘图标 → **Setup** 打开设置窗口。

配置文件路径：

```
%APPDATA%\SlimPaste\config.ini
```

| 配置项 | 默认值 | 说明 |
|---|---|---|
| Hotkey | `^+v` | 快捷键（`^`=Ctrl `+`=Shift `!`=Alt `#`=Win） |
| Quality | `80` | JPG 质量（1–100） |
| UseJpegli | `1` | 使用内置 JPEGli 编码器 |
| TempDirectory | `%TEMP%\SlimPaste` | 临时文件目录 |
| CleanupDays | `7` | 自动清理 N 天前的临时文件 |
| ShowNotification | `1` | 粘贴后显示通知 |
| StartupWithWindows | `0` | 开机自启 |

## 系统需求

- Windows 7 及以上（64 位）

## 附注

- 如果 JPEGli 编码器不可用，会自动回退到 Windows 系统自带的 GDI+ JPEG 编码器，功能不受影响
- 临时文件默认保存在 `%TEMP%\SlimPaste`，可在设置中修改

## 构建

源码使用 AutoHotkey v2，如需自行编译：

1. 安装 AutoHotkey v2
2. 使用 Ahk2Exe 编译 `SlimPaste.ahk` 和 `setup\settings_gui.ahk`
3. 保留 `worker`、`setup`、`config`、`assets`、`bin` 目录与 exe 同级
