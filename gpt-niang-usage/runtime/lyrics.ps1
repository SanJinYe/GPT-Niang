function Read-WidgetMusicSnapshot {
  $file=Join-Path $script:dataDir 'music-now-playing.json'
  try{
    if(![IO.File]::Exists($file)){return $null}
    $state=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)|ConvertFrom-Json
    if([Math]::Abs([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$state.at)-ge 10000){return $null}
    return $state
  }catch{return $null}
}
function Test-WidgetMusicPlaying {
  $state=Read-WidgetMusicSnapshot
  return [bool]($state -and $state.connected -and $state.playing-eq $true)
}
function Set-WidgetLyricText {
  $state=Read-WidgetMusicSnapshot
  $lyric=$state.lyric
  $text=switch([string]$lyric.status){
    'ready' {if($lyric.text){[string]$lyric.text}else{'间奏'};break}
    'intro' {'前奏';break}
    'interlude' {'间奏';break}
    'no_lyrics' {'这首歌暂无歌词';break}
    'unavailable' {'歌词暂时无法读取';break}
    'unknown_position' {'暂时无法同步播放进度';break}
    'unknown_track' {'暂时无法识别这首歌';break}
    default {'正在读取歌词…'}
  }
  if($lyric.status-ne 'ready' -and $state.title){$text+="`n"+[string]$state.title}
  if($script:ui.QuoteText.Tag-ne $text){
    $script:ui.QuoteText.Text=$text;Fit-QuoteText
    Set-WidgetSceneLayout;Update-BubbleTooltip
  }
  $script:sceneDeadline=0
}
function Update-WidgetLyricScene {
  if($script:collapsed -or $script:bubbleMode-notin @('quote','lyrics')){return}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if($now-[long]$script:lastLyricPoll-lt 250){return}
  $script:lastLyricPoll=$now
  if(Test-WidgetMusicPlaying){
    if($script:bubbleMode-ne 'lyrics'){Switch-Scene 'lyrics'}else{Set-WidgetLyricText}
  }elseif($script:bubbleMode-eq 'lyrics'){
    Switch-Scene 'quote'
  }
}
