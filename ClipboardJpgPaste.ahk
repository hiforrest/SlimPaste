#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Clipboard JPG Paste / 剪贴板图片瘦身粘贴
; First version:
; - Dedicated hotkey only, default Ctrl+Alt+V
; - PowerShell STA worker reads clipboard image / image file, writes JPG file object back
; - Does not intercept ordinary Ctrl+V

global APP_NAME := "Clipboard JPG Paste"
global APP_DIR := A_ScriptDir
global CONFIG_DIR := A_AppData "\ClipboardJpgPaste"
global CONFIG_PATH := CONFIG_DIR "\config.ini"
global DEFAULT_CONFIG_PATH := APP_DIR "\config\default-config.ini"
global WORKER_PATH := APP_DIR "\worker\clipboard-jpeg-worker.ps1"
global SETUP_SCRIPT := APP_DIR "\setup\settings_gui.ahk"
global PS_EXE := GetPowerShellPath()

global Config := Map()
global RegisteredHotkey := ""
global Processing := false
global HotkeyPaused := false

Init()
return

Init() {
    DirCreate(CONFIG_DIR)
    EnsureConfig()
    LoadConfig()
    CreateTrayMenu()
    CleanupOldTempFiles()
    SyncStartupSetting()
    RegisterConfiguredHotkey()
}

EnsureConfig() {
    global CONFIG_PATH, DEFAULT_CONFIG_PATH
    if FileExist(CONFIG_PATH)
        return

    if FileExist(DEFAULT_CONFIG_PATH) {
        FileCopy(DEFAULT_CONFIG_PATH, CONFIG_PATH, true)
    } else {
        WriteDefaultConfig(CONFIG_PATH)
    }
}

WriteDefaultConfig(path) {
    defaultText :=
    (
    "[General]
Hotkey=^!v
UseJpegli=1
JpegliPath=D:\GProgram\jxl-x64-windows-static\cjpegli.exe
OutputMode=jpg_quality
Quality=80
TempDirectory=%TEMP%\ClipboardJpg
ImageFallback=0
CleanupDays=7
ShowNotification=1
StartupWithWindows=0
"
    )
    FileAppend(defaultText, path, "UTF-8")
}

LoadConfig() {
    global Config, CONFIG_PATH

    try {
        Config["Hotkey"] := IniRead(CONFIG_PATH, "General", "Hotkey", "^!v")
        Config["UseJpegli"] := ReadIniBool("UseJpegli", true)
        Config["JpegliPath"] := IniRead(CONFIG_PATH, "General", "JpegliPath", "D:\GProgram\jxl-x64-windows-static\cjpegli.exe")
        Config["OutputMode"] := IniRead(CONFIG_PATH, "General", "OutputMode", "jpg_quality")
        Config["Quality"] := ClampInt(IniRead(CONFIG_PATH, "General", "Quality", "80"), 1, 100, 80)
        Config["TempDirectory"] := IniRead(CONFIG_PATH, "General", "TempDirectory", "%TEMP%\ClipboardJpg")
        Config["ImageFallback"] := ReadIniBool("ImageFallback", false)
        Config["CleanupDays"] := ClampInt(IniRead(CONFIG_PATH, "General", "CleanupDays", "7"), 0, 3650, 7)
        Config["ShowNotification"] := ReadIniBool("ShowNotification", true)
        Config["StartupWithWindows"] := ReadIniBool("StartupWithWindows", false)
    } catch as err {
        BackupBrokenConfig(err.Message)
        WriteDefaultConfig(CONFIG_PATH)
        LoadConfig()
    }
}

ReadIniBool(key, defaultValue := false) {
    global CONFIG_PATH
    raw := IniRead(CONFIG_PATH, "General", key, defaultValue ? "1" : "0")
    return raw = "1" || StrLower(raw) = "true" || StrLower(raw) = "yes" || StrLower(raw) = "on"
}

ClampInt(value, min, max, defaultValue) {
    try n := Integer(value)
    catch
        return defaultValue
    if n < min
        return min
    if n > max
        return max
    return n
}

BackupBrokenConfig(reason) {
    global CONFIG_PATH
    if !FileExist(CONFIG_PATH)
        return
    backup := CONFIG_PATH ".broken_" FormatTime(, "yyyyMMdd_HHmmss") ".bak"
    try {
        FileMove(CONFIG_PATH, backup, true)
    } catch {
        ; Keep running even if backup fails.
        return
    }
}

RegisterConfiguredHotkey() {
    global Config, RegisteredHotkey, HotkeyPaused, APP_NAME

    if RegisteredHotkey != "" {
        try Hotkey(RegisteredHotkey, "Off")
    }

    hk := Config["Hotkey"]
    try {
        Hotkey(hk, CompressAndPaste, "On")
        RegisteredHotkey := hk
        HotkeyPaused := false
        try A_TrayMenu.Uncheck("Pause Hotkey")
    } catch as err {
        ; Fall back to the default hotkey if the configured one is invalid.
        try Hotkey("^!v", CompressAndPaste, "On")
        RegisteredHotkey := "^!v"
        HotkeyPaused := false
        ShowTip("Hotkey fallback", "Invalid hotkey in config. Using Ctrl + Alt + V.")
    }
}

CreateTrayMenu() {
    global APP_NAME

    A_TrayMenu.Delete()
    A_TrayMenu.Add("Compress and Paste", CompressAndPaste)
    A_TrayMenu.Add("Setup", OpenSetup)
    A_TrayMenu.Add("Open Temp Folder", OpenTempFolder)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Pause Hotkey", TogglePauseHotkey)
    A_TrayMenu.Add("Reload", (*) => Reload())
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_TrayMenu.Default := "Compress and Paste"

    try TraySetIcon(APP_DIR "\assets\icon.ico")
}

CompressAndPaste(*) {
    global Processing, Config

    if Processing {
        ShowTip("Processing", "Clipboard image is already being compressed...")
        return
    }

    Processing := true
    try {
        result := RunWorker()

        ; If worker failed, do not block the user's original paste.
        if !result["ok"] {
            ShowTip("Compression failed", result["message"])
            Send("^v")
            return
        }

        ; Not an image: dedicated hotkey behaves exactly like ordinary Ctrl+V.
        if !result["hadImage"] {
            Send("^v")
            return
        }

        ; Worker has replaced clipboard with JPG FileDropList.
        Sleep(80)
        Send("^v")

        if Config["ShowNotification"] {
            before := FormatBytes(result["sourceBytes"])
            after := FormatBytes(result["outputBytes"])
            enc := result["encoder"]
            msg := "Compressed " before " -> " after " using " enc "."
            ShowTip("Image pasted", msg)
        }
    } catch as err {
        ShowTip("Clipboard JPG Paste", "Unexpected error: " err.Message)
        Send("^v")
    } finally {
        Processing := false
    }
}

RunWorker() {
    global Config, WORKER_PATH, PS_EXE

    if !FileExist(WORKER_PATH) {
        return Map("ok", false, "hadImage", false, "message", "Worker script not found: " WORKER_PATH)
    }

    outputDir := ExpandEnvVars(Config["TempDirectory"])
    DirCreate(outputDir)

    outFile := A_Temp "\clipboardjpgpaste_" A_TickCount "_out.json"
    errFile := A_Temp "\clipboardjpgpaste_" A_TickCount "_err.txt"

    args := "-NoProfile -ExecutionPolicy Bypass -STA -File " QuoteArg(WORKER_PATH)
    args .= " -Quality " Config["Quality"]
    args .= " -Dpi 96"
    args .= " -OutputDirectory " QuoteArg(outputDir)
    args .= " -JpegliPath " QuoteArg(Config["JpegliPath"])
    if !Config["UseJpegli"]
        args .= " -DisableJpegli"
    if Config["ImageFallback"]
        args .= " -ImageFallback"
    args .= " -JsonOutput"

    cmd := A_ComSpec ' /D /C ""' PS_EXE '" ' args ' > "' outFile '" 2> "' errFile '""'
    exitCode := RunWait(cmd, , "Hide")

    stdout := FileExist(outFile) ? FileRead(outFile, "UTF-8") : ""
    stderr := FileExist(errFile) ? FileRead(errFile, "UTF-8") : ""

    try FileDelete(outFile)
    try FileDelete(errFile)

    if stdout = "" {
        msg := "PowerShell worker returned no output (exit code " exitCode ")."
        if stderr != ""
            msg .= " " Trim(stderr)
        return Map("ok", false, "hadImage", false, "message", msg)
    }

    json := ExtractJsonObject(stdout)
    if json = "" {
        msg := "PowerShell worker output was not JSON (exit code " exitCode ")."
        if stderr != ""
            msg .= " " Trim(stderr)
        return Map("ok", false, "hadImage", false, "message", msg)
    }

    ok := JsonBool(json, "ok", false)
    hadImage := JsonBool(json, "hadImage", false)
    message := JsonString(json, "message", "")
    if !ok && stderr != ""
        message .= " " Trim(stderr)

    return Map(
        "ok", ok,
        "hadImage", hadImage,
        "encoder", JsonString(json, "encoder", ""),
        "source", JsonString(json, "source", ""),
        "jpgPath", JsonString(json, "jpgPath", ""),
        "sourceBytes", JsonNumber(json, "sourceBytes", 0),
        "outputBytes", JsonNumber(json, "outputBytes", 0),
        "width", JsonNumber(json, "width", 0),
        "height", JsonNumber(json, "height", 0),
        "quality", JsonNumber(json, "quality", Config["Quality"]),
        "message", message
    )
}

ExtractJsonObject(text) {
    if RegExMatch(text, "s)\{.*\}", &m)
        return m[0]
    return ""
}

JsonBool(json, key, defaultValue := false) {
    pattern := '"' key '"\s*:\s*(true|false)'
    if RegExMatch(json, pattern, &m)
        return m[1] = "true"
    return defaultValue
}

JsonNumber(json, key, defaultValue := 0) {
    pattern := '"' key '"\s*:\s*(-?\d+(?:\.\d+)?)'
    if RegExMatch(json, pattern, &m)
        return Number(m[1])
    return defaultValue
}

JsonString(json, key, defaultValue := "") {
    pattern := '"' key '"\s*:\s*"((?:\\.|[^"\\])*)"'
    if RegExMatch(json, pattern, &m)
        return JsonUnescape(m[1])
    return defaultValue
}

JsonUnescape(s) {
    s := StrReplace(s, '\"', '"')
    s := StrReplace(s, "\\", "\")
    s := StrReplace(s, "\r", "`r")
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\t", "`t")
    return s
}

OpenSetup(*) {
    global SETUP_SCRIPT

    if !FileExist(SETUP_SCRIPT) {
        ShowTip("Setup", "Setup script not found.")
        return
    }

    try {
        RunWait(QuoteArg(A_AhkPath) " " QuoteArg(SETUP_SCRIPT), APP_DIR)
    } catch as err {
        ShowTip("Setup failed", err.Message)
        return
    }

    ; Reload config and hotkey after setup closes.
    LoadConfig()
    CleanupOldTempFiles()
    SyncStartupSetting()
    RegisterConfiguredHotkey()
}

OpenTempFolder(*) {
    global Config
    dir := ExpandEnvVars(Config["TempDirectory"])
    DirCreate(dir)
    Run("explorer.exe " QuoteArg(dir))
}

TogglePauseHotkey(*) {
    global RegisteredHotkey, HotkeyPaused

    if RegisteredHotkey = ""
        return

    if HotkeyPaused {
        try Hotkey(RegisteredHotkey, "On")
        HotkeyPaused := false
        try A_TrayMenu.Uncheck("Pause Hotkey")
        ShowTip("Hotkey enabled", "Clipboard JPG Paste hotkey is active.")
    } else {
        try Hotkey(RegisteredHotkey, "Off")
        HotkeyPaused := true
        try A_TrayMenu.Check("Pause Hotkey")
        ShowTip("Hotkey paused", "Clipboard JPG Paste hotkey is paused.")
    }
}

CleanupOldTempFiles() {
    global Config

    dir := ExpandEnvVars(Config["TempDirectory"])
    days := Config["CleanupDays"]

    if days <= 0
        return

    if !DirExist(dir)
        return

    cutoff := DateAdd(A_Now, -days, "Days")
    Loop Files, dir "\*.*", "F" {
        try {
            modTime := FileGetTime(A_LoopFileFullPath, "M")
            if modTime < cutoff {
                FileDelete(A_LoopFileFullPath)
            }
        }
    }
}

SyncStartupSetting() {
    global Config, APP_NAME

    runKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    value := QuoteArg(A_AhkPath) " " QuoteArg(A_ScriptFullPath)

    try {
        if Config["StartupWithWindows"] {
            RegWrite(value, "REG_SZ", runKey, APP_NAME)
        } else {
            try RegDelete(runKey, APP_NAME)
        }
    }
}

ShowTip(title, text) {
    try TrayTip(text, title, 1)
}

FormatBytes(bytes) {
    try n := Number(bytes)
    catch
        n := 0

    if n < 1024
        return Round(n) " B"
    if n < 1048576
        return Round(n / 1024, 1) " KB"
    if n < 1073741824
        return Round(n / 1048576, 1) " MB"
    return Round(n / 1073741824, 1) " GB"
}

HotkeyHumanReadable(hk) {
    s := hk
    s := StrReplace(s, "^", "Ctrl + ")
    s := StrReplace(s, "!", "Alt + ")
    s := StrReplace(s, "+", "Shift + ")
    s := StrReplace(s, "#", "Win + ")
    return Trim(s, " +")
}

ExpandEnvVars(value) {
    buf := Buffer(32767 * 2, 0)
    len := DllCall("ExpandEnvironmentStrings", "Str", value, "Ptr", buf.Ptr, "UInt", 32767, "UInt")
    if len = 0
        return value
    return StrGet(buf)
}

QuoteArg(s) {
    ; Safe enough for normal Windows paths, including spaces.
    return '"' StrReplace(s, '"', '\"') '"'
}

GetPowerShellPath() {
    path := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if FileExist(path)
        return path
    return "powershell.exe"
}
