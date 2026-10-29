$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/characters.ps1'),[Text.Encoding]::UTF8)))
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/dock-poses.ps1'),[Text.Encoding]::UTF8)))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Set-Facing','Animate-Press','Get-WidgetLayoutScale','Set-WidgetIndependentLayout','Set-WidgetPixelSize')){
 $def=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst]-and $n.Name-eq $name},$true)
 . ([ScriptBlock]::Create($def.Extent.Text))
}
function Test-WidgetMusicActive {return $false}
function Sync-WidgetCharacterColors {}
function Get-WidgetPlacementDpi {return 1.0}
$script:designWidth=378
$script:scale=$script:bubbleScale=$script:displayScale=1.0
function Pump([int]$Ms){
 $frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new()
 $timer.Interval=[TimeSpan]::FromMilliseconds($Ms);$handler={param($s,$e)$s.Stop();$frame.Continue=$false}.GetNewClosure()
 $timer.Add_Tick($handler);$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame);$timer.Remove_Tick($handler)
}
$script:clickCalls=@()
function Animate-Value($Target,$Property,[double]$To,[int]$Duration,[int]$Delay=0,[bool]$Rebound=$false){
 $script:clickCalls+=@{target=$Target;to=$To;duration=$Duration;rebound=$Rebound}
 $animation=[Windows.Media.Animation.DoubleAnimation]::new([double]$Target.GetValue($Property),$To,[Windows.Duration]::new([TimeSpan]::FromMilliseconds($Duration)))
 $Target.BeginAnimation($Property,$animation)
}
$text=[IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8)
$script:window=[Windows.Markup.XamlReader]::Parse($text);$script:ui=@{};$xml=[xml]$text
foreach($n in $xml.SelectNodes('//*[@*[local-name()="Name"]]')){$name=$n.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$script:ui[$name]=$script:window.FindName($name)}
$script:window.ShowActivated=$false;$script:window.Left=-5000;$script:window.Top=-5000
$image=Read-WidgetCharacterImage (Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png')
$script:dockBaseState=@{bitmap=$image;alpha=$image;stride=$image.PixelWidth*4;pixels=$null};$script:bitmap=$image
try{
 $script:window.Show();$script:widgetHandle=[Windows.Interop.WindowInteropHelper]::new($script:window).Handle
 foreach($pose in @('side-left','side-right','bottom-left','bottom-right','top-left','top-right','top')){
  $script:side=if($pose-like '*left'){'left'}else{'right'}
  Set-WidgetDockPose $pose;Reset-WidgetDockAnimation;Set-WidgetDockAnimationAnchor
  $anchor=[Windows.Point]::new($script:ui.DockClickScale.CenterX,$script:ui.DockClickScale.CenterY)
  $script:clickCalls=@();Animate-Press $true;Pump 260
  if($script:clickCalls.Count-ne 2 -or $script:clickCalls[0].to-ne 1.05 -or $script:clickCalls[1].to-ne .88 -or $script:clickCalls[0].duration-ne 220 -or !$script:clickCalls[0].rebound){throw 'Dock click differs from original stretch effect'}
  $mapped=$script:ui.PoseLayer.RenderTransform.Transform($anchor)
  if([Math]::Abs($mapped.X-$anchor.X)-gt .001 -or [Math]::Abs($mapped.Y-$anchor.Y)-gt .001){throw 'Click moved the frame anchor'}
  if($script:ui.DockClickScale.ScaleX-lt 1.04 -or $script:ui.DockClickScale.ScaleY-gt .89){throw 'Click scale was not rendered'}
  Animate-Press $false;Pump 260
  if([Math]::Abs($script:ui.DockClickScale.ScaleX-1)-gt .001 -or [Math]::Abs($script:ui.DockClickScale.ScaleY-1)-gt .001){throw 'Release did not restore scale'}
 }
 foreach($pose in @('bottom-left','bottom-right','top-left','top-right')){
  Set-WidgetDockPose 'free';$script:side=if($pose-like '*-left'){'left'}else{'right'};Set-WidgetDockPose $pose
  $revision=$script:dockRevealRevision;Start-WidgetCornerReveal;Pump 60
  if(($pose-like 'bottom-*' -and $script:ui.DockRevealMove.Y-le 0)-or ($pose-like 'top-*' -and $script:ui.DockRevealMove.Y-ge 0)){throw 'Corner entry has wrong vertical direction'}
  $screenX=$script:ui.DockRevealMove.X*$script:ui.FacingScale.ScaleX
  if(($pose-like '*-left' -and $screenX-ge 0)-or ($pose-like '*-right' -and $screenX-le 0)){throw 'Corner entry came from wrong side'}
  Start-WidgetCornerReveal
  if($script:dockRevealRevision-ne $revision+1){throw 'Unchanged dock replayed entry animation'}
  Pump 420
  if([Math]::Abs($script:ui.DockRevealMove.Y)-gt .001 -or [Math]::Abs($script:ui.DockRevealMove.X)-gt .001 -or [Math]::Abs($script:ui.DockRevealScale.ScaleX-1)-gt .001){throw 'Entry did not settle exactly at dock'}
 }
 foreach($spec in @(@{mode='left';pose='side-right';axis='X';sign=-1},@{mode='right';pose='side-left';axis='X';sign=1},@{mode='top';pose='top';axis='Y';sign=-1},@{mode='bottom';pose='free';axis='Y';sign=1})){
  Set-WidgetDockPose 'free';$script:dockMode=$spec.mode;$script:dockInward=$true;$script:side='right';Set-WidgetDockPose $spec.pose
  $script:dockRevealPending=$true;Start-WidgetCornerReveal;Pump 60
  $start=$script:ui.DockRevealMove.($spec.axis)
  if($start*$spec.sign-le 0){throw ('Wrong edge entry direction: '+$spec.mode)}
  Pump 190
  if($script:ui.DockRevealMove.($spec.axis)*$spec.sign-ge 0){throw ('Edge did not overshoot before rebound: '+$spec.mode)}
  Pump 180
  if([Math]::Abs($script:ui.DockRevealMove.($spec.axis))-gt .001){throw ('Edge failed to settle: '+$spec.mode)}
 }
 Set-WidgetDockPose 'free';Set-WidgetDockPose 'bottom-left';Start-WidgetCornerReveal;Pump 40;Set-WidgetDockPose 'free'
 if($script:ui.DockRevealMove.Y-ne 0 -or $script:ui.DockClickScale.ScaleX-ne 1){throw 'Leaving dock retained animation offsets'}
 $undock=$ast.Find({param($n)$n-is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith("if(`$script:dockPosesEnabled -and `$script:dockPose-ne 'free')")},$true)
 $script:hostFollower=[pscustomobject]@{AllowOutsideHost=$true}
 foreach($pose in @('side-left','side-right','bottom-left','bottom-right','top-left','top-right','top')){
  Set-WidgetDockPose $pose;Reset-WidgetDockAnimation;$script:window.UpdateLayout()
  $before=$script:ui.Girl.PointToScreen([Windows.Point]::new($script:ui.Girl.ActualWidth/2,$script:ui.Girl.ActualHeight/2))
  $script:drag=@{left=0.0;top=0.0}
  & ([ScriptBlock]::Create($undock.Extent.Text))
  $after=$script:ui.Girl.PointToScreen([Windows.Point]::new($script:ui.Girl.ActualWidth/2,$script:ui.Girl.ActualHeight/2))
  if([Math]::Abs($after.X+$script:drag.left-$before.X)-gt .01 -or [Math]::Abs($after.Y+$script:drag.top-$before.Y)-gt .01){throw 'Size change moved the drag origin'}
 }
 $script:drag=$null
 Write-Output 'PASS: seven anchored click stretches, four corner entries, exact settling, one-shot trigger and interruption cleanup'
}finally{$script:window.Close()}
