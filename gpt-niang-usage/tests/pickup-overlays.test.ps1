$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
Initialize-WidgetMusicTypes
$window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$window.ShowActivated=$false;$window.Left=-5000;$window.Top=-5000;$window.Show()
$girl=$window.FindName('Girl');$girl.Source=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png'))
$colors=[Windows.Media.Color[]]@([Windows.Media.Colors]::Purple,[Windows.Media.Colors]::Violet)
$music=$null
try{
 $music=[GptMusicVisual]::new($window,$girl,$window.FindName('Bubble'),[Action[int,int]]{param($x,$y)},$colors,$true)
 $motion=[GptMusicMotion]::new(100,100,1000,800,208,1)
 $music.GetType().GetProperty('Motion').SetValue($music,$motion,$null)
 $flags=[Reflection.BindingFlags]'Instance,NonPublic'
 $music.GetType().GetField('appearanceReady',$flags).SetValue($music,$true)
 $music.ColorEnabled=$true
 foreach($method in @('DrawUnder','DrawOver')){
   $motion.BeginHold();$motion.Props=1
   $drawing=[Windows.Media.DrawingGroup]::new();$dc=$drawing.Open()
   try{$music.GetType().GetMethod($method,$flags).Invoke($music,@($dc))|Out-Null}finally{$dc.Close()}
   if($drawing.Children.Count){throw "$method retained old music art during pickup"}
   $motion.Release();$motion.Props=1
   $normal=[Windows.Media.DrawingGroup]::new();$dc=$normal.Open()
   try{$music.GetType().GetMethod($method,$flags).Invoke($music,@($dc))|Out-Null}finally{$dc.Close()}
   if(!$normal.Children.Count){throw "$method failed to resume after release"}
 }
 'PASS: held sprite suppresses both music redraw layers; release restores them'
}finally{if($music){$music.Dispose()};$window.Close()}
