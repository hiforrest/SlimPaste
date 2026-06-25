# Changelog

## v0.1.1

- Fixed AutoHotkey v2 syntax error in `BackupBrokenConfig()`.
- The previous `catch` block only contained a comment, which AutoHotkey treated as an empty block and reported as `Unexpected "}"`.
- Renamed project to SlimPaste.
- Fixed cmd.exe /C quoting that caused silent worker failure.
