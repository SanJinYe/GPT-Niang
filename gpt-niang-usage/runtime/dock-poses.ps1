$script:dockPosesEnabled=$true
$script:dockMode='auto'
$script:dockPose='free'
$script:dockBottom=0.0
$script:dockLeft=175.0
$script:dockBaseState=$null
$script:dockImages=@{}
$script:dockInward=$false
$script:dockRevealPending=$false
$script:dockRevealRevision=0
$script:dockRevealMode='free'

function Get-WidgetPoseScale([string]$Pose) {
  # Optical size: match face/eye spacing, not the different PNG canvas crops.
  switch($Pose){
    'side-left' {return 1.20}
    'side-right' {return 1.20}
    'bottom-left' {return .259/.418}
    'bottom-right' {return .259/.365}
    'top-left' {return .259/.306}
    'top-right' {return .259/.298}
    'top' {return 1.35}
    default {return 1.0}
  }
}
function Test-WidgetCornerPose([string]$Pose){return $Pose-in @('bottom-left','bottom-right','top-left','top-right')}
function Set-WidgetDockCanvas([string]$Pose){
  $script:designHeight=if($Pose-like 'top*'){580.0}else{378.0}
  $script:window.FindName('AnimationStage').Height=$script:designHeight
  if($script:widgetHandle -and $script:widgetHandle-ne [IntPtr]::Zero){$null=Set-WidgetPixelSize (Get-WidgetPlacementDpi)}
}

function Reset-WidgetDockAnimation {
  if(!$script:ui.DockClickScale){return}
  foreach($scale in @($script:ui.DockClickScale,$script:ui.DockRevealScale)){
    $scale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty,$null)
    $scale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty,$null)
    $scale.ScaleX=1;$scale.ScaleY=1
  }
  $move=$script:ui.DockRevealMove
  $move.BeginAnimation([Windows.Media.TranslateTransform]::XProperty,$null)
  $move.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null)
  $move.X=0;$move.Y=0;$script:dockRevealPending=$false
}
function Set-WidgetDockAnimationAnchor {
  if(!$script:ui.DockClickScale){return}
  $girl=$script:ui.Girl
  $fit=[Math]::Min($girl.Width/$script:bitmap.PixelWidth,$girl.Height/$script:bitmap.PixelHeight)
  $w=$script:bitmap.PixelWidth*$fit;$h=$script:bitmap.PixelHeight*$fit
  $ax=switch($script:dockPose){'bottom-left'{0};'top-left'{0};'bottom-right'{1};'top-right'{1};'side-left'{.906};'side-right'{.094};default{.5}}
  $ay=if($script:dockPose-like 'top*'){0.0}elseif($script:dockPose-like 'bottom-*'-or $script:dockMode-eq 'bottom'){1.0}else{.74}
  $x=($girl.Width-$w)/2+$w*$ax
  if($script:ui.FacingScale.ScaleX-lt 0){$x=$girl.Width-$x}
  $x+=[Windows.Controls.Canvas]::GetLeft($girl)
  $y=[Windows.Controls.Canvas]::GetTop($girl)+($girl.Height-$h)/2+$h*$ay
  foreach($scale in @($script:ui.DockClickScale,$script:ui.DockRevealScale)){$scale.CenterX=$x;$scale.CenterY=$y}
}
function Start-WidgetCornerReveal {
  if(!$script:dockRevealPending -or !$script:ui.DockRevealScale){return}
  $script:dockRevealPending=$false
  Set-WidgetDockAnimationAnchor
  $script:dockRevealRevision++
  $direction=if($script:dockPose-like '*-left'){-1.0}else{1.0}
  $dx=$direction*$script:ui.FacingScale.ScaleX*$script:ui.Girl.Width*.55
  $dy=$script:ui.Girl.Height*.9
  if($script:dockPose-like 'top-*'){$dy=-$dy}
  if(!(Test-WidgetCornerPose $script:dockPose)){
    $dx=0.0;$dy=0.0
    if($script:dockMode-eq 'top'-or $script:dockPose-eq 'top'){$dy=-$script:ui.Girl.Height*.65}
    elseif($script:dockMode-eq 'bottom'){$dy=$script:ui.Girl.Height*.65}
    else{
      $left=$script:dockMode-eq 'left';$sign=if($left){-1.0}else{1.0};if(!$script:dockInward){$sign=-$sign}
      $dx=$sign*$script:ui.FacingScale.ScaleX*$script:ui.Girl.Width*.55
    }
  }
  foreach($track in @(
    @{target=$script:ui.DockRevealMove;property=[Windows.Media.TranslateTransform]::XProperty;start=$dx;over=-$dx*.10;end=0},
    @{target=$script:ui.DockRevealMove;property=[Windows.Media.TranslateTransform]::YProperty;start=$dy;over=-$dy*.10;end=0},
    @{target=$script:ui.DockRevealScale;property=[Windows.Media.ScaleTransform]::ScaleXProperty;start=.88;over=1.035;end=1},
    @{target=$script:ui.DockRevealScale;property=[Windows.Media.ScaleTransform]::ScaleYProperty;start=.88;over=1.035;end=1}
  )){
    $animation=[Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
    $animation.Duration=[Windows.Duration]::new([TimeSpan]::FromMilliseconds(380))
    $animation.FillBehavior=[Windows.Media.Animation.FillBehavior]::Stop
    $first=[Windows.Media.Animation.DiscreteDoubleKeyFrame]::new([double]$track.start,[Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::Zero))
    $ease=[Windows.Media.Animation.CubicEase]::new();$ease.EasingMode='EaseOut'
    $over=[Windows.Media.Animation.EasingDoubleKeyFrame]::new([double]$track.over,[Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds(240)),$ease)
    $settle=[Windows.Media.Animation.EasingDoubleKeyFrame]::new([double]$track.end,[Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds(380)),$ease)
    $animation.KeyFrames.Add($first)|Out-Null;$animation.KeyFrames.Add($over)|Out-Null;$animation.KeyFrames.Add($settle)|Out-Null
    $track.target.BeginAnimation($track.property,$animation,[Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
  }
}

function Resolve-WidgetDockMode($Frame,$Bounds,[double]$Dpi=1,[double]$ThresholdDip=24) {
  $threshold=$ThresholdDip*$Dpi
  $left=[Math]::Abs($Bounds.Left-$Frame.Left)-le $threshold
  $right=[Math]::Abs($Bounds.Right-$Frame.Right)-le $threshold
  $bottom=[Math]::Abs($Bounds.Bottom-$Frame.Bottom)-le $threshold
  $top=$null-ne $Bounds.Top -and [Math]::Abs($Bounds.Top-$Frame.Top)-le $threshold
  if($top -and $bottom){$top=[Math]::Abs($Bounds.Top-$Frame.Top)-lt [Math]::Abs($Bounds.Bottom-$Frame.Bottom);$bottom=!$top}
  if($left -and $right){$left=($Bounds.Left+$Bounds.Right)/2-lt ($Frame.Left+$Frame.Right)/2;$right=!$left}
  if($left){if($top){return 'top-left'};if($bottom){return 'bottom-left'};return 'left'}
  if($right){if($top){return 'top-right'};if($bottom){return 'bottom-right'};return 'right'}
  if($top){return 'top'}
  if($bottom){return 'bottom'}
  return 'free'
}
function Get-WidgetDockImage([string]$Pose) {
  if($Pose-eq 'free'){return $script:dockBaseState}
  if(!$script:dockImages.ContainsKey($Pose)){
    $file=Join-Path $script:appDir ('assets/dock-poses/'+$Pose+'.png')
    $image=Read-WidgetCharacterImage $file
    $alpha=[Windows.Media.Imaging.FormatConvertedBitmap]::new($image,[Windows.Media.PixelFormats]::Bgra32,$null,0)
    $alpha.Freeze();$stride=$image.PixelWidth*4;$pixels=New-Object byte[] ($stride*$image.PixelHeight)
    $alpha.CopyPixels($pixels,$stride,0)
    $script:dockImages[$Pose]=@{bitmap=$image;alpha=$alpha;stride=$stride;pixels=$pixels}
  }
  return $script:dockImages[$Pose]
}
function Set-WidgetDockPose([string]$Pose) {
  if($Pose-eq $script:dockPose){return}
  $state=Get-WidgetDockImage $Pose
  if(!$state){return}
  Reset-WidgetDockAnimation
  $script:bitmap=$state.bitmap;$script:alphaBitmap=$state.alpha;$script:alphaStride=$state.stride;$script:alphaPixels=$state.pixels
  $script:ui.Girl.Source=$state.bitmap;$script:dockPose=$Pose
  Set-WidgetDockCanvas $Pose
  Set-WidgetIndependentLayout
  if($Pose-ne 'free'){
    $script:ui.PressScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty,$null)
    $script:ui.PressScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty,$null)
    $script:ui.PressScale.ScaleX=1;$script:ui.PressScale.ScaleY=1
  }
  if($script:widgetColors){foreach($overlay in @($script:widgetColors.halo,$script:widgetColors.tint)){if($overlay -and $overlay.OpacityMask){$overlay.OpacityMask.ImageSource=$state.bitmap}}}
  Set-Facing
  if((Test-WidgetMusicActive) -and $script:widgetMusic.Pinned){$script:widgetMusic.RefreshLayout()}
  $script:window.UpdateLayout();$script:lastPosition=$null
  $script:dockRevealPending=$Pose-ne 'free'
}
function Get-WidgetDockMetrics([double]$Dpi) {
  # Resting coordinates deliberately exclude the transient press animation.
  $girl=$script:ui.Girl;$unit=$script:displayScale*$Dpi
  $left=[Windows.Controls.Canvas]::GetLeft($girl);$top=[Windows.Controls.Canvas]::GetTop($girl)
  if($script:ui.FacingScale.ScaleX-lt 0){$left=350-$left-$girl.Width}
  $fit=[Math]::Min($girl.Width/$script:bitmap.PixelWidth,$girl.Height/$script:bitmap.PixelHeight)
  $width=$script:bitmap.PixelWidth*$fit;$height=$script:bitmap.PixelHeight*$fit
  $x=(14+$left+($girl.Width-$width)/2)*$unit
  $y=(14+$top+($girl.Height-$height)/2)*$unit
  return @{Left=$x;Top=$y;Right=$x+$width*$unit;Bottom=$y+$height*$unit;Width=$width*$unit;Height=$height*$unit}
}
function Get-WidgetDockScreenBounds {
  $dpi=Get-WidgetPlacementDpi
  $r=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$r)|Out-Null
  $m=Get-WidgetDockMetrics $dpi
  return @{Left=$r.Left+$m.Left;Right=$r.Left+$m.Right;Top=$r.Top+$m.Top;Bottom=$r.Top+$m.Bottom}
}
function Complete-WidgetDockDrag([switch]$VisibleBounds,[hashtable]$ReleaseBounds) {
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  $bounds=if($ReleaseBounds){$ReleaseBounds.Clone()}else{Get-WidgetDockScreenBounds}
  if($VisibleBounds){$bounds.Left=[Math]::Max($Frame.Left,$bounds.Left);$bounds.Right=[Math]::Min($Frame.Right,$bounds.Right);$bounds.Top=[Math]::Max($Frame.Top,$bounds.Top);$bounds.Bottom=[Math]::Min($Frame.Bottom,$bounds.Bottom)}
  $script:dockMode=Resolve-WidgetDockMode $frame $bounds $dpi
  $script:dockBottom=($frame.Bottom-($bounds.Top+$bounds.Bottom)/2)/$dpi
  $script:dockLeft=(($bounds.Left+$bounds.Right)/2-$frame.Left)/$dpi
  $script:lastPosition=$null
}
function Get-WidgetDockPlacement($Frame,[double]$Dpi,[double]$X,[double]$Y,[double]$Width,[double]$Height) {
  if($script:characterId-ne 'gpt-dragon'){
    if($script:hostFollower){$script:hostFollower.AllowOutsideHost=$false;$script:hostFollower.AnchorTop=$false}
    return $null
  }
  if($script:dockMode-eq 'auto'){
    $m=Get-WidgetDockMetrics $Dpi
    $bounds=@{Left=$X+$m.Left;Right=$X+$m.Right;Top=$Y+$m.Top;Bottom=$Y+$m.Bottom}
    $script:dockMode=Resolve-WidgetDockMode $Frame $bounds $Dpi
    $script:dockBottom=($Frame.Bottom-($bounds.Top+$bounds.Bottom)/2)/$Dpi
    $script:dockLeft=(($bounds.Left+$bounds.Right)/2-$Frame.Left)/$Dpi
  }
  if($script:dockMode-eq 'free'){
    $script:dockRevealMode='free'
    $script:dockInward=$false
    if($script:hostFollower){$script:hostFollower.AllowOutsideHost=$false;$script:hostFollower.AnchorTop=$false}
    if(!(Test-WidgetMusicActive)){Set-WidgetDockPose 'free'}
    return $null
  }
  $left=$script:dockMode-in @('left','bottom-left','top-left');$corner=Test-WidgetCornerPose $script:dockMode
  $top=$script:dockMode-like 'top*'
  if($script:dockMode-in @('top','bottom')){$left=$script:dockLeft*$Dpi-lt ($Frame.Right-$Frame.Left)/2}
  $script:side=if($left){'left'}else{'right'}
  $script:anchor=if($script:dockMode-in @('top','bottom')){'free'}else{$script:side}
  $work=[Windows.Forms.Screen]::FromHandle($(if($script:followHost){$script:hostHandle}else{$script:widgetHandle})).WorkingArea
  $script:dockInward=$false
  if($script:dockMode-eq 'bottom'){$pose='free'}
  elseif($corner -or $script:dockMode-eq 'top'){$pose=$script:dockMode}
  else{
    $pose=if($left){'side-left'}else{'side-right'}
    $image=Get-WidgetDockImage $pose
    $outsideWidth=208*$script:scale*$Dpi*(Get-WidgetPoseScale $pose)*$image.bitmap.PixelWidth/$image.bitmap.PixelHeight*.91
    $space=if($left){$Frame.Left-$work.Left}else{$work.Right-$Frame.Right}
    $script:dockInward=(!$script:followHost -or $space-lt $outsideWidth+8*$Dpi)
    if($script:dockInward){$pose=if($left){'side-right'}else{'side-left'}}
  }
  Set-WidgetDockPose $pose;Set-Facing
  $Height=$script:designHeight*$script:displayScale*$Dpi
  $m=Get-WidgetDockMetrics $Dpi
  if($script:dockMode-in @('top','bottom')){
    $X=$Frame.Left+$script:dockLeft*$Dpi-($m.Left+$m.Width/2)
    $X=[Math]::Max($Frame.Left-$m.Left,[Math]::Min($Frame.Right-$m.Right,$X))
    $Y=if($top){$Frame.Top-$m.Top}else{$Frame.Bottom-$m.Bottom};$ax=.5;$ay=if($top){0.0}else{1.0}
  }elseif($corner){
    $X=if($left){$Frame.Left-$m.Left}else{$Frame.Right-$m.Right}
    $Y=if($top){$Frame.Top-$m.Top}else{$Frame.Bottom-$m.Bottom}
    $ax=if($left){0.0}else{1.0};$ay=if($top){0.0}else{1.0}
  }else{
    $ax=if($pose-eq 'side-left'){.906}else{.094};$ay=.74
    $edge=if($left){$Frame.Left}else{$Frame.Right}
    $X=$edge-($m.Left+$m.Width*$ax)
    $Y=$Frame.Bottom-$script:dockBottom*$Dpi-($m.Top+$m.Height*$ay)
    $Y=[Math]::Max($Frame.Top-$m.Top,[Math]::Min($Frame.Bottom-$m.Bottom,$Y))
  }
  $X=[Math]::Round($X);$Y=[Math]::Round($Y)
  if($script:followHost){
    $script:offsetLeft=($X-$Frame.Left)/$Dpi;$script:offsetRight=($Frame.Right-$X-$Width)/$Dpi;$script:offsetBottom=($Frame.Bottom-$Y-$Height)/$Dpi
  }else{$script:desktopLeft=$X;$script:desktopTop=$Y}
  if($script:hostFollower){$script:hostFollower.AllowOutsideHost=(!$corner -and !$top -and $script:dockMode-ne 'bottom' -and $script:followHost);$script:hostFollower.AnchorTop=$top;$script:hostFollower.TopOffset=[int]($Y-$Frame.Top)}
  if(Test-WidgetMusicActive){$script:widgetMusic.SideDock=($pose-like 'side-*');$script:widgetMusic.TopDock=($pose-eq 'top');$script:widgetMusic.DockPose=$pose;$script:widgetMusic.SetDockAnchor($ax,$ay)}
  Set-WidgetDockAnimationAnchor
  if($script:dockRevealMode-ne $script:dockMode){$script:dockRevealPending=$true;$script:dockRevealMode=$script:dockMode}
  Start-WidgetCornerReveal
  return @{X=$X;Y=$Y;Width=$Width;Height=$Height}
}
