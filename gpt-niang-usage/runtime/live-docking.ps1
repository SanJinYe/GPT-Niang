$script:liveDockingEnabled=$true
function Get-LiveDockClock {return [Diagnostics.Stopwatch]::GetTimestamp()*1000.0/[Diagnostics.Stopwatch]::Frequency}
function Start-WidgetPointerGesture($Control,$Cursor) {
  if($script:drag){return}
  $state=@{pendingClick=$true;control=$Control;x=$Cursor.X;y=$Cursor.Y;lastCursor=$Cursor;activateAt=(Get-LiveDockClock)+200;threshold=6*(Get-WidgetPlacementDpi)}
  $script:drag=$state
  if(!$Control.CaptureMouse()){$script:drag=$null;return}
  Animate-Press $true
  Play-WidgetPressSound
  $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Tag=$state;$timer.Interval=[TimeSpan]::FromMilliseconds(200)
  $timer.Add_Tick({param($sender,$event)
    $sender.Stop()
    if(!$script:runtimeClosed-and [Object]::ReferenceEquals($script:drag,$sender.Tag)){
      $remaining=$script:drag.activateAt-(Get-LiveDockClock)
      if($remaining-gt 0){$sender.Interval=[TimeSpan]::FromMilliseconds([Math]::Max(1,$remaining));$sender.Start();return}
      Activate-WidgetPointerDrag $script:drag.lastCursor
    }
    $sender.Tag=$null
  })
  $state.holdTimer=$timer;$timer.Start()
}
function Activate-WidgetPointerDrag($Cursor) {
  if(!$script:drag-or !$script:drag.pendingClick){return}
  $pending=$script:drag
  if($pending.holdTimer){$pending.holdTimer.Stop();$pending.holdTimer.Tag=$null}
  Animate-Press $false
  $script:drag=$null
  Start-LiveDockDrag $pending.control $Cursor -SilentPress
  # Once drag is committed, its release must never advance the bubble.
  $script:drag.gestureDrag=$true;$script:drag.moved=$true;Hide-Quota
}
function Update-WidgetPointerGesture($Cursor) {
  if(!$script:drag-or !$script:drag.pendingClick){return}
  $script:drag.lastCursor=$Cursor
  $dx=$Cursor.X-$script:drag.x;$dy=$Cursor.Y-$script:drag.y
  if($dx*$dx+$dy*$dy-ge $script:drag.threshold*$script:drag.threshold-or (Get-LiveDockClock)-ge $script:drag.activateAt){Activate-WidgetPointerDrag $Cursor}
}
function Complete-WidgetPointerGesture($Cursor,[switch]$Cancel) {
  if(!$script:drag-or !$script:drag.pendingClick){return}
  if(!$Cancel){Update-WidgetPointerGesture $Cursor;if($script:drag.liveDock){Complete-LiveDockDrag;return}}
  $state=$script:drag;$script:drag=$null
  if($state.holdTimer){$state.holdTimer.Stop();$state.holdTimer.Tag=$null}
  $state.control.ReleaseMouseCapture()|Out-Null
  if($script:runtimeClosed){return}
  Animate-Press $false
  Reset-WidgetAutoQuoteSchedule
  if(!$Cancel){Play-WidgetReleaseSound;Click-Character}else{Stop-WidgetAudio}
  $script:hostEventTimer.Start()
}
function Get-LivePickupBounds($Cursor,$Frame,[double]$Dpi) {
  $width=$script:drag.pickupWidth*$Dpi;$height=$script:drag.pickupHeight*$Dpi
  $left=$Cursor.X-$width*$script:drag.grabX;$top=$Cursor.Y-$height*.16
  if($width-le $Frame.Right-$Frame.Left){$left=[Math]::Max($Frame.Left,[Math]::Min($Frame.Right-$width,$left))}
  if($height-le $Frame.Bottom-$Frame.Top){$top=[Math]::Max($Frame.Top,[Math]::Min($Frame.Bottom-$height,$top))}
  return @{Left=$left;Top=$top;Right=$left+$width;Bottom=$top+$height;Width=$width;Height=$height;PointerX=$Cursor.X;PointerY=$Cursor.Y}
}
function Resolve-LiveDockMode($Frame,$Bounds,[double]$Dpi,[string]$Current) {
  $probe=$Bounds.Clone()
  # An oversized image cannot fit between both edges. Use the pointer on that axis.
  if($Bounds.Width-gt $Frame.Right-$Frame.Left){$probe.Left=$probe.Right=[Math]::Max($Frame.Left,[Math]::Min($Frame.Right,$Bounds.PointerX))}
  if($Bounds.Height-gt $Frame.Bottom-$Frame.Top){$probe.Top=$probe.Bottom=[Math]::Max($Frame.Top,[Math]::Min($Frame.Bottom,$Bounds.PointerY))}
  $mode=Resolve-WidgetDockMode $Frame $probe $Dpi
  if($mode-eq 'free'-and $Current-ne 'free'-and (Resolve-WidgetDockMode $Frame $probe $Dpi 40)-eq $Current){return $Current}
  return $mode
}
function Move-LiveWidget($Frame,[double]$Dpi,[double]$X,[double]$Y) {
  [GptWidgetNative]::SetWindowPos($script:widgetHandle,[IntPtr]::Zero,[int][Math]::Round($X),[int][Math]::Round($Y),0,0,0x15)|Out-Null
  if($script:followHost){
    $script:offsetLeft=($X-$Frame.Left)/$Dpi;$script:offsetRight=($Frame.Right-$X-$script:designWidth*$script:displayScale*$Dpi)/$Dpi
    $script:offsetBottom=($Frame.Bottom-$Y-$script:designHeight*$script:displayScale*$Dpi)/$Dpi;$script:anchor='free'
  }else{$script:desktopLeft=$X;$script:desktopTop=$Y}
  $script:lastPosition=$null
}
function Enter-LivePickup {
  Stop-WidgetPickup
  $script:dockMode='free';Set-WidgetDockPose 'free';Reset-WidgetDockAnimation
  if($script:drag.liveDock){$script:side=$script:drag.initial.side}
  Set-WidgetIndependentLayout;Set-Facing
  $script:hostFollower.AllowOutsideHost=$false
  $null=Start-WidgetPickup
}
function Start-LiveDockDrag($Control,$Cursor,[switch]$SilentPress) {
  if($script:drag-and $script:drag.liveDock){return}
  $initial=@{}
  foreach($name in @('dockMode','dockPose','dockBottom','dockLeft','anchor','side','offsetLeft','offsetRight','offsetBottom','desktopLeft','desktopTop')){$initial[$name]=Get-Variable -Name $name -Scope Script -ValueOnly}
  $resume=Test-WidgetMusicActive
  if($resume){Stop-WidgetMusic -KeepPosition}
  $rect=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
  $script:hostFollower.Suspend()
  $script:drag=@{liveDock=$true;ready=$false;updating=$false;control=$Control;x=$Cursor.X;y=$Cursor.Y;moved=$false;previewMode='free';resumeMusic=$resume;initial=$initial;initialX=$rect.Left;initialY=$rect.Top;dockAllowedAt=[double]::PositiveInfinity;lastCursor=$Cursor;lastX=$Cursor.X;lastY=$Cursor.Y}
  Enter-LivePickup
  $dpi=Get-WidgetPlacementDpi;$m=Get-WidgetDockMetrics $dpi
  $script:drag.pickupWidth=$m.Width/$dpi;$script:drag.pickupHeight=$m.Height/$dpi
  $script:drag.grabX=if($script:ui.FacingScale.ScaleX-lt 0){.40}else{.60}
  $frame=Get-WidgetPlacementFrame;$bounds=Get-LivePickupBounds $Cursor $frame $dpi
  Move-LiveWidget $frame $dpi ($bounds.Left-$m.Left) ($bounds.Top-$m.Top)
  $Control.CaptureMouse()|Out-Null;if(!$SilentPress){Play-WidgetPressSound}
  # Start the grace period only after decoding, layout and capture have completed.
  $script:drag.dockAllowedAt=(Get-LiveDockClock)+500
  $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Tag=$script:drag
  $timer.Interval=[TimeSpan]::FromMilliseconds([Math]::Max(1,$script:drag.dockAllowedAt-(Get-LiveDockClock)))
  $timer.Add_Tick({param($sender,$event)
    $sender.Stop()
    if(!$script:runtimeClosed-and [Object]::ReferenceEquals($script:drag,$sender.Tag)){
      $remaining=$script:drag.dockAllowedAt-(Get-LiveDockClock)
      if($remaining-gt 0){$sender.Interval=[TimeSpan]::FromMilliseconds([Math]::Max(1,$remaining));$sender.Start();return}
      if($script:drag.moved){Update-LiveDockDrag $script:drag.lastCursor -Recheck}
    }
    $sender.Tag=$null
  })
  $script:drag.dockGraceTimer=$timer;$script:drag.ready=$true;$timer.Start()
}
function Update-LiveDockDrag($Cursor,[switch]$Recheck) {
  if(!$script:drag-or !$script:drag.liveDock){return}
  if(!$script:drag.ready-or $script:drag.updating){return}
  if(!$Recheck-and $Cursor.X-eq $script:drag.lastX-and $Cursor.Y-eq $script:drag.lastY){return}
  $active=$script:drag;$active.updating=$true
  try{
  $active.lastX=$Cursor.X;$active.lastY=$Cursor.Y
  $script:drag.lastCursor=$Cursor
  $distance=($Cursor.X-$script:drag.x)*($Cursor.X-$script:drag.x)+($Cursor.Y-$script:drag.y)*($Cursor.Y-$script:drag.y)
  if(!$script:drag.moved-and $distance-lt 9){return}
  if(!$script:drag.moved){$script:drag.moved=$true;Hide-Quota}
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  if(!(Test-WidgetPlacementFrame $frame $dpi)){return}
  # Hit regions use a stable virtual pickup rectangle, never the preview pose's shape.
  $bounds=Get-LivePickupBounds $Cursor $frame $dpi
  $previous=$script:drag.previewMode
  $mode=if((Get-LiveDockClock)-lt $script:drag.dockAllowedAt){'free'}else{Resolve-LiveDockMode $frame $bounds $dpi $previous}
  if($mode-eq 'free'){
    if($previous-ne 'free'-or !$script:pickupState){Enter-LivePickup}
    $m=Get-WidgetDockMetrics $dpi
    Move-LiveWidget $frame $dpi ($bounds.Left-$m.Left) ($bounds.Top-$m.Top)
  }else{
    $pickupColors=if($script:pickupState){$script:pickupState.colors}else{$null}
    if($previous-ne $mode){Stop-WidgetPickup -ForDock;$script:dockRevealMode='free'}
    $script:dockMode=$mode
    $script:dockBottom=($frame.Bottom-($bounds.Top+$bounds.Bottom)/2)/$dpi
    $script:dockLeft=(($bounds.Left+$bounds.Right)/2-$frame.Left)/$dpi
    $placement=Get-WidgetDockPlacement $frame $dpi 0 0 ($script:designWidth*$script:displayScale*$dpi) ($script:designHeight*$script:displayScale*$dpi)
    if($placement){Move-LiveWidget $frame $dpi $placement.X $placement.Y}
    if($pickupColors){foreach($name in @('halo','tint')){if($script:widgetColors-and $script:widgetColors[$name]){$script:widgetColors[$name].Visibility=$pickupColors[$name]}}}
  }
  $script:drag.previewMode=$mode
  }finally{$active.updating=$false}
}
function Complete-LiveDockDrag([switch]$Cancel,$Cursor) {
  if(!$script:drag-or !$script:drag.liveDock){return}
  $state=$script:drag
  if($state.dockGraceTimer){$state.dockGraceTimer.Stop();$state.dockGraceTimer.Tag=$null}
  if(!$Cancel-and ($state.moved-or $state.gestureDrag)){
    # Mouse-up ends grace immediately, even if 500 ms have not elapsed.
    $state.dockAllowedAt=0
    if(!$Cursor){$Cursor=$state.lastCursor}
    Update-LiveDockDrag $Cursor -Recheck
  }
  Stop-WidgetPickup;$script:drag=$null
  $state.control.ReleaseMouseCapture()|Out-Null
  if($script:runtimeClosed){return}
  if(!$state.moved){
    $originalPose=$state.initial.dockPose
    foreach($name in $state.initial.Keys){if($name-ne 'dockPose'){Set-Variable -Name $name -Value $state.initial[$name] -Scope Script}}
    Set-WidgetDockPose $originalPose;Reset-WidgetDockAnimation
    [GptWidgetNative]::SetWindowPos($script:widgetHandle,[IntPtr]::Zero,$state.initialX,$state.initialY,0,0,0x15)|Out-Null
  }elseif($state.previewMode-eq 'free'){
    $script:dockMode='free';Set-WidgetDockPose 'free';Reset-WidgetDockAnimation
  }
  Reset-WidgetAutoQuoteSchedule;Save-Settings;Tick-Widget
  if($state.resumeMusic-and !$script:runtimeClosed-and $script:window.IsVisible){
    $wasOpen=!$script:collapsed;$mode=$script:bubbleMode;$provider=$script:quotaProvider
    Set-WidgetMusicEnabled $true
    if($wasOpen){$script:quotaProvider=$provider;Open-WidgetBubble $mode}
  }
  if(!$Cancel){Play-WidgetReleaseSound;if(!$state.moved-and !$state.gestureDrag){Click-Character}}
  else{Stop-WidgetAudio}
  $script:hostEventTimer.Start()
}
