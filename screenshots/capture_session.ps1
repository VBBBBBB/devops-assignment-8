$ErrorActionPreference = 'Continue'
$base = Split-Path -Parent $PSCommandPath
$sig = Join-Path $base 'signals'
New-Item -ItemType Directory -Force -Path $sig | Out-Null
Get-ChildItem $sig -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'Gray'
Clear-Host
$Host.UI.RawUI.WindowTitle = 'Ass8 Kubernetes Lab - devops-cluster'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CONSOLE_FONT_INFO_EX {
    public uint cbSize;
    public uint nFont;
    public short dwFontSizeX;
    public short dwFontSizeY;
    public int FontFamily;
    public int FontWeight;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string FaceName;
}
public class ConsoleFont {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);
    public static void Set(string face, short size) {
        CONSOLE_FONT_INFO_EX f = new CONSOLE_FONT_INFO_EX();
        f.cbSize = (uint)Marshal.SizeOf(f);
        f.FaceName = face;
        f.dwFontSizeX = 0;
        f.dwFontSizeY = size;
        f.FontFamily = 54;
        f.FontWeight = 400;
        SetCurrentConsoleFontEx(GetStdHandle(-11), false, ref f);
    }
}
"@
[ConsoleFont]::Set('Consolas', 20)

Set-Location 'C:\Users\bhamr\anti\Devops\Assignment\Ass8'

$tmpKube = Join-Path $env:TEMP 'ass8-kubeconfig'
Copy-Item "$HOME\.kube\config" $tmpKube -Force
kubectl config use-context kind-devops-cluster --kubeconfig $tmpKube | Out-Null
$env:KUBECONFIG = $tmpKube

function Show-Header {
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host ' Assignment 8 - Kubernetes Objects, Deployments & Services' -ForegroundColor Cyan
    Write-Host ' Cluster: kind-devops-cluster' -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
}

function Show-Cmd([string]$text) {
    Write-Host ''
    Write-Host 'PS Ass8> ' -NoNewline -ForegroundColor DarkCyan
    Write-Host $text -ForegroundColor White
}

function Wait-Go([string]$name) {
    New-Item -ItemType File -Force (Join-Path $sig "$name.ready") | Out-Null
    while (-not (Test-Path (Join-Path $sig "$name.go"))) { Start-Sleep -Milliseconds 150 }
    Remove-Item (Join-Path $sig "$name.ready") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $sig "$name.go") -Force -ErrorAction SilentlyContinue
}

kubectl delete -k k8s/ --ignore-not-found=true 2>$null | Out-Null
while (kubectl get ns devops-demo 2>$null) { Start-Sleep -Seconds 1 }

Clear-Host
Show-Header
Show-Cmd 'kubectl get nodes'
kubectl get nodes
Wait-Go '01-nodes'

Clear-Host
Show-Header
Show-Cmd 'kubectl apply -k k8s/'
kubectl apply -k k8s/
kubectl rollout status deployment/nginx -n devops-demo --timeout=300s | Out-Null
Start-Sleep -Seconds 3

Clear-Host
Show-Header
Show-Cmd 'kubectl get pods -n devops-demo'
kubectl get pods -n devops-demo
Wait-Go '02-pods'

Clear-Host
Show-Header
Show-Cmd 'kubectl get all,configmap -n devops-demo'
kubectl get all,configmap -n devops-demo
Wait-Go '03-getall'

Clear-Host
Show-Header
Show-Cmd 'kubectl scale deployment nginx --replicas=3 -n devops-demo'
kubectl scale deployment nginx --replicas=3 -n devops-demo
kubectl rollout status deployment/nginx -n devops-demo --timeout=240s | Out-Null
Start-Sleep -Seconds 3
Show-Cmd 'kubectl get pods -n devops-demo'
kubectl get pods -n devops-demo
Wait-Go '04-scale'

Clear-Host
Show-Header
Show-Cmd 'kubectl set image deployment/nginx nginx=nginx:1.26 -n devops-demo'
kubectl set image deployment/nginx nginx=nginx:1.26 -n devops-demo
kubectl rollout status deployment/nginx -n devops-demo --timeout=300s
Show-Cmd 'kubectl rollout history deployment/nginx -n devops-demo'
kubectl rollout history deployment/nginx -n devops-demo
Wait-Go '05-rollout'

Write-Host ''
Write-Host 'All steps completed. You may close this window.' -ForegroundColor Green
Start-Sleep -Seconds 20
