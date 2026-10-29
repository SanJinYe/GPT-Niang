param([switch]$WidgetOnly,[switch]$SettingsMenuOnly,[string]$PreviewDirectory,[string[]]$TestNames,[switch]$List,[string]$PowerShellExecutable)
$ErrorActionPreference='Stop'
$registered=@(
  'host-identity.test.ps1',
  'peer-layer.test.ps1',
  'host-occlusion.test.ps1',
  'occlusion-reminder.test.ps1',
  'dock-accessories.test.ps1',
  'music-fixed-cadence.test.ps1',
  'music-dock-release.test.ps1',
  'dock-rhythm.test.ps1',
  'dock-animation.test.ps1',
  'dock-poses.test.ps1',
  'dock-native.test.ps1',
  'music-audio.test.ps1',
  'music-rhythm.test.ps1',
  'music-beat-clock.test.ps1',
  'music-envelope.test.ps1',
  'music-color.test.ps1',
  'music-interaction.test.ps1',
  'music-throw-release.test.ps1',
  'music-layer.test.ps1',
  'music-background-lifecycle.test.ps1',
  'music-drag-delivery.test.ps1',
  'music-follow.test.ps1',
  'music-motion.test.ps1',
  'music-frame-clock.test.ps1',
  'music-position-dispatch.test.ps1',
  'music-tempo-recheck.test.ps1',
  'music-startup-response.test.ps1',
  'music-player-capture.test.ps1',
  'music-native-position.test.ps1',
  'music-quiet-startup.test.ps1',
  'music-first-motion.test.ps1',
  'music-visual.test.ps1',
  'quota-selection.test.ps1',
  'installation.test.ps1',
  'supervisor.test.ps1',
  'update.test.ps1',
  'lifecycle.test.ps1',
  'entrypoint.test.ps1',
  'characters.test.ps1',
  'character-startup.test.ps1',
  'character-rendering.test.ps1',
  'sound-player.test.ps1',
  'audio-import.test.ps1',
  'menu-icon.test.ps1',
  'quote-layout.test.ps1',
  'auto-quotes.test.ps1',
  'completion-notifications.test.ps1',
  'completion-current-position.test.ps1',
  'completion-layer-restore.test.ps1',
  'completion-pipe.test.ps1',
  'independent-size.test.ps1',
  'size.test.ps1',
  'display.test.ps1',
  'desktop-mode.test.ps1',
  'drag-sizing.test.ps1',
  'drag-facing.test.ps1',
  'drag-horizontal.test.ps1',
  'drag-vertical.test.ps1',
  'fixed-relative-position.test.ps1',
  'settings-menu.test.ps1',
  'menu-dismiss.test.ps1',
  'placement-settings.test.ps1',
  'host-ready.test.ps1',
  'ark-refresh.test.ps1',
  'lyrics-scene.test.ps1',
  'quota-page-cycle.test.ps1',
  'credit-layout.test.ps1',
  'drag-pickup.test.ps1',
  'live-docking.test.ps1',
  'pickup-dock-release.test.ps1',
  'pickup-overlays.test.ps1',
  'provider-background.test.ps1',
  'provider-cycle.test.ps1',
  'settings-window.test.ps1',
  'review-fixes.test.ps1',
  'widget.test.ps1'
)
if($List){$registered;return}
if($WidgetOnly){$selected=@('widget.test.ps1')}
elseif($SettingsMenuOnly){$selected=@('settings-menu.test.ps1')}
elseif($TestNames){$selected=@($TestNames|ForEach-Object{$_ -split ','}|ForEach-Object{if($_.EndsWith('.test.ps1')){$_}else{$_+'.test.ps1'}})}
else{$selected=$registered}
foreach($name in $selected){if($name-notin $registered){throw ('Unregistered test: '+$name)}}
if(!$PowerShellExecutable){$PowerShellExecutable=Join-Path $PSHOME $(if($PSVersionTable.PSEdition-eq 'Core'){'pwsh.exe'}else{'powershell.exe'})}
$launcher=Join-Path $PSScriptRoot 'run-windows-case.ps1'
foreach($name in $selected){
  $arguments=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$launcher,'-TestFile',(Join-Path $PSScriptRoot $name))
  if($PreviewDirectory){$arguments+=@('-PreviewDirectory',$PreviewDirectory)}
  & $PowerShellExecutable @arguments
  if($LASTEXITCODE-ne 0){throw ($name+' failed ('+$LASTEXITCODE+')')}
}
Write-Output ('PASS: '+$selected.Count+' registered Windows test files')
