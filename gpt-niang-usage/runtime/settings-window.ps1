$script:musicSources=$null
$script:usageProcess=$null
function Initialize-MusicSources {
  if($null-ne $script:musicSources){return}
  $file=Join-Path $script:dataDir 'music-sources.json'
  $script:musicSources=@{netease=[bool]$script:musicFollowNetease;qqmusic=$false;spotify=$false}
  if(Test-Path -LiteralPath $file){
    try{$saved=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)|ConvertFrom-Json;foreach($id in @('netease','qqmusic','spotify')){$script:musicSources[$id]=($saved.$id-eq $true)}}catch{$script:musicLastError='音乐来源配置读取失败：'+$_.Exception.Message}
  }else{Write-WidgetJson $file $script:musicSources}
}
function Set-MusicSource([string]$Id,[bool]$Enabled) {
  Initialize-MusicSources
  $script:musicSources[$Id]=$Enabled
  Write-WidgetJson (Join-Path $script:dataDir 'music-sources.json') $script:musicSources
  $script:musicFollowNetease=@($script:musicSources.Values|Where-Object{$_}).Count-gt 0
  if(!$script:musicFollowNetease){Stop-WidgetMusic}
  Save-Settings
}
function Protect-ProviderKey([string]$Value) {
  if(!$Value-or $Value.Length-gt 8192-or $Value-match '\s'){throw '密钥格式无效，请重新粘贴。'}
  Add-Type -AssemblyName System.Security
  $bytes=[Text.Encoding]::UTF8.GetBytes($Value)
  try{return [Convert]::ToBase64String([Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser))}finally{[Array]::Clear($bytes,0,$bytes.Length)}
}
function Unprotect-ProviderKey([string]$Value) {
  Add-Type -AssemblyName System.Security
  try{
    $bytes=[Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($Value),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    try{return [Text.Encoding]::UTF8.GetString($bytes)}finally{[Array]::Clear($bytes,0,$bytes.Length)}
  }catch{throw '无法解密已保存密钥，请重新粘贴并保存。'}
}
function Clear-ProviderKeyDraft([string]$Slot) {
  $box=$script:settingsWindow.FindName($Slot);$box.Clear();$box.Tag='clear'
  $script:settingsWindow.FindName($Slot+'State').Text='保存后清除'
}
function New-ProviderQueryRequest {
  $items=@(foreach($p in @(Get-ProviderSettings|Where-Object{$_.enabled-and $_.id-ne 'ark'})){
    $keys=@{}
    if($p.keyProtected){$keys.key=Unprotect-ProviderKey $p.keyProtected}
    if($p.id-eq 'openrouter'-and $p.managementKeyProtected){$keys.managementKey=Unprotect-ProviderKey $p.managementKeyProtected}
    @{id=$p.id;name=$p.name;enabled=$true;keyEnv=$p.keyEnv;managementKeyEnv=$p.managementKeyEnv;credentials=$keys}
  })
  return @{requestId=[Guid]::NewGuid().ToString('N');providers=$items}
}
function Get-ProviderSettings {
  $defaults=@(
    @{id='ark';name='Ark';keyEnv='';enabled=(Test-Path -LiteralPath (Join-Path $script:dataDir 'ark-connection.json'))},
    @{id='openrouter';name='OpenRouter';keyEnv='OPENROUTER_API_KEY';enabled=$false},
    @{id='openai';name='OpenAI';keyEnv='OPENAI_ADMIN_KEY';enabled=$false},
    @{id='anthropic';name='Claude API';keyEnv='ANTHROPIC_ADMIN_KEY';enabled=$false},
    @{id='deepseek';name='DeepSeek';keyEnv='DEEPSEEK_API_KEY';enabled=$false},
    @{id='siliconflow';name='硅基流动';keyEnv='SILICONFLOW_API_KEY';enabled=$false}
  )|ForEach-Object{$_.keyProtected='';$_.managementKeyProtected='';$_.managementKeyEnv=if($_.id-eq 'openrouter'){'OPENROUTER_MANAGEMENT_KEY'}else{''};[pscustomobject]$_}
  $file=Join-Path $script:dataDir 'providers.json'
  if(Test-Path -LiteralPath $file){
    # PS 5.1 emits a JSON array as one pipeline object; an outer @() nests it.
    $saved=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($file,[Text.Encoding]::UTF8))
    $ordered=@();$seen=@{}
    foreach($old in $saved){$p=@($defaults|Where-Object{$_.id-eq $old.id})|Select-Object -First 1;if(!$p-or $seen.ContainsKey($p.id)){continue};$seen[$p.id]=$true;$p.enabled=[bool]$old.enabled;$p.keyEnv=[string]$old.keyEnv;$p.keyProtected=[string]$old.keyProtected;$p.managementKeyProtected=[string]$old.managementKeyProtected;if($old.managementKeyEnv){$p.managementKeyEnv=[string]$old.managementKeyEnv};$ordered+=,$p}
    # Existing Ark connections predate the ordered source list.
    if(!$seen.ContainsKey('ark')){$ordered=@($defaults[0])+$ordered;$seen['ark']=$true}
    $defaults=@($ordered)+@($defaults|Where-Object{!$seen.ContainsKey($_.id)})
  }
  return $defaults
}
function Set-ProviderForm {
  $w=$script:settingsWindow;$p=$w.FindName('Provider').SelectedItem;if(!$p){return}
  $w.FindName('ProviderEnabled').IsChecked=[bool]$p.enabled
  $w.FindName('KeyEnv').Text=[string]$p.keyEnv
  $w.FindName('DirectCredential').Visibility=if($p.id-eq 'ark'){'Collapsed'}else{'Visible'}
  $w.FindName('CredentialLabel').Visibility=$w.FindName('DirectCredential').Visibility
  $w.FindName('LegacyCredentials').Visibility=$w.FindName('DirectCredential').Visibility
  $w.FindName('LegacyCredentials').IsExpanded=$false
  $w.FindName('ManagementCredential').Visibility=if($p.id-eq 'openrouter'){'Visible'}else{'Collapsed'}
  $w.FindName('ManagementKeyEnv').Text=[string]$p.managementKeyEnv
  $w.FindName('LegacyManagementCredential').Visibility=$w.FindName('ManagementCredential').Visibility
  foreach($slot in @('ApiKey','ManagementKey')){$w.FindName($slot).Clear();$w.FindName($slot).Tag=$null}
  $w.FindName('ApiKeyState').Text=if($p.keyProtected){'已保存 · 留空保持不变'}else{'粘贴 API 密钥'}
  $w.FindName('ManagementKeyState').Text=if($p.managementKeyProtected){'已保存 · 留空保持不变'}else{'未配置'}
  $admin=$p.id-in @('openai','anthropic')
  $w.FindName('QueryKind').Text=if($p.id-eq 'ark'){'查询类型 · Coding Plan'}elseif($p.id-eq 'openrouter'){'查询类型 · Credit 与当前 Key 限额'}elseif($admin){'查询类型 · 账户 token · 最近 7 天'}else{'查询类型 · 账户余额'}
  $w.FindName('CredentialLabel').Text=if($admin){'管理密钥'}else{'API 密钥'}
}
function Save-ProviderForm {
  try{
    $w=$script:settingsWindow;$p=$w.FindName('Provider').SelectedItem
    $envName=$w.FindName('KeyEnv').Text.Trim()
    $encrypted=[string]$p.keyProtected;$encryptedManagement=[string]$p.managementKeyProtected
    if($w.FindName('ApiKey').Tag-eq 'clear'){$encrypted=''}
    if($w.FindName('ManagementKey').Tag-eq 'clear'){$encryptedManagement=''}
    $key=$w.FindName('ApiKey').Password.Trim();$managementKey=$w.FindName('ManagementKey').Password.Trim()
    if($p.id-ne 'ark'-and $key){$encrypted=Protect-ProviderKey $key;$envName='GPT_NIANG_USAGE_'+$p.id.ToUpperInvariant()+'_KEY'}
    if($p.id-ne 'ark' -and $envName-notmatch '^[A-Za-z_][A-Za-z0-9_]*$'){throw '请输入有效的密钥环境变量名。'}
    $management=$w.FindName('ManagementKeyEnv').Text.Trim()
    if($p.id-eq 'openrouter'-and $managementKey){$encryptedManagement=Protect-ProviderKey $managementKey;$management='GPT_NIANG_USAGE_OPENROUTER_MANAGEMENT_KEY'}
    if($p.id-eq 'openrouter'-and $management-and $management-notmatch '^[A-Za-z_][A-Za-z0-9_]*$'){throw '请输入有效的管理密钥环境变量名。'}
    if($encrypted-and $envName-ne ('GPT_NIANG_USAGE_'+$p.id.ToUpperInvariant()+'_KEY')){throw '请先清除已保存密钥，再切换环境变量。'}
    if($encryptedManagement-and $management-ne 'GPT_NIANG_USAGE_OPENROUTER_MANAGEMENT_KEY'){throw '请先清除已保存管理密钥，再切换环境变量。'}
    $wasEnabled=$p.enabled;$p.enabled=[bool]$w.FindName('ProviderEnabled').IsChecked;$p.keyEnv=$envName;$p.managementKeyEnv=$management;$p.keyProtected=$encrypted;$p.managementKeyProtected=$encryptedManagement
    if($p.enabled-and !$wasEnabled){$script:providerSettings=@($script:providerSettings|Where-Object{$_.id-ne $p.id})+@($p)}
    Write-WidgetJson (Join-Path $script:dataDir 'providers.json') @($script:providerSettings)
    $verified=@(Get-ProviderSettings|Where-Object{$_.id-eq $p.id})[0]
    if($verified.keyProtected-ne $encrypted-or $verified.managementKeyProtected-ne $encryptedManagement-or $verified.enabled-ne $p.enabled){throw '保存校验失败，请重试。'}
    $w.FindName('ProviderFeedback').Text='已保存'
    $w.FindName('ProviderEditorCard').Visibility='Collapsed'
    Update-AccountCards $script:usageResult
    $script:providerNextQuery=0L
    Set-ProviderForm
    Start-ProviderUsageQuery
  }catch{$script:settingsWindow.FindName('ProviderFeedback').Text=$_.Exception.Message}
  finally{$key=$null;$managementKey=$null}
}
function Open-ProviderEditor([string]$Id) {
  $w=$script:settingsWindow
  if($Id){$w.FindName('Provider').SelectedItem=@($script:providerSettings|Where-Object{$_.id-eq $Id})[0]}
  else{$next=@($script:providerSettings|Where-Object{!$_.enabled})|Select-Object -First 1;if($next){$w.FindName('Provider').SelectedItem=$next};$w.FindName('ProviderEnabled').IsChecked=$true}
  Set-ProviderForm
  if(!$Id){$w.FindName('ProviderEnabled').IsChecked=$true}
  $w.FindName('ProviderFeedback').Text=''
  $w.FindName('ProviderEditorCard').Visibility='Visible'
  $w.FindName('ProviderEditorCard').BringIntoView()
}
function Update-AccountCards($Result) {
  $panel=$script:settingsWindow.FindName('AccountCards');$arkCard=$script:settingsWindow.FindName('ArkCard')
  if($arkCard.Parent){$arkCard.Parent.Children.Remove($arkCard)}
  $panel.Children.Clear()
  foreach($p in @($script:providerSettings|Where-Object{$_.enabled})){
    if($p.id-eq 'ark'){$panel.Children.Add($arkCard)|Out-Null;continue}
    $card=[Windows.Controls.Border]::new();$card.Style=$script:settingsWindow.FindResource('Card')
    $body=[Windows.Controls.StackPanel]::new();$head=[Windows.Controls.DockPanel]::new()
    $edit=[Windows.Controls.Button]::new();$edit.Content='编辑';$edit.Tag=$p.id
    [Windows.Controls.DockPanel]::SetDock($edit,[Windows.Controls.Dock]::Right)
    $edit.Add_Click({param($sender,$event)Open-ProviderEditor ([string]$sender.Tag)})
    $head.Children.Add($edit)|Out-Null
    $title=[Windows.Controls.TextBlock]::new();$title.Text=$p.name;$title.Style=$script:settingsWindow.FindResource('Heading');$head.Children.Add($title)|Out-Null
    $body.Children.Add($head)|Out-Null
    $saved=[Windows.Controls.TextBlock]::new();$saved.Style=$script:settingsWindow.FindResource('Caption')
    $saved.Text=if($p.keyProtected){'API 密钥已保存'}else{'API 密钥：环境配置'}
    if($p.id-eq 'openrouter'){$saved.Text+=if($p.managementKeyProtected){' · 管理密钥已保存'}else{' · 管理密钥未保存'}}
    $body.Children.Add($saved)|Out-Null
    $record=@($Result.accounts|Where-Object{$_.provider-eq $p.id})|Select-Object -First 1
    if($record-and (Test-CreditRecord $record)){$body.Children.Add((New-CreditPanel (Get-CreditView $record)))|Out-Null}
    else{$text=[Windows.Controls.TextBlock]::new();$text.Text=if($record){Format-UsageRecord $record -HideSource}else{'尚未查询'};$text.LineHeight=25;$body.Children.Add($text)|Out-Null}
    $card.Child=$body;$panel.Children.Add($card)|Out-Null
  }
}
function Convert-SettingsSection($Section,[bool]$Top=$false) {
  $panel=[Windows.Controls.StackPanel]::new()
  foreach($item in @($Section.Items)){
    if($item.HasItems){
      $sub=Convert-SettingsSection $item
      $expand=[Windows.Controls.Expander]::new();$expand.Header=[string]$item.Header;$expand.Content=$sub;$expand.Margin=[Windows.Thickness]::new(0,6,0,6)
      $panel.Children.Add($expand)|Out-Null;continue
    }
    if(!$item.IsHitTestVisible){continue}
    $header=$item.Header
    $description=$header-is [Windows.Controls.StackPanel] -and $header.Children.Count-eq 2 -and $header.Children[0]-is [Windows.Controls.TextBlock] -and $header.Children[1]-is [Windows.Controls.TextBlock]
    if($header-is [Windows.UIElement] -and !$description){
      $item.Header=$null;$panel.Children.Add($header)|Out-Null;continue
    }
    $label=if($description){$header.Children[0].Text}else{[string]$header}
    if($item.IsCheckable){
      $control=[Windows.Controls.CheckBox]::new();$control.Content=$label;$control.IsChecked=$item.IsChecked;$control.Tag=$item
      $control.Add_Click({param($sender,$event)$original=$sender.Tag;$original.IsChecked=[bool]$sender.IsChecked;$original.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent));Update-WidgetSettingsMenu})
    }else{
      $control=[Windows.Controls.Button]::new();$control.Content=$label;$control.HorizontalAlignment='Left';$control.Tag=$item
      $control.Add_Click({param($sender,$event)$sender.Tag.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent));Update-WidgetSettingsMenu})
    }
    $control.IsEnabled=$item.IsEnabled;$script:settingsControls+=,$control;$panel.Children.Add($control)|Out-Null
  }
  return ,$panel
}
function Set-UsageFeedback([string]$Text) {if($script:settingsWindow){$script:settingsWindow.FindName('ProviderFeedback').Text=$Text}}
function Start-ProviderUsageQuery {
  if($script:usageProcess-and !$script:usageProcess.HasExited){$script:providerQueryPending=$true;return}
  if($script:usageProcess){$script:usageProcess.Dispose();$script:usageProcess=$null}
  $script:providerQueryPending=$false
  try{
    $script:usageQueryFailed=$false
    $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$script:config.nodePath
    $start.Arguments='"'+(Join-Path $script:appDir 'runtime/provider-usage.mjs')+'" "'+$script:dataDir+'" --credentials-stdin'
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.RedirectStandardInput=$true
    $request=New-ProviderQueryRequest
    $script:providerRequestId=$request.requestId
    $script:usageProcess=[Diagnostics.Process]::Start($start)
    $script:usageOut=$script:usageProcess.StandardOutput.ReadToEndAsync();$script:usageErr=$script:usageProcess.StandardError.ReadToEndAsync()
    $payload=[Text.Encoding]::UTF8.GetBytes(($request|ConvertTo-Json -Depth 8 -Compress))
    try{$script:usageProcess.StandardInput.BaseStream.Write($payload,0,$payload.Length)}finally{[Array]::Clear($payload,0,$payload.Length);$payload=$null}
    $script:usageProcess.StandardInput.Close();$request=$null
    $script:usageStarted=[DateTime]::UtcNow;$script:arkNextRead=0L
    $script:providerNextQuery=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+60000
    Set-UsageFeedback '查询中…'
  }catch{$script:usageQueryFailed=$true;if($script:usageProcess-and !$script:usageProcess.HasExited){$script:usageProcess.Kill()};Set-UsageFeedback ('查询启动失败：'+$_.Exception.Message)}
  finally{$request=$null}
}
function Sync-ProviderUsage {
  if($script:usageProcess){
    if(!$script:usageProcess.HasExited-and ([DateTime]::UtcNow-$script:usageStarted).TotalMinutes-gt 3){$script:usageProcess.Kill();$script:usageQueryFailed=$true}
    if($script:usageProcess.HasExited){
      $ok=$script:usageProcess.ExitCode-eq 0-and !$script:usageQueryFailed
      if($ok){try{$completed=[IO.File]::ReadAllText((Join-Path $script:dataDir 'provider-usage.json'))|ConvertFrom-Json;$ok=$completed.requestId-eq $script:providerRequestId}catch{$ok=$false}}
      $script:usageProcess.Dispose();$script:usageProcess=$null
      if(!$script:collapsed-and $script:bubbleMode-eq 'quota'-and $script:quotaProvider-notin @('Codex','Ark')){Restart-SceneTtl}
      Set-UsageFeedback $(if($ok){''}else{'查询失败，请重试'})
      if(!$ok){$script:usageQueryFailed=$true}
    }
  }
  $file=Join-Path $script:dataDir 'provider-usage.json'
  if((Test-Path -LiteralPath $file)-and !$script:usageQueryFailed){try{$script:usageResult=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)|ConvertFrom-Json}catch{$script:usageQueryFailed=$true;Set-UsageFeedback '用量读取失败'}}
  if($script:providerQueryPending-and !$script:usageProcess){$script:providerQueryPending=$false;Start-ProviderUsageQuery}
}
function Get-QuotaPageIds {
  @('Codex')+@((Get-ProviderSettings)|Where-Object{$_.enabled}|ForEach-Object{$_.id})
}
function Request-ProviderBubble {
  if($script:quotaProvider-eq 'Ark'){$script:arkNextRead=0L;return}
  if($script:quotaProvider-eq 'Codex'){return}
  if([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-ge [long]$script:providerNextQuery){Start-ProviderUsageQuery}
}
function Test-CreditRecord($Record) {
  return $Record.kind-in @('openrouter','balance')-or $Record.provider-in @('openrouter','deepseek','siliconflow')
}
function Get-CreditView($Record) {
  $view=@{limit='当前 Key limit：未提供';usage='Key 消耗：未提供';balance='总余额：未提供';percent=$null}
  $key=$Record.keyLimit
  if($key.status-eq 'ok'){
    if($null-eq $key.limit){
      $view.limit='当前 Key limit：未设限额'
      $view.usage=if($null-ne $key.usage){'Key 消耗 $'+([double]$key.usage).ToString('0.##')+' · 无上限'}else{'Key 消耗：未提供 · 无上限'}
    }else{
      $limit=[double]$key.limit;$view.limit='当前 Key limit：$'+$limit.ToString('0.##')
      if($null-ne $key.remaining){
        $used=[Math]::Max(0,$limit-[double]$key.remaining)
        $view.usage='Key 消耗 $'+$used.ToString('0.##')+' / $'+$limit.ToString('0.##')
        if($limit-gt 0){$view.percent=[Math]::Max(0,[Math]::Min(100,100*$used/$limit))}
      }
    }
  }elseif($key.status){
    $error=if($key.status-eq 'unconfigured'){'未配置密钥'}else{'查询失败'}
    $view.limit='当前 Key limit：'+$error;$view.usage='Key 消耗：'+$error
  }
  if($Record.kind-eq 'openrouter'){
    $view.balance=if($Record.credits.status-eq 'ok'){'总余额：$'+([double]$Record.credits.remaining).ToString('0.##')}elseif($Record.credits.status-eq 'unconfigured'){'总余额：未配置管理密钥'}else{'总余额：查询失败'}
  }elseif($Record.status-eq 'ok'){
    $view.balance='总余额：'+(($Record.balances|ForEach-Object{$_.remaining+' '+$_.currency})-join ' / ')
  }elseif($Record.status){$view.balance='总余额：'+$(if($Record.status-eq 'unconfigured'){'未配置密钥'}else{'查询失败'})}
  return $view
}
function Format-CreditView($View){return @($View.limit,$View.usage,$View.balance)-join "`n"}
function New-CreditPanel($View,[switch]$Compact) {
  $panel=[Windows.Controls.StackPanel]::new()
  foreach($line in @($View.limit,$View.usage)){
    $text=[Windows.Controls.TextBlock]::new();$text.Text=$line;$text.TextWrapping='Wrap';$text.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#745A98')
    $text.FontSize=if($Compact){11.5}else{14};$text.LineHeight=if($Compact){16}else{23};$panel.Children.Add($text)|Out-Null
  }
  $bar=[Windows.Controls.ProgressBar]::new();$bar.Minimum=0;$bar.Maximum=100;$bar.Value=if($null-ne $View.percent){$View.percent}else{0};$bar.Height=if($Compact){5}else{7};$bar.Margin=[Windows.Thickness]::new(0,4,0,5)
  $bar.Template=[Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="ProgressBar"><Grid><Border x:Name="PART_Track" Background="#EAE4F3" CornerRadius="3"/><Border x:Name="PART_Indicator" Background="#AA95CD" HorizontalAlignment="Left" CornerRadius="3"/></Grid></ControlTemplate>
'@)
  if($null-eq $View.percent){$bar.Opacity=.45;$bar.ToolTip='无可用比例'}else{$bar.ToolTip='已消耗 '+([double]$View.percent).ToString('0.#')+'%'}
  $panel.Children.Add($bar)|Out-Null
  $balance=[Windows.Controls.TextBlock]::new();$balance.Text=$View.balance;$balance.TextWrapping='Wrap';$balance.FontSize=if($Compact){12}else{15};$balance.LineHeight=if($Compact){17}else{24};$balance.FontWeight='SemiBold';$balance.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#745A98');$panel.Children.Add($balance)|Out-Null
  return ,$panel
}
function Update-ProviderBubble {
  if($script:quotaProvider-eq 'Codex'){$script:ui.Header.Text='Codex 剩余额度';return}
  if($script:quotaProvider-eq 'Ark'){$script:ui.Header.Text='Ark 剩余额度';return}
  $p=@((Get-ProviderSettings)|Where-Object{$_.id-eq $script:quotaProvider})|Select-Object -First 1
  $script:ui.Header.Text=if($p){$p.name}else{'用量'}
  $creditRecord=$null
  $text=if($script:usageQueryFailed){'查询失败 · 点击 ↻ 重试'}elseif($script:usageProcess){'查询中…'}else{
    $record=@($script:usageResult.accounts|Where-Object{$_.provider-eq $script:quotaProvider})|Select-Object -First 1
    if(!$record){'尚未查询 · 点击 ↻ 刷新'}elseif($script:usageResult.at-and ([DateTimeOffset]::UtcNow-[DateTimeOffset]::Parse($script:usageResult.at)).TotalMinutes-gt 3){'数据已过期 · 点击 ↻ 刷新'}else{if(Test-CreditRecord $record){$creditRecord=$record};Format-ProviderBubble $record}
  }
  $script:window.FindName('ProviderQuotaText').Text=$text
  $creditHost=$script:window.FindName('CreditQuotaContent')
  $creditHost.Visibility=if($creditRecord){'Visible'}else{'Collapsed'}
  $script:window.FindName('ProviderQuotaText').Visibility=if($creditRecord){'Collapsed'}else{'Visible'}
  if($creditRecord){$view=Get-CreditView $creditRecord;$signature=$view|ConvertTo-Json -Compress;if($creditHost.Tag-ne $signature){$creditHost.Content=New-CreditPanel $view -Compact;$creditHost.Tag=$signature}}
}
function Format-ProviderBubble($Record) {
  if(Test-CreditRecord $Record){return Format-CreditView (Get-CreditView $Record)}
  if($Record.status-ne 'ok'){return Format-UsageRecord $Record -HideSource}
  if($Record.kind-eq 'balance'){return ($Record.balances|ForEach-Object{'余额 '+$_.remaining+' '+$_.currency})-join "`n"}
  $lines=@('近 7 天 · token 用量',('输入 '+([double]$Record.input).ToString('N0')),('输出 '+([double]$Record.output).ToString('N0')))
  if($Record.provider-eq 'anthropic'){$lines+='剩余额度：接口未提供'}
  return $lines-join "`n"
}
function Format-UsageRecord($Record,[switch]$HideSource) {
  if(Test-CreditRecord $Record){return Format-CreditView (Get-CreditView $Record)}
  $lines=@()
  if(!$HideSource){$lines+=if($Record.source-match 'Codex'){'Codex'}elseif($Record.source-match 'OpenCode'){'OpenCode'}else{[string]$Record.source}}
  $status=switch([string]$Record.status){'ok'{''};'partial'{'部分记录读取失败'};'no_data'{'暂无记录'};'unconfigured'{'未配置查询凭据'};'unsupported'{'暂不支持查询'};default{'查询失败'}}
  if($status){$lines+=$status}
  if($Record.status-in @('ok','partial')){
    foreach($field in @(@('input','输入'),@('output','输出'),@('cached','缓存读取'),@('cacheWrite','缓存写入'),@('reasoning','推理'))){
      if($null-ne $Record.($field[0])){$lines+=($field[1]+'  '+([double]$Record.($field[0])).ToString('N0')+' token')}
    }
    foreach($balance in $Record.balances){$lines+=('余额  '+$balance.remaining+' '+$balance.currency)}
    if($Record.kind-eq 'tokens'){$lines+='账户 · 最近 7 天'}
  }
  return $lines-join "`n"
}
function Update-SettingsWindow {
  if(!$script:settingsWindow-or !$script:settingsWindow.IsVisible){return}
  $w=$script:settingsWindow
  foreach($control in $script:settingsControls){$control.IsEnabled=$control.Tag.IsEnabled;if($control-is [Windows.Controls.CheckBox]){$control.IsChecked=$control.Tag.IsChecked}}
  $w.FindName('FollowMusic').IsChecked=[bool]$script:musicFollowNetease
  $w.FindName('ManualMusic').IsChecked=(!$script:musicFollowNetease-and (Test-WidgetMusicActive))
  $w.FindName('Lights').IsChecked=[bool]$script:musicLightsEnabled;$w.FindName('Horizontal').IsChecked=[bool]$script:musicHorizontalEnabled
  foreach($spec in @(@('Netease','netease'),@('QQMusic','qqmusic'),@('Spotify','spotify'))){$w.FindName($spec[0]).IsChecked=[bool]$script:musicSources[$spec[1]]}
  $rows=@();foreach($spec in @(@('netease','网易云'),@('qqmusic','QQ 音乐'),@('spotify','Spotify'))){
    $p=@($script:musicNowPlaying.players|Where-Object{$_.provider-eq $spec[0]})|Select-Object -First 1
    $state=if(!$p-or !$p.connected){'未连接'}elseif($p.playing){'播放中 · '+$p.title}else{'已暂停'}
    $controlName=@{netease='NeteaseState';qqmusic='QQMusicState';spotify='SpotifyState'}[$spec[0]];$w.FindName($controlName).Text=$state
    if($p.error-and $p.error-ne 'PLAYER_NOT_DETECTED'){$rows+=('读取失败：'+$p.error)}
    if($p.warning){$rows+=('桌面控制连接异常：'+$p.warning)}
  }
  if($script:musicLastError){$rows+='音乐错误：'+$script:musicLastError}
  $w.FindName('MusicState').Text=$rows-join "`n"
  $ark=$script:arkStatus
  $text=if(!$ark){'尚未查询'}elseif(!$ark.queryOk){'读取失败：'+$ark.error}elseif(([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$ark.observedAt)-gt 180000){'数据已过期，请重新查询'}else{
    (@($ark.windows|ForEach-Object{($(if($_.minutes-eq 300){'5 小时'}else{'每周'}))+'：剩余 '+$_.remaining+'%'}))-join "`n"
  }
  $w.FindName('ArkUsage').Text=$text
  $w.FindName('ArkCard').Visibility=if(@($script:providerSettings|Where-Object{$_.id-eq 'ark'-and $_.enabled}).Count){'Visible'}else{'Collapsed'}
  Sync-ProviderUsage
  $file=Join-Path $script:dataDir 'provider-usage.json'
  if((Test-Path -LiteralPath $file)-and !$script:usageQueryFailed){
    try{$result=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)|ConvertFrom-Json
      $w.FindName('LocalUsage').Text=($result.local|ForEach-Object{Format-UsageRecord $_})-join "`n`n"
      $w.FindName('UsageTime').Text='更新于 '+([DateTimeOffset]::Parse($result.at).ToLocalTime().ToString('MM-dd HH:mm'))
      if($script:usageRenderedAt-ne $result.at){$script:usageRenderedAt=$result.at;Update-AccountCards $result}
    }catch{$w.FindName('ProviderFeedback').Text='用量结果读取失败。'}
  }
}
function Load-SettingsQuotes {
  $current=Get-WidgetQuoteSettings $script:dataDir
  $script:settingsWindow.FindName('QuoteLines').Text=($current.quotes|ForEach-Object{if($_.weight-eq 1){$_.text}else{$_.weight.ToString([Globalization.CultureInfo]::InvariantCulture)+' | '+$_.text}})-join [Environment]::NewLine
  $script:settingsWindow.FindName('QuoteFeedback').Text=[string]$current.error
}
function Save-SettingsQuotes {
  try{
    $rows=@(foreach($line in ($script:settingsWindow.FindName('QuoteLines').Text -split '\r?\n')){
      $text=$line.Trim();if(!$text){continue};$weight=1.0
      if($text-match '^\s*(\d+(?:\.\d+)?)\s*\|\s*(.*)$'){$text=$Matches[2].Trim();$weight=[double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture)}
      if(!$text-or $text.Length-gt 200-or $weight-le 0-or $weight-gt 1000-or [double]::IsInfinity($weight)){throw '每句须为 1–200 字，权重须大于 0 且不超过 1000。'}
      @{text=$text;weight=$weight}
    })
    $null=Save-WidgetQuotes $script:dataDir $rows
    $script:settingsWindow.FindName('QuoteFeedback').Text='已保存'
  }catch{$script:settingsWindow.FindName('QuoteFeedback').Text=$_.Exception.Message}
}
function Open-WidgetSettings([int]$Tab=1) {
  Initialize-MusicSources
  if($script:settingsWindow-and $script:settingsWindow.IsVisible){$script:settingsWindow.FindName('Tabs').SelectedIndex=$Tab;$script:settingsWindow.Activate()|Out-Null;if($Tab-eq 1-and [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-ge [long]$script:providerNextQuery){Start-ProviderUsageQuery};return}
  if(!$script:settingsWindow){
    $w=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/settings-window.xaml'),[Text.Encoding]::UTF8));$script:settingsWindow=$w
    $w.Owner=$script:window
    $w.Add_IsVisibleChanged({param($sender,$event)if(!$sender.IsVisible){foreach($slot in @('ApiKey','ManagementKey')){$sender.FindName($slot).Clear();$sender.FindName($slot).Tag=$null}}})
    $w.MaxHeight=[Windows.SystemParameters]::WorkArea.Height-24;$w.MaxWidth=[Windows.SystemParameters]::WorkArea.Width-24
    $w.FindName('CloseSettings').Add_Click({$script:settingsWindow.Hide()})
    $w.FindName('WindowHeader').Add_MouseLeftButtonDown({param($sender,$event)
      $node=$event.OriginalSource
      while($node-and $node-ne $sender){if($node-is [Windows.Controls.Primitives.ButtonBase]){return};$node=[Windows.Media.VisualTreeHelper]::GetParent($node)}
      if($node-eq $sender){$script:settingsWindow.DragMove();$event.Handled=$true}
    })
    $w.FindName('EditArk').Add_Click({Open-ProviderEditor 'ark'})
    $w.Resources['SettingsSubmenuWidth']=[double]320
    $w.Resources['SettingsSubmenuMaxHeight']=[double]500
    $w.Resources.MergedDictionaries.Add($script:settingsMenuResources)
    $script:settingsControls=@()
    foreach($id in @('Appearance','Audio','AutoQuotes','Display','Updates')){
      $item=$script:settingsMenuUi[$id];if(!$item){continue}
      $script:context.Items.Remove($item)
      $card=[Windows.Controls.Border]::new();$card.Style=$w.FindResource('Card');$body=[Windows.Controls.StackPanel]::new()
      $heading=[Windows.Controls.TextBlock]::new();$heading.Text=[string]$item.Header;$heading.Style=$w.FindResource('Heading');$body.Children.Add($heading)|Out-Null
      $body.Children.Add((Convert-SettingsSection $item $true))|Out-Null;$card.Child=$body
      $target=if($id-eq 'AutoQuotes'){'QuoteSettings'}else{'ExistingSettings'}
      $w.FindName($target).Children.Add($card)|Out-Null
    }
    foreach($spec in @(@('Netease','netease'),@('QQMusic','qqmusic'),@('Spotify','spotify'))){$c=$w.FindName($spec[0]);$c.IsChecked=[bool]$script:musicSources[$spec[1]];$c.Add_Click({param($s,$e)Set-MusicSource ([string]$s.Tag) ([bool]$s.IsChecked)})}
    $w.FindName('ManualMusic').IsChecked=(!$script:musicFollowNetease-and (Test-WidgetMusicActive))
    $w.FindName('FollowMusic').Add_Click({param($s,$e)Set-WidgetMusicFollowNetease ([bool]$s.IsChecked)})
    $w.FindName('ManualMusic').Add_Click({param($s,$e)Set-WidgetManualMusic ([bool]$s.IsChecked)})
    $w.FindName('Lights').IsChecked=$script:musicLightsEnabled;$w.FindName('Lights').Add_Click({param($s,$e)Set-WidgetMusicLights ([bool]$s.IsChecked)})
    $w.FindName('Horizontal').IsChecked=$script:musicHorizontalEnabled;$w.FindName('Horizontal').Add_Click({param($s,$e)Set-WidgetMusicHorizontal ([bool]$s.IsChecked)})
    $w.FindName('Reconnect').Add_Click({Stop-WidgetMusicBridge;try{Start-WidgetMusicBridge;$script:settingsWindow.FindName('Feedback').Text='连接中…'}catch{$script:settingsWindow.FindName('Feedback').Text=$_.Exception.Message}})
    foreach($spec in @(@('OpenNetease','orpheus://'),@('OpenQQ','qqmusic://'),@('OpenSpotify','spotify:'))){$b=$w.FindName($spec[0]);$b.Tag=$spec[1];$b.Add_Click({param($s,$e)try{Start-Process ([string]$s.Tag);$script:settingsWindow.FindName('Feedback').Text=''}catch{$script:settingsWindow.FindName('Feedback').Text='无法打开播放器，请确认已经安装。'}})}
    $w.FindName('Characters').Add_Click({Open-WidgetCharacterGallery})
    Load-SettingsQuotes
    $w.FindName('SaveQuotes').Add_Click({Save-SettingsQuotes})
    $w.FindName('ResetQuotes').Add_Click({try{$null=Reset-WidgetQuotes $script:dataDir;Load-SettingsQuotes;$script:settingsWindow.FindName('QuoteFeedback').Text='已恢复内置台词'}catch{$script:settingsWindow.FindName('QuoteFeedback').Text=$_.Exception.Message}})
    $script:providerSettings=@(Get-ProviderSettings);$w.FindName('Provider').ItemsSource=$script:providerSettings
    $w.FindName('Provider').Add_SelectionChanged({Set-ProviderForm});$w.FindName('Provider').SelectedIndex=0;Update-AccountCards $null
    $w.FindName('ClearApiKey').Add_Click({Clear-ProviderKeyDraft 'ApiKey'})
    $w.FindName('ClearManagementKey').Add_Click({Clear-ProviderKeyDraft 'ManagementKey'})
    $w.FindName('AddProvider').Add_Click({Open-ProviderEditor ''});$w.FindName('CancelProvider').Add_Click({$script:settingsWindow.FindName('ProviderEditorCard').Visibility='Collapsed';$script:settingsWindow.FindName('ProviderFeedback').Text=''});$w.FindName('SaveProvider').Add_Click({Save-ProviderForm});$w.FindName('QueryUsage').Add_Click({Start-ProviderUsageQuery})
    $w.Add_Closing({param($s,$e)if(!$script:settingsShutdown){$e.Cancel=$true;$s.Hide()}})
    $w.Add_KeyDown({param($s,$e)if($e.Key-eq [Windows.Input.Key]::Escape){$s.Hide()}})
    $script:settingsTimer=[Windows.Threading.DispatcherTimer]::new();$script:settingsTimer.Interval=[TimeSpan]::FromSeconds(1);$script:settingsTimer.Add_Tick({Update-SettingsWindow});$script:settingsTimer.Start()
  }
  $script:settingsWindow.FindName('Tabs').SelectedIndex=$Tab;Update-WidgetSettingsMenu;$script:settingsWindow.Show();$script:settingsWindow.Activate()|Out-Null;Update-SettingsWindow
  if($Tab-eq 1-and [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-ge [long]$script:providerNextQuery){Start-ProviderUsageQuery}
}
