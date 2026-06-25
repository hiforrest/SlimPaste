[CmdletBinding()]
param(
    [int]$Quality = 80,
    [int]$Dpi = 96,
    [string]$OutputDirectory = "$env:TEMP\SlimPaste",
    [string]$JpegliPath = "",
    [switch]$DisableJpegli,
    [switch]$ImageFallback,
    [switch]$KeepSourceDpi,
    [switch]$JsonOutput
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function New-Result {
    param(
        [bool]$Ok,
        [bool]$HadImage,
        [string]$Message,
        [string]$Encoder = "",
        [string]$Source = "",
        [string]$JpgPath = "",
        [long]$SourceBytes = 0,
        [long]$OutputBytes = 0,
        [int]$Width = 0,
        [int]$Height = 0,
        [int]$QualityValue = $Quality
    )

    [PSCustomObject]@{
        ok          = $Ok
        hadImage    = $HadImage
        encoder     = $Encoder
        source      = $Source
        jpgPath     = $JpgPath
        sourceBytes = $SourceBytes
        outputBytes = $OutputBytes
        width       = $Width
        height      = $Height
        quality     = $QualityValue
        message     = $Message
    }
}

function Write-Result {
    param([object]$Result)
    if ($JsonOutput) {
        $Result | ConvertTo-Json -Compress
    } else {
        $Result
    }
}

function Clamp-Int {
    param([int]$Value, [int]$Min, [int]$Max)
    if ($Value -lt $Min) { return $Min }
    if ($Value -gt $Max) { return $Max }
    return $Value
}

function Get-JpegCodec {
    [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq "image/jpeg" } |
        Select-Object -First 1
}

function Save-SystemJpeg {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path,
        [int]$Quality
    )

    $codec = Get-JpegCodec
    if (-not $codec) {
        throw "System JPEG encoder was not found."
    }

    $params = New-Object System.Drawing.Imaging.EncoderParameters 1
    $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality,
        [long]$Quality
    )

    $Bitmap.Save($Path, $codec, $params)
}

function Save-Png {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-FlattenedBitmap {
    param(
        [System.Drawing.Image]$Image,
        [int]$Dpi,
        [switch]$KeepSourceDpi
    )

    $width = [int]$Image.Width
    $height = [int]$Image.Height

    $bitmap = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)

    if ($KeepSourceDpi -and $Image.HorizontalResolution -gt 0 -and $Image.VerticalResolution -gt 0) {
        $bitmap.SetResolution($Image.HorizontalResolution, $Image.VerticalResolution)
    } else {
        $bitmap.SetResolution($Dpi, $Dpi)
    }

    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $g.Clear([System.Drawing.Color]::White)
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($Image, 0, 0, $width, $height)
    } finally {
        $g.Dispose()
    }

    return $bitmap
}

function Get-ClipboardImageCandidate {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
        $img = [System.Windows.Forms.Clipboard]::GetImage()
        if ($img) {
            return [PSCustomObject]@{
                Image = $img
                Source = "clipboard image data"
                SourcePath = ""
                SourceBytes = 0
            }
        }
    }

    if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
        $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
        $supported = @(".png", ".jpg", ".jpeg", ".bmp", ".gif", ".tif", ".tiff")
        foreach ($file in $files) {
            if (-not [string]::IsNullOrWhiteSpace($file) -and (Test-Path -LiteralPath $file)) {
                $ext = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
                if ($supported -contains $ext) {
                    $img = [System.Drawing.Image]::FromFile($file)
                    $len = 0
                    try { $len = (Get-Item -LiteralPath $file).Length } catch {}
                    return [PSCustomObject]@{
                        Image = $img
                        Source = "clipboard file: $file"
                        SourcePath = $file
                        SourceBytes = [long]$len
                    }
                }
            }
        }
    }

    return $null
}

function Set-JpgFileDropClipboard {
    param(
        [string]$JpgPath,
        [switch]$ImageFallback
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $collection = New-Object System.Collections.Specialized.StringCollection
    [void]$collection.Add($JpgPath)

    $data = New-Object System.Windows.Forms.DataObject
    $data.SetFileDropList($collection)

    $fallbackImage = $null
    try {
        if ($ImageFallback) {
            $fallbackImage = [System.Drawing.Image]::FromFile($JpgPath)
            $data.SetImage($fallbackImage)
        }

        # retryTimes/retryDelay protect against temporary clipboard ownership conflicts.
        [System.Windows.Forms.Clipboard]::SetDataObject($data, $true, 5, 200)
    } finally {
        if ($fallbackImage) { $fallbackImage.Dispose() }
    }
}

function Invoke-Jpegli {
    param(
        [string]$ExePath,
        [string]$InputPng,
        [string]$OutputJpg,
        [int]$Quality
    )

    if ([string]::IsNullOrWhiteSpace($ExePath)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $ExePath)) {
        return $false
    }

    & $ExePath $InputPng $OutputJpg "-q" ([string]$Quality) "--quiet" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return (Test-Path -LiteralPath $OutputJpg) -and ((Get-Item -LiteralPath $OutputJpg).Length -gt 0)
}

try {
    if ([Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
        throw "PowerShell worker must run in STA mode. Use powershell.exe -STA."
    }

    $Quality = Clamp-Int -Value $Quality -Min 1 -Max 100
    $Dpi = Clamp-Int -Value $Dpi -Min 1 -Max 1200

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        [void][System.IO.Directory]::CreateDirectory($OutputDirectory)
    }

    $candidate = Get-ClipboardImageCandidate
    if (-not $candidate) {
        Write-Result (New-Result -Ok $true -HadImage $false -Message "Clipboard does not contain an image.")
        exit 0
    }

    $srcImage = $candidate.Image
    $sourceBytes = [long]$candidate.SourceBytes
    $flattened = $null

    try {
        $flattened = New-FlattenedBitmap -Image $srcImage -Dpi $Dpi -KeepSourceDpi:$KeepSourceDpi

        $stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        $baseName = "clipboard_$stamp"
        $tempPng = Join-Path $OutputDirectory "$baseName.png"
        $jpgPath = Join-Path $OutputDirectory "$baseName.jpg"

        Save-Png -Bitmap $flattened -Path $tempPng

        if ($sourceBytes -le 0 -and (Test-Path -LiteralPath $tempPng)) {
            $sourceBytes = [long](Get-Item -LiteralPath $tempPng).Length
        }

        $encoder = ""
        $jpegliSucceeded = $false

        if (-not $DisableJpegli) {
            if ([string]::IsNullOrWhiteSpace($JpegliPath)) {
                $bundled = Join-Path $PSScriptRoot "..\bin\jpegli\cjpegli.exe"
                $JpegliPath = [System.IO.Path]::GetFullPath($bundled)
            }
            $jpegliSucceeded = Invoke-Jpegli -ExePath $JpegliPath -InputPng $tempPng -OutputJpg $jpgPath -Quality $Quality
        }

        if ($jpegliSucceeded) {
            $encoder = "jpegli"
        } else {
            Save-SystemJpeg -Bitmap $flattened -Path $jpgPath -Quality $Quality
            $encoder = "system-jpeg"
        }

        if (-not (Test-Path -LiteralPath $jpgPath)) {
            throw "JPG output was not created."
        }

        $outputBytes = [long](Get-Item -LiteralPath $jpgPath).Length
        if ($outputBytes -le 0) {
            throw "JPG output is empty."
        }

        Set-JpgFileDropClipboard -JpgPath $jpgPath -ImageFallback:$ImageFallback

        $msg = "OK"
        if (-not $jpegliSucceeded -and -not $DisableJpegli) {
            $msg = "JPEGli unavailable or failed; used system JPEG encoder."
        }

        Write-Result (New-Result `
            -Ok $true `
            -HadImage $true `
            -Message $msg `
            -Encoder $encoder `
            -Source $candidate.Source `
            -JpgPath $jpgPath `
            -SourceBytes $sourceBytes `
            -OutputBytes $outputBytes `
            -Width $flattened.Width `
            -Height $flattened.Height `
            -QualityValue $Quality)
    } finally {
        if ($flattened) { $flattened.Dispose() }
        if ($srcImage) { $srcImage.Dispose() }
    }
} catch {
    Write-Result (New-Result -Ok $false -HadImage $false -Message $_.Exception.Message)
    exit 1
}
