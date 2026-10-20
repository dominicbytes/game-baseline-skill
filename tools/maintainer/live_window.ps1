<#
Maintainer helper for the live window checks (B11, B13, B15, B16) on an exported build.
Each call does one action, so a person or agent can look at screenshots between steps.

  -Action start    -GameExe <exe> -AppData <folder> [-Mode windowed|fullscreen|exclusive]
  -Action shot     -Out <png>                 client area of the game window (PrintWindow)
  -Action click    -X <x> -Y <y>              posted WM_LBUTTONDOWN/UP at client coordinates
  -Action realclick -X <x> -Y <y>             real SendInput click; cursor is put back afterwards
  -Action key      -Vk <code> -Scan <code>    posted key press (Enter 0x0D/0x1C, Esc 0x1B/0x01)
  -Action blur                                minimize the game (it loses focus), then restore it
  -Action focus                               bring the game window forward
  -Action close                               post WM_CLOSE and wait for the process to exit
  -Action info                                print window rect, client size and foreground state

Coordinates are physical pixels (the script is DPI aware). The game process is found by name.
#>
param(
    [Parameter(Mandatory)] [ValidateSet("start", "shot", "click", "realclick", "key", "blur", "focus", "close", "info")] [string]$Action,
    [string]$GameExe,
    [string]$AppData,
    [ValidateSet("windowed", "fullscreen", "exclusive")] [string]$Mode = "windowed",
    [string]$Out,
    [int]$X, [int]$Y,
    [int]$Vk, [int]$Scan,
    [string]$ProcessName = "BaselineDemo"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class LiveWin {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy, mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public int type; public MOUSEINPUT mi; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
}
"@
[void][LiveWin]::SetProcessDPIAware()

function Get-GameWindow {
    $p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
    if (-not $p) { throw "no $ProcessName window" }
    return $p
}

function Bring-Forward([IntPtr]$hwnd) {
    # An Alt tap lets a background process take the foreground (Windows foreground lock).
    [LiveWin]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
    [LiveWin]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
    [void][LiveWin]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 300
    return ([LiveWin]::GetForegroundWindow() -eq $hwnd)
}

switch ($Action) {
    "start" {
        $settingsDir = Join-Path $AppData "Redot\app_userdata\Baseline Demo"
        New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
        @{ "game.display.window_mode" = $Mode } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $settingsDir "settings.json") -Encoding ASCII
        $saved = $env:APPDATA; $env:APPDATA = $AppData
        try { $p = Start-Process -FilePath $GameExe -PassThru } finally { $env:APPDATA = $saved }
        $deadline = (Get-Date).AddSeconds(20)
        while ($p.MainWindowHandle -eq [IntPtr]::Zero) {
            if ((Get-Date) -gt $deadline) { throw "game window did not appear" }
            Start-Sleep -Milliseconds 250; $p.Refresh()
        }
        Start-Sleep -Seconds 2
        "started pid $($p.Id); foreground=$(Bring-Forward $p.MainWindowHandle)"
    }
    "shot" {
        $h = (Get-GameWindow).MainWindowHandle
        $r = New-Object LiveWin+RECT; [void][LiveWin]::GetClientRect($h, [ref]$r)
        $bmp = New-Object Drawing.Bitmap ([Math]::Max(1, $r.R)), ([Math]::Max(1, $r.B))
        $g = [Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
        [void][LiveWin]::PrintWindow($h, $dc, 3)   # PW_CLIENTONLY | PW_RENDERFULLCONTENT
        $g.ReleaseHdc($dc); $g.Dispose()
        $bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        "saved $($r.R)x$($r.B)"
    }
    "click" {
        $h = (Get-GameWindow).MainWindowHandle
        $l = [IntPtr](($Y -shl 16) -bor ($X -band 0xFFFF))
        [void][LiveWin]::PostMessage($h, 0x0200, [IntPtr]::Zero, $l)   # WM_MOUSEMOVE
        Start-Sleep -Milliseconds 60
        [void][LiveWin]::PostMessage($h, 0x0201, [IntPtr]1, $l)        # WM_LBUTTONDOWN
        Start-Sleep -Milliseconds 60
        [void][LiveWin]::PostMessage($h, 0x0202, [IntPtr]::Zero, $l)   # WM_LBUTTONUP
        "posted click at $X,$Y"
    }
    "realclick" {
        $h = (Get-GameWindow).MainWindowHandle
        [void](Bring-Forward $h)
        $before = New-Object LiveWin+POINT; [void][LiveWin]::GetCursorPos([ref]$before)
        $pt = New-Object LiveWin+POINT; $pt.X = $X; $pt.Y = $Y; [void][LiveWin]::ClientToScreen($h, [ref]$pt)
        # Absolute move, then press and release, as one input stream (like a real mouse).
        $vx = [LiveWin]::GetSystemMetrics(76); $vy = [LiveWin]::GetSystemMetrics(77)
        $vw = [LiveWin]::GetSystemMetrics(78); $vh = [LiveWin]::GetSystemMetrics(79)
        $ax = [int](($pt.X - $vx) * 65535 / ($vw - 1)); $ay = [int](($pt.Y - $vy) * 65535 / ($vh - 1))
        $inputs = New-Object LiveWin+INPUT[] 3
        $inputs[0].type = 0; $inputs[0].mi.dx = $ax; $inputs[0].mi.dy = $ay; $inputs[0].mi.dwFlags = 0x0001 -bor 0x8000 -bor 0x4000   # MOVE | ABSOLUTE | VIRTUALDESK
        $inputs[1].type = 0; $inputs[1].mi.dwFlags = 0x0002   # LEFTDOWN
        $inputs[2].type = 0; $inputs[2].mi.dwFlags = 0x0004   # LEFTUP
        $sent = [LiveWin]::SendInput(3, $inputs, [Runtime.InteropServices.Marshal]::SizeOf([type][LiveWin+INPUT]))
        if ($sent -ne 3) { throw "SendInput sent $sent of 3 events (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))" }
        Start-Sleep -Milliseconds 150
        [void][LiveWin]::SetCursorPos($before.X, $before.Y)
        "real click at client $X,$Y (screen $($pt.X),$($pt.Y)); cursor restored"
    }
    "key" {
        $h = (Get-GameWindow).MainWindowHandle
        [void][LiveWin]::PostMessage($h, 0x0100, [IntPtr]$Vk, [IntPtr](1 -bor ($Scan -shl 16)))
        Start-Sleep -Milliseconds 80
        [void][LiveWin]::PostMessage($h, 0x0101, [IntPtr]$Vk, [IntPtr]([int64](1 -bor ($Scan -shl 16) -bor (3 -shl 30))))
        "posted key vk=$Vk scan=$Scan"
    }
    "blur" {
        # Minimizing deactivates the window, which is what alt-tab does to a game.
        $h = (Get-GameWindow).MainWindowHandle
        [void][LiveWin]::ShowWindow($h, 6)   # SW_MINIMIZE
        Start-Sleep -Milliseconds 1500
        $lost = [LiveWin]::GetForegroundWindow() -ne $h
        [void][LiveWin]::ShowWindow($h, 9)   # SW_RESTORE
        Start-Sleep -Milliseconds 800
        "focus left the game=$lost; restored"
    }
    "focus" { "foreground=$(Bring-Forward (Get-GameWindow).MainWindowHandle)" }
    "close" {
        $p = Get-GameWindow
        [void][LiveWin]::PostMessage($p.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        if (-not $p.WaitForExit(5000)) { throw "game did not exit within 5 s" }
        "exited in $($sw.ElapsedMilliseconds) ms"
    }
    "info" {
        $h = (Get-GameWindow).MainWindowHandle
        $w = New-Object LiveWin+RECT; [void][LiveWin]::GetWindowRect($h, [ref]$w)
        $c = New-Object LiveWin+RECT; [void][LiveWin]::GetClientRect($h, [ref]$c)
        "window $($w.L),$($w.T),$($w.R),$($w.B); client $($c.R)x$($c.B); foreground=$([LiveWin]::GetForegroundWindow() -eq $h)"
    }
}
