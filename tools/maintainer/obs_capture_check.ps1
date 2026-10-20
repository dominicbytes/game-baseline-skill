<#
Maintainer check for B04 (and the B02 audio level): capture the exported game with OBS Studio's
Game Capture, with "Capture audio" on, and prove picture and sound arrive.

Uses a portable OBS copy (portable_mode.txt) with obs-websocket enabled, no auth, on -Port.
Never point this at an OBS install whose settings you care about: it changes the current
profile's recording folder and format and adds a scene.

Example:
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\maintainer\obs_capture_check.ps1 `
    -ObsDir <portable obs folder> -GameExe <exported exe> -OutDir <scratch folder> `
    -Ffmpeg <ffmpeg.exe> -Mode windowed [-NoCaptureAudio]
#>
param(
    [Parameter(Mandatory)] [string]$ObsDir,
    [Parameter(Mandatory)] [string]$GameExe,
    [Parameter(Mandatory)] [string]$OutDir,
    [Parameter(Mandatory)] [string]$Ffmpeg,
    [ValidateSet("windowed", "fullscreen")] [string]$Mode = "windowed",
    [switch]$NoCaptureAudio,
    [int]$Port = 4466,
    [int]$RecordSeconds = 12
)

$ErrorActionPreference = "Stop"
$CaptureAudio = -not $NoCaptureAudio
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Win {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
}
"@
[void][Win]::SetProcessDPIAware()

$WM_KEYDOWN = 0x0100; $WM_KEYUP = 0x0101; $WM_CLOSE = 0x0010

function Send-Key([IntPtr]$hwnd, [int]$vk, [int]$scan) {
    [void][Win]::PostMessage($hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
    Start-Sleep -Milliseconds 80
    [void][Win]::PostMessage($hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr]([int64](1 -bor ($scan -shl 16) -bor (3 -shl 30))))
}

function Get-Rect([IntPtr]$hwnd) {
    $r = New-Object Win+RECT
    [void][Win]::GetWindowRect($hwnd, [ref]$r)
    return "{0},{1},{2},{3}" -f $r.L, $r.T, $r.R, $r.B
}

function Send-Obs($socket, $message) {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($message | ConvertTo-Json -Depth 20 -Compress))
    [void]$socket.SendAsync([ArraySegment[byte]]::new($bytes), "Text", $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

function Receive-Obs($socket) {
    $buffer = New-Object byte[] 1048576
    $text = [Text.StringBuilder]::new()
    do {
        $result = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        [void]$text.Append([Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count))
    } while (-not $result.EndOfMessage)
    return $text.ToString() | ConvertFrom-Json
}

$script:meterPeak = 0.0
function Invoke-Obs($socket, [string]$type, $data = @{}) {
    $id = [Guid]::NewGuid().ToString("N")
    Send-Obs $socket @{ op = 6; d = @{ requestType = $type; requestId = $id; requestData = $data } }
    while ($true) {
        $msg = Receive-Obs $socket
        if ($msg.op -eq 5 -and $msg.d.eventType -eq "InputVolumeMeters") { Update-Meter $msg; continue }
        if ($msg.op -eq 7 -and $msg.d.requestId -eq $id) {
            if (-not $msg.d.requestStatus.result) { throw "$type failed ($($msg.d.requestStatus.code)): $($msg.d.requestStatus.comment)" }
            return $msg.d.responseData
        }
    }
}

function Update-Meter($msg) {
    foreach ($input in @($msg.d.eventData.inputs)) {
        if ($input.inputName -ne "Game") { continue }
        foreach ($channel in @($input.inputLevelsMul)) {
            foreach ($level in @($channel)) { $script:meterPeak = [Math]::Max($script:meterPeak, [double]$level) }
        }
    }
}

# Luma on a 160x90 grid: dense enough to see a moving sprite or a changing timer digit.
$GridW = 160; $GridH = 90
function Get-Luma([string]$path) {
    $bmp = [Drawing.Bitmap]::FromFile($path)
    try {
        $sum = 0.0; $n = 0; $samples = New-Object double[] ($GridW * $GridH)
        for ($y = 0; $y -lt $GridH; $y++) { for ($x = 0; $x -lt $GridW; $x++) {
            $p = $bmp.GetPixel([int](($x + 0.5) * $bmp.Width / $GridW), [int](($y + 0.5) * $bmp.Height / $GridH))
            $l = 0.2126 * $p.R + 0.7152 * $p.G + 0.0722 * $p.B
            $samples[$n] = $l; $sum += $l; $n++
        } }
        return @{ mean = $sum / $n; samples = $samples }
    } finally { $bmp.Dispose() }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$tag = "$Mode-" + $(if ($CaptureAudio) { "audio" } else { "noaudio" })
$report = [ordered]@{ mode = $Mode; capture_audio = $CaptureAudio }

# Fresh game user data with the window mode pre-set.
$gameData = Join-Path $OutDir "appdata-$tag"
$settingsDir = Join-Path $gameData "Redot\app_userdata\Baseline Demo"
New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
@{ "game.display.window_mode" = $Mode } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $settingsDir "settings.json") -Encoding ASCII

$obsBin = Join-Path $ObsDir "bin\64bit"
$obs = Start-Process -FilePath (Join-Path $obsBin "obs64.exe") -WorkingDirectory $obsBin -PassThru -WindowStyle Minimized `
    -ArgumentList "--portable", "--disable-shutdown-check", "--disable-updater"
$game = $null
$socket = [System.Net.WebSockets.ClientWebSocket]::new()
try {
    $deadline = (Get-Date).AddSeconds(30)
    while ($true) {
        try { [void]$socket.ConnectAsync([Uri]"ws://127.0.0.1:$Port", [Threading.CancellationToken]::None).GetAwaiter().GetResult(); break }
        catch { if ((Get-Date) -gt $deadline) { throw "OBS websocket did not open" }; Start-Sleep -Milliseconds 500; $socket = [System.Net.WebSockets.ClientWebSocket]::new() }
    }
    $hello = Receive-Obs $socket
    if ($hello.d.authentication) { throw "OBS websocket requires auth; use a portable copy with auth off" }
    Send-Obs $socket @{ op = 1; d = @{ rpcVersion = 1; eventSubscriptions = 65536 } }
    if ((Receive-Obs $socket).op -ne 2) { throw "OBS websocket identify failed" }
    # OBS answers 207 "not ready" until its UI has finished loading.
    $deadline = (Get-Date).AddSeconds(60)
    while ($true) {
        try { $report.obs_version = (Invoke-Obs $socket "GetVersion").obsVersion; [void](Invoke-Obs $socket "GetSceneList"); break }
        catch { if ($_.Exception.Message -notmatch "\(207\)" -or (Get-Date) -gt $deadline) { throw }; Start-Sleep -Milliseconds 500 }
    }

    # Only the game capture may produce sound.
    $special = Invoke-Obs $socket "GetSpecialInputs"
    foreach ($name in @($special.desktop1, $special.desktop2, $special.mic1, $special.mic2, $special.mic3, $special.mic4)) {
        if ($name) { [void](Invoke-Obs $socket "SetInputMute" @{ inputName = $name; inputMuted = $true }) }
    }
    [void](Invoke-Obs $socket "SetRecordDirectory" @{ recordDirectory = (Resolve-Path $OutDir).Path })
    foreach ($section in "SimpleOutput", "AdvOut") {
        [void](Invoke-Obs $socket "SetProfileParameter" @{ parameterCategory = $section; parameterName = "RecFormat2"; parameterValue = "mkv" })
    }

    # Start the game with its own user data and real audio.
    $savedAppData = $env:APPDATA
    $env:APPDATA = $gameData
    try { $game = Start-Process -FilePath $GameExe -PassThru } finally { $env:APPDATA = $savedAppData }
    $deadline = (Get-Date).AddSeconds(20)
    while ($game.MainWindowHandle -eq [IntPtr]::Zero) {
        if ((Get-Date) -gt $deadline) { throw "game window did not appear" }
        Start-Sleep -Milliseconds 250; $game.Refresh()
    }
    Start-Sleep -Seconds 3
    $hwnd = $game.MainWindowHandle
    $cls = [Text.StringBuilder]::new(256); [void][Win]::GetClassName($hwnd, $cls, 256)
    $title = [Text.StringBuilder]::new(256); [void][Win]::GetWindowText($hwnd, $title, 256)
    $exe = [IO.Path]::GetFileName($GameExe)
    $window = (@($title.ToString(), $cls.ToString(), $exe) | ForEach-Object { $_ -replace ":", "#3A" }) -join ":"
    $report.window = $window

    try { [void](Invoke-Obs $socket "CreateScene" @{ sceneName = "Baseline Capture" }) } catch { }
    [void](Invoke-Obs $socket "SetCurrentProgramScene" @{ sceneName = "Baseline Capture" })
    try { [void](Invoke-Obs $socket "RemoveInput" @{ inputName = "Game" }) } catch { }
    [void](Invoke-Obs $socket "CreateInput" @{
        sceneName = "Baseline Capture"; inputName = "Game"; inputKind = "game_capture"
        inputSettings = @{ capture_mode = "window"; window = $window; priority = 2; capture_audio = $CaptureAudio }
    })
    $rectBefore = Get-Rect $hwnd

    # Title -> New Game (Enter, scan code 0x1C), then let gameplay run.
    Send-Key $hwnd 0x0D 0x1C
    Start-Sleep -Seconds 5

    $shots = @()
    for ($i = 1; $i -le 3; $i++) {
        $img = Invoke-Obs $socket "GetSourceScreenshot" @{ sourceName = "Game"; imageFormat = "png"; imageWidth = 640 }
        $path = Join-Path $OutDir "$tag-shot$i.png"
        [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String(($img.imageData -replace "^data:image/png;base64,", "")))
        $shots += $path
        Start-Sleep -Seconds 2
    }

    $script:meterPeak = 0.0
    $until = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $until) {
        $msg = Receive-Obs $socket
        if ($msg.op -eq 5 -and $msg.d.eventType -eq "InputVolumeMeters") { Update-Meter $msg }
    }
    $report.meter_peak_dbfs = if ($script:meterPeak -gt 0) { [Math]::Round(20 * [Math]::Log10($script:meterPeak), 1) } else { -999 }

    [void](Invoke-Obs $socket "StartRecord")
    Start-Sleep -Seconds $RecordSeconds
    $recording = (Invoke-Obs $socket "StopRecord").outputPath
    $report.recording = [IO.Path]::GetFileName($recording)
    $rectAfter = Get-Rect $hwnd
    $report.window_rect_unchanged = ($rectBefore -eq $rectAfter)
    $report.window_rect = $rectBefore
    try { [void](Invoke-Obs $socket "RemoveInput" @{ inputName = "Game" }) } catch { }
}
finally {
    if ($game -and -not $game.HasExited) {
        [void][Win]::PostMessage($game.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
        if (-not $game.WaitForExit(5000)) { $report.game_quit_cleanly = $false; Stop-Process -Id $game.Id -Force } else { $report.game_quit_cleanly = $true }
    }
    if ($socket.State -eq "Open") { $socket.Dispose() }
    # Close OBS gracefully; a forced kill makes the next launch stop at a safe-mode prompt.
    if ($obs -and -not $obs.HasExited) {
        [void]$obs.CloseMainWindow()
        if (-not $obs.WaitForExit(20000)) { Stop-Process -Id $obs.Id -Force; Write-Warning "OBS had to be killed" }
    }
}

# Picture: not black, and changing between shots.
$lumas = $shots | ForEach-Object { Get-Luma $_ }
$report.shot_mean_luma = @($lumas | ForEach-Object { [Math]::Round($_.mean, 1) })
$changed = 0
for ($i = 1; $i -lt $lumas.Count; $i++) {
    $count = 0
    for ($k = 0; $k -lt $GridW * $GridH; $k++) { if ([Math]::Abs($lumas[$i].samples[$k] - $lumas[0].samples[$k]) -gt 24) { $count++ } }
    $changed = [Math]::Max($changed, $count)
}
$report.shot_changed_samples = $changed
$report.picture_ok = (($lumas | Where-Object { $_.mean -gt 10 }).Count -eq $lumas.Count) -and ($changed -ge 3)

# Sound: decode the recording and measure it. ffmpeg logs to stderr, which is not an error here.
$ErrorActionPreference = "Continue"
$volume = & $Ffmpeg -hide_banner -nostats -i $recording -map 0:a:0? -af volumedetect -f null - 2>&1 | Out-String
$mean = [regex]::Match($volume, "mean_volume:\s*(-?[\d.]+) dB")
$report.recording_mean_db = if ($mean.Success) { [double]$mean.Groups[1].Value } else { -999 }
$frames = & $Ffmpeg -hide_banner -nostats -i $recording -map 0:v:0 -f null - 2>&1 | Out-String
$report.video_decodes = $frames -match "frame=\s*\d+"
$report.sound_ok = ($report.recording_mean_db -gt -60) -and ($report.meter_peak_dbfs -gt -60)

$report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutDir "$tag-report.json") -Encoding UTF8
$report | ConvertTo-Json
