$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appDir=Split-Path $PSScriptRoot -Parent
. (Join-Path $script:appDir 'runtime/characters.ps1')
. (Join-Path $script:appDir 'runtime/drag-pickup.ps1')
function Reset-WidgetDockAnimation {}
$script:ui=@{Girl=[Windows.Controls.Image]::new();PressScale=[Windows.Media.ScaleTransform]::new()}
$original=Read-WidgetCharacterImage (Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png')
$script:bitmap=$original;$script:alphaBitmap=$original;$script:alphaStride=99;$script:alphaPixels=@(1,2)
$script:ui.Girl.Source=$original;$script:characterId='other';$script:drag=@{moved=$true}
$script:ui.Girl.Width=208;$script:ui.Girl.Height=208
[Windows.Controls.Canvas]::SetLeft($script:ui.Girl,142);[Windows.Controls.Canvas]::SetTop($script:ui.Girl,142)
$script:widgetColors=@{halo=[Windows.Shapes.Rectangle]::new();tint=[Windows.Shapes.Rectangle]::new()}
foreach($layer in $script:widgetColors.Values){$layer.Visibility='Visible';$layer.OpacityMask=[Windows.Media.ImageBrush]::new($original)}
if(Start-WidgetPickup){throw 'Custom character must keep its own art'}
$script:characterId='gpt-dragon'
try{
 if(!(Start-WidgetPickup)){throw 'Pickup did not start'}
 if($script:pickupFrames.Count-ne 4){throw 'Expected four animation cells'}
 if([Math]::Abs($script:ui.Girl.Width*.167-208*.259*.9)-gt .01){throw 'Pickup size must be 90 percent of the face-calibrated size'}
 if([Windows.Controls.Canvas]::GetLeft($script:ui.Girl)-lt 0-or [Windows.Controls.Canvas]::GetTop($script:ui.Girl)-lt 0){throw 'Larger pickup sprite was clipped by the canvas'}
 foreach($layer in $script:widgetColors.Values){if($layer.Visibility-ne 'Collapsed'){throw 'Old silhouette layer remained visible'}}
 $first=$script:ui.Girl.Source
 $frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(160);$timer.Add_Tick({$timer.Stop();$frame.Continue=$false});$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
 if($script:ui.Girl.Source-eq $first){throw 'Limbs did not advance to next frame'}
 if(Start-WidgetPickup){throw 'Repeated move reset the frame cycle'}
 Stop-WidgetPickup
 Invoke-WidgetPickupTick
 if($script:ui.Girl.Source-ne $original-or $script:alphaStride-ne 99-or $script:pickupTimer.IsEnabled){throw 'Release did not restore original art and hit testing'}
 if($script:ui.Girl.Width-ne 208-or [Windows.Controls.Canvas]::GetLeft($script:ui.Girl)-ne 142){throw 'Release did not restore original dimensions'}
 foreach($layer in $script:widgetColors.Values){if($layer.Visibility-ne 'Visible'-or $layer.OpacityMask.ImageSource-ne $original){throw 'Release did not restore layer state'}}
 $null=Start-WidgetPickup;$script:drag=$null
 $timer.Start();$frame=[Windows.Threading.DispatcherFrame]::new();[Windows.Threading.Dispatcher]::PushFrame($frame)
 if($script:pickupState-or $script:pickupTimer.IsEnabled){throw 'Lost drag left sprite animation running'}
 'PASS: four frame pickup, independent custom art, stable cycling, release and lost-drag restore'
}finally{Stop-WidgetPickup}
