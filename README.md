<p align="right">
  <a href="README.en.md">English</a>
</p>

# SlimPaste

**粘贴时自动压缩剪贴板图片**

![Slim Robot](README.assets/ani.avif)

剪贴板中的图片通常会以未压缩的位图数据暂存。无论是截图还是复制图片，当你把它粘贴到微信或文档里时，目标应用会按自己的方式重新编码或保存，图片体积很容易达到 MB 级。你的微信和文档，就是这样被一点点撑大的。

粘贴时按快捷键 Ctrl+Shift+V，SlimPaste 在后台完成一次肉眼无损的压缩，再帮你执行粘贴。一张数 MB 的大图，贴出来只有几百甚至几十 KB。

让每次粘贴都轻盈利落。

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

1. 下载 [Releases](https://github.com/hiforrest/SlimPaste/releases) 中的 `SlimPaste-v0.4.0.zip`
2. 解压，运行 `SlimPaste.exe`
3. 截图或复制一张图片
4. 按 `Ctrl + Shift + V`
5. 在目标窗口（聊天、文档、笔记等）中即粘贴为压缩后的 JPG 文件

> 无需安装 AutoHotkey。

## 配置

右键托盘图标 → **Setup** 打开设置窗口。

配置文件路径（与 `SlimPaste.exe` 同目录）：

```
.\config.ini
```

| 配置项 | 默认值 | 说明 |
|---|---|---|
| Hotkey | `^+v` | 快捷键（`^`=Ctrl `+`=Shift `!`=Alt `#`=Win） |
| UseJpegli | `1` | 使用内置 JPEGli 编码器 |
| OutputMode | `jpg_quality` | 压缩模式 |
| Quality | `80` | JPG 质量（1–100） |
| TempDirectory | `.\temp` | 临时文件目录（exe 同目录） |
| ImageFallback | `0` | 同时将图片数据写入剪贴板 |
| CleanupDays | `7` | 自动清理 N 天前的临时文件 |
| ShowNotification | `1` | 粘贴后显示通知 |
| StartupWithWindows | `0` | 开机自启 |

## 系统需求

- Windows 7 及以上（64 位）

## 附注

- 如果 JPEGli 编码器不可用，会自动回退到 Windows 系统自带的 GDI+ JPEG 编码器，功能不受影响
- 临时文件默认保存在 `.\temp`（exe 同目录），可在设置中修改

## 构建

源码使用 AutoHotkey v2，如需自行编译：

1. 安装 AutoHotkey v2
2. 使用 Ahk2Exe 编译 `SlimPaste.ahk` 和 `setup\settings_gui.ahk`
3. 保留 `worker`、`setup`、`config`、`assets`、`bin` 目录与 exe 同级

## 常见问题

### 如何安装使用？

SlimPaste 是绿色软件，无需安装。下载后解压压缩包（建议不要放到 `C:/Program Files/`，避免权限问题），运行其中的 `SlimPaste.exe` 即可。

使用时，先截图或复制一张图片，然后在需要粘贴的位置按下 `Ctrl + Shift + V`，SlimPaste 会自动压缩剪贴板中的图片并完成粘贴。

### SlimPaste 安全吗？

SlimPaste 纯本地运行，仅在按下快捷键时处理剪贴板图片，**不上传数据**，也不会主动读取其它内容。源码开源可查。AHK/PowerShell 可能被杀软误报，确认下载来源可靠，可放心加入杀软信任列表，或自行查看源码、编译使用。

### 压缩算法靠谱吗？

靠谱。SlimPaste 使用 **jpegli** 进行 JPG 编码。jpegli 是基于 JPEG XL 项目技术发展而来的高质量 JPEG 编码器，在保持标准 JPG 格式兼容性的同时，能获得更好的压缩效率和视觉质量。

默认会将图片压缩到肉眼无损的质量，按原大小查看时几乎看不出差别。如果你希望图片体积更小，或想保留更高的画质，也可以在设置中自行调整质量参数。

### 可以自定义快捷键吗？

可以在设置中更换快捷键。

### 会修改我的原图吗？

不会。SlimPaste 处理的是剪贴板里的临时图片数据，**不会修改你电脑上的原始图片文件**。你可以把它理解为：在粘贴之前，SlimPaste 临时生成了一份更轻量的图片，然后把这份图片粘贴出去。

### 支持哪些应用？

SlimPaste 适合在支持图片粘贴的应用中使用，例如微信、QQ、飞书、文档编辑器、笔记软件、浏览器输入框等。

### 为什么从文件夹复制图片后没有压缩？

SlimPaste 处理的是剪贴板中的图片数据，不处理图片文件本身。

如果你在图片查看器、浏览器或聊天软件中打开图片，右键选择「复制」或「复制图像」，图片通常会以可粘贴的图像数据进入剪贴板，SlimPaste 会对其进行压缩。

但如果你在文件夹中选中图片文件（图标）并按 `Ctrl + C`，复制的通常是文件引用，而不是图片像素数据。它没有被转换为图像数据，体积没有剧增，所以不一定需要压缩，SlimPaste 不会处理它。

如果需要压缩粘贴，请先打开图片，选择「复制图像」，或直接截图后按 `Ctrl + Shift + V`。
