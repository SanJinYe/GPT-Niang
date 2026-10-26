$ErrorActionPreference='Stop'
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $PSScriptRoot '../runtime/music.ps1'),[Text.Encoding]::UTF8)))
$script:dataDir=Join-Path $env:TEMP ('music-follow-'+[Guid]::NewGuid())
[IO.Directory]::CreateDirectory($script:dataDir)|Out-Null
[IO.File]::WriteAllText((Join-Path $script:dataDir 'music-connection.json'),'{}')
$script:window=[pscustomobject]@{IsVisible=$true}
$script:settingsMenuUi=@{MusicTrack=[pscustomobject]@{Header='';ToolTip=''}}
$script:active=$false;$script:starts=0;$script:stops=0
function Start-WidgetMusicBridge {}
function Stop-WidgetMusicBridge {}
function Save-Settings {}
function Test-WidgetMusicActive {return $script:active}
function Set-WidgetMusicEnabled([bool]$Enabled){$script:active=$Enabled;$script:starts++}
function Stop-WidgetMusic {$script:active=$false;$script:stops++}
function Publish($Playing,[bool]$Connected=$true,[long]$Age=0){
 $state=@{playing=$Playing;connected=$Connected;title='Test Song';artists='Artist';at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-$Age;error=$null}
 [IO.File]::WriteAllText((Join-Path $script:dataDir 'music-now-playing.json'),($state|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
}
try{
 $script:musicFollowNetease=$true
 Publish $true;Update-WidgetNowPlaying
 if(!$script:active -or $script:starts-ne 1){throw 'Playing did not start dance'}
 Update-WidgetNowPlaying
 if($script:starts-ne 1){throw 'Unchanged playback restarted dance'}
 Publish $false;Update-WidgetNowPlaying
 if($script:active){throw 'Pause did not stop dance'}
 Publish $true;Update-WidgetNowPlaying
 Publish $true $true 11000;Update-WidgetNowPlaying
 if($script:active){throw 'Stale status did not stop dance'}
 Publish $true $false;Update-WidgetNowPlaying
 if($script:active){throw 'Disconnected MCP started dance'}
 Set-WidgetManualMusic $true
 Publish $false;Update-WidgetNowPlaying
 if(!$script:active -or $script:musicFollowNetease){throw 'Automatic polling overrode manual mode'}
 Write-Output 'PASS: playback, pause, stale/disconnected status and manual mode'
}finally{[IO.Directory]::Delete($script:dataDir,$true)}
