$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $root 'runtime/lyrics.ps1'),[Text.Encoding]::UTF8)))
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $root 'runtime/dual-quota.ps1'),[Text.Encoding]::UTF8)))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $root 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Restart-SceneTtl','Tick-Scene','Get-QuotaRows','Get-QuotaWindowLabel')){
 $d=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst]-and $n.Name-eq $name},$true)
 . ([ScriptBlock]::Create($d.Extent.Text))
}
$script:dataDir=Join-Path $env:TEMP ('lyric-test-'+[Guid]::NewGuid());[IO.Directory]::CreateDirectory($script:dataDir)|Out-Null
$script:ui=@{QuoteText=[Windows.Controls.TextBlock]::new()}
function Fit-QuoteText {$script:ui.QuoteText.Tag=$script:ui.QuoteText.Text}
function Set-WidgetSceneLayout {}
function Update-BubbleTooltip {}
function Set-ResetTimeMode {}
function Hide-Quota {$script:collapsed=$true}
function Switch-Scene($mode){
 if($mode-eq 'quote' -and (Test-WidgetMusicPlaying)){$mode='lyrics'}
 $script:bubbleMode=$mode
 if($mode-eq 'lyrics'){Set-WidgetLyricText}else{$script:ui.QuoteText.Text='Preset';Fit-QuoteText}
 Restart-SceneTtl
}
function Publish($Playing,$Status,$Text,[int]$Age=0){
 $data=@{connected=$true;playing=$Playing;title='Sample';at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-$Age;lyric=@{status=$Status;text=$Text}}
 [IO.File]::WriteAllText((Join-Path $script:dataDir 'music-now-playing.json'),($data|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
 $script:lastLyricPoll=0
}
try{
 $script:collapsed=$false;$script:bubbleMode='quote'
 Publish $true 'ready' 'First sample line';Update-WidgetLyricScene
 if($script:bubbleMode-ne 'lyrics' -or $script:sceneDeadline-ne 0 -or $script:ui.QuoteText.Text-ne 'First sample line'){throw 'Playing did not replace and pin the preset'}
 Tick-Scene ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+10000)
 if($script:collapsed){throw 'Pinned lyric expired'}
 Publish $true 'ready' 'Second sample line';Update-WidgetLyricScene
 if($script:ui.QuoteText.Text-ne 'Second sample line'){throw 'Lyric line did not advance'}
 Publish $true 'no_lyrics' '';Update-WidgetLyricScene
 if($script:ui.QuoteText.Text.Contains('Second sample')){throw 'Missing lyrics retained the old song'}
 Publish $false 'ready' 'Second sample line';Update-WidgetLyricScene
 if($script:bubbleMode-ne 'quote' -or $script:sceneDeadline-eq 0 -or $script:ui.QuoteText.Text-ne 'Preset'){throw 'Pause did not restore timed preset'}
 Publish $true 'ready' 'First sample line';Update-WidgetLyricScene
 Publish $true 'ready' 'Stale' 11000;Update-WidgetLyricScene
 if($script:bubbleMode-ne 'quote'){throw 'Stale playback kept lyrics pinned'}
 Publish $true 'ready' 'First sample line';$script:collapsed=$true;Update-WidgetLyricScene
 if(!$script:collapsed){throw 'Dismissed lyrics reopened automatically'}
 $script:status=@{queryOk=$true;windows=@(@{minutes=300;used=10;remaining=90},@{minutes=10080;used=20;remaining=80})}
 $rows=@(Get-AllQuotaRows)
 if(!$rows[0].hidden -or $rows[1].hidden){throw 'Codex 5h visibility does not match request'}
 Write-Output 'PASS: live-line update, pinning, pause, stale/no-lyrics handling, dismissal, Codex 5h hidden even if returned'
}finally{[IO.Directory]::Delete($script:dataDir,$true)}
