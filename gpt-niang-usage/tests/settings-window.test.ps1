param([string]$PreviewDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appDir=Split-Path $PSScriptRoot -Parent
. (Join-Path $script:appDir 'runtime/quotes.ps1')
. (Join-Path $script:appDir 'runtime/settings-window.ps1')
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('niang-settings-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($script:dataDir)|Out-Null
function Write-WidgetJson($Path,$Value){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))}
function Save-Settings {}
function Stop-WidgetMusic {}
function Test-WidgetMusicActive {return $false}
function Update-WidgetSettingsMenu {}
function Start-ProviderUsageQuery {$script:queryRequests++}
$script:window=[Windows.Window]::new();$script:window.Width=1;$script:window.Height=1;$script:window.Left=-10000;$script:window.Show()
$script:settingsMenuUi=@{};$script:settingsMenuResources=[Windows.ResourceDictionary]::new();$script:context=[Windows.Controls.ContextMenu]::new()
$script:musicFollowNetease=$true
try{
 Open-WidgetSettings
 $w=$script:settingsWindow
 if(!$w.FindName('Netease').IsChecked){throw 'Migration lost enabled NetEase'}
 Set-MusicSource 'spotify' $true
 Set-MusicSource 'netease' $false
 $saved=Get-Content (Join-Path $script:dataDir 'music-sources.json') -Raw|ConvertFrom-Json
 if(!$saved.spotify-or $saved.netease-or !$script:musicFollowNetease){throw 'Source selection persistence failed'}
 if($w.FindName('Tabs').SelectedIndex-ne 1){throw 'Usage must open by default'}
 if($w.FindName('Models')-or $w.FindName('BaseUrl')){throw 'Unused API fields must not appear'}
 if(@($script:providerSettings|Where-Object{$_.id-in @('gemini','custom')}).Count){throw 'Only queryable providers belong in the form'}
 if($w.WindowStyle-ne 'None'-or !$w.AllowsTransparency){throw 'Settings must be a borderless floating card'}
 $w.FindName('Provider').SelectedItem=@($script:providerSettings|Where-Object{$_.id-eq 'openai'})[0]
 $w.FindName('KeyEnv').Text='MY_USAGE_KEY';$w.FindName('ProviderEnabled').IsChecked=$true;Save-ProviderForm
 $providers=Get-Content (Join-Path $script:dataDir 'providers.json') -Raw|ConvertFrom-Json
 $savedProvider=@($providers|Where-Object{$_.id-eq 'openai'})[0]
 if($savedProvider.keyEnv-ne 'MY_USAGE_KEY'-or !$savedProvider.enabled){throw 'Query configuration did not persist'}
 if($w.FindName('AccountCards').Children.Count-ne 1){throw 'Enabled provider card missing'}
 $sample=[pscustomobject]@{source='本机 Codex';status='ok';input=100;output=20;note='验收说明不应显示'}
 if((Format-UsageRecord $sample)-match '验收|状态：|\bok\b'){throw 'Non-functional text leaked into UI'}
 $w.FindName('KeyEnv').Text='secret-with-dashes';Save-ProviderForm
 if($w.FindName('ProviderFeedback').Text-notmatch '环境变量名'){throw 'Invalid credential name was not rejected'}
 $w.FindName('Provider').SelectedItem=@($script:providerSettings|Where-Object{$_.id-eq 'openrouter'})[0]
 $w.FindName('ProviderEnabled').IsChecked=$true
 $w.FindName('ApiKey').Password='test-current-key-not-real';$w.FindName('ManagementKey').Password='test-management-key-not-real'
 Save-ProviderForm
 $savedText=[IO.File]::ReadAllText((Join-Path $script:dataDir 'providers.json'))
 if($savedText.Contains('test-current-key-not-real')-or $savedText.Contains('test-management-key-not-real')){throw 'Plaintext credential leaked to disk'}
 $savedOr=@((Get-ProviderSettings)|Where-Object{$_.id-eq 'openrouter'})[0]
 if((Unprotect-ProviderKey $savedOr.keyProtected)-ne 'test-current-key-not-real'){throw 'Encrypted key roundtrip failed'}
 if((Unprotect-ProviderKey $savedOr.managementKeyProtected)-ne 'test-management-key-not-real'){throw 'Encrypted management key roundtrip failed'}
 $request=New-ProviderQueryRequest;$requestSource=@($request.providers|Where-Object{$_.id-eq 'openrouter'})[0]
 if($requestSource.credentials.key-ne 'test-current-key-not-real'){throw 'Query request did not receive saved key'}
 $request=$null;$requestSource=$null
 if([Environment]::GetEnvironmentVariable($savedOr.keyEnv)){throw 'Credential leaked into parent environment'}
 Open-ProviderEditor 'openrouter'
 if($w.FindName('ApiKey').Password-or $w.FindName('ManagementKey').Password){throw 'Saved keys must not be revealed in editor'}
 Save-ProviderForm
 if(@((Get-ProviderSettings)|Where-Object{$_.id-eq 'openrouter'})[0].keyProtected-ne $savedOr.keyProtected){throw 'Blank edit must preserve saved key'}
 Clear-ProviderKeyDraft 'ApiKey';Save-ProviderForm
 if(@((Get-ProviderSettings)|Where-Object{$_.id-eq 'openrouter'})[0].keyProtected){throw 'Explicit clear did not remove saved key'}
 if($script:queryRequests-lt 4){throw 'Save must immediately request a refresh'}
 $w.FindName('CancelProvider').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
 $w.UpdateLayout()
 foreach($name in @('CloseSettings','AddProvider','QueryUsage')){
   $button=$w.FindName($name);if($null-ne $button.FocusVisualStyle){throw "Dotted focus outline on $name"}
   $point=$button.TranslatePoint([Windows.Point]::new($button.ActualWidth/2,$button.ActualHeight/2),$w)
   $hit=$w.InputHitTest($point);while($hit-and $hit-ne $button){$hit=[Windows.Media.VisualTreeHelper]::GetParent($hit)}
   if($hit-ne $button){throw "Button is covered: $name"}
 }
 Write-WidgetJson (Join-Path $script:dataDir 'providers.json') @(@{id='ark';enabled=$true},@{id='openrouter';enabled=$true;keyEnv='TEST_OR'},@{id='anthropic';enabled=$true;keyEnv='TEST_CLAUDE'})
 if(((Get-QuotaPageIds)-join ',')-ne 'Codex,ark,openrouter,anthropic'){throw 'Saved source order must survive reload'}
 $w.FindName('Tabs').SelectedIndex=3
 $w.FindName('QuoteLines').Text="第一句`n3 | 第二句"
 $w.FindName('SaveQuotes').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
 $quotes=Get-WidgetQuoteSettings $script:dataDir
 if($quotes.quotes.Count-ne 2-or $quotes.quotes[1].weight-ne 3){throw 'Inline quote save lost text or weight'}
 $w.FindName('QuoteLines').Text='字'*201;Save-SettingsQuotes
 if((Get-WidgetQuoteSettings $script:dataDir).quotes.Count-ne 2){throw 'Invalid draft overwrote saved quotes'}
 Load-SettingsQuotes
 $w.FindName('ResetQuotes').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
 if((Get-WidgetQuoteSettings $script:dataDir).source-ne 'built-in'){throw 'Inline defaults reset failed'}
 if($PreviewDirectory){
  [IO.Directory]::CreateDirectory($PreviewDirectory)|Out-Null
  foreach($tab in 0..3){
   if($tab-eq 1){Open-ProviderEditor 'openrouter'}
   $w.FindName('Tabs').SelectedIndex=$tab;$w.UpdateLayout()
   $frame=[Windows.Threading.DispatcherFrame]::new();$null=$w.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background,[Action]{$frame.Continue=$false});[Windows.Threading.Dispatcher]::PushFrame($frame)
   $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$w.ActualWidth,[int]$w.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($w)
   $png=[Windows.Media.Imaging.PngBitmapEncoder]::new();$png.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $PreviewDirectory ('settings-'+$tab+'.png')));try{$png.Save($stream)}finally{$stream.Dispose()}
  }
 }
 'PASS: floating window, visible hit targets, no dotted focus, source order persistence, preferences, all tabs render'
}finally{$script:settingsShutdown=$true;if($script:settingsTimer){$script:settingsTimer.Stop()};if($script:settingsWindow){$script:settingsWindow.Close()};$script:window.Close();Remove-Item -LiteralPath $script:dataDir -Recurse -Force}
