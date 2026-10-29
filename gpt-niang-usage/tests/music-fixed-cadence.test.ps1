$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
Initialize-WidgetMusicTypes
$period=[GptMusicVisual]::RhythmPeriodSeconds
foreach($fps in @(30,60,144)){
 $m=[GptMusicMotion]::new(300,600,1000,600,150,1);$m.Phase=2;$m.Props=1;$m.HorizontalTravelEnabled=$false
 $peaks=@();$previous=0.0;$beforePrevious=0.0
 for($i=0;$i-lt $fps*9;$i++){
  $t=$i/[double]$fps;$m.Step(1.0/$fps,$false,$true,$t/$period,$period,1,1.0/$fps)
  if($t-gt 1 -and $previous-gt .35 -and $previous-ge $beforePrevious -and $previous-gt $m.Bend){$peaks+=($t-1.0/$fps)}
  $beforePrevious=$previous;$previous=$m.Bend
 }
 if($peaks.Count-lt 4){throw 'Fixed cadence failed to animate'}
 for($i=1;$i-lt $peaks.Count;$i++){if([Math]::Abs($peaks[$i]-$peaks[$i-1]-$period)-gt 2.0/$fps){throw 'Frequency changed across frames'}}
}
if([GptMusicVisual]::RhythmAmplitude-ge .5){throw 'Motion amplitude was not reduced'}
Write-Output ('PASS: '+$period+'-second cadence at 30/60/144 fps with reduced amplitude')
