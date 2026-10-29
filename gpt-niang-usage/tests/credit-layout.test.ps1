param([string]$PreviewPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root=Split-Path $PSScriptRoot -Parent
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root 'runtime/settings-window.ps1'),[Text.Encoding]::UTF8)))
$record=@{provider='openrouter';kind='openrouter';status='ok';keyLimit=@{status='ok';limit=10;remaining=6;usage=999};credits=@{status='ok';remaining=38.5}}
$view=Get-CreditView $record
if($view.percent-ne 40-or $view.usage-notmatch '\$4 / \$10'-or $view.balance-ne '总余额：$38.5'){throw 'Key window consumption must stay separate from lifetime usage and account balance'}
$panel=New-CreditPanel $view
$window=[Windows.Window]::new();$window.Width=420;$window.Height=510;$window.Background=[Windows.Media.Brushes]::White
$body=[Windows.Controls.StackPanel]::new();$body.Margin=[Windows.Thickness]::new(24);$window.Content=$body;$body.Children.Add($panel)|Out-Null
$record.keyLimit.limit=$null;$record.keyLimit.usage=7
$unlimited=Get-CreditView $record
if($null-ne $unlimited.percent-or $unlimited.limit-notmatch '未设限额'-or $unlimited.usage-notmatch '\$7'){throw 'Unlimited must not invent a percentage'}
$body.Children.Add((New-CreditPanel $unlimited))|Out-Null
$record.keyLimit.limit=0;$record.keyLimit.remaining=0
if($null-ne (Get-CreditView $record).percent){throw 'Zero limit cannot divide by zero'}
$missing=Get-CreditView @{provider='deepseek';kind='balance';status='ok';balances=@(@{currency='CNY';remaining='12.5'})}
if($missing.limit-notmatch '未提供'-or $null-ne $missing.percent-or $missing.balance-ne '总余额：12.5 CNY'){throw 'Balance-only API must not invent key data'}
$body.Children.Add((New-CreditPanel $missing))|Out-Null
try{
 $window.Show();$window.UpdateLayout()
 $bar=$panel.Children[2];$bar.ApplyTemplate()|Out-Null;$window.UpdateLayout()
 $indicator=$bar.Template.FindName('PART_Indicator',$bar)
 if([Math]::Abs($indicator.ActualWidth/$bar.ActualWidth-.4)-gt .02){throw 'Rendered bar does not match 40 percent consumption'}
 if($PreviewPath){$png=[Windows.Media.Imaging.PngBitmapEncoder]::new();$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new(420,510,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($window);$png.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$stream=[IO.File]::Create($PreviewPath);try{$png.Save($stream)}finally{$stream.Dispose()}}
 'PASS: key limit, current-period usage bar, total balance, unlimited, zero and missing fields'
}finally{$window.Close()}
