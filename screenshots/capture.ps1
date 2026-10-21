$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSCommandPath
$sig = Join-Path $base 'signals'
New-Item -ItemType Directory -Force -Path $sig | Out-Null
Get-ChildItem $sig -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Capture {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[Win32Capture]::SetProcessDPIAware() | Out-Null

$sessionScript = Join-Path $base 'capture_session.ps1'
$proc = Start-Process powershell.exe -ArgumentList '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$sessionScript`"" -WindowStyle Maximized -PassThru

$handle = [IntPtr]::Zero
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 250
    $proc.Refresh()
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero -and $proc.MainWindowTitle -like 'Ass8*') { $handle = $proc.MainWindowHandle; break }
}
if ($handle -eq [IntPtr]::Zero) { throw 'Could not find the terminal window.' }

[Win32Capture]::ShowWindow($handle, 3) | Out-Null
[Win32Capture]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Seconds 5

$steps = @(
    '01-nodes',
    '02-pods',
    '03-getall',
    '04-scale',
    '05-rollout'
)

foreach ($name in $steps) {
    $ready = Join-Path $sig "$name.ready"
    $deadline = (Get-Date).AddSeconds(300)
    while (-not (Test-Path $ready)) {
        if ((Get-Date) -gt $deadline) { throw "Timed out waiting for step $name" }
        if ($proc.HasExited) { throw "Session exited before step $name" }
        Start-Sleep -Milliseconds 250
    }
    Start-Sleep -Milliseconds 1000

    [Win32Capture]::ShowWindow($handle, 3) | Out-Null
    [Win32Capture]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 800

    $rect = New-Object Win32Capture+RECT
    [Win32Capture]::GetWindowRect($handle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
    $out = Join-Path $base "$name.png"
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()

    New-Item -ItemType File -Force (Join-Path $sig "$name.go") | Out-Null
    Write-Output "Captured: $out ($width x $height)"
}

$proc.WaitForExit(30000) | Out-Null
Write-Output 'Done.'
