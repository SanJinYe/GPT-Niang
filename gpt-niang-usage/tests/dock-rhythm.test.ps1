$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
Initialize-WidgetMusicTypes
$samples=0
foreach($side in @($true,$false)){
 foreach($x in @(0.0,19.55,188.45,208.0)){
  $y=if($side){153.92}else{208.0}
  for($i=0;$i-lt 120;$i++){
   $phase=$i/60.0;$bend=[GptMusicMotion]::BeatPose($phase);$rock=7.5*[Math]::Sin(2*[Math]::PI*$phase)
   $m=[GptMusicVisual]::DockBeatMatrix($side,$bend,$rock,$x,$y)
   $anchor=$m.Transform([Windows.Point]::new($x,$y))
   if([Math]::Abs($anchor.X-$x)-gt 1e-8 -or [Math]::Abs($anchor.Y-$y)-gt 1e-8){throw 'Music moved the dock anchor'}
   foreach($v in @(0,70,160,208)){
    $edge=$m.Transform([Windows.Point]::new($x,$v))
    if([Math]::Abs($edge.X-$x)-gt 1e-8){throw 'Vertical frame contact changed'}
    if($side -and [Math]::Abs($edge.Y-$v)-gt 1e-8){throw 'Side hand positions moved along the grip line'}
    if(!$side){$bottom=$m.Transform([Windows.Point]::new($v,$y));if([Math]::Abs($bottom.Y-$y)-gt 1e-8){throw 'Bottom edge detached'}}
   }
   if($m.Determinant-le 0){throw 'Music inverted a sprite'}
   $samples++
  }
 }
}
$sideBeat=[GptMusicVisual]::DockBeatMatrix($true,.4,7.5,180,150)
$cornerBeat=[GptMusicVisual]::DockBeatMatrix($false,.4,7.5,208,208)
if($sideBeat.M11-lt .90 -or $sideBeat.M11-ge .95 -or $sideBeat.M22-ne 1 -or [Math]::Abs($sideBeat.M12)-gt .025){throw 'Side motion is not reduced and stable'}
if($cornerBeat.M11-lt .90 -or $cornerBeat.M22-lt .88 -or $cornerBeat.M22-ge .95 -or $cornerBeat.M12-ne 0){throw 'Corner motion is not reduced and stable'}
if(!([GptMusicVisual]::DockBeatMatrix($true,0,0,180,150)).IsIdentity -or !([GptMusicVisual]::DockBeatMatrix($false,0,0,208,208)).IsIdentity){throw 'Silence did not restore neutral pose'}
Write-Output ('PASS: '+$samples+' beat samples, fixed side grip/corner edges, visible distinct motion and neutral restoration')
foreach($rock in @(-7.5,-3,0,3,7.5)){
 $m=[GptMusicVisual]::DockBeatMatrix($false,$true,.4,$rock,100,0)
 $anchor=$m.Transform([Windows.Point]::new(100,0));$head=$m.Transform([Windows.Point]::new(100,120))
 if([Math]::Abs($anchor.X-100)-gt 1e-8 -or [Math]::Abs($anchor.Y)-gt 1e-8){throw 'Hanging swing moved its top attachment'}
 if($m.M11-ne 1 -or $m.M22-ne 1 -or $m.M12-ne 0 -or [Math]::Abs($m.Determinant-1)-gt 1e-8){throw 'Top motion must be shear, not rotation or scaling'}
 foreach($handX in @(15,185)){
  $hand=$m.Transform([Windows.Point]::new($handX,0))
  if([Math]::Abs($hand.X-$handX)-gt 1e-8 -or [Math]::Abs($hand.Y)-gt 1e-8){throw 'A gripping hand moved off the top frame'}
 }
 $bottomLeft=$m.Transform([Windows.Point]::new(0,250));$bottomRight=$m.Transform([Windows.Point]::new(200,250))
 if($bottomLeft.Y-ne 250 -or $bottomRight.Y-ne 250 -or [Math]::Abs($bottomRight.X-$bottomLeft.X-200)-gt 1e-8){throw 'Top shear lost the horizontal parallel edges'}
 if([Math]::Abs($rock)-gt 3 -and ([Math]::Abs($head.X-100)-lt 4 -or [Math]::Abs($head.X-100)-gt 8)){throw 'Hanging shear amplitude is not gentle'}
}
Write-Output 'PASS: top parallelogram shear fixes both hands and preserves parallel horizontal edges'
