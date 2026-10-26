param([string]$ImagePath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $root 'runtime/dual-quota.ps1'),[Text.Encoding]::UTF8)))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $root 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Get-QuotaRows','Get-QuotaWindowLabel','Format-ResetTime','Format-ResetDisplay','Reset-Label','Update-Quota')){
 $def=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
 . ([ScriptBlock]::Create($def.Extent.Text))
}
function Update-BubbleTooltip {}
$script:dataDir=Join-Path $env:LOCALAPPDATA 'GPTNiangUsage/state'
$script:window=[pscustomobject]@{IsVisible=$true}
try{
 $deadline=[DateTime]::UtcNow.AddSeconds(55)
 do{Update-ArkQuotaRead;if($script:arkStatus){break};Start-Sleep -Milliseconds 100}while([DateTime]::UtcNow-lt $deadline)
 if(!$script:arkStatus.queryOk){throw ('Live Ark query failed: '+$script:arkStatus.error)}
 $live=$script:arkStatus
 $script:arkStatus=@{queryOk=$false;error='auth_required'}
 $rows=@(Get-AllQuotaRows)
 if(@($rows|Where-Object{$_.provider-eq 'Ark' -and $null-ne $_.window}).Count){throw 'Auth failure showed an invented quota'}
 $script:arkStatus=$live
 $live.observedAt-=181000
 if(@(Get-AllQuotaRows|Where-Object{$_.provider-eq 'Ark' -and $null-ne $_.window}).Count){throw 'Stale Ark data remained current'}
 $live.observedAt+=181000
 $view=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $root 'widget.xaml'),[Text.Encoding]::UTF8))
 $script:ui=@{}
 foreach($name in @('Header','Status','LiveDot','WeekRow','ShortRow','CodexTitle','ArkTitle')){$script:ui[$name]=$view.FindName($name)}
 foreach($prefix in @('Short','Week','ArkShort','ArkWeek')){foreach($suffix in @('Row','Label','Used','Left','Reset','Bar')){$name=$prefix+$suffix;$script:ui[$name]=$view.FindName($name)}}
 $script:quotaProvider='Codex';$script:resetTimeMode='fixed';$script:statusStamp=0
 Update-Quota
 if($script:ui.ArkShortLeft.Text-eq ([string][char]0x2014) -or $script:ui.ArkWeekLeft.Text-eq ([string][char]0x2014)){throw 'Ark rows are empty despite successful query'}
 foreach($prefix in @('Short','Week','ArkShort','ArkWeek')){if($script:ui[$prefix+'Bar'].Width-gt 184){throw 'Quota bar exceeds its column'}}
 $girl=$view.FindName('Girl');$girl.Source=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $root 'assets/gpt-dragon-niang-bust.png'))
 $stage=$view.FindName('AnimationStage');$stage.Measure([Windows.Size]::new(378,378));$stage.Arrange([Windows.Rect]::new(0,0,378,378));$stage.UpdateLayout()
 $panel=$view.FindName('QuotaText')
 if($panel.ActualHeight-gt 115.1){throw ('Quota panel exceeds bubble: '+$panel.ActualHeight)}
 if($ImagePath){
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(756,756,192,192,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($stage)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create($ImagePath);try{$encoder.Save($stream)}finally{$stream.Dispose()}
 }
 Write-Output ('PASS: live Ark query, failures/staleness, four quota rows and bounds; values '+(@('Short','Week','ArkShort','ArkWeek')|ForEach-Object{$script:ui[$_+'Left'].Text}) -join ' ')
}finally{Stop-ArkQuotaRead}
