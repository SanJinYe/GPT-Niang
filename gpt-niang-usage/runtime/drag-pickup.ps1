$script:pickupFrames=$null
$script:pickupState=$null
$script:pickupTimer=$null
function Get-WidgetPickupFrames {
  if($script:pickupFrames){return $script:pickupFrames}
  $sheet=Read-WidgetCharacterImage (Join-Path $script:appDir 'assets/dock-poses/drag-pickup-sheet.png')
  if($sheet.PixelWidth%2-or $sheet.PixelHeight%2){throw '拖动动画帧尺寸无效。'}
  $width=[int]($sheet.PixelWidth/2);$height=[int]($sheet.PixelHeight/2)
  $script:pickupFrames=@(foreach($index in 0..3){
    $frame=[Windows.Media.Imaging.CroppedBitmap]::new($sheet,[Windows.Int32Rect]::new(($index%2)*$width,[int][Math]::Floor($index/2)*$height,$width,$height));$frame.Freeze()
    $alpha=[Windows.Media.Imaging.FormatConvertedBitmap]::new($frame,[Windows.Media.PixelFormats]::Bgra32,$null,0);$alpha.Freeze()
    $stride=$width*4;$pixels=New-Object byte[] ($stride*$height);$alpha.CopyPixels($pixels,$stride,0)
    @{bitmap=$frame;alpha=$alpha;stride=$stride;pixels=$pixels}
  })
  return $script:pickupFrames
}
function Set-WidgetPickupFrame($Frame) {
  $script:bitmap=$Frame.bitmap;$script:alphaBitmap=$Frame.alpha;$script:alphaStride=$Frame.stride;$script:alphaPixels=$Frame.pixels
  $script:ui.Girl.Source=$Frame.bitmap
  foreach($overlay in @($script:widgetColors.halo,$script:widgetColors.tint)){if($overlay){if($overlay.OpacityMask){$overlay.OpacityMask.ImageSource=$Frame.bitmap};if($script:pickupState){$overlay.Visibility='Collapsed'}}}
}
function Invoke-WidgetPickupTick {
  if(!$script:drag){Stop-WidgetPickup;return}
  # A queued tick may arrive after a live snap while mouse capture stays active.
  if(!$script:pickupState){if($script:pickupTimer){$script:pickupTimer.Stop()};return}
  $script:pickupFrameIndex=($script:pickupFrameIndex+1)%4
  Set-WidgetPickupFrame $script:pickupFrames[$script:pickupFrameIndex]
}
function Start-WidgetPickup {
  if($script:pickupState-or $script:characterId-ne 'gpt-dragon'){return $false}
  $frames=@(Get-WidgetPickupFrames)
  $girl=$script:ui.Girl
  $script:pickupState=@{bitmap=$script:bitmap;alpha=$script:alphaBitmap;stride=$script:alphaStride;pixels=$script:alphaPixels;width=$girl.Width;height=$girl.Height;left=[Windows.Controls.Canvas]::GetLeft($girl);top=[Windows.Controls.Canvas]::GetTop($girl);colors=@{}}
  foreach($name in @('halo','tint')){if($script:widgetColors-and $script:widgetColors[$name]){$script:pickupState.colors[$name]=$script:widgetColors[$name].Visibility}}
  Reset-WidgetDockAnimation
  $script:dockRevealMode='free'
  if($script:ui.PressScale){foreach($property in @([Windows.Media.ScaleTransform]::ScaleXProperty,[Windows.Media.ScaleTransform]::ScaleYProperty)){$script:ui.PressScale.BeginAnimation($property,$null);$script:ui.PressScale.SetValue($property,1.0)}}
  $script:pickupFrameIndex=0;Set-WidgetPickupFrame $frames[0]
  # Base eye separation: .259 of the square canvas; pickup cells: .167.
  # Keep the larger full-body sprite inside the existing 350 DIP canvas.
  $girl.Width=$script:pickupState.width*(.259/.167)*.9;$girl.Height=$script:pickupState.height*(.259/.167)*.9
  [Windows.Controls.Canvas]::SetLeft($girl,350-$girl.Width);[Windows.Controls.Canvas]::SetTop($girl,350-$girl.Height)
  if($script:window){$script:window.UpdateLayout()}
  if($script:widgetMusic-and $script:widgetMusic.Enabled){$script:widgetMusic.RefreshLayout()}
  if(!$script:pickupTimer){
    $script:pickupTimer=[Windows.Threading.DispatcherTimer]::new();$script:pickupTimer.Interval=[TimeSpan]::FromMilliseconds(125)
    $script:pickupTimer.Add_Tick({Invoke-WidgetPickupTick})
  }
  $script:pickupTimer.Start();return $true
}
function Stop-WidgetPickup([switch]$ForDock) {
  if($script:pickupTimer){$script:pickupTimer.Stop()}
  if(!$script:pickupState){return}
  $state=$script:pickupState;$script:pickupState=$null
  # The dock owns the next bitmap and layout. Do not flash the fallback bust.
  if($ForDock){$script:dockPose='pickup';return}
  $script:ui.Girl.Width=$state.width;$script:ui.Girl.Height=$state.height
  [Windows.Controls.Canvas]::SetLeft($script:ui.Girl,$state.left);[Windows.Controls.Canvas]::SetTop($script:ui.Girl,$state.top)
  Set-WidgetPickupFrame $state
  foreach($name in @('halo','tint')){if($script:widgetColors-and $script:widgetColors[$name]){$script:widgetColors[$name].Visibility=$state.colors[$name]}}
  if(Get-Command Sync-WidgetCharacterColors -ErrorAction SilentlyContinue){Sync-WidgetCharacterColors}
  if($script:widgetMusic-and $script:widgetMusic.Enabled){$script:widgetMusic.RefreshLayout()}
}
