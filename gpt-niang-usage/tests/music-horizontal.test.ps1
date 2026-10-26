$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
Initialize-WidgetMusicTypes
foreach($dpi in @(1,1.5,2)){
 $motion=[GptMusicMotion]::new(350*$dpi,650*$dpi,1000*$dpi,650*$dpi,132*$dpi,$dpi)
 $motion.Phase=2;$motion.Props=1
 for($i=0;$i-lt 120;$i++){$motion.Step(1.0/60,$false,$true,$i/30.0,.5,1)}
 if([Math]::Abs($motion.X-350*$dpi)-lt 10){throw 'Enabled horizontal movement is missing'}
 $motion.HorizontalTravelEnabled=$false;$x=$motion.X;$min=1.0;$max=-1.0
 for($i=0;$i-lt 120;$i++){
  $motion.Step(1.0/60,$false,$true,$i/30.0,.5,1)
  if([Math]::Abs($motion.X-$x)-gt .0001){throw 'Disabled horizontal travel drifted'}
  $min=[Math]::Min($min,$motion.Bend);$max=[Math]::Max($max,$motion.Bend)
 }
 if($min-gt -.1 -or $max-lt .3){throw 'Stationary mode lost musical bounce'}
 $motion.BeginHold();$motion.MoveHeld($x+80*$dpi,450*$dpi,.1)
 if($motion.X-le $x){throw 'Stationary mode prevented user dragging'}
 $motion.Release();$motion.Phase=2;$motion.HorizontalTravelEnabled=$true;$x=$motion.X
 for($i=0;$i-lt 120;$i++){$motion.Step(1.0/60,$false,$true,$i/30.0,.5,1)}
 if([Math]::Abs($motion.X-$x)-lt 10){throw 'Re-enabling horizontal movement failed'}
}
Write-Output 'PASS: horizontal toggle stops drift, retains bounce/dragging, and resumes at three DPI scales'
