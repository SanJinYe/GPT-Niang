$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root=Split-Path $PSScriptRoot -Parent
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root 'runtime/settings-window.ps1'),[Text.Encoding]::UTF8)))
$source=[IO.File]::ReadAllText((Join-Path $root 'widget.ps1'),[Text.Encoding]::UTF8);$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Next-Bubble','Click-Character','Show-Quota','Apply-Scene')){$def=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst]-and $n.Name-eq $name},$true);. ([scriptblock]::Create($def.Extent.Text))}
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $root 'widget.xaml'),[Text.Encoding]::UTF8));$script:ui=@{}
foreach($name in @('CodexPanel','ArkPanel','Header','QuotaText','QuoteText','Refresh','LiveDot')){$script:ui[$name]=$script:window.FindName($name)}
function Set-WidgetSceneLayout {}
function Update-BubbleTooltip {}
function Restart-SceneTtl {}
function Request-Refresh {}
function Request-ProviderBubble {$script:requests++}
function Open-WidgetBubble($mode){$script:collapsed=$false;$script:bubbleMode=$mode;Apply-Scene}
function Switch-Scene($mode){$script:bubbleMode=$mode;Apply-Scene}
function Hide-Quota {$script:collapsed=$true}
function Get-ProviderSettings {return $script:testProviders}
foreach($ids in @(@(),@('ark'),@('ark','openrouter','anthropic'),@('openrouter','ark'))){
 $script:testProviders=@($ids|ForEach-Object{[pscustomobject]@{id=$_;name=$_;enabled=$true}});$script:collapsed=$true
 Click-Character
 if($script:quotaProvider-ne 'Codex'){throw 'First click must be Codex'}
 foreach($id in $ids){Click-Character;if($script:quotaProvider-ne $id-or $script:bubbleMode-ne 'quota'){throw "Missing page $id"}}
 Click-Character;if($script:bubbleMode-ne 'quote'){throw 'Quote/lyrics must follow the final provider'}
 Click-Character;if(!$script:collapsed){throw 'Last click must close'}
}
$script:testProviders=@([pscustomobject]@{id='ark';enabled=$false})
if(@(Get-QuotaPageIds).Count-ne 1){throw 'Disabled sources must not be paged'}
$r=[pscustomobject]@{kind='openrouter';credits=@{status='ok';remaining=8.5};keyLimit=@{status='ok';limit=10;remaining=0}}
if((Get-CreditView $r).percent-ne 100){throw 'Zero remaining must show a fully consumed bar'}
$r.keyLimit.limit=$null;if((Format-ProviderBubble $r)-notmatch '未设限额'){throw 'Null key limit must be unlimited'}
$script:window.Close()
'PASS: zero, one, multiple, disabled, reordered source cycles; quote last; zero and unlimited limits'
