$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing
$script:appDir=Split-Path $PSScriptRoot -Parent
foreach($module in @('characters','dock-poses','drag-pickup','live-docking')){. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir ('runtime/'+$module+'.ps1')),[Text.Encoding]::UTF8)))}
Add-Type @'
using System;
public static class GptWidgetNative {
 public struct Rect{public int Left,Top,Right,Bottom;}
 public static int X=300,Y=250;
 public static Action OnMove;
 public static bool GetWindowRect(IntPtr h,out Rect r){r=new Rect{Left=X,Top=Y,Right=X+378,Bottom=Y+378};return true;}
 public static bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint flags){X=x;Y=y;if(OnMove!=null)OnMove();return true;}
}
'@
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors.Message -join '; ')}
foreach($name in @('Set-Facing','Get-WidgetLayoutScale','Set-WidgetIndependentLayout','Test-WidgetPlacementFrame')){$def=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst]-and $n.Name-eq $name},$true);. ([scriptblock]::Create($def.Extent.Text))}
function Get-WidgetPlacementFrame {return @{Left=100;Top=100;Right=1100;Bottom=900}}
function Get-WidgetPlacementDpi {return $(if($script:testDpi){$script:testDpi}else{1.0})}
function Get-LiveDockClock {return $script:testClock}
function Set-WidgetPixelSize($Dpi) {}
function Sync-WidgetCharacterColors {}
function Test-WidgetMusicActive {return $script:musicTest}
function Stop-WidgetMusic([switch]$KeepPosition){$script:musicTest=$false}
function Set-WidgetMusicEnabled($Enabled){$script:musicTest=$Enabled}
function Hide-Quota {$script:collapsed=$true}
function Reset-WidgetAutoQuoteSchedule {}
function Save-Settings {}
function Tick-Widget {}
function Play-WidgetPressSound {if($script:simulateSlowPickup){$script:testClock+=400}}
function Play-WidgetReleaseSound {}
function Animate-Press([bool]$Down){$script:pressFeedback=$Down;$script:pressFeedbackCalls++}
function Stop-WidgetAudio {}
function Click-Character {$script:clicks++}
function Open-WidgetBubble($Mode){$script:collapsed=$false;$script:bubbleMode=$Mode}
$text=[IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8)
$script:window=[Windows.Markup.XamlReader]::Parse($text);$xml=[xml]$text;$script:ui=@{}
foreach($n in $xml.SelectNodes('//*[@*[local-name()="Name"]]')){$name=$n.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$script:ui[$name]=$script:window.FindName($name)}
$script:window.Left=-5000;$script:window.Top=-5000;$script:window.ShowActivated=$false;$script:window.Show()
$script:widgetHandle=[IntPtr]::Zero;$script:hostHandle=[IntPtr]::Zero;$script:characterId='gpt-dragon'
$script:scale=$script:bubbleScale=$script:displayScale=1.0;$script:designWidth=378;$script:designHeight=378;$script:followHost=$false
$script:side='right';$script:anchor='free';$script:offsetLeft=$script:offsetRight=$script:offsetBottom=0;$script:desktopLeft=300;$script:desktopTop=250
$script:hostFollower=[pscustomobject]@{AllowOutsideHost=$false;AnchorTop=$false;TopOffset=0};$script:hostFollower|Add-Member ScriptMethod Suspend {}
$script:hostEventTimer=[pscustomobject]@{};$script:hostEventTimer|Add-Member ScriptMethod Start {}
$sender=[pscustomobject]@{captured=$false};$sender|Add-Member ScriptMethod CaptureMouse {$this.captured=$true;return $true};$sender|Add-Member ScriptMethod ReleaseMouseCapture {$this.captured=$false}
$image=Read-WidgetCharacterImage (Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png');$script:dockBaseState=@{bitmap=$image;alpha=$image;stride=1;pixels=$null};$script:bitmap=$image;$script:ui.Girl.Source=$image
try{
 foreach($music in @($false,$true)){
  $script:testClock=1000.0
  $script:dockMode='top';Set-WidgetDockPose 'top';$script:musicTest=$music;$script:collapsed=$true
  Start-LiveDockDrag $sender ([pscustomobject]@{X=600;Y=450})
  if(!$script:pickupState-or !$sender.captured-or $script:musicTest){throw 'Mouse down must immediately lift and suspend rhythm'}
  $w=$script:drag.pickupWidth;$h=$script:drag.pickupHeight;$gx=$script:drag.grabX
  $xLeft=100+$w*$gx+10;$xRight=1100-$w*(1-$gx)-10;$yTop=100+$h*.16+10;$yBottom=900-$h*.84-10
  foreach($elapsed in @(0,100,499)){
   $script:testClock=1000+$elapsed;Update-LiveDockDrag ([pscustomobject]@{X=600;Y=$yTop})
   if(!$script:pickupState-or $script:drag.previewMode-ne 'free'){throw 'Docked during the 500 ms pickup grace period'}
  }
  $script:testClock=1500.0
  $pump=[Windows.Threading.DispatcherFrame]::new();$wake=[Windows.Threading.DispatcherTimer]::new();$wake.Interval=[TimeSpan]::FromMilliseconds(550)
  $wake.Add_Tick({$wake.Stop();$pump.Continue=$false});$wake.Start();[Windows.Threading.Dispatcher]::PushFrame($pump)
  if($script:drag.previewMode-ne 'top'){throw 'Grace expiry did not reevaluate the stationary pointer'}
  foreach($case in @(@('top',600,$yTop),@('left',$xLeft,500),@('right',$xRight,500),@('bottom',600,$yBottom),@('top-left',$xLeft,$yTop),@('top-right',$xRight,$yTop),@('bottom-left',$xLeft,$yBottom),@('bottom-right',$xRight,$yBottom))){
   Update-LiveDockDrag ([pscustomobject]@{X=$case[1];Y=$case[2]})
   if($script:drag.previewMode-ne $case[0]-or $script:pickupState-or !$sender.captured){throw "Live docking failed before release: $($case[0])"}
   $revision=$script:dockRevealRevision
   Update-LiveDockDrag ([pscustomobject]@{X=$case[1];Y=$case[2]})
   if($revision-ne $script:dockRevealRevision){throw 'Stationary preview replayed the animation'}
   Update-LiveDockDrag ([pscustomobject]@{X=600;Y=450})
   if(!$script:pickupState-or $script:drag.previewMode-ne 'free'){throw 'Leaving an edge did not resume pickup'}
  }
  Update-LiveDockDrag ([pscustomobject]@{X=600;Y=$yTop})
  Update-LiveDockDrag ([pscustomobject]@{X=600;Y=100+$h*.16+32})
  if($script:drag.previewMode-ne 'top'){throw 'Boundary hysteresis failed'}
  Complete-LiveDockDrag
  if($script:dockMode-ne 'top'-or $script:drag-or $sender.captured-or $script:musicTest-ne $music){throw 'Release failed to retain preview and resume rhythm'}
  Start-LiveDockDrag $sender ([pscustomobject]@{X=600;Y=450});Update-LiveDockDrag ([pscustomobject]@{X=630;Y=450});Complete-LiveDockDrag
  if($script:dockMode-ne 'free'-or $script:dockPose-ne 'free'-or $script:pickupState){throw 'No preview must restore default bottom art'}
  $script:dockMode='top';Set-WidgetDockPose 'top';$before=$script:clicks
  Start-LiveDockDrag $sender ([pscustomobject]@{X=600;Y=450});Complete-LiveDockDrag
  if($script:dockMode-ne 'top'-or $script:clicks-ne $before+1){throw 'Simple click must restore dock and preserve click action'}
  Start-LiveDockDrag $sender ([pscustomobject]@{X=600;Y=450});Complete-LiveDockDrag -Cancel
  if($script:drag-or $script:pickupState-or $sender.captured){throw 'Lost capture failed to clean up'}
 }
 $script:musicTest=$false;$script:testClock=2000.0;$script:simulateSlowPickup=$true
 $script:syntheticEvents=0;$script:probeCursor=[pscustomobject]@{X=600;Y=160}
 [GptWidgetNative]::OnMove=[Action]{$script:syntheticEvents++;if($script:syntheticEvents-lt 20){Update-LiveDockDrag $script:probeCursor}}
 Start-LiveDockDrag $sender ([pscustomobject]@{X=600;Y=450})
 if($script:drag.dockAllowedAt-ne 2900-or !$script:pickupState){throw 'Slow initialization consumed the visible pickup grace period'}
 $same=$script:drag;Start-LiveDockDrag $sender ([pscustomobject]@{X=600;Y=450})
 if(![Object]::ReferenceEquals($same,$script:drag)){throw 'Duplicate mouse down restarted drag'}
 $script:testClock=2899;Update-LiveDockDrag $script:probeCursor
 if($script:drag.previewMode-ne 'free'-or !$script:pickupState){throw 'Synthetic move bypassed grace'}
 $revision=$script:dockRevealRevision;$script:testClock=2900;Update-LiveDockDrag $script:probeCursor -Recheck
 if($script:drag.previewMode-ne 'top'-or $script:dockRevealRevision-ne $revision+1){throw 'Reentrant movement replayed the snap transition'}
 $events=$script:syntheticEvents
 foreach($i in 1..20){Update-LiveDockDrag $script:probeCursor}
 if($events-ne $script:syntheticEvents){throw 'Stationary physical pointer still moved the window repeatedly'}
 [GptWidgetNative]::OnMove=$null;Complete-LiveDockDrag -Cancel
 $script:simulateSlowPickup=$false;$script:musicTest=$true;$script:testClock=5000.0
 foreach($i in 1..4){
  $before=$script:clicks;$source=$script:ui.Girl.Source;$mode=$script:dockMode
  Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450});$candidate=$script:drag
  if(!$script:pressFeedback){throw 'Click candidate lost press squash feedback'}
  if($candidate.activateAt-ne $script:testClock+500-or $candidate.holdTimer.Interval.TotalMilliseconds-ne 500){throw 'Pickup hold delay must be 500 ms'}
  if(!$candidate.pendingClick-or $script:pickupState-or !$script:musicTest){throw 'Click candidate changed artwork or stopped music'}
  Update-WidgetPointerGesture ([pscustomobject]@{X=602;Y=451})
  $script:testClock+=80;Complete-WidgetPointerGesture ([pscustomobject]@{X=602;Y=451})
  if($script:clicks-ne $before+1-or $script:drag-or $script:ui.Girl.Source-ne $source-or $script:dockMode-ne $mode-or $candidate.holdTimer.IsEnabled){throw 'Short click failed exclusivity or cleanup'}
  if($script:pressFeedback){throw 'Release did not trigger rebound'}
 }
 foreach($script:testDpi in @(1.0,1.5,2.0)){
  foreach($preview in @($false,$true)){
   $before=$script:clicks
   Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450})
   if($preview){Activate-WidgetPointerDrag ([pscustomobject]@{X=600;Y=450}) -PreviewOnly}
   $jitter=[pscustomobject]@{X=600+18*$script:testDpi;Y=450+4*$script:testDpi}
   if($preview){Update-LiveDockDrag $jitter;Complete-LiveDockDrag -Cursor $jitter}
   else{Update-WidgetPointerGesture $jitter;Complete-WidgetPointerGesture $jitter}
   if($script:clicks-ne $before+1-or $script:drag){throw 'Touchpad press jitter lost its click'}
   Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450})
   if($preview){Activate-WidgetPointerDrag ([pscustomobject]@{X=600;Y=450}) -PreviewOnly}
   $travel=[pscustomobject]@{X=600+20*$script:testDpi;Y=450}
   if($preview){Update-LiveDockDrag $travel}else{Update-WidgetPointerGesture $travel}
   if(!$script:drag.liveDock-or !$script:drag.moved){throw 'Intentional drag acquired a timing delay'}
   Complete-LiveDockDrag
   if($script:clicks-ne $before+1){throw 'Intentional drag also clicked'}
  }
 }
 $script:testDpi=1.0
 $before=$script:clicks
 Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450})
 Update-WidgetPointerGesture ([pscustomobject]@{X=620;Y=450})
 if(!$script:drag.liveDock-or !$script:pickupState){throw 'Movement threshold failed to activate pickup'}
 if($script:pressFeedback){throw 'Pickup inherited click squash'}
 Complete-LiveDockDrag
 if($script:clicks-ne $before){throw 'Dragging also advanced the bubble'}
 Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450});$script:testClock+=500
 $pump=[Windows.Threading.DispatcherFrame]::new();$wake=[Windows.Threading.DispatcherTimer]::new();$wake.Interval=[TimeSpan]::FromMilliseconds(540);$wake.Add_Tick({$wake.Stop();$pump.Continue=$false});$wake.Start();[Windows.Threading.Dispatcher]::PushFrame($pump)
 if(!$script:pickupState-or $script:drag.gestureDrag){throw 'Long press should preview pickup without committing drag'}
 Complete-LiveDockDrag
 if($script:clicks-ne $before+1){throw 'Stationary long press lost its click'}
 $before=$script:clicks
 foreach($delay in @(0,199,200,350,499,500,800)){
  Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450})
  $script:testClock+=$delay
  Complete-WidgetPointerGesture ([pscustomobject]@{X=602;Y=451})
  $before++
  if($script:clicks-ne $before-or $script:drag){throw "Delayed release ($delay ms) lost or duplicated click"}
 }
 Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450})
 Activate-WidgetPointerDrag ([pscustomobject]@{X=600;Y=450}) -PreviewOnly
 Update-LiveDockDrag ([pscustomobject]@{X=603;Y=451})
 if($script:drag.moved){throw 'Hold preview committed drag on sub-threshold jitter'}
 Complete-LiveDockDrag -Cursor ([pscustomobject]@{X=620;Y=450})
 if($script:clicks-ne $before){throw 'Release-only movement incorrectly clicked'}
 Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450})
 Activate-WidgetPointerDrag ([pscustomobject]@{X=600;Y=450}) -PreviewOnly
 Complete-LiveDockDrag -Cancel
 if($script:clicks-ne $before-or $script:drag){throw 'Cancelled hold preview clicked'}
 Start-WidgetPointerGesture $sender ([pscustomobject]@{X=600;Y=450});$candidate=$script:drag;Complete-WidgetPointerGesture -Cancel
 if($script:clicks-ne $before-or $script:drag-or $candidate.holdTimer.IsEnabled){throw 'Cancelled click candidate leaked an action'}
 $script:musicTest=$false;$script:testClock=9000
 Start-LiveDockDrag $sender ([pscustomobject]@{X=600;Y=450})
 $nearTop=[pscustomobject]@{X=600;Y=100+$script:drag.pickupHeight*.16+10}
 $script:testClock=9100;Update-LiveDockDrag $nearTop
 if(!$script:pickupState-or $script:drag.previewMode-ne 'free'){throw 'Early hover must remain exempt'}
 $grace=$script:drag.dockGraceTimer
 $script:sourceChanges=[Collections.Generic.List[object]]::new()
 $descriptor=[ComponentModel.DependencyPropertyDescriptor]::FromProperty([Windows.Controls.Image]::SourceProperty,[Windows.Controls.Image])
 $handler=[EventHandler]{param($sender,$event)$script:sourceChanges.Add($script:ui.Girl.Source)}
 $descriptor.AddValueChanged($script:ui.Girl,$handler)
 try{Complete-LiveDockDrag -Cursor $nearTop}finally{$descriptor.RemoveValueChanged($script:ui.Girl,$handler)}
 if($script:dockMode-ne 'top'-or $grace.IsEnabled){throw 'Mouse-up failed to end grace and dock immediately'}
 if($script:sourceChanges.Count-ne 1-or $script:sourceChanges[0]-eq $script:dockBaseState.bitmap){throw 'Dock transition flashed an intermediate fallback frame'}
 Invoke-WidgetPickupTick
 if($script:ui.Girl.Source-ne (Get-WidgetDockImage 'top').bitmap){throw 'Late pickup frame overrode the replacement dock animation'}
 'PASS: click/drag exclusivity, min(500 ms, release), direct source replacement, no fallback flash and late-frame protection'
}finally{Stop-WidgetPickup;$script:window.Close()}
