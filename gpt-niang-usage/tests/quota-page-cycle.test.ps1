$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$source=[IO.File]::ReadAllText((Join-Path $root 'widget.ps1'),[Text.Encoding]::UTF8)
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Next-Bubble','Click-Character','Show-Quota','Apply-Scene')){
 $def=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
 . ([ScriptBlock]::Create($def.Extent.Text))
}
$text=[IO.File]::ReadAllText((Join-Path $root 'widget.xaml'),[Text.Encoding]::UTF8)
$view=[Windows.Markup.XamlReader]::Parse($text);$xml=[xml]$text;$script:ui=@{}
foreach($n in $xml.SelectNodes('//*[@*[local-name()="Name"]]')){$name=$n.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$script:ui[$name]=$view.FindName($name)}
function Set-WidgetSceneLayout {}
function Update-BubbleTooltip {}
function Restart-SceneTtl {}
function Request-Refresh {}
function Open-WidgetBubble($Mode){$script:collapsed=$false;$script:bubbleMode=$Mode;Apply-Scene}
function Switch-Scene($Mode){$script:bubbleMode=$Mode;Apply-Scene}
function Hide-Quota {$script:collapsed=$true}
foreach($legacySetting in @($false,$true)){
 $script:bubbleTapAdvance=$legacySetting;$script:collapsed=$true;$script:quotaProvider='Ark'
 Click-Character
 if($script:quotaProvider-ne 'Codex' -or $script:ui.CodexPanel.Visibility-ne 'Visible' -or $script:ui.ArkPanel.Visibility-ne 'Collapsed'){throw 'First click is not exclusively Codex'}
 Click-Character
 if($script:quotaProvider-ne 'Ark' -or $script:ui.ArkPanel.Visibility-ne 'Visible' -or $script:ui.CodexPanel.Visibility-ne 'Collapsed'){throw 'Second click is not exclusively Ark'}
 Click-Character
 if($script:bubbleMode-ne 'quote' -or $script:ui.QuoteText.Visibility-ne 'Visible'){throw 'Third click is not the preset quote'}
 Click-Character
 if(!$script:collapsed){throw 'Fourth click did not close'}
 Click-Character
 if($script:quotaProvider-ne 'Codex'){throw 'Cycle failed to restart at Codex'}
 Next-Bubble
 if($script:quotaProvider-ne 'Ark'){throw 'Bubble click differs from character click'}
 Show-Quota
 if($script:quotaProvider-ne 'Codex' -or $script:ui.CodexPanel.Visibility-ne 'Visible'){throw 'Menu quota command did not restore Codex'}
}
Write-Output 'PASS: character/bubble cycle, exclusive panels, close/reopen, menu reset, both legacy preferences'
