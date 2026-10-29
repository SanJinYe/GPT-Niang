$script:widgetMusic=$null
$script:musicColorEnabled=$false
$script:musicLastError=$null
$script:musicLightsEnabled=$true
$script:musicHorizontalEnabled=$true
function Set-WidgetMusicHorizontal([bool]$Enabled) {
  $script:musicHorizontalEnabled=$Enabled
  if(Test-WidgetMusicActive){$script:widgetMusic.HorizontalTravelEnabled=$Enabled}
  Save-Settings
}
$script:musicFollowNetease=$false
$script:musicBridge=$null
$script:musicNowPlaying=$null
function Start-WidgetMusicBridge {
  if($script:musicBridge -and !$script:musicBridge.HasExited){return}
  $config=[IO.File]::ReadAllText((Join-Path $script:dataDir 'music-connection.json')) | ConvertFrom-Json
  $start=[Diagnostics.ProcessStartInfo]::new()
  $start.FileName=$config.nodePath
  $start.Arguments='"'+$config.bridgePath+'" "'+(Join-Path $script:dataDir 'music-now-playing.json')+'"'
  $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardInput=$true
  $script:musicBridge=[Diagnostics.Process]::Start($start)
}
function Stop-WidgetMusicBridge {
  if($script:musicBridge){
    if(!$script:musicBridge.HasExited){$script:musicBridge.StandardInput.Close()}
    $script:musicBridge.Dispose();$script:musicBridge=$null
  }
}
function Set-WidgetMusicFollowNetease([bool]$Enabled) {
  Initialize-MusicSources
  if($Enabled -and @($script:musicSources.Values|Where-Object{$_}).Count-eq 0){Set-MusicSource 'netease' $true}
  $script:musicFollowNetease=$Enabled
  if(!$Enabled){Stop-WidgetMusic}
  Save-Settings
  if($Enabled){Update-WidgetNowPlaying}
}
function Set-WidgetManualMusic([bool]$Enabled) {
  $script:musicFollowNetease=$false;Save-Settings
  Set-WidgetMusicEnabled $Enabled
}
function Update-WidgetNowPlaying {
  Initialize-MusicSources
  if(![IO.File]::Exists((Join-Path $script:dataDir 'music-connection.json'))){return}
  try{
    Start-WidgetMusicBridge
    $file=Join-Path $script:dataDir 'music-now-playing.json'
    if(![IO.File]::Exists($file)){return}
    $state=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8) | ConvertFrom-Json
    $fresh=([Math]::Abs([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$state.at)-lt 10000)
    $script:musicNowPlaying=$state
    $script:musicLastError=$state.error
    if($script:musicFollowNetease){
    if($fresh -and $state.connected -and $state.playing-eq $true){
      if($script:window.IsVisible -and !$script:drag -and !(Test-WidgetMusicActive)){Set-WidgetMusicEnabled $true}
    }elseif(Test-WidgetMusicActive){Stop-WidgetMusic}
    }
    if($script:settingsMenuUi.MusicTrack){
      $script:settingsMenuUi.MusicTrack.Header=if(!$fresh){'歌曲状态已过期'}elseif(!$state.connected){'播放器未连接'}elseif(!$state.playing){'已勾选播放器暂无播放'}else{'正在播放：'+$state.title+' · '+$state.artists}
      $script:settingsMenuUi.MusicTrack.ToolTip=$state.error
    }
  }catch{$script:musicLastError=$_.Exception.Message;if($script:musicFollowNetease -and (Test-WidgetMusicActive)){Stop-WidgetMusic}}
}
function Set-WidgetMusicLights([bool]$Enabled) {
  $script:musicLightsEnabled=$Enabled
  if(Test-WidgetMusicActive){$script:widgetMusic.LightsEnabled=$Enabled}
  Save-Settings
}
function Initialize-WidgetMusicTypes {
  if('GptMusicVisual' -as [type]){return}
  Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms,System.Drawing
  $references=@('System.dll','System.Core.dll','System.Xaml.dll','System.Windows.Forms.dll','System.Drawing.dll',[Windows.Window].Assembly.Location,[Windows.Media.Brush].Assembly.Location,[Windows.Point].Assembly.Location)
  if($PSVersionTable.PSEdition-eq 'Core'){
    $references=@((Get-ChildItem -LiteralPath (Join-Path $PSHOME 'ref') -Filter '*.dll'|ForEach-Object FullName)+@([Windows.Window].Assembly.Location,[Windows.Media.Brush].Assembly.Location,[Windows.Point].Assembly.Location,[Windows.Forms.Form].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location))|Sort-Object -Unique
  }
  Add-Type -Path @((Join-Path $script:appDir 'runtime/music-audio.cs'),(Join-Path $script:appDir 'runtime/music-visual.cs')) -ReferencedAssemblies $references
}
function Test-WidgetMusicActive {
  # A visual-layer failure stops the C# object internally. Reconcile the
  # PowerShell/menu state on the next check instead of leaving a stale
  # "enabled" menu item and a half-restored layout.
  if($script:widgetMusic -and !$script:widgetMusic.Enabled){try{Stop-WidgetMusic}catch{}}
  return [bool]($script:widgetMusic -and $script:widgetMusic.Enabled)
}
function Set-WidgetMusicPickupColor {
  if(!(Test-WidgetMusicActive)){return}
  $chance=[Math]::Min(100.0,[Math]::Max(0.0,2.0*$script:colorChance))/100.0
  $script:musicColorEnabled=($script:colorMode-ne 'original' -and $chance-gt 0 -and (Get-WidgetColorRoll)-lt $chance)
  $script:widgetMusic.ColorEnabled=$script:musicColorEnabled
  $script:widgetMusic.Redraw()
}
function Stop-WidgetMusic([switch]$KeepPosition) {
  if($script:widgetMusic){
    $state=$script:widgetMusic;$script:widgetMusic=$null
    try{$state.Stop([bool]$KeepPosition)}finally{if($state.Error){$script:musicLastError=$state.Error}}
  }
  $script:musicColorEnabled=$false
  $script:lastPosition=$null
  if($script:widgetColors){Update-WidgetColorScene}
  if($script:settingsMenuUi -and $script:settingsMenuUi.MusicEnabled){$script:settingsMenuUi.MusicEnabled.IsChecked=$false}
  if($script:hostEventTimer -and !$script:runtimeClosed){$script:hostEventTimer.Start()}
}
function Set-WidgetMusicEnabled([bool]$Enabled) {
  if(!$Enabled){Stop-WidgetMusic;return}
  if(Test-WidgetMusicActive){return}
  if(!$script:window.IsVisible){throw '请先显示挂件再开启音乐律动。'}
  try{
    if($script:bubbleMode-notin @('quote','lyrics')){Hide-Quota}
    Initialize-WidgetMusicTypes
    $colors=[Windows.Media.Color[]]@(Get-WidgetColorPalette 'rainbow'|ForEach-Object{[Windows.Media.ColorConverter]::ConvertFromString($_)})
    $move=[Delegate]::CreateDelegate([Action[int,int]],$script:hostFollower,'SetTemporaryOffset')
    $normal=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$normal)|Out-Null
    $script:musicLastError=$null;$script:musicColorEnabled=$false
    $script:widgetMusic=[GptMusicVisual]::new($script:window,$script:ui.Girl,$script:ui.Bubble,$move,$colors,($script:characterId-eq 'gpt-dragon'))
    $script:widgetMusic.FollowLamp=[Delegate]::CreateDelegate([Action[IntPtr,int,int,int]],$script:hostFollower,'SetCompanion')
    $script:widgetMusic.HostFrame=[Delegate]::CreateDelegate([Func[int[]]],$script:hostFollower,'GetFrame')
    $script:widgetMusic.Pinned=($script:dockPosesEnabled -and $script:dockPose-ne 'free')
    $script:widgetMusic.SideDock=($script:dockPose-like 'side-*')
    $script:widgetMusic.TopDock=($script:dockPose-eq 'top')
    $script:widgetMusic.DockPose=$script:dockPose
    $script:widgetMusic.AllowLyricsBubble=(!$script:collapsed -and $script:bubbleMode-eq 'lyrics')
    $script:widgetMusic.LightsEnabled=$script:musicLightsEnabled
    $script:widgetMusic.HorizontalTravelEnabled=$script:musicHorizontalEnabled
    Update-WidgetMusicPlacement (Get-WidgetPlacementFrame) (Get-WidgetPlacementDpi) $normal.Left $normal.Top $true
    Update-WidgetColorScene
    $script:lastPosition=$null;Tick-Widget
    if($script:settingsMenuUi.MusicEnabled){$script:settingsMenuUi.MusicEnabled.IsChecked=$true}
  }catch{
    $script:musicLastError=$_.Exception.Message;Stop-WidgetMusic
    [Windows.MessageBox]::Show(('音乐律动暂时无法启动：'+$script:musicLastError),'GPT 娘')|Out-Null
  }
}
function Update-WidgetMusicPlacement($Frame,[double]$Dpi,[double]$X,[double]$Y,[bool]$Visible) {
  if(!(Test-WidgetMusicActive)){return}
  try{
    $blocked=[bool]($script:settingsSizePreview -or ($script:characterGallery -and $script:characterGallery.IsVisible) -or ($script:quoteEditor -and $script:quoteEditor.IsVisible))
    $script:widgetMusic.Configure($script:widgetHandle,$script:hostHandle,$script:followHost,$Visible,$blocked,$script:desktopTopmost,$X,$Y,$Frame.Left,$Frame.Bottom,$Dpi)
  }catch{
    # A music placement failure must not truncate the rest of Tick-Widget.
    $script:musicLastError=$_.Exception.Message
    try{Stop-WidgetMusic}catch{}
    try{[IO.File]::WriteAllText((Join-Path $script:dataDir 'music-error.txt'),$script:musicLastError,[Text.UTF8Encoding]::new($false))}catch{}
  }
}
function Update-WidgetMusicVisibility([bool]$Visible,[bool]$Blocked=$false) {
  if(!$script:widgetMusic){return}
  try{$script:widgetMusic.SetVisibility($Visible,$Blocked)}
  catch{
    $script:musicLastError=$_.Exception.Message
    try{Stop-WidgetMusic}catch{}
    try{[IO.File]::WriteAllText((Join-Path $script:dataDir 'music-error.txt'),$script:musicLastError,[Text.UTF8Encoding]::new($false))}catch{}
  }
}
function Get-WidgetMusicStatus {
  if(!(Test-WidgetMusicActive)){return @{enabled=$false;lights=$script:musicLightsEnabled;horizontal=$script:musicHorizontalEnabled;followNetease=$script:musicFollowNetease;nowPlaying=$script:musicNowPlaying;color=$script:musicColorEnabled;error=$script:musicLastError}}
  $a=$script:widgetMusic.Audio;$m=$script:widgetMusic.Motion
  return @{enabled=$true;dockRhythm=if($script:widgetMusic.Pinned){if($script:widgetMusic.TopDock){'top'}elseif($script:widgetMusic.SideDock){'side'}else{'corner'}}else{'bottom'};lights=$script:musicLightsEnabled;horizontal=$script:musicHorizontalEnabled;followNetease=$script:musicFollowNetease;nowPlaying=$script:musicNowPlaying;color=$script:musicColorEnabled;paused=$script:widgetMusic.Paused;running=[bool]($a -and $a.Running);source=if($a){$a.Source}else{'system-playback'};sourceProcessId=if($a){$a.SourceProcessId}else{0};captureReadyMs=if($a){$a.CaptureReadyMs}else{0};firstPacketMs=if($a){$a.FirstPacketMs}else{0};
    beats=if($a){$a.BeatSequence}else{0};onsets=if($a){$a.Sequence}else{0};rhythmLocked=[bool]($a -and $a.RhythmLocked);bpm=if($a){$a.Bpm}else{0};confidence=if($a){$a.Confidence}else{0};
    tracking=if(!$a -or !$a.RhythmLocked){'acquiring'}elseif($a.BassCycle){'bass-cycle'}else{'onsets'};
    nextBeatAtMs=if($a){$a.NextBeatAtMs}else{0};periodMs=if($a){$a.PeriodMs}else{0};audioLagMs=if($a){$a.AudioLagMs}else{0};
    strength=if($a){$a.Strength}else{0};sampleRate=if($a){$a.SampleRate}else{0};channels=if($a){$a.Channels}else{0};
    level=if($a){$a.Level}else{0};lowLevel=if($a){$a.LowLevel}else{0};drive=if($a){$a.Drive}else{0};error=if($script:widgetMusic.Error){$script:widgetMusic.Error}elseif($a){$a.Error}else{$null};
    phase=if($m){$m.Phase}else{-1};held=[bool]($m -and $m.Held);velocityX=if($m){$m.Vx}else{0};velocityY=if($m){$m.Vy}else{0};
    releaseVelocityX=if($m -and !$m.Held){$m.ThrowX}else{0};releaseVelocityY=if($m -and !$m.Held){$m.ThrowY}else{0};releaseIdleMs=if($m){$m.ReleaseIdleMs}else{0};
    impacts=if($m){$m.Impacts}else{0};compression=if($m){$m.Bend}else{0};x=if($m){$m.X}else{0};y=if($m){$m.Y}else{0};
    lamp=$script:widgetMusic.LampHandle.ToInt64()}
}
