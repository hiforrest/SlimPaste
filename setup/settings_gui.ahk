#Requires AutoHotkey v2.0
#SingleInstance Off

;@Ahk2Exe-SetVersion 0.4.0
;@Ahk2Exe-SetDescription SlimPaste Setup
;@Ahk2Exe-SetCopyright (c) 2026 SlimPaste
;@Ahk2Exe-SetCompanyName SlimPaste
;@Ahk2Exe-SetOrigFilename Settings.exe

; WPF setup window launcher.
; This first-version package does not vendor ahko's ahk-xaml engine directly.
; It keeps the same file organization and uses a WPF XAML/AXML file hosted by PowerShell.
; You can later replace settings-wpf.ps1 with an ahk-xaml adapter without changing config semantics.

appDir := RegExReplace(A_ScriptDir, "\\setup$")
configPath := appDir "\config.ini"
defaultConfigPath := appDir "\config\default-config.ini"
themePath := appDir "\themes.ini"
setupPs1 := A_ScriptDir "\settings-wpf.ps1"
setupAxml := A_ScriptDir "\setup.axml"
psExe := GetPowerShellPath()
appVersion := A_Args.Length >= 1 ? A_Args[1] : "v0.2.0"

if !FileExist(setupPs1) {
    MsgBox("settings-wpf.ps1 not found.", "SlimPaste Setup", "Iconx")
    ExitApp(1)
}

cmdArgs := "-NoProfile -ExecutionPolicy Bypass -STA -File " QuoteArg(setupPs1)
cmdArgs .= " -ConfigPath " QuoteArg(configPath)
cmdArgs .= " -DefaultConfigPath " QuoteArg(defaultConfigPath)
cmdArgs .= " -AxmlPath " QuoteArg(setupAxml)
cmdArgs .= " -AppVersion " QuoteArg(appVersion)
cmdArgs .= " -ThemePath " QuoteArg(themePath)

cmd := A_ComSpec ' /D /C ""' psExe '" ' cmdArgs '""'
ExitCode := RunWait(cmd, appDir, "Hide")
ExitApp(ExitCode)

QuoteArg(s) {
    return '"' StrReplace(s, '"', '\"') '"'
}

GetPowerShellPath() {
    path := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if FileExist(path)
        return path
    return "powershell.exe"
}
