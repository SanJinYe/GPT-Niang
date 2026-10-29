param([string]$OutputDirectory=$env:GPT_NIANG_PREVIEW_DIR)
$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
Initialize-WidgetMusicTypes
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/characters.ps1'),[Text.Encoding]::UTF8)))
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/dock-poses.ps1'),[Text.Encoding]::UTF8)))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
foreach($name in @('Set-Facing','Get-WidgetLayoutScale','Set-WidgetIndependentLayout','Set-WidgetPixelSize')){
 $d=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst]-and $n.Name-eq $name},$true)
 . ([ScriptBlock]::Create($d.Extent.Text))
}
function Get-WidgetPlacementDpi {return 1.0}
function Test-WidgetMusicActive {return [bool]($script:widgetMusic -and $script:widgetMusic.Enabled)}
function Sync-WidgetCharacterColors {}
function Measure-BlueNote($Visual){
 $w=[int][Math]::Ceiling($Visual.ActualWidth);$h=[int][Math]::Ceiling($Visual.ActualHeight)
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new($w,$h,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Visual)
 $pixels=[byte[]]::new($w*$h*4);$bitmap.CopyPixels($pixels,$w*4,0)
 $left=$w;$right=-1;$top=$h;$bottom=-1
 for($i=0;$i-lt $pixels.Length;$i+=4){
  $a=$pixels[$i+3]
  if($a-gt 64 -and [Math]::Abs($pixels[$i+2]*255.0/$a-139)-lt 3 -and [Math]::Abs($pixels[$i+1]*255.0/$a-168)-lt 3 -and [Math]::Abs($pixels[$i]*255.0/$a-212)-lt 3){
   $x=($i/4)%$w;$y=[Math]::Floor(($i/4)/$w);$left=[Math]::Min($left,$x);$right=[Math]::Max($right,$x);$top=[Math]::Min($top,$y);$bottom=[Math]::Max($bottom,$y)
  }
 }
 if($right-lt 0){throw 'Floating note was not rendered'}
 return @{Width=$right-$left+1;Height=$bottom-$top+1}
}
$script:scale=$script:bubbleScale=$script:displayScale=1.0;$script:designWidth=378
$script:characterId='gpt-dragon';$script:followHost=$true;$script:hostHandle=[IntPtr]::Zero
$script:hostFollower=[pscustomobject]@{AllowOutsideHost=$false;AnchorTop=$false;TopOffset=0}
$text=[IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8)
$script:window=[Windows.Markup.XamlReader]::Parse($text);$xml=[xml]$text;$script:ui=@{}
foreach($n in $xml.SelectNodes('//*[@*[local-name()="Name"]]')){$name=$n.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$script:ui[$name]=$script:window.FindName($name)}
$script:window.ShowActivated=$false;$script:window.ShowInTaskbar=$false;$script:window.Left=-5000;$script:window.Top=-5000
foreach($name in @('Bubble','Tail','TailNear','MenuButton')){$script:ui[$name].Visibility='Collapsed'}
$image=Read-WidgetCharacterImage (Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png');$script:bitmap=$image
$script:dockBaseState=@{bitmap=$image;alpha=$image;stride=$image.PixelWidth*4;pixels=$null}
$colors=[Windows.Media.Color[]]@([Windows.Media.Colors]::MediumPurple,[Windows.Media.Colors]::Pink)
$move=[Action[int,int]]{param($x,$y)}
try{
 $script:window.Show();$script:widgetHandle=[Windows.Interop.WindowInteropHelper]::new($script:window).Handle
 if($OutputDirectory){[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null}
 foreach($mode in @('left','right','bottom-left','bottom-right','top-left','top-right','top')){
  $script:dockMode=$mode;$script:dockBottom=200;$script:dockLeft=300
  $frame=@{Left=400;Top=60;Right=1100;Bottom=900}
  $null=Get-WidgetDockPlacement $frame 1 400 200 378 378;Reset-WidgetDockAnimation
  $girl=$script:ui.Girl;$parent=$girl.Parent;$children=$parent.Children.Count
  $script:widgetMusic=[GptMusicVisual]::new($script:window,$girl,$script:ui.Bubble,$move,$colors,$true)
  $music=$script:widgetMusic;$music.Pinned=$true;$music.DockPose=$script:dockPose;$music.SideDock=$script:dockPose-like 'side-*';$music.TopDock=$script:dockPose-eq 'top';$music.LightsEnabled=$false
  $music.Configure($script:widgetHandle,[IntPtr]::Zero,$false,$true,$false,$false,-5000,-5000,0,900,1)
  $null=Get-WidgetDockPlacement $frame 1 400 200 378 $script:designHeight
  $music.Motion.Bend=0;$music.Motion.Rock=0;$music.Redraw();$script:window.UpdateLayout()
  $eyes=[GptMusicVisual]::AccessoryEyes($script:dockPose)
  $ax=switch($script:dockPose){'side-left'{.906};'side-right'{.094};'bottom-left'{0};'top-left'{0};'bottom-right'{1};'top-right'{1};default{.5}}
  $ay=if($mode-like 'top*'){0}elseif($mode-like 'bottom-*'){1}else{.74}
  $fit=[Math]::Min($girl.ActualWidth/$girl.Source.PixelWidth,$girl.ActualHeight/$girl.Source.PixelHeight)
  $point=[Windows.Point]::new(($girl.ActualWidth-$girl.Source.PixelWidth*$fit)/2+$girl.Source.PixelWidth*$fit*$ax,($girl.ActualHeight-$girl.Source.PixelHeight*$fit)/2+$girl.Source.PixelHeight*$fit*$ay)
  $music.Motion.Bend=0;$music.Motion.Rock=0;$music.SetDockAnchor($ax,$ay);$before=$girl.PointToScreen($point)
  $music.Motion.Bend=.4;$music.Motion.Rock=7.5;$music.SetDockAnchor($ax,$ay);$after=$girl.PointToScreen($point)
  if([Math]::Abs($before.X-$after.X)-gt .01 -or [Math]::Abs($before.Y-$after.Y)-gt .01){throw 'Actual image grip moved during dock beat'}
  $music.Motion.Bend=0;$music.Motion.Rock=0;$music.SetDockAnchor($ax,$ay);$music.Redraw()
  if($eyes.Count-ne 2 -or $eyes[0]-eq $eyes[1]){throw 'Missing face accessory landmarks'}
  if($OutputDirectory){
   $stage=$script:window.FindName('AnimationStage');$stage.Measure([Windows.Size]::new(378,$script:designHeight));$stage.Arrange([Windows.Rect]::new(0,0,378,$script:designHeight));$stage.UpdateLayout()
   $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(756,[int]($script:designHeight*2),192,192,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($stage)
   $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render));$stream=[IO.File]::Create((Join-Path $OutputDirectory ($mode+'.png')));try{$encoder.Save($stream)}finally{$stream.Dispose()}
  }
  if($music.Error){throw $music.Error}
  if($mode-eq 'bottom-right'){
   $sizes=@()
   foreach($viewScale in @(.75,1.5)){
    $script:window.Width=378*$viewScale;$script:window.Height=$script:designHeight*$viewScale;$script:window.UpdateLayout()
    $music.Motion.Energy=1;$music.Motion.Bend=if($viewScale-gt 1){.4}else{0};$music.SetDockAnchor(1,1);$music.Redraw();$script:window.UpdateLayout()
    $sizes+=Measure-BlueNote $script:window.Content
   }
   if([Math]::Abs($sizes[0].Width-$sizes[1].Width)-gt 2 -or [Math]::Abs($sizes[0].Height-$sizes[1].Height)-gt 2 -or $sizes[1].Width-gt 15 -or $sizes[1].Height-gt 18){throw ('Notes scaled with the character: '+($sizes|ConvertTo-Json -Compress))}
  }
  $music.Dispose();$script:widgetMusic=$null
  if($parent.Children.Count-ne $children){throw 'Music accessory layers remained after closing music'}
 }
 Write-Output 'PASS: seven accessory poses render and all temporary layers are removed on stop'
}finally{if($script:widgetMusic){$script:widgetMusic.Dispose()};$script:window.Close()}
