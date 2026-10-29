$ErrorActionPreference='Stop'
# Isolate existing geometry/lifecycle tests from the independently tested pickup sprite.
function Start-WidgetPickup {return $false}
function Stop-WidgetPickup {}

$app=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $app 'runtime/dock-poses.ps1'),[Text.Encoding]::UTF8)))
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $app 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$def=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq '$pressUp'},$true)
$body=$def.Right.Extent.Text.Trim();$release=[ScriptBlock]::Create($body.Substring(1,$body.Length-2))
Add-Type -TypeDefinition @'
using System;
public static class GptWidgetNative {
 public struct Rect{public int Left,Top,Right,Bottom;}
 public static int X,Y;
 public static bool GetWindowRect(IntPtr h,out Rect r){r=new Rect{Left=X,Top=Y,Right=X+100,Bottom=Y+100};return true;}
}
'@
function Get-WidgetPlacementFrame {return @{Left=0;Top=0;Right=1000;Bottom=700}}
function Get-WidgetPlacementDpi {return 1.0}
function Get-WidgetDockMetrics($Dpi){return @{Left=0;Top=0;Right=100;Bottom=100}}
function Test-WidgetMusicActive {return $script:active}
function Stop-WidgetMusic([switch]$KeepPosition){$script:active=$false;$script:stops++}
function Set-WidgetMusicEnabled($Enabled){$script:active=$Enabled;$script:starts++}
function Tick-Widget {$script:placements++}
function Save-Settings {}
function Reset-WidgetAutoQuoteSchedule {}
function Play-WidgetReleaseSound {}
function Animate-Press {}
$script:widgetHandle=[IntPtr]::Zero;$script:characterId='gpt-dragon';$script:dockPosesEnabled=$true
$script:widgetMusic=[pscustomobject]@{};$script:widgetMusic|Add-Member ScriptMethod EndHold {}
$script:hostEventTimer=[pscustomobject]@{};$script:hostEventTimer|Add-Member ScriptMethod Start {}
$sender=[pscustomobject]@{};$sender|Add-Member ScriptMethod ReleaseMouseCapture {}
$event=[pscustomobject]@{Handled=$false}
$cases=@(@(0,250,'left'),@(900,250,'right'),@(450,0,'top'),@(450,600,'bottom'),@(0,600,'bottom-left'),@(900,600,'bottom-right'),@(-20,-40,'top-left'),@(950,-40,'top-right'),@(400,300,'free'))
foreach($case in $cases){
 [GptWidgetNative]::X=$case[0];[GptWidgetNative]::Y=$case[1];$script:active=$true;$script:starts=$script:stops=$script:placements=0
 $script:drag=@{music=$true}; & $release $sender $event
 if($script:dockMode-ne $case[2] -or !$script:active -or $script:drag){throw ('Music release failed at '+$case[2])}
 if($case[2]-eq 'free'){if($script:stops-ne 0){throw 'Free throw was unnecessarily stopped'}}
 elseif($script:starts-ne 1 -or $script:stops-ne 1 -or $script:placements-ne 1){throw 'Docking did not resume music after placement'}
}
[GptWidgetNative]::X=0;[GptWidgetNative]::Y=250;$script:active=$false;$script:starts=0
$script:drag=@{moved=$true;resumeMusic=$true}; & $release $sender $event
if(!$script:active -or $script:starts-ne 1){throw 'Pinned drag lost manual music mode'}
Write-Output 'PASS: music drag docks on all edges/corners, clipped top bounds, free throw and manual resume'
