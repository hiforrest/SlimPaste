[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$DefaultConfigPath,
    [string]$AxmlPath,
    [string]$AppVersion = "v0.2.0"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms

function Read-Ini {
    param([string]$Path)

    $result = @{}
    $section = ""

    if (-not (Test-Path -LiteralPath $Path)) {
        return $result
    }

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trim = $line.Trim()
        if ($trim -eq "" -or $trim.StartsWith(";") -or $trim.StartsWith("#")) { continue }

        if ($trim.StartsWith("[") -and $trim.EndsWith("]")) {
            $section = $trim.Trim("[", "]")
            if (-not $result.ContainsKey($section)) { $result[$section] = @{} }
            continue
        }

        $idx = $trim.IndexOf("=")
        if ($idx -gt 0 -and $section -ne "") {
            $key = $trim.Substring(0, $idx).Trim()
            $value = $trim.Substring($idx + 1).Trim()
            $result[$section][$key] = $value
        }
    }

    return $result
}

function Get-ConfigValue {
    param(
        [hashtable]$Ini,
        [string]$Key,
        [string]$Default
    )

    if ($Ini.ContainsKey("General") -and $Ini["General"].ContainsKey($Key)) {
        return [string]$Ini["General"][$Key]
    }

    return $Default
}

function Write-Config {
    param(
        [string]$Path,
        [hashtable]$Values
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }

    $orderedKeys = @(
        "Hotkey",
        "UseJpegli",
        "OutputMode",
        "Quality",
        "TempDirectory",
        "ImageFallback",
        "CleanupDays",
        "ShowNotification",
        "StartupWithWindows"
    )

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("[General]")
    foreach ($key in $orderedKeys) {
        $value = if ($Values.ContainsKey($key)) { $Values[$key] } else { "" }
        [void]$sb.AppendLine("$key=$value")
    }

    # Write UTF-8 without BOM for best compatibility with AHK IniRead
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $sb.ToString(), $utf8NoBom)
}

function To-Bool {
    param([string]$Value)
    return $Value -eq "1" -or $Value.ToLowerInvariant() -in @("true", "yes", "on")
}

function Bool-To-Ini {
    param([object]$Value)
    if ([bool]$Value) { return "1" }
    return "0"
}

function Clamp-Int {
    param([string]$Value, [int]$Min, [int]$Max, [int]$Default)
    $n = 0
    if (-not [int]::TryParse($Value, [ref]$n)) { return $Default }
    if ($n -lt $Min) { return $Min }
    if ($n -gt $Max) { return $Max }
    return $n
}

function Expand-Env {
    param([string]$Value)
    return [Environment]::ExpandEnvironmentVariables($Value)
}

function Hotkey-Readable {
    param([string]$Hotkey)
    if ([string]::IsNullOrWhiteSpace($Hotkey)) { return "Hotkey is not set" }

    $text = $Hotkey
    $text = $text.Replace("^", "Ctrl + ")
    $text = $text.Replace("!", "Alt + ")
    $text = $text.Replace("+", "Shift + ")
    $text = $text.Replace("#", "Win + ")
    return "Hotkey is " + $text.Trim(" +".ToCharArray())
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    $dir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    if (Test-Path -LiteralPath $DefaultConfigPath) {
        Copy-Item -LiteralPath $DefaultConfigPath -Destination $ConfigPath -Force
    }
}

[xml]$xaml = Get-Content -LiteralPath $AxmlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

function C {
    param([string]$Name)
    return $window.FindName($Name)
}

$ini = Read-Ini -Path $ConfigPath

$HotkeyBox = C "HotkeyBox"
$HotkeyReadable = C "HotkeyReadable"
$UseJpegliCheck = C "UseJpegliCheck"
$QualityPresetCombo = C "QualityPresetCombo"
$QualitySlider = C "QualitySlider"
$QualityBox = C "QualityBox"
$ImageFallbackCheck = C "ImageFallbackCheck"
$TempDirectoryBox = C "TempDirectoryBox"
$SelectTempButton = C "SelectTempButton"
$CleanupDaysBox = C "CleanupDaysBox"
$OpenTempButton = C "OpenTempButton"
$StartupCheck = C "StartupCheck"
$NotificationCheck = C "NotificationCheck"
$HotkeyError = C "HotkeyError"
$AboutVersion = C "AboutVersion"
$AboutCopyright = C "AboutCopyright"
$SaveButton = C "SaveButton"
$CancelButton = C "CancelButton"
$CloseButton = C "CloseButton"
$HeaderPanel = C "HeaderPanel"

$HotkeyBox.Text = Get-ConfigValue $ini "Hotkey" "^!v"
$UseJpegliCheck.IsChecked = To-Bool (Get-ConfigValue $ini "UseJpegli" "1")
$quality = Clamp-Int (Get-ConfigValue $ini "Quality" "80") 1 100 80
$QualitySlider.Value = $quality
$QualityBox.Text = [string]$quality
$ImageFallbackCheck.IsChecked = To-Bool (Get-ConfigValue $ini "ImageFallback" "0")
$TempDirectoryBox.Text = Get-ConfigValue $ini "TempDirectory" "%TEMP%\SlimPaste"
$CleanupDaysBox.Text = Get-ConfigValue $ini "CleanupDays" "7"
$StartupCheck.IsChecked = To-Bool (Get-ConfigValue $ini "StartupWithWindows" "0")
$NotificationCheck.IsChecked = To-Bool (Get-ConfigValue $ini "ShowNotification" "1")

function Update-HotkeyText {
    $text = $HotkeyBox.Text.Trim()
    $HotkeyReadable.Text = Hotkey-Readable $text

    if ([string]::IsNullOrWhiteSpace($text)) {
        $HotkeyError.Text = "Hotkey cannot be empty."
        $HotkeyError.Visibility = "Visible"
        return
    }

    if (-not (Test-ValidHotkey $text)) {
        $HotkeyError.Text = "Invalid hotkey format. Use modifiers (^ ! + #) + key (e.g. ^!v, #+a, ^F1)."
        $HotkeyError.Visibility = "Visible"
    } else {
        $HotkeyError.Visibility = "Collapsed"
    }
}

function Test-ValidHotkey {
    param([string]$Hotkey)
    if ([string]::IsNullOrWhiteSpace($Hotkey)) { return $false }

    # Strip modifiers from the start, then check the remainder is a valid key name
    $key = $Hotkey
    foreach ($ch in [char[]]'^!+#') { $key = $key.TrimStart($ch) }
    if ([string]::IsNullOrWhiteSpace($key)) { return $false }

    # Single letter or digit
    if ($key -match '^[a-zA-Z0-9]$') { return $true }

    # F1-F24
    if ($key -match '^F(1[0-9]?|2[0-4]?|[2-9])$' -and -not ($key -match '^F0$')) { return $true }

    # Common named keys
    $named = @('Space','Tab','Enter','Escape','Esc','Backspace','BS','Delete','Del','Insert','Ins',
               'Home','End','PgUp','PgDn','PageUp','PageDown','Up','Down','Left','Right',
               'ScrollLock','CapsLock','NumLock','PrintScreen','Pause','Break','AppsKey')
    return $named -contains $key
}

# Set About section info
$AboutVersion.Text = "Version $AppVersion"
$AboutCopyright.Text = "Copyright (c) 2026 SlimPaste contributors. MIT License."

function Sync-PresetFromQuality {
    $q = [int]$QualitySlider.Value
    for ($i = 0; $i -lt $QualityPresetCombo.Items.Count; $i++) {
        $item = $QualityPresetCombo.Items[$i]
        if ([string]$item.Tag -eq [string]$q) {
            $QualityPresetCombo.SelectedIndex = $i
            return
        }
    }
    $QualityPresetCombo.SelectedIndex = -1
}

Update-HotkeyText
Sync-PresetFromQuality

$HotkeyBox.Add_TextChanged({ Update-HotkeyText })

$HeaderPanel.Add_MouseLeftButtonDown({
    try { $window.DragMove() } catch {}
})

$CloseButton.Add_Click({ $window.Close() })
$CancelButton.Add_Click({ $window.Close() })

$QualitySlider.Add_ValueChanged({
    $QualityBox.Text = [string][int]$QualitySlider.Value
    Sync-PresetFromQuality
})

$QualityBox.Add_LostFocus({
    $q = Clamp-Int $QualityBox.Text 1 100 80
    $QualitySlider.Value = $q
    $QualityBox.Text = [string]$q
})

$QualityPresetCombo.Add_SelectionChanged({
    $item = $QualityPresetCombo.SelectedItem
    if ($item -and $item.Tag) {
        $QualitySlider.Value = [int]$item.Tag
    }
})

$SelectTempButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select temporary output folder"
    $expanded = Expand-Env $TempDirectoryBox.Text
    if (Test-Path -LiteralPath $expanded) { $dlg.SelectedPath = $expanded }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TempDirectoryBox.Text = $dlg.SelectedPath
    }
})

$OpenTempButton.Add_Click({
    $dir = Expand-Env $TempDirectoryBox.Text
    if (-not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    Start-Process explorer.exe -ArgumentList "`"$dir`""
})

$SaveButton.Add_Click({
    $qualityValue = Clamp-Int $QualityBox.Text 1 100 80
    $cleanupValue = Clamp-Int $CleanupDaysBox.Text 0 3650 7

    $values = @{
        Hotkey = $HotkeyBox.Text.Trim()
        UseJpegli = Bool-To-Ini $UseJpegliCheck.IsChecked
        OutputMode = "jpg_quality"
        Quality = [string]$qualityValue
        TempDirectory = $TempDirectoryBox.Text.Trim()
        ImageFallback = Bool-To-Ini $ImageFallbackCheck.IsChecked
        CleanupDays = [string]$cleanupValue
        ShowNotification = Bool-To-Ini $NotificationCheck.IsChecked
        StartupWithWindows = Bool-To-Ini $StartupCheck.IsChecked
    }

    if ([string]::IsNullOrWhiteSpace($values.Hotkey)) {
        [System.Windows.MessageBox]::Show("Hotkey cannot be empty.", "SlimPaste Setup", "OK", "Warning") | Out-Null
        return
    }

    if (-not (Test-ValidHotkey $values.Hotkey)) {
        [System.Windows.MessageBox]::Show("Invalid hotkey format.`n`nUse modifiers (^ Ctrl, ! Alt, + Shift, # Win) + a key.`nExamples: ^!v, #+a, ^F1, !Space", "SlimPaste Setup", "OK", "Warning") | Out-Null
        return
    }

    Write-Config -Path $ConfigPath -Values $values
    $window.Close()
})

[void]$window.ShowDialog()
