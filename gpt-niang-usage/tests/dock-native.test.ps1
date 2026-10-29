$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime/host-follow.ps1')
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class DockRegionProbe {
 [StructLayout(LayoutKind.Sequential)]public struct Rect{public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int height,uint flags);
 [DllImport("user32.dll")]public static extern int GetWindowRgn(IntPtr h,IntPtr r);
 [DllImport("gdi32.dll")]public static extern IntPtr CreateRectRgn(int l,int t,int r,int b);
 [DllImport("gdi32.dll")]public static extern int GetRgnBox(IntPtr h,out Rect r);
 [DllImport("gdi32.dll")]public static extern bool DeleteObject(IntPtr h);
}
'@
function New-TestWindow {
 $w=[Windows.Window]::new();$w.WindowStyle='None';$w.ShowActivated=$false;$w.ShowInTaskbar=$false;$w.AllowsTransparency=$true;$w.Background=[Windows.Media.Brushes]::Transparent;$w.Width=500;$w.Height=400;$w.Show();return $w
}
function Region($Handle){
 $region=[DockRegionProbe]::CreateRectRgn(0,0,0,0)
 try{if([DockRegionProbe]::GetWindowRgn($Handle,$region)-eq 0){throw 'Missing native window clipping region'};$r=[DockRegionProbe+Rect]::new();[DockRegionProbe]::GetRgnBox($region,[ref]$r)|Out-Null;return $r}finally{[DockRegionProbe]::DeleteObject($region)|Out-Null}
}
$hostWindow=$null;$widget=$null;$follower=$null
try{
 $hostWindow=New-TestWindow;$widget=New-TestWindow
 $hostHandle=[Windows.Interop.WindowInteropHelper]::new($hostWindow).Handle;$handle=[Windows.Interop.WindowInteropHelper]::new($widget).Handle
 $work=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
 [DockRegionProbe]::SetWindowPos($hostHandle,[IntPtr]::Zero,$work.Left+300,$work.Top+100,500,400,0x214)|Out-Null
 [DockRegionProbe]::SetWindowPos($handle,[IntPtr]::Zero,0,0,378,378,0x214)|Out-Null
 $r=[DockRegionProbe+Rect]::new();[DockRegionProbe]::GetWindowRect($hostHandle,[ref]$r)|Out-Null
 $follower=[GptWidgetHostFollower]::new($handle)
 $follower.Configure($hostHandle,$r.Left,$r.Top,$r.Right,$r.Bottom,378,378,-120,0,0,'left',$true)
 if((Region $handle).Left-ne 120){throw 'Normal host clipping changed'}
 $follower.AllowOutsideHost=$true;$null=$follower.Synchronize()
 if((Region $handle).Left-ne 0){throw 'Outward pose still clipped by host edge'}
 $follower.AllowOutsideHost=$false;$null=$follower.Synchronize()
 if((Region $handle).Left-ne 120){throw 'Leaving outward pose did not restore host clipping'}
 $follower.AnchorTop=$true;$follower.TopOffset=-14;$null=$follower.Synchronize()
 $beforeTop=[DockRegionProbe+Rect]::new();[DockRegionProbe]::GetWindowRect($handle,[ref]$beforeTop)|Out-Null
 [DockRegionProbe]::SetWindowPos($hostHandle,[IntPtr]::Zero,$r.Left,$r.Top,500,550,0x214)|Out-Null;$null=$follower.Synchronize()
 $afterTop=[DockRegionProbe+Rect]::new();[DockRegionProbe]::GetWindowRect($handle,[ref]$afterTop)|Out-Null
 if($afterTop.Top-ne $beforeTop.Top){throw 'Top dock moved when only host height changed'}
 Write-Output 'PASS: outward artwork is visible beyond host edge; normal host clipping restores'
}finally{if($follower){$follower.Dispose()};if($widget){$widget.Close()};if($hostWindow){$hostWindow.Close()}}
