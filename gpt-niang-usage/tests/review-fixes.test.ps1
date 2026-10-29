$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$app=Split-Path $PSScriptRoot -Parent
foreach($name in @('settings-window','update-ui','dock-poses','live-docking')){. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $app ('runtime/'+$name+'.ps1')),[Text.Encoding]::UTF8)))}
$script:settingsWindow=[pscustomobject]@{IsVisible=$true}
if(Test-WidgetUpdateEditor -AllowSettingsWindow){throw 'Settings window still blocks manual checking'}
if(!(Test-WidgetUpdateEditor)){throw 'Open settings must still block installation'}
$script:audioDialogOpen=$true;if(!(Test-WidgetUpdateEditor -AllowSettingsWindow)){throw 'Active audio editor must remain protected'};$script:audioDialogOpen=$false
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('niang-review-fixes-'+[Guid]::NewGuid().ToString('N'))
try{
 [IO.Directory]::CreateDirectory((Join-Path $temporary 'runtime'))|Out-Null
 [IO.File]::WriteAllText((Join-Path $temporary 'runtime/update.mjs'),"import fs from 'node:fs';fs.writeFileSync(process.argv[2],process.argv[3]);")
 $script:appDir=$temporary;$script:configPath=Join-Path $temporary 'started.txt';$script:config=@{nodePath=(Get-Command node).Source}
 Start-WidgetUpdate 'manual'
 if(!$script:updateProcess-or !$script:updateProcess.WaitForExit(5000)-or [IO.File]::ReadAllText($script:configPath)-ne 'manual'){throw 'Manual update action did not start its worker'}
 $script:updateProcess.Dispose();$script:updateProcess=$null
 $section=[Windows.Controls.MenuItem]::new();$item=[Windows.Controls.MenuItem]::new();$item.Header='未设置';$section.Items.Add($item)|Out-Null
 $script:settingsMenuUi=@{};$script:settingsControls=@();$panel=Convert-SettingsSection $section
 $item.Header='测试.wav';$panel.Children[0].GetBindingExpression([Windows.Controls.ContentControl]::ContentProperty).UpdateTarget()
 if($panel.Children[0].Content-ne '测试.wav'){throw 'Audio filename binding did not refresh'}
 $item.Header='未设置';$panel.Children[0].GetBindingExpression([Windows.Controls.ContentControl]::ContentProperty).UpdateTarget()
 if($panel.Children[0].Content-ne '未设置'){throw 'Cleared filename binding did not refresh'}
 $statusItem=[Windows.Controls.MenuItem]::new();$statusItem.IsHitTestVisible=$false;$statusItem.Header=[Windows.Controls.TextBlock]::new();$statusItem.Header.Text='检查中'
 $script:settingsMenuUi.UpdateStatus=$statusItem;$section.Items.Clear();$section.Items.Add($statusItem)|Out-Null;$panel=Convert-SettingsSection $section
 $statusItem.Header.Text='暂无正式版';$panel.Children[0].GetBindingExpression([Windows.Controls.TextBlock]::TextProperty).UpdateTarget()
 if($panel.Children[0].Text-ne '暂无正式版'){throw 'Functional update status was hidden or stale'}
 foreach($dpi in @(1,1.5,2)){
  $frame=@{Left=0;Top=0;Right=1000*$dpi;Bottom=600*$dpi};$script:drag=@{pickupWidth=726;pickupHeight=726;grabX=.6}
  $bounds=Get-LivePickupBounds ([pscustomobject]@{X=500*$dpi;Y=300*$dpi}) $frame $dpi
  if((Resolve-LiveDockMode $frame $bounds $dpi 'free')-ne 'free'){throw 'Oversized pickup forced a dock in the middle'}
  foreach($entry in @(@(500,5,'top'),@(500,595,'bottom'),@(5,300,'left'),@(995,300,'right'))){
   $bounds=Get-LivePickupBounds ([pscustomobject]@{X=$entry[0]*$dpi;Y=$entry[1]*$dpi}) $frame $dpi
   if((Resolve-LiveDockMode $frame $bounds $dpi 'free')-ne $entry[2]){throw ('Oversized edge failed: '+$entry[2])}
  }
  $script:drag.pickupWidth=1500
  $bounds=Get-LivePickupBounds ([pscustomobject]@{X=500*$dpi;Y=300*$dpi}) $frame $dpi
  if((Resolve-LiveDockMode $frame $bounds $dpi 'free')-ne 'free'){throw 'Oversized width forced a dock'}
 }
 'PASS: manual check launch/install protection, live labels/status, oversized drag across DPI and edges'
}finally{
 if($script:updateProcess){if(!$script:updateProcess.HasExited){$script:updateProcess.Kill()};$script:updateProcess.Dispose()}
 $resolved=[IO.Path]::GetFullPath($temporary);if(!$resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe test path'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
