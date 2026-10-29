$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appDir=Split-Path $PSScriptRoot -Parent
foreach($module in @('characters','dock-poses','drag-pickup')){. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir ('runtime/'+$module+'.ps1')),[Text.Encoding]::UTF8)))}
Add-Type @'
using System;
public static class GptWidgetNative {
 public struct Rect{public int Left,Top,Right,Bottom;}
 public static int X,Y;
 public static bool GetWindowRect(IntPtr h,out Rect r){r=new Rect{Left=X,Top=Y,Right=X+400,Bottom=Y+400};return true;}
}
'@
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:appDir 'widget.ps1'),[ref]$tokens,[ref]$errors)
$definition=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst]-and $n.Left.Extent.Text-eq '$pressUp'},$true)
$body=$definition.Right.Extent.Text.Trim();$release=[scriptblock]::Create($body.Substring(1,$body.Length-2))
function Get-WidgetPlacementFrame {return @{Left=0;Top=0;Right=3000;Bottom=2200}}
function Get-WidgetPlacementDpi {return $script:testDpi}
function Reset-WidgetDockAnimation {}
function Reset-WidgetAutoQuoteSchedule {}
function Animate-Press {}
function Play-WidgetReleaseSound {}
function Save-Settings {}
function Tick-Widget {}
function Set-WidgetMusicEnabled($Enabled) {}
function Stop-WidgetMusic([switch]$KeepPosition) {}
function Test-WidgetMusicActive {return $script:musicTest}
$sender=[pscustomobject]@{};$sender|Add-Member ScriptMethod ReleaseMouseCapture {}
$script:hostEventTimer=[pscustomobject]@{};$script:hostEventTimer|Add-Member ScriptMethod Start {}
$script:widgetMusic=[pscustomobject]@{Enabled=$false};$script:widgetMusic|Add-Member ScriptMethod EndHold {}
$script:ui=@{Girl=[Windows.Controls.Image]::new();FacingScale=[Windows.Media.ScaleTransform]::new()}
$script:ui.Girl.Width=208;$script:ui.Girl.Height=208
[Windows.Controls.Canvas]::SetLeft($script:ui.Girl,142);[Windows.Controls.Canvas]::SetTop($script:ui.Girl,142)
$script:bitmap=Read-WidgetCharacterImage (Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png');$script:alphaBitmap=$script:bitmap;$script:ui.Girl.Source=$script:bitmap
$script:characterId='gpt-dragon';$script:widgetHandle=[IntPtr]::Zero;$script:dockPosesEnabled=$true;$count=0
try{
 foreach($script:musicTest in @($false,$true)){foreach($script:testDpi in @(1,1.5,2)){foreach($script:displayScale in @(.6,1,1.4)){
  foreach($mode in @('top','bottom','left','right','top-left','top-right','bottom-left','bottom-right','free')){
   $script:drag=@{moved=$true;music=$script:musicTest};$null=Start-WidgetPickup;$m=Get-WidgetDockMetrics $script:testDpi
   $x=1500-($m.Left+$m.Width/2);$y=1100-($m.Top+$m.Height/2)
   if($mode-eq 'left'-or $mode-like '*-left'){$x=-$m.Left};if($mode-eq 'right'-or $mode-like '*-right'){$x=3000-$m.Right}
   if($mode-eq 'top'-or $mode-like 'top-*'){$y=-$m.Top};if($mode-eq 'bottom'-or $mode-like 'bottom-*'){$y=2200-$m.Bottom}
   [GptWidgetNative]::X=[int][Math]::Round($x);[GptWidgetNative]::Y=[int][Math]::Round($y)
   & $release $sender ([pscustomobject]@{Handled=$false})
   if($script:dockMode-ne $mode){throw "Pickup release expected $mode, got $($script:dockMode)"}
   if($script:pickupState-or $script:ui.Girl.Width-ne 208){throw 'Original sprite was not restored'}
   $count++
  }
 }}}
 "PASS: $count enlarged pickup releases across edges, corners, scale/DPI and music modes"
}finally{Stop-WidgetPickup}
