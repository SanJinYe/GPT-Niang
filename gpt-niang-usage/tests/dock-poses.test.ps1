param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/characters.ps1'),[Text.Encoding]::UTF8)))
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/dock-poses.ps1'),[Text.Encoding]::UTF8)))
function Test-WidgetMusicActive {return $false}
function Sync-WidgetCharacterColors {}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Set-Facing','Get-WidgetLayoutScale','Set-WidgetIndependentLayout')){
 $definition=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst]-and $n.Name-eq $name},$true)
 . ([ScriptBlock]::Create($definition.Extent.Text))
}
$text=[IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8)
$script:window=[Windows.Markup.XamlReader]::Parse($text);$xml=[xml]$text;$script:ui=@{}
foreach($n in $xml.SelectNodes('//*[@*[local-name()="Name"]]')){$name=$n.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$script:ui[$name]=$script:window.FindName($name)}
$script:characterId='gpt-dragon';$script:scale=1.0;$script:bubbleScale=1.0;$script:displayScale=1.0;$script:followHost=$true
$script:hostHandle=$script:widgetHandle=[IntPtr]::Zero;$script:hostFollower=[pscustomobject]@{AllowOutsideHost=$false;AnchorTop=$false;TopOffset=0}
$image=Read-WidgetCharacterImage (Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png')
$script:dockBaseState=@{bitmap=$image;alpha=$image;stride=$image.PixelWidth*4;pixels=$null};$script:bitmap=$image
$work=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$cases=0
foreach($dpi in @(1.0,1.5,2.0)){
 foreach($scale in @(.6,1.0,1.8)){
  $script:scale=$scale;$script:displayScale=[Math]::Max($scale,1.0);Set-WidgetIndependentLayout
  $frame=@{Left=$work.Left+400;Top=$work.Top+50;Right=$work.Right-400;Bottom=$work.Bottom-50}
  $width=$height=378*$script:displayScale*$dpi
  foreach($mode in @('left','right','bottom-left','bottom-right','top-left','top-right','top')){
   $script:dockMode=$mode;$script:dockBottom=200
   $result=Get-WidgetDockPlacement $frame $dpi 400 200 $width $height
   $m=Get-WidgetDockMetrics $dpi
   # Measured eye spacing / longest source-image edge; independent optical landmarks.
   $eyeSpans=@{'side-left'=.215;'side-right'=.215;'bottom-left'=.418;'bottom-right'=.365;'top-left'=.306;'top-right'=.298;'top'=.1925}
   $eyeWidth=[Math]::Max($m.Width,$m.Height)*$eyeSpans[$script:dockPose]
   $referenceEyeWidth=208*$scale*$dpi*.259
   if([Math]::Abs($eyeWidth-$referenceEyeWidth)-gt $referenceEyeWidth*.05){throw 'Pose face scale differs from standard portrait by more than 5 percent'}
   if($mode-eq 'top'){
    if([Math]::Abs($result.Y+$m.Top-$frame.Top)-gt 1){throw 'Top hanger detached'}
   }elseif(Test-WidgetCornerPose $mode){
    $edge=if($mode-like '*-left'){$result.X+$m.Left}else{$result.X+$m.Right}
    $expected=if($mode-like '*-left'){$frame.Left}else{$frame.Right}
    $vertical=if($mode-like 'top-*'){$result.Y+$m.Top-$frame.Top}else{$result.Y+$m.Bottom-$frame.Bottom}
    if([Math]::Abs($edge-$expected)-gt 1 -or [Math]::Abs($vertical)-gt 1){throw 'Corner anchor drift'}
   }else{
    $ax=if($script:dockPose-eq 'side-left'){.906}else{.094}
    $edge=$result.X+$m.Left+$m.Width*$ax;$expected=if($mode-eq 'left'){$frame.Left}else{$frame.Right}
    if([Math]::Abs($edge-$expected)-gt 1){throw 'Hands are detached from vertical frame'}
   }
   if($mode-like 'top*'){
    if(!$script:hostFollower.AnchorTop){throw 'Native top anchoring was not selected'}
    $bubbleTop=[Windows.Controls.Canvas]::GetTop($script:ui.Bubble)
    if($bubbleTop-lt $script:ui.Girl.Height -or $bubbleTop+239*$script:ui.Bubble.LayoutTransform.ScaleY+14-gt $script:designHeight){throw 'Top speech bubble is clipped or covers character'}
   }
   $contentDirection=$script:ui.FacingScale.ScaleX*$script:ui.Girl.LayoutTransform.Value.M11
   if($contentDirection-ne 1){throw 'Dedicated pose artwork was mirrored'}
   $cases++
  }
  $frame.Left=$work.Left;$frame.Right=$work.Right
  foreach($mode in @('left','right')){
   $script:dockMode=$mode;$result=Get-WidgetDockPlacement $frame $dpi 0 0 $width $height
   if(!$script:dockInward){throw 'Screen-edge dock did not select inward pose'}
  }
  $bounds=@{Left=$frame.Left;Right=$frame.Left+200;Top=$frame.Bottom-200;Bottom=$frame.Bottom}
  if((Resolve-WidgetDockMode $frame $bounds $dpi)-ne 'bottom-left'){throw 'Corner must outrank side snapping'}
  $bounds.Left=$frame.Left+100;$bounds.Right=$frame.Left+300;$bounds.Bottom=$frame.Bottom-100
  if((Resolve-WidgetDockMode $frame $bounds $dpi)-ne 'free'){throw 'Center unexpectedly snapped'}
  $bounds=@{Left=$frame.Left+150;Right=$frame.Left+350;Top=$frame.Top;Bottom=$frame.Top+200}
  if((Resolve-WidgetDockMode $frame $bounds $dpi)-ne 'top'){throw 'Top-center release did not snap'}
  $bounds.Left=$frame.Left;$bounds.Right=$frame.Left+200
  if((Resolve-WidgetDockMode $frame $bounds $dpi)-ne 'top-left'){throw 'Top-left corner priority missing'}
  $bounds.Left=$frame.Right-200;$bounds.Right=$frame.Right
  if((Resolve-WidgetDockMode $frame $bounds $dpi)-ne 'top-right'){throw 'Top-right corner priority missing'}
 }
}
$script:dockMode='free';$null=Get-WidgetDockPlacement $frame 1 0 0 378 378
if($script:dockPose-ne 'free' -or $script:ui.Girl.Source-ne $image){throw 'Free mode did not restore base artwork'}
$script:characterId='custom-example';$script:dockMode='left'
if($null-ne (Get-WidgetDockPlacement $frame 1 0 0 378 378)){throw 'Custom character was replaced by dragon art'}
Write-Output ('PASS: '+$cases+' scale/DPI dock alignments, inward fallback, corner priority, identity orientation and free/custom restoration')
if($OutputDirectory){
 [IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
 $script:characterId='gpt-dragon';$script:scale=$script:bubbleScale=$script:displayScale=1.0
 Set-WidgetIndependentLayout
 foreach($name in @('Bubble','Tail','TailNear','MenuButton')){$script:ui[$name].Visibility='Collapsed'}
 foreach($mode in @('left','right','bottom-left','bottom-right','top-left','top-right','top','top-bubble')){
  $script:dockMode=if($mode-eq 'top-bubble'){'top'}else{$mode};$script:dockBottom=280
  foreach($name in @('Bubble','Tail','TailNear')){$script:ui[$name].Visibility=if($mode-eq 'top-bubble'){'Visible'}else{'Collapsed'}}
  $frame=@{Left=400;Top=60;Right=900;Bottom=680}
  $position=Get-WidgetDockPlacement $frame 1 0 0 378 378
  Reset-WidgetDockAnimation
  $preview=[Windows.Controls.Canvas]::new();$preview.Width=1280;$preview.Height=760;$preview.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#242735')
  $hostPanel=[Windows.Controls.Border]::new();$hostPanel.Width=500;$hostPanel.Height=620;$hostPanel.Background=[Windows.Media.Brushes]::WhiteSmoke;$hostPanel.BorderBrush=[Windows.Media.Brushes]::SlateGray;$hostPanel.BorderThickness=[Windows.Thickness]::new(2)
  [Windows.Controls.Canvas]::SetLeft($hostPanel,400);[Windows.Controls.Canvas]::SetTop($hostPanel,60);$preview.Children.Add($hostPanel)|Out-Null
  $view=$script:window.Content;$script:window.Content=$null;$view.Width=378;$view.Height=$script:designHeight
  [Windows.Controls.Canvas]::SetLeft($view,$position.X);[Windows.Controls.Canvas]::SetTop($view,$position.Y);$preview.Children.Add($view)|Out-Null
  $preview.Measure([Windows.Size]::new(1280,760));$preview.Arrange([Windows.Rect]::new(0,0,1280,760));$preview.UpdateLayout()
  $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(1280,760,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($preview)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
  $stream=[IO.File]::Create((Join-Path $OutputDirectory ($mode+'.png')));try{$encoder.Save($stream)}finally{$stream.Dispose()}
  $preview.Children.Remove($view);$script:window.Content=$view
 }
}
