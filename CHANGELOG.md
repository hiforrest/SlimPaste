# Changelog

## v0.4.0 (2026-07-01)

- **绿色软件化** — Config/Temp 移至 exe 同目录，零写盘
- 修复 Setup 设置窗口无法打开的问题
- 去除重复动画文件，改为共用 `README.assets/ani.avif`
- 更新 README 介绍文案与 FAQ

## v0.3.0

- `themes.ini` 配色主题支持
- 托盘菜单快捷键显示修复
- README 添加动图，图标优化
- 编译新版 exe

## v0.2.0

- 设置窗口全面重写为 WPF/XAML 深色风格（`setup/setup.axml` + `settings-wpf.ps1`）
- 修复 ComboBox 下拉背景/边框/选中项配色问题
- 修复 `{x:Static}` 导致 XAML 加载失败（Setup 无法打开的问题）
- 修复关闭按钮不可见问题
- 快捷键从 `Ctrl+Alt+V` 改为 `Ctrl+Shift+V`
- 添加热键校验、关于页面、版本号显示
- JPEGli 改为项目内捆绑路径，移除用户配置项
- 编译发布适配 — exe 编译、图标、中文 README、gitignore

## v0.1.1

- Fixed AutoHotkey v2 syntax error in `BackupBrokenConfig()`.
- The previous `catch` block only contained a comment, which AutoHotkey treated as an empty block and reported as `Unexpected "}"`.
- Renamed project to SlimPaste.
- Fixed cmd.exe /C quoting that caused silent worker failure.
